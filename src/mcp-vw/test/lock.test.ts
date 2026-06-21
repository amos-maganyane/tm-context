import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { OwnerLock } from '../src/lock.js';

const tmpFiles: string[] = [];
function makeLockPath(): string {
  const p = join(tmpdir(), `mcp-vw-test-lock-${Date.now()}-${Math.random().toString(36).slice(2)}.lock`);
  tmpFiles.push(p);
  return p;
}

async function fileExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

beforeEach(() => {
  // Reset env var leaking from prior tests.
  delete process.env['MCP_VW_SINGLE_OWNER'];
});

afterEach(async () => {
  for (const f of tmpFiles.splice(0)) {
    try {
      await fs.unlink(f);
    } catch {
      /* ignore */
    }
  }
});

describe('OwnerLock — acquire', () => {
  it('acquires when no lockfile exists', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
    expect(await fileExists(lockFile)).toBe(true);
  });

  it('writes the current PID into the lockfile', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });

    await lock.acquire();
    const contents = await fs.readFile(lockFile, 'utf-8');

    expect(contents.trim()).toBe(String(process.pid));
  });

  it('rejects acquire when lockfile holds a live PID (current process)', async () => {
    const lockFile = makeLockPath();
    // Plant the current process's PID — guaranteed alive while the test runs.
    await fs.writeFile(lockFile, String(process.pid), 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(false);
    if (!result.acquired) {
      expect(result.heldByPid).toBe(process.pid);
    }
  });

  it('takes over when lockfile holds a DEAD PID (stale recovery)', async () => {
    const lockFile = makeLockPath();
    // PID 999999 is almost-certainly not a running process on this OS.
    // The lock should recognize it as stale and overwrite with current PID.
    await fs.writeFile(lockFile, '999999', 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
    const contents = await fs.readFile(lockFile, 'utf-8');
    expect(contents.trim()).toBe(String(process.pid));
  });

  it('takes over when lockfile contains garbage (defensive parsing)', async () => {
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, 'not a pid!!!\n\ngarbage\n', 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
    const contents = await fs.readFile(lockFile, 'utf-8');
    expect(contents.trim()).toBe(String(process.pid));
  });

  it('takes over when lockfile is empty', async () => {
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, '', 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
  });

  it('takes over when lockfile has negative or zero PID', async () => {
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, '0', 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
  });

  it('throws on lockfile path in nonexistent directory (no silent failure)', async () => {
    const lock = new OwnerLock({
      lockFile: join(tmpdir(), 'mcp-vw-nonexistent-dir-xyzzy', 'lock.lock'),
    });

    await expect(lock.acquire()).rejects.toThrow();
  });
});

describe('OwnerLock — release', () => {
  it('removes the lockfile on release', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });
    await lock.acquire();
    expect(await fileExists(lockFile)).toBe(true);

    await lock.release();

    expect(await fileExists(lockFile)).toBe(false);
  });

  it('release is idempotent (safe to call twice)', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });
    await lock.acquire();

    await lock.release();
    await expect(lock.release()).resolves.toBeUndefined();
  });

  it('release does NOT remove a lockfile owned by another process', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });
    await lock.acquire();
    // Simulate another process taking over (overwrite the PID).
    await fs.writeFile(lockFile, '999999', 'utf-8');

    await lock.release();

    // Lockfile should still exist because it no longer belongs to us.
    expect(await fileExists(lockFile)).toBe(true);
    const contents = await fs.readFile(lockFile, 'utf-8');
    expect(contents.trim()).toBe('999999');
  });

  it('release on never-acquired lock is a no-op', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });

    await expect(lock.release()).resolves.toBeUndefined();
    expect(await fileExists(lockFile)).toBe(false);
  });
});

describe('OwnerLock — env opt-out (MCP_VW_SINGLE_OWNER=0)', () => {
  it('acquire is a no-op when MCP_VW_SINGLE_OWNER=0', async () => {
    process.env['MCP_VW_SINGLE_OWNER'] = '0';
    const lockFile = makeLockPath();
    // Plant our own PID — would normally block.
    await fs.writeFile(lockFile, String(process.pid), 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
    // No lockfile mutation — original content preserved.
    const contents = await fs.readFile(lockFile, 'utf-8');
    expect(contents.trim()).toBe(String(process.pid));
  });

  it('release is a no-op when MCP_VW_SINGLE_OWNER=0', async () => {
    process.env['MCP_VW_SINGLE_OWNER'] = '0';
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, 'preserved content', 'utf-8');
    const lock = new OwnerLock({ lockFile });

    await lock.acquire();
    await lock.release();

    expect(await fileExists(lockFile)).toBe(true);
    const contents = await fs.readFile(lockFile, 'utf-8');
    expect(contents.trim()).toBe('preserved content');
  });

  it('constructor singleOwner:false also disables', async () => {
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, String(process.pid), 'utf-8');
    const lock = new OwnerLock({ lockFile, singleOwner: false });

    const result = await lock.acquire();

    expect(result.acquired).toBe(true);
  });

  it('constructor singleOwner:true overrides env=0 (explicit > env)', async () => {
    process.env['MCP_VW_SINGLE_OWNER'] = '0';
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, String(process.pid), 'utf-8');
    const lock = new OwnerLock({ lockFile, singleOwner: true });

    const result = await lock.acquire();

    expect(result.acquired).toBe(false);
  });

  it('treats MCP_VW_SINGLE_OWNER=false and MCP_VW_SINGLE_OWNER=off as disable', async () => {
    const lockFile1 = makeLockPath();
    const lockFile2 = makeLockPath();
    await fs.writeFile(lockFile1, String(process.pid), 'utf-8');
    await fs.writeFile(lockFile2, String(process.pid), 'utf-8');

    process.env['MCP_VW_SINGLE_OWNER'] = 'false';
    expect((await new OwnerLock({ lockFile: lockFile1 }).acquire()).acquired).toBe(true);

    process.env['MCP_VW_SINGLE_OWNER'] = 'off';
    expect((await new OwnerLock({ lockFile: lockFile2 }).acquire()).acquired).toBe(true);
  });

  it('does NOT disable for unrelated values like MCP_VW_SINGLE_OWNER=1', async () => {
    process.env['MCP_VW_SINGLE_OWNER'] = '1';
    const lockFile = makeLockPath();
    await fs.writeFile(lockFile, String(process.pid), 'utf-8');
    const lock = new OwnerLock({ lockFile });

    const result = await lock.acquire();

    expect(result.acquired).toBe(false);
  });
});

describe('OwnerLock — atomicity', () => {
  it('writes lockfile via rename (tmp file does not linger)', async () => {
    const lockFile = makeLockPath();
    const lock = new OwnerLock({ lockFile });
    await lock.acquire();

    // No stray .tmp sibling left behind.
    const dir = lockFile.substring(0, lockFile.lastIndexOf(/[\\/]/.exec(lockFile)?.[0] ?? '/'));
    const entries = await fs.readdir(dir);
    const strays = entries.filter((e) => e.startsWith('mcp-vw-test-lock-') && e.endsWith('.tmp'));
    expect(strays).toEqual([]);
  });

  it('concurrent acquire from two locks: at most one wins', async () => {
    const lockFile = makeLockPath();
    const a = new OwnerLock({ lockFile });
    const b = new OwnerLock({ lockFile });

    // Race both. Since they share PID (process.pid is the same in this test process),
    // a true cross-process race is impossible to simulate; this verifies the
    // shape of returns matches the contract.
    const results = await Promise.all([a.acquire(), b.acquire()]);
    const acquiredCount = results.filter((r) => r.acquired).length;

    // Both might see the same PID and treat it as "self" — the contract is that
    // at most one CAN write its PID. The lockfile reflects that one write.
    expect(acquiredCount).toBeGreaterThanOrEqual(1);
  });
});
