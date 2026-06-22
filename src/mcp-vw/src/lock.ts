/**
 * lock.ts — Single-owner enforcement via lockfile + PID + stale-PID recovery.
 *
 * Goal: prevent two `mcp-vw` instances from speaking on the same stdio channel
 * to the same VW Runtime API. Claude Desktop on Windows MSIX has historically
 * spawned duplicate MCP servers; this guard catches that.
 *
 * Pattern (knowledge-rag MCP servers, [04 §3.2]):
 *
 *   acquire():
 *     1. Try to write lockfile atomically via tmp + rename.
 *     2. If lockfile already exists, read it and parse the PID.
 *        - PID matches current process (already held by us) → reject.
 *        - PID is alive (another process) → reject with the holder PID.
 *        - PID is dead / garbage / negative / zero → take over (overwrite).
 *
 *   release():
 *     - Only delete the lockfile if its PID is still ours.
 *     - Don't trip another process that has taken over since.
 *
 * Caller is responsible for exiting with code 75 (EX_TEMPFAIL) on rejection
 * per architecture.md §9. We don't `process.exit` here — testable.
 *
 * Opt-out: `MCP_VW_SINGLE_OWNER=0` (or `=false` / `=off`) disables the guard.
 * Useful for dev workflows running tests against the bridge in parallel.
 * Explicit constructor flag `singleOwner: true` overrides env opt-out.
 */

import { promises as fs } from 'node:fs';
import { dirname } from 'node:path';
import { randomBytes } from 'node:crypto';

export type AcquireResult =
  | { acquired: true }
  | { acquired: false; heldByPid: number };

interface OwnerLockOptions {
  lockFile: string;
  /**
   * Explicit override of the single-owner guard:
   *   - `true`  → always enforce (ignore env)
   *   - `false` → never enforce (no-op)
   *   - omitted → defer to `MCP_VW_SINGLE_OWNER` env var (default ON)
   */
  singleOwner?: boolean;
}

export class OwnerLock {
  private readonly lockFile: string;
  private readonly explicitSingleOwner: boolean | undefined;

  constructor(opts: OwnerLockOptions) {
    this.lockFile = opts.lockFile;
    this.explicitSingleOwner = opts.singleOwner;
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /**
   * Attempt to acquire the lock.
   * Returns `{acquired: true}` on success or stale-recovery overwrite.
   * Returns `{acquired: false, heldByPid: N}` when another live process holds it.
   * Throws only on unrecoverable filesystem errors (e.g. lockfile parent dir missing).
   *
   * Handles the Windows race where two processes both observe "no lockfile"
   * then both try to write — on Windows `fs.rename` to an existing file fails
   * with EPERM/EEXIST. We catch that, re-read the holder, and surface cleanly.
   */
  async acquire(): Promise<AcquireResult> {
    if (!this.isEnforcing()) {
      return { acquired: true };
    }

    // Two attempts: optimistic write, plus one retry after a rename-race.
    for (let attempt = 0; attempt < 2; attempt++) {
      const holder = await this.readHolderPid();
      if (holder !== null && this.isProcessAlive(holder)) {
        // Active holder. Even if `holder === process.pid` we surface as held —
        // means "we already initialized this lock", which is a bug to surface.
        return { acquired: false, heldByPid: holder };
      }

      // No holder OR holder is stale/garbage. Try atomic write.
      try {
        await this.writeLockFileAtomic(String(process.pid));
        return { acquired: true };
      } catch (err) {
        const code = (err as NodeJS.ErrnoException | null)?.code;
        // Windows rename race: another process wrote the lockfile between
        // our readHolderPid() and our rename(). Re-read + retry once.
        if (
          attempt === 0 &&
          (code === 'EPERM' || code === 'EEXIST' || code === 'EACCES')
        ) {
          continue;
        }
        throw err;
      }
    }

    // Defensive: loop always returns or throws above.
    // Reached only if the race-retry itself raced again, which is vanishingly rare.
    const holder = await this.readHolderPid();
    return { acquired: false, heldByPid: holder ?? -1 };
  }

  /**
   * Release the lock IF it still belongs to us (PID matches).
   * Safe to call on a never-acquired lock or after another process took over.
   */
  async release(): Promise<void> {
    if (!this.isEnforcing()) {
      return;
    }

    const holder = await this.readHolderPid();
    if (holder !== process.pid) {
      // Lockfile gone, or taken over by another process — do NOT delete.
      return;
    }

    try {
      await fs.unlink(this.lockFile);
    } catch (err) {
      // Already gone is fine; anything else propagates.
      if (!isNotFoundError(err)) throw err;
    }
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  /**
   * Decide whether to enforce based on:
   *   1. Explicit `singleOwner` constructor flag (highest precedence)
   *   2. `MCP_VW_SINGLE_OWNER` env var (`0`/`false`/`off` disable; anything else enables)
   *   3. Default: enabled
   */
  private isEnforcing(): boolean {
    if (this.explicitSingleOwner !== undefined) {
      return this.explicitSingleOwner;
    }
    const envValue = process.env['MCP_VW_SINGLE_OWNER'];
    if (envValue === undefined) return true;
    const normalized = envValue.trim().toLowerCase();
    if (normalized === '0' || normalized === 'false' || normalized === 'off' || normalized === 'no') {
      return false;
    }
    return true;
  }

  /**
   * Read the lockfile and parse the PID inside.
   * Returns `null` if file doesn't exist OR contains unparseable / invalid (<=0) content.
   */
  private async readHolderPid(): Promise<number | null> {
    let raw: string;
    try {
      raw = await fs.readFile(this.lockFile, 'utf-8');
    } catch (err) {
      if (isNotFoundError(err)) return null;
      throw err;
    }
    const trimmed = raw.trim();
    if (!trimmed) return null;
    const pid = Number.parseInt(trimmed, 10);
    if (!Number.isFinite(pid) || pid <= 0) return null;
    return pid;
  }

  /**
   * Probe whether a PID is live by sending signal 0 (no-op signal).
   * - On Linux/macOS: standard POSIX behavior; throws ESRCH if process is dead.
   * - On Windows: Node maps to OpenProcess + checks existence; throws on dead PID.
   * - EPERM (caller lacks permission) means the process EXISTS but we can't signal
   *   it — that's still "alive" for our purposes.
   */
  private isProcessAlive(pid: number): boolean {
    try {
      process.kill(pid, 0);
      return true;
    } catch (err) {
      const code = (err as NodeJS.ErrnoException).code;
      // EPERM = process exists but signal denied. Treat as alive.
      if (code === 'EPERM') return true;
      // ESRCH = no such process. Stale.
      return false;
    }
  }

  /**
   * Write `content` to `lockFile` atomically via tmp + rename.
   * Rename is atomic on every modern filesystem; ensures no half-written lockfile.
   *
   * The tmp filename embeds PID + ms + random suffix so concurrent acquires
   * from the same process (e.g. two `OwnerLock` instances) never collide on tmp.
   */
  private async writeLockFileAtomic(content: string): Promise<void> {
    const suffix = randomBytes(6).toString('hex');
    const tmpFile = `${this.lockFile}.tmp.${process.pid}.${Date.now()}.${suffix}`;
    await fs.writeFile(tmpFile, content, 'utf-8');
    try {
      await fs.rename(tmpFile, this.lockFile);
    } catch (err) {
      // Best-effort cleanup of the tmp file on rename failure.
      try {
        await fs.unlink(tmpFile);
      } catch {
        /* ignore secondary failure */
      }
      // Only attribute ENOENT to a missing parent when the parent really IS missing.
      if (isNotFoundError(err)) {
        const parent = dirname(this.lockFile);
        const parentExists = await pathExists(parent);
        if (!parentExists) {
          throw new Error(
            `OwnerLock: cannot create lockfile at ${this.lockFile} — parent directory ${parent} does not exist. ` +
              `Create the directory first or pick a different lockFile path.`
          );
        }
      }
      throw err;
    }
  }
}

function isNotFoundError(err: unknown): boolean {
  return (err as NodeJS.ErrnoException | null)?.code === 'ENOENT';
}

async function pathExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}
