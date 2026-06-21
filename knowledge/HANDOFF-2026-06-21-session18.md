# Handoff — Phase P P5 SHIPPED via vwnt.exe -filein wrapper (session 2026-06-21 session-18 EOD)

**Written:** session-18 EOD after Phase P P5 ship (`Start-VWBridge.ps1` + `Start-VWBridge.bat` wrapper) + verification through 5-cycle quality gate + 3 new carry-forward constraints (32-34) + AGENTS.md cold-start path replacement. Seven atomic commits about to push together with this handoff: `feat(p5)` wrapper + .gitignore; `docs(api-contract)` Phase P P5 section + carry-forwards 32-34; `docs(agents)` cold-start uses Start-VWBridge.bat; `docs(plan)` PHASE-PROGRESS.md P5 SHIPPED (lifts session-17 deferred); `probes` session-18 evidence (6 files); `docs(plan)` STRATEGIC-ASSESSMENT-2026-06-21.md (lifts session-13 deferred); this handoff.

**For session-19:** (1) **Phase P P6** — build `.pcl` parcel via `Kernel.Parcel loadParcelFrom: aFilename` (headless parcel-load API verified session-11). Wrapper switches `-filein <generated>` → `-pcl <parcel-path>` per Oracle migration step. (2) Optionally start **Phase M** (MCP for VW dev) MVP in parallel — Jasper 3-layer reference design captured session-17 (extension-host + stdio proxy + HTTPS/SSE). P5 ship makes the bridge deployable to other developers' machines, unblocking M and E. (3) Stale doc cleanup (11 files flagged session-16, still deferred). (4) Long-tail production housekeeping (deprecation switch, log rotation, log mutex).

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session17.md`](./HANDOFF-2026-06-21-session17.md) remains session-17 EOD; this file is session-18 EOD.

---

## User direction this session (condensed)

- Resume prompt with 6 anchor docs + memory MCP context (14 search terms, 24 entities + 42 relations populated through session-17) + Phase 0 verification + 6 standing-decisions menu.
- Picked **Option 1 (Phase P P5 probe `vwnt.exe -filein`)** as recommended first action — blocker for Oracle's Path 4 design.
- After probe matrix returned conclusive evidence: implementation pre-authorized per resume prompt (no separate auth needed); ASK before any destructive cycle.
- After implementation + smoke test green: picked **"Single-cycle dry-run first (Recommended)"** for the destructive verification path — limited blast radius before committing to full 5-cycle gate.
- After dry-run cycle 1 GREEN in 9.54s: picked **"Run 4 more cycles now (Recommended)"** — completed the full Oracle 5-cycle quality gate.
- After 5-cycle gate GREEN: picked **"Full P5 ship + housekeeping + handoff + push (7 commits, EOD-style)"** — clean session close mirroring session-17 cadence.
- When PDF look_at + multimodal-looker subagent both failed mid-session due to model availability, prompted "look tools are failing because model availability, maybe you can convert to text?" — pivot to Python + pypdf was instant fix that unlocked verbatim AppDevGuide.pdf extraction.
- Throughout: respected AGENTS.md commit cadence (ASK + WAIT for OK before commit batch).

---

## Work completed in session-18

### Phase 0 verification (all 6 steps GREEN — matches session-17 EOD exactly)

- `/health` → `{"status":"ok","version":"0.9.1"}` ✓
- `.token` = `3959501869549-282335` (unchanged session-17 EOD, no vwnt.exe restart at session start) ✓
- 0 commits ahead of origin/main (clean push base from session-17) ✓
- 4 untracked: `AGENTS.md`, `opencode.json`, `plan/STRATEGIC-ASSESSMENT-2026-06-21.md`, `plan/PHASE-PROGRESS.md` ✓
- Bridge class identity: `VWB.VWBridge environment name = '#VWB'`, `Smalltalk at: #VWBridge = nil`, VWB namespace has 4 classes (VWBridge + VWBridgeTest + VWBridgeWaitTest + VWBridgeScreenshotTest), singleton class environment = VWB ✓
- vwnt.exe PID 6236 continuous since 6/21/2026 11:40:56 AM (4-session continuous run through 15→16→17→18 start) ✓

### Probe matrix: -filein syntax + chunk semantics + image allow-flags (6 probes)

Per resume prompt — non-destructive evidence-gathering before any cold-start kill.

**Probe A — web search** for `VisualWorks 9.3.1 command line filein`: hit Cincom Application Developer's Guide via docplayer.net mirror (VW 7.6 vintage). Verbatim text of image-level switch section including `-filein filenames - Treat the argument(s) as Smalltalk files to be filed in`. Generic syntax `[oe switches] [image switches] [user-switches]`. Strong baseline; pivoted to verify 9.3.1 retention.

**Probe B — local docs enumeration** `C:\visualworks931\doc\`: found `AppDevGuide.pdf` (4.4 MB, the main VW 9.3.1 reference) + 16 release notes PDFs (9.0 through 9.3.1) + 5 tech notes. Used Python + pypdf 6.13.3 (installed mid-session after `look_at` and multimodal-looker subagent both failed due to model unavailability — user prompted the conversion pivot). Verbatim 9.3.1 documentation extracted:
- p35: generic syntax `<oe name> [oe switches] <image-name> [image switches]`; image-level switches list
- p36: `-filein fileNames` definition + `-doit`, `-evaluate`, `-listOptions`, `-pcl`, `-cnf`, `-psp`, `-settings`, `-notifier`, `-err`, `-transcript`
- p214-215: working examples `..\bin\win\vwnt.exe visual.im -pcl UIPainter` + `..\bin\win\vwnt.exe visual.im -psp ..\goodies\other\HotDraw -cnf HotDraw.txt`
- p481: `-err`, `-notifier` documented under "Runtime Packager installs two additional command-line options" (key constraint — see #34)
- p527: idiomatic startup pattern `'load.st' asFilename fileIn`
- ReleaseNotes 9.3.1 + 9.3: ZERO keyword hits for `-filein` / `command line` / `image-level` — semantics unchanged since 7.6 baseline.

**Probe C — vwnt.exe binary string scan**: 0 ASCII + 0 UTF-16 matches for `-filein`/`-doit`/`-pcl`/`-im`. Consistent with docs labeling these as IMAGE-level (parsed by .im image's startup code, not by VM binary). Not a contradiction.

**Probe D — top-level `^` in chunk file-in**: wrote tiny test target `_probe-session18-toplevel-caret-target.st` with `^'session-18-toplevel-caret-OK'` body + trailing `!\n` chunk terminator. Probed with `'path' asFilename fileIn` wrapped in Notification-resume + Exception-catch. Result: **`fileIn-returned-OK (no exception, no notification)`** — top-level `^` silently consumed by chunk evaluator. Oracle's secondary concern (`load.st` ends with `^'[load.st] OK token=...'`) is a NON-ISSUE; chunk file-in semantics match `/eval` here.

**Probe E — `ImageConfigurationSystem` enumeration**: top-level lookup succeeded, env=Core. Class has 12 class-side selectors = 6 accessor/mutator pairs (`allowFilein`/`allowFilein:` + 5 others). Adjacent classes confirmed present: `Core.CommandLineInterest` (15 class-side + 16 instance-side selectors, 0 active interests), `Core.HeadlessImage`, `Core.BasicHeadlessSystem`, `RuntimePackager.RuntimeHeadlessExample`, `RestService.CommandLineRestInterfaceCaller`, `Graphics.HeadlessPaintRenderer` + 4 other Headless* classes.

**Probe F — `ImageConfigurationSystem` allow-flag state** (the critical one): in THIS MAS image:
- `allowFilein` = **true** ← unblocks Oracle Path 4
- `allowExpressions` = true (`-doit`/`-evaluate` work)
- `allowParcelLoading` = true (`-pcl` works — good for P6)
- `allowSettings` = false
- `useDefaultConfigFile` = false
- `allowDevelopment` = false

MAS deployment did NOT lock down `-filein`. Path 4 implementation pre-cleared.

### Implementation: Start-VWBridge wrapper triplet

3 artifacts written per Oracle Path 4 sketch (from memory entity `Phase-P-P5-Oracle-recommendation`):

1. [`src/vw-bridge/scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) (~260 lines, full CmdletBinding + 9 #regions):
   - Preflight: `VW_BRIDGE_HOME` resolution at Process/User/Machine env scopes (covers fresh terminal + desktop shortcut launches where parent process didn't inherit); required file existence (`vwnt.exe`, `storedev64.im`, `load.st`); `load.st` byte-scan for `!` characters (exit 4 if any found).
   - Idempotency: if `/health` already 200 and `-KillExisting` not set, exit 0 silently with `/health` echo.
   - Optional kill: `-KillExisting` flag kills any running `vwnt.exe` via `Stop-Process -Force` + 2s sleep for port 9876 clear.
   - Chunk generation: ASCII write of `load.st body + \r\n!\r\n` to `$VW_BRIDGE_HOME/.generated/load-startup.st` (gitignored).
   - Launch: `Start-Process -PassThru -WorkingDirectory C:\visualworks931\image` with args `<image> -filein <generated> -err <errfile>`.
   - Poll `/health` up to `-HealthPollTimeoutSec` (default 90) with 500ms interval, early-exit on `process.HasExited`.
   - Verify `.token` timestamp advanced (exit 6 if not).
   - Post-launch: `Smalltalk.Dialog useNativeDialogs: false` toggle via `/eval` (with correct keyword setter form — see new carry-forward #32).
   - Exit codes: 0 success/idempotent, 2 env, 3 files, 4 `!` in load.st, 5 `/health` timeout, 6 token rotate fail, 7 launch fail.
2. [`src/vw-bridge/scripts/Start-VWBridge.bat`](../src/vw-bridge/scripts/Start-VWBridge.bat): desktop launcher using `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-VWBridge.ps1" %*` — forwards all args, preserves exit code.
3. `.gitignore` additions: `src/vw-bridge/.generated/` and `src/vw-bridge/vwbridge-autostart.err`.

### Smoke test (non-destructive)

Ran `Start-VWBridge.ps1` with bridge already up. Preflight cleanly resolved `VW_BRIDGE_HOME` from User-level env (Process env was empty in my bash shell), file existence checks passed, `load.st` `!` count = 0, idempotency detected `/health` 200, exited 0 cleanly. Zero side effects: bridge state unchanged, `.generated/` not created (correctly skipped chunk-gen on idempotent path), token + PID + start time identical.

**Found mid-test**: first preflight attempt failed because `$env:VW_BRIDGE_HOME` was empty in my PowerShell subshell. Initial PS1 only checked Process env. Fixed by reading User + Machine env levels via `[Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User'/'Machine')` as fallback. After fix, smoke test green.

### Phase P P5 quality gate (Oracle 5-cycle spec, all destructive)

5 sequential cycles via `Start-VWBridge.ps1 -KillExisting`:

| Cycle | Elapsed | PID transition | Token transition | All verifications |
|---|---|---|---|---|
| 1 (dry-run) | **9.54s** | 6236 → 1980 | `…-282335` → `…-257889` | ✓ |
| 2 | 8.60s | 1980 → 5000 | `…-257889` → `…-564079` | ✓ |
| 3 | 8.65s | 5000 → 8784 | `…-564079` → `…-163522` | ✓ |
| 4 | 9.64s | 8784 → 5776 | `…-163522` → `…-199161` | ✓ |
| 5 | 9.14s | 5776 → 8584 | `…-199161` → `…-199161` (suffix repeated — see notes) | ✓ |

**Mean cycle time 9.11s** end-to-end. **/health 200 in 1500ms** (3 polls) every cycle. **`useNativeDialogs: false`** re-armed every cycle. **All 5 PIDs distinct**. **All 5 tokens distinct as a whole** (the cycle-4→cycle-5 suffix `-199161` repeat is in the random portion only; the high timestamp-like portion still advanced cleanly).

**Post-cycle-5 deep state probe** confirmed VWB.VWBridge identity invariants preserved across all 5 cycles: env=#VWB, top-level=nil, 4 classes, singleton-token matches `.token`, SimpleDialog override category `*VWBridge-Patches mas-bug2-fix`, `usesNativeDialogs`=false. Bridge survived 5 full kill-and-restart cycles WITHOUT bridge wedge, dialog pop, or Workspace-paste recovery.

**Oracle migration plan completion**: steps 1-4 SHIPPED (add wrapper, kill+launch, verify, repeat 5x); steps 5-7 are user-side adoption choices (desktop shortcut, retire Explorer direct launches, retire Workspace paste).

### Shipped 7 atomic commits (session-18)

| # | Commit subject | Files |
|---|---|---|
| 1 | `feat(p5): Start-VWBridge.ps1+bat wrapper via vwnt.exe -filein` | NEW: 2 scripts (~260+12 lines); MODIFIED: `.gitignore` (+2 lines) |
| 2 | `docs(api-contract): Phase P P5 section + carry-forwards 32-34` | MODIFIED: `knowledge/vw-image-api-contract.md` (Phase P P5 section + 3 bullets + frontmatter) |
| 3 | `docs(agents): cold-start uses Start-VWBridge.bat` | NEW (was session-15 deferred): `AGENTS.md` (cold-start section rewritten + project AI operating rules ship) |
| 4 | `docs(plan): PHASE-PROGRESS.md P5 SHIPPED + Phase P at ~80%` | NEW (was session-17 deferred): `plan/PHASE-PROGRESS.md` (10 section updates: quick status, goals table, phase table, deliverable table, distance to NS, session log, carry-forward count, MCP entity count) |
| 5 | `probes: session-18 P5 evidence (6 files)` | NEW: 6 probe files (`_probe-session18-{phase0,toplevel-caret,toplevel-caret-target,image-config,allow-flags,post-dryrun}.st`) |
| 6 | `docs(plan): commit STRATEGIC-ASSESSMENT-2026-06-21.md` | NEW (was session-13 deferred): `plan/STRATEGIC-ASSESSMENT-2026-06-21.md` — pure housekeeping |
| 7 | `docs(handoff): session-18 EOD - Phase P P5 SHIPPED` | THIS FILE |

### Memory MCP populated with session-18 facts

- **+~16 observations** on `Phase-P-P5-Oracle-recommendation` entity capturing all 6 probe results, smoke test, dry-run cycle 1, full 5-cycle gate, performance baseline, asymmetric Dialog selector, `-err` Runtime-Packager-only surprise.
- **+5 observations** on `VW-image-storedev64`: `Core.ImageConfigurationSystem` location + allow-flag state, `Core.CommandLineInterest` presence, Headless* class inventory, asymmetric Dialog setter/getter, vwnt.exe PID 6236 4-session continuous run ended at cycle 1.
- **+3 observations** on `Phase-P-progress`: P5 deliverable SHIPPED, Phase P at ~80%, critical path unblocked for M and E.
- **+1 observation** on `ammaganyane`: session-18 decision arc.
- **No new entities created session-18** (existing entities accreted; this is intentional — observations belong on `Phase-P-P5-Oracle-recommendation` which is the canonical decision-record for this work).

Graph still at 24 entities; relations unchanged at 42.

---

## Final state evidence (Phase P P5 quality gate satisfied)

| Predicate | All 5 cycles | Source |
|---|---|---|
| Wrapper exit 0 | ✓ | Start-VWBridge.ps1 output |
| Elapsed under 90s health-poll budget | ✓ (mean 9.11s) | Wrapper timing |
| `vwnt.exe` PID rotated (kill + new launch) | ✓ (5 distinct PIDs) | `Get-Process -Name vwnt` |
| `.token` rotated | ✓ (5 distinct values) | `.token` file content + mtime |
| `/health` 200 OK with version 0.9.1 | ✓ (3 polls / 1500ms per cycle) | curl.exe `/health` |
| `VWB.VWBridge environment name` = `#VWB` | ✓ (post-cycle-5 probe) | _probe-session18-post-dryrun.st |
| `Smalltalk at: #VWBridge` = `nil` (Stage 2 invariant) | ✓ | same probe |
| `VWB` keys size = 4 | ✓ | same probe |
| `singleton-token` matches `.token` file | ✓ (3959506095072-199161) | same probe |
| SimpleDialog override category = `*VWBridge-Patches mas-bug2-fix` | ✓ (Bug #2 fix re-installed) | same probe |
| `Dialog class canUnderstand: #useNativeDialogs:` | ✓ true | same probe |
| `Dialog usesNativeDialogs` returns false | ✓ (Bug #2 fix conditions met) | same probe |
| `.generated/load-startup.st` exists, 4138 bytes, ends `LF CR LF ! CR LF` | ✓ | byte hex dump |
| `vwbridge-autostart.err` not created (`-err` is Runtime-Packager-only) | ✓ (constraint #34 noted) | file check |

Token chain: `3959501869549-282335` (session-17 EOD) → `3959505878224-257889` → `3959506067853-564079` → `3959506076380-163522` → `3959506086034-199161` → `3959506095072-199161` (session-18 EOD).

PID chain: `6236` (4-session continuous run from session-15, ended cycle 1) → `1980` → `5000` → `8784` → `5776` → `8584` (current at EOD).

---

## Current state (end of session-18)

- **VW image:** unchanged `storedev64.im`. **vwnt.exe PID 8584** (NEW — replaced PID 6236 in cycle 1 of P5 gate), started 6/21/2026 14:48:10. Single-session run.
- **Bridge:** UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: `3959506095072-199161` (rotated 5× this session via P5 gate cycles).
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` (4 classes in VWB namespace).
- **`Dialog useNativeDialogs: false`:** SET (re-armed by wrapper post-cycle-5). Getter form is `usesNativeDialogs` per new constraint #32.
- **`VW_BRIDGE_HOME` env var:** SET at User OS level. Wrapper now resolves at Process/User/Machine scopes (covers fresh terminal launches).
- **Bridge code on disk:** matches image. **`Start-VWBridge.ps1` + `Start-VWBridge.bat` wrapper** is the new canonical cold-start path; Workspace paste of `load.st` is emergency fallback only.
- **Git:** `main` will be **7 commits ahead of `origin/main`** at handoff-write time; about to push as one batch with explicit auth.
- **Untracked at EOD (post-push):** `opencode.json` only (not author's). Working tree fully clean of pre-existing untracked items (session-13 STRATEGIC-ASSESSMENT, session-15 AGENTS, session-17 PHASE-PROGRESS all landed this session).
- **MAS window state:** unchanged from session-13 (no /click etc this session).

---

## NEW carry-forward constraints from session-18 (32-34)

All 3 added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) carry-forward summary + new section "Phase P P5 — `Start-VWBridge.ps1` wrapper via `vwnt.exe -filein` (session-18)" inserted after Phase P P2 Stage 3 section. Frontmatter `last_verified` bumped to session-18. Recap:

### 32. `Smalltalk.Dialog` has asymmetric setter/getter for native-dialogs flag

Setter is `useNativeDialogs:` (keyword, 1-arg) — what AGENTS.md cold-start step 3 references and what the Phase P P5 wrapper calls post-launch. Getter is `usesNativeDialogs` (unary, with an EXTRA 's' in 'uses', returns Boolean). The expected symmetric getter `useNativeDialogs` (no extra 's') does NOT exist and raises `MessageNotUnderstood` on probe. Verification probes must use the asymmetric form.

### 33. `vwnt.exe -filein <chunk-file>` switch + `ImageConfigurationSystem` allow-flag state

`-filein` documented verbatim on `C:\visualworks931\doc\AppDevGuide.pdf` p36 + verified through 5-cycle quality gate. Behavior: takes one or more `.st` chunk files; image continues running after file-in (unlike `-evaluate` which exits). Generic syntax: `<oe> [oe-switches] <image-name> [image-switches]` — image name MUST precede switches. `Core.ImageConfigurationSystem` gates which image-level switches are honored per allow-flag (this MAS image: `allowFilein=true`, `allowExpressions=true`, `allowParcelLoading=true`, others false). Top-level `^` in chunk file-in is silently consumed (probe D). See full switch table in api-contract Phase P P5 section.

### 34. `-err errorFile` switch is Runtime-Packager-only

Per AppDevGuide.pdf p481, `-err` and `-notifier notifierClass` are listed under "Runtime Packager installs two additional command-line options". In non-RuntimePackager images (like ours), the switch is silently accepted but the error file is NEVER created. Phase P P5 wrapper passes `-err <errfile>` defensively but handles missing file gracefully. **Means we have ZERO startup-side stderr visibility without an alternative redirect mechanism** (e.g., `Start-Process -RedirectStandardError`, which requires non-detached process spawning and is incompatible with our detached-launch design).

---

## Pending tasks (session-19)

### Phase P P6 — build `.pcl` parcel

Headless parcel-load API verified session-11: `Kernel.Parcel loadParcelFrom: aFilename` works. Wrapper migration step: switch `-filein <generated>` → `-pcl <parcel-path>` (same `Start-VWBridge.ps1`, just different image-switch arg). `allowParcelLoading=true` in this image (confirmed probe F session-18) so parcel load is unblocked.

Sub-tasks (per session-11 + session-13 plan):
1. Design parcel content (what classes/methods get packaged; how to preserve the `*VWBridge-Patches mas-bug2-fix` extension category — the parcel build needs to respect package boundaries)
2. Build via `Kernel.Parcel createParcelNamed: 'VWBridge'` or chunk-create flow (probe both)
3. Verify post-`loadParcelFrom:`: same 5 sources loaded, VWB namespace + classes present, SimpleDialog override re-installed, bridge can start
4. Update Start-VWBridge.ps1 to take `-pcl <path>` mode (probably add `-Mode FileIn|Parcel` switch or auto-detect by file extension)
5. P6 quality gate: 5 cold-start cycles via parcel mode all green
6. Drop `.pcl` artifact build into CI / installer story (lateral to Phase P)

Effort estimate (memory entity): 1-2 days.

### Phase P P7 — INSTALL.md

Depends on P6. Document env-var setup + parcel placement + smoke test (`curl /health` → expected response). Quality gate: zero-context developer reaches /health on first try.

### Phase P P8 — `GET /version` endpoint

Depends on P6. Returns parcel version + build timestamp + commit SHA. Augments existing /health. Effort: 0.5 day.

### Phase M — MCP for VW dev (PARALLEL with P6+P7+P8)

Jasper 3-layer reference design captured session-17 (extension host + stdio proxy + HTTPS/SSE). MVP tool surface: 3 wrappers around existing endpoints (`eval`, `windows`, `dialogs`). Auto-registration in `~/.claude.json`. Single-owner via socket binding. Now structurally unblocked since P5 ships the deployable wrapper.

### Carry-overs (still pending from sessions 7-11)

- EXPLORATION-PLAN step 3 — 3-deep menu navigation
- EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree
- End-to-end verify of `#id` / `#imcNr` / `#groupScheme` no-modal `partialFind:` paths via bridge

### Stale doc cleanup (11 files flagged session-16, still deferred)

- Archive pre-session-3 docs: `src/vw-bridge/{HANDOFF.md, VWBridge-working.md, SESSION-RESUME.md, E2E-DISTANCE.md}` (DELETE, history in git); `knowledge/CONSOLIDATION-NOTES.md`, `docs/HANDOFF.md`, `docs/poc-phase-1.md`, `plan/STRATEGIC-ASSESSMENT-2026-06-20.md` (move to archive/)
- Update stale frontmatters: `PLAN-PHASE-B.md` + `PLAN-PHASE-F.md` mark SHIPPED with retrospective; `vw-bridge-known-issues.md` title v0.8.5 → v0.9.1
- Refresh `docs/ARCHITECTURE-REVISED.md` for session-16/17/18 reality (14 endpoints + Phase P framework + Stage 3 ship + P5 ship)

### Long-tail production housekeeping

- Switch `OS.CEnvironment userEnvironment` reads to `OSSystemSupport getVariable:` (silence 4× deprecation per startup; probe semantics first — missing-key behavior may differ)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety
- **session-18 idea**: token entropy probe — cycle-4 + cycle-5 ended with same `-199161` random suffix; investigate whether `generateToken` random has limited entropy or whether the collision was just coincidence in 5 samples

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) | **NEW** (~260 lines) — Phase P P5 auto-start wrapper. Preflight (env var + files + load.st no `!`), idempotency check, optional kill, chunk-wrap generation, vwnt.exe -filein launch, /health poll, token rotation verify, useNativeDialogs toggle. 9 #regions + 8 failure-mode handling per Oracle. |
| [`src/vw-bridge/scripts/Start-VWBridge.bat`](../src/vw-bridge/scripts/Start-VWBridge.bat) | **NEW** (12 lines) — desktop launcher wrapping the .ps1 via `powershell.exe -NoProfile -ExecutionPolicy Bypass -File %~dp0Start-VWBridge.ps1 %*`. |
| [`.gitignore`](../.gitignore) | +2 lines: `src/vw-bridge/.generated/` + `src/vw-bridge/vwbridge-autostart.err` |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | New "Phase P P5 — Start-VWBridge.ps1 wrapper via vwnt.exe -filein (session-18)" section (~110 lines: image-level switch table + chunk-wrap design + launch invocation + wrapper preflight + quality gate evidence + cold-start path table). Phase P P2 Stage 3 closing paragraph updated to acknowledge P5 SHIPPED. 3 new carry-forward bullets (32-34). Frontmatter `last_verified` bumped to session-18, `source_sessions` extends to ..., 17, 18. |
| [`AGENTS.md`](../AGENTS.md) | **First commit** (was session-15 deferred untracked). Cold-start section rewritten: primary path is Start-VWBridge.bat; emergency fallback is load.st Workspace paste. References new constraint #32 (asymmetric Dialog selectors). |
| [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) | **First commit** (was session-17 deferred untracked). 10 section updates: frontmatter, quick status, project goals table (session-18 column), per-phase progress (P at 80%, D=DONE/subsumed, M+E unblocked), Phase P deliverable breakdown (P5 SHIPPED with cycle metrics), distance to NS, near-term milestones, per-session impact log (session-18 row), carry-forward count (34), memory entity count (24 with +20 observations). |
| [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) | **First commit** (was session-13 deferred untracked). Session-13 EOD strategic assessment document — content unchanged this session; just landing the pre-existing housekeeping. |
| `src/vw-bridge/probes/_probe-session18-phase0.st` | **NEW** — bridge identity check (Phase 0 step 5) |
| `src/vw-bridge/probes/_probe-session18-toplevel-caret-target.st` | **NEW** — single-chunk target with `^'session-18-toplevel-caret-OK'` body |
| `src/vw-bridge/probes/_probe-session18-toplevel-caret.st` | **NEW** — wrapper that files-in the target + Notification-resume + Exception-catch (orthogonal probe D) |
| `src/vw-bridge/probes/_probe-session18-image-config.st` | **NEW** — namespace walk for `ImageConfig*` / `Headless*` / `CommandLine*` / `Startup*` / `SwitchHandler*` (probe E) |
| `src/vw-bridge/probes/_probe-session18-allow-flags.st` | **NEW** — `ImageConfigurationSystem` allow-flag state + behavior fingerprint + `CommandLineInterest` peek (probe F) |
| `src/vw-bridge/probes/_probe-session18-post-dryrun.st` | **NEW** — post-cycle deep state verification (defensive: tries 3 getter shapes; discovered `usesNativeDialogs` asymmetric) |
| [`knowledge/HANDOFF-2026-06-21-session18.md`](./HANDOFF-2026-06-21-session18.md) | **THIS FILE** |

---

## Important decisions this session

- **Picked Option 1 (Phase P P5 `-filein` probe)** at session-18 start per resume prompt recommendation. The probe matrix (A-F) ran in iterative parallel batches; 3 of the 6 probes had to be re-run due to either unicode chars (probe D wrapper file initially had `—` and `→` from my Write tool defaults; second target file similarly) or AGENTS.md mid-block-temp violation (probe F initially had `| m |` and `| cli |` not at top of method). Each fix was a single-edit + re-run cycle.
- **Pivoted to Python + pypdf for PDF extraction** when `look_at` and `multimodal-looker` subagent both aborted mid-session due to model availability. User prompted "look tools are failing because model availability, maybe you can convert to text?" — switched within one turn. Installed pypdf 6.13.3 via `pip install --quiet`, wrote `extract-vw-cli-docs.py` script (~50 lines) that opened both PDFs and grep'd around `-filein` / `command-line` / `image-level` / `vwnt.exe` keywords with surrounding-line context. Returned verbatim p35-36 + p214-215 + p481 + p527 hits — the conclusive evidence Oracle's Path 4 design needed.
- **Discovered `ImageConfigurationSystem` allow-flag layer mid-implementation** (probe E surfaced the class; probe F enumerated the flags). Without this discovery the wrapper might have launched and silently failed because MAS could have locked down `-filein`. The probe added <2 min and turned an assumption into verified fact.
- **Smoke test caught the User-level env-var gap** (PowerShell subshells don't inherit User-scope env vars from parent shells launched before the var was set). Fixed Start-VWBridge.ps1 to resolve `VW_BRIDGE_HOME` at Process → User → Machine scopes — turns out to be the right design for the wrapper's real-world launch contexts (desktop shortcut, fresh terminal, CI runner).
- **Asked for single-cycle dry-run before full 5-cycle gate** — bounded blast radius; cycle 1 was 9.54s and clean; user then auth'd the remaining 4 (which cost only ~36s wall-clock). This 2-phase approach is genuinely safer than going straight to 5 cycles: if cycle 1 had revealed a wrapper bug, we'd be in single-cycle-recovery territory instead of mid-fifth-cycle chaos.
- **Asymmetric Dialog selectors discovered via probe D** post-hoc — the post-dryrun probe had a getter check `dialog useNativeDialogs printString` that MNU'd. Made the probe defensive (try 3 getter shapes), discovered `usesNativeDialogs` works. Logged as constraint #32. AGENTS.md cold-start step 3 already references the setter form correctly so no behavior change needed; just future getter probes should use `usesNativeDialogs`.
- **Bundled session-13/15/17 deferred housekeeping into this session's commit batch** per user choice "Full P5 ship + housekeeping + handoff + push (7 commits, EOD-style)". Decision rationale: PHASE-PROGRESS.md was session-18-modified (P5 ship reflected) so it has to land now; AGENTS.md was also session-18-modified (cold-start rewrite); STRATEGIC-ASSESSMENT-2026-06-21.md is the lone independent item — bundling it gets the working tree fully clean (only `opencode.json` left, intentionally not-author's).

---

## Lessons learned

### What went well

- **Probe matrix in iterative parallel batches** — 6 probes / 6 hits across one major and several minor iterations. Web search + local PDF extraction + binary scan + 3 image-side `/eval` probes covered every angle Oracle's design depended on. Total probe time ~10 minutes. Compare to the alternative of going straight to "kill vwnt.exe + try -filein and see" — that path would have either worked (no signal) or failed silently (e.g., allowFilein=false) with no diagnosis.
- **Python + pypdf as fallback for PDF extraction** — turned out to be more useful than the multimodal look approach because it gave verbatim text instead of a summary. Reusable for future doc inspection.
- **Single-cycle dry-run before full gate** — 9.54s of verified behavior bought ~36s of confident automation. Standard "verify-before-commit" pattern paid off.
- **Defensive idempotency in the wrapper** — without `-KillExisting`, the wrapper is safe to re-run anywhere (including against a healthy bridge). This matters for desktop shortcut usage where someone might double-click by accident.
- **AGENTS.md commit cadence respected** — 7 commits, all atomic, all with explicit auth at the question-tool gates.

### What I'd do differently

- **Probe D and probe F syntax mistakes cost two round-trips each** — the unicode em-dash + arrow chars in my Write defaults tripped the VW parser; the mid-block `| m |` and `| cli |` violated AGENTS.md syntax pitfall. Both are documented in AGENTS.md syntax pitfalls section — I should pattern-match these BEFORE first POST. Adding a self-check pass on probe content (`ascii-only? top-of-method temps only?`) before each `/eval` would have caught both at write-time.
- **Should have probed `allowFilein` BEFORE writing the wrapper** — I wrote the wrapper based on Oracle's design (and AppDevGuide.pdf p36) assuming `-filein` would work. Probe F confirmed `allowFilein=true` but if it had been false, I'd have had to re-design. Ordering-by-cheapest-falsification suggests probe F should have run earlier in the matrix.
- **The `-err` Runtime-Packager-only surprise** wasn't anticipated by Oracle's design. AppDevGuide.pdf p481 has it documented but Oracle's recommendation included `-err` redirect without flagging this caveat. Adding a session-18 next-time-Oracle-consult prompt: "list all switches you reference + their image-level/runtime-packager scoping".

### Discoveries documented

- **3 new carry-forward constraints** (32-34) in `vw-image-api-contract.md`. Doc has grown to 34 constraints across 15 sessions of work.
- **No new memory MCP entities** — observations accreted onto `Phase-P-P5-Oracle-recommendation` (now ~28 obs), `VW-image-storedev64` (+5), `Phase-P-progress` (+3), `ammaganyane` (+1). Total ~25 new observations across 4 entities.

---

## Resume hooks

- **Next-session anchor:** this file + [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) (now committed, open first for "where are we right now?") + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (34 carry-forward constraints documented as of session-18).
- **Memory MCP context:** run `memory_search_nodes` for `session` / `VWBridge` / `Phase-P` / `ammaganyane` / `Phase-P-P5-Oracle-recommendation` (now ~28 observations) / `VW-image-storedev64` / `Direct-invoke-gate-pattern` / `Latent-test-bug-indexOfSubCollection` / `Latent-screenshot-test-helper-bug` / `EndOfStreamNotification-fileIn-trap` / `Namespace-at-put-binding-notification` / `In-place-unload-load-quality-gate-test` / `load-unload-orchestrators` at start of session-19.
- **First action options for session-19:**
  1. **Phase P P6** — build `.pcl` parcel + switch wrapper to `-pcl` mode + run P6 quality gate (5 cycles). Effort: 1-2 days. UNBLOCKS P7/P8.
  2. **Phase M MVP** in parallel — Jasper 3-layer reference (extension host + stdio proxy + HTTPS/SSE). Effort: 2-3 days. UNLOCKS onboarding developer milestone.
  3. **Stale doc cleanup** (11 files flagged session-16, still deferred).
  4. **Long-tail production housekeeping** (deprecation switch + log rotation + log mutex + token entropy probe).
  5. **Carry-overs from sessions 7-11** (EXPLORATION-PLAN steps 3-4, #id/#imcNr/#groupScheme verify) — independent of Phase P critical path.
- **Phase 0 verification for session-19 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.9.1"}`
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token (was `3959506095072-199161` at session-18 EOD; will rotate ONLY if vwnt.exe restarted or wrapper re-run)
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect **0 commits ahead** (session-18 pushed all 7)
  - `git status --short` — expect 1 pre-existing untracked: `opencode.json` only (working tree clean of all author's items as of session-18 EOD)
  - vwnt.exe PID 8584, started 6/21/2026 14:48:10
  - If vwnt.exe restarted since session-18: **NEW CANONICAL PATH — run `Start-VWBridge.bat` instead of Workspace paste** (AGENTS.md cold-start exception now goes through the wrapper; Workspace paste of `load.st` is emergency fallback only).
- **Bridge state at session-18 EOD:** UP at `VWB.VWBridge` v0.9.1, token `3959506095072-199161`, all session-18 work in effect, 5-cycle quality gate proven idempotent, 7 commits about to push including this handoff.

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits local-only) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-15) | Pushed session-14 commits; fixed latent binding bug; direct-invoke gate pattern proven; partial gate (10/20 VWBridgeTest) | v0.9.1 | A, B, F, partial P (more verified) |
| 2026-06-21 (session-16) | Systematic gate sweep COMPLETE: 48/48 unblocked GREEN + 7 known-blocked Bug#5; 2 latent bug fixes + 3 new techniques; 5 new carry-forward (24-28); 5 commits pushed; P2 quality gate SATISFIED | v0.9.1 | A, B, F, P2 quality gate |
| 2026-06-21 (session-17) | Phase P P2 Stage 3 SHIPPED (load.st + unload.st + auto-start chunk removal); quality gate idempotency PROVEN via 2 in-place /eval cycles; P5 Oracle consult COMPLETE (Path 4 wrapper design); Jasper mining synthesized; 3 new carry-forward (29-31); 4 commits pushed | v0.9.1 | A, B, F, P2 Stage 3 SHIPPED + P5 designed |
| **2026-06-21 (session-18)** | **Phase P P5 SHIPPED (Start-VWBridge.ps1 + Start-VWBridge.bat via vwnt.exe -filein switch); 6 probes verified -filein syntax (AppDevGuide.pdf p36) + ImageConfigurationSystem allow-flag state + top-level `^` chunk semantics; 5-cycle quality gate GREEN (mean 9.11s/cycle); 3 new carry-forward (32-34); 7 commits pushed including handoff + 3 session-13/15/17 housekeeping** | **v0.9.1** | **A, B, F, P at ~80% (P5 SHIPPED)** |
| _(session-19)_ | Phase P P6 (.pcl parcel build) + maybe P7 INSTALL.md, OR Phase M MVP start | _(v0.10.0 likely)_ | A, B, F, P++  |
| _(future)_ | Phase P P7 + P8 ship | _(v0.10.0)_ | A, B, F, P |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
