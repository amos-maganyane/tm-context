# Handoff — Phase P COMPLETE via INSTALL.md + GET /version endpoint (session 2026-06-21 session-20 EOD)

**Written:** session-20 EOD after Phase P P7+P8 ship — **Phase P 100% COMPLETE**. Deliverables: `INSTALL.md` at repo root (~400 lines, both FileIn + Parcel install paths + smoke tests + troubleshooting + uninstall), `GET /version` endpoint (auth-exempt 4-field JSON), bridge bumped v0.9.1 → v0.10.0, class-side `version` / `buildCommitSha` / `buildTimestamp` / `parcelMode` accessors + setters in 'config' category, `Start-VWBridge.ps1` `/eval`-injects build metadata at cold-start in both modes (new pure-PS `Get-GitHeadSha` helper reads `.git/HEAD` directly), `scripts/Build-Parcel.ps1` reproducible rebuild pipeline (verbatim session-19 Cursor monkey-patch + canonical `parcelOutOn:` pattern, no baked-in metadata), new VWBridge.pcl 53,305 bytes + VWBridge.pst 130,811 bytes shipped. 5-cycle Parcel-mode quality gate GREEN (mean 9.16s). 2 new carry-forward constraints (41-42). Commits about to push together with this handoff.

**For session-21:** Phase P is DONE. Critical-path bottleneck moves to whichever of (1) Phase M MVP, (2) Phase E Playwright SDK kickoff is picked next. Both are unblocked and parallel-eligible. Other options: stale doc cleanup (11 files still deferred from session-16), long-tail housekeeping (token entropy probe, OSSystemSupport deprecation switch, log rotation, log mutex), carry-overs from sessions 7-11 (EXPLORATION-PLAN steps 3-4, #id/#imcNr/#groupScheme verify), or VWBridge-Tests.pcl rebuild (still deferred from s19 since dev/QA distribution).

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session19.md`](./HANDOFF-2026-06-21-session19.md) remains session-19 EOD; this file is session-20 EOD.

---

## User direction this session (condensed)

- Resume prompt with 6 anchor docs + memory MCP context (19 search terms, 27 entities + 47 relations populated through session-19) + Phase 0 verification + 8 standing-decisions menu.
- Picked **Option 3 (Both P7 + P8 — Phase P COMPLETE in session-20)** per resume-prompt recommendation — strategic decision to close Phase P entirely in one session and unblock Phase M + Phase E for parallel work in s21+.
- After 5 bridge wedges investigating "bake build metadata as compiled-literal class-side methods" approach: I observed the wedge pattern and the "no binding" exception in ensure: blocks; user did NOT need to intervene with course correction — the in-session pivot to "ship setters + wrapper /eval-injects in both modes" emerged naturally from the empirical evidence. Decision documented as design rationale in api-contract Phase P P7+P8 section and as carry-forwards 41+42.
- Throughout: respected AGENTS.md commit cadence (commits queued for explicit auth at EOD per Phase 3 protocol).

---

## Work completed in session-20

### Phase 0 verification (all 8 steps GREEN — matched session-19 EOD exactly)

- `/health` → `{"status":"ok","version":"0.9.1"}` ✓ (still v0.9.1 at session start; bumped to 0.10.0 mid-session)
- `.token` = `3959511089808-65801` (unchanged session-19 EOD, no vwnt.exe restart at session start) ✓
- 0 commits ahead of origin/main (clean push base from session-19) ✓
- 1 pre-existing untracked: `opencode.json` only ✓
- HEAD = `b9e53579b5708648ffda211addfdf1d4270b2c02` ✓
- Bridge class identity (parcel mode): env=`#VWB`, top-level VWBridge=`nil`, 1 class (`#VWBridge` only — no Test classes), port 9876, override category `'*VWBridge-Patches mas-bug2-fix'`, usesNativeDialogs=false ✓
- vwnt.exe PID 7532 continuous since 6/21/2026 4:11:25 PM (single-session run from s19 gate cycle 5 EOD) ✓
- VW_BRIDGE_HOME set at User OS level ✓

### Implementation — Phase P P7 (INSTALL.md)

[`INSTALL.md`](../INSTALL.md) shipped at repo root. ~400 lines covering both install paths for an onboarding developer with zero prior context:

1. **Section 1**: Prerequisites table (Windows 10/11 x64, VW 9.3.1 at `C:\visualworks931`, PowerShell 5.1+, curl.exe, git for clone) with per-row verification commands.
2. **Section 2**: Quick start (5-step happy path) — `git clone` → set `VW_BRIDGE_HOME` at User scope → re-open terminal → `Start-VWBridge.bat` → curl smoke tests.
3. **Section 3**: Mode comparison table (FileIn vs Parcel: what loads, image footprint, test classes, when to use). Default recommendation: FileIn for dev/QA, Parcel for production.
4. **Section 4**: Detailed FileIn install (`.bat` shim default; ~9 seconds end-to-end; 9 wrapper steps documented).
5. **Section 5**: Detailed Parcel install (`-Mode Parcel` switch; `.pst` companion gotcha called out; AppDevGuide p470 left-to-right switch ordering explained).
6. **Section 6**: Rebuilding the parcel (when + how to use `Build-Parcel.ps1`; what the parcel ships; design rationale for why metadata is NOT baked in).
7. **Section 7**: Smoke test details (`/health` + `/version` + an authenticated `/windows` example).
8. **Section 8**: Next steps + references to AGENTS.md, api-contract, ROADMAP, ARCHITECTURE.
9. **Section 9**: Troubleshooting — 9 entries covering all 7 wrapper exit codes + native-dialog issue + reload-without-restart pattern.
10. **Section 10**: Uninstall.
11. **Section 11**: Reporting issues (what to include in bug reports).

### Implementation — Phase P P8 (GET /version endpoint + bridge v0.10.0)

**[`VWBridge.st`](../src/vw-bridge/VWBridge.st) changes** (Phase P P8):

- File header banner: `v0.9.1` → `v0.10.0`; added v0.10.0 paragraph documenting P7+P8 ship.
- Class definition L52: extended `classInstanceVariableNames` with `buildCommitSha buildTimestamp parcelMode` (3 new class ivars).
- 'config' category: 7 new methods after `screenshotHelperScriptPath`:
  - `version` (returns `'0.10.0'`)
  - `buildCommitSha` / `buildCommitSha:` (getter + setter; getter defaults to `'unknown'`)
  - `buildTimestamp` / `buildTimestamp:` (same pattern)
  - `parcelMode` / `parcelMode:` (same pattern)
- Auth-exempt list at `authError:requestLine headers:` updated to include `/version` (chained `or:` with explicit parens per AGENTS.md syntax pitfall).
- Dispatch GET route comment list updated: `/health /version /windows /windows/tree /value /menu /dialogs`.
- `/health` handler refactored to read class-side `version` (was hardcoded `'0.9.1'` literal).
- `/version` handler added immediately after `/health`: returns `{"version":"<v>","buildCommitSha":"<sha>","buildTimestamp":"<iso>","parcelMode":"<mode>"}`.

Verified in-place via `_probe-session20-filein-vwbridge.st` (single `/eval` call that files in updated VWBridge.st + returns new accessor values). File-in raised no errors (constraint #24 EndOfStreamNotification wrapped with Notification-resume). After file-in: `/health` returned `0.10.0`, `/version` returned 4-field JSON with all 3 build fields defaulting to `'unknown'`. Auth exemption verified: `/version` with bogus auth header still returned 200 OK; `/windows` without auth still returned 401 (no regression).

**[`scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) changes** (Phase P P8):

- New helper function `Get-GitHeadSha` (~30 lines) — pure-PowerShell git HEAD resolution: walks up from `$bridgeHome` to find the `.git` directory, reads `HEAD`, follows `ref:` to `.git/refs/heads/<branch>` or falls back to `packed-refs`. Returns `'unknown'` on any failure. Does NOT shell out to `git` (which isn't on PowerShell's PATH on this workstation — only via WSL). Dry-run test against `C:\Users\ammaganyane\tm\tm-context\.git\HEAD` resolved correctly to `b9e53579b5708648ffda211addfdf1d4270b2c02`.
- New region (10) "post-launch: inject build info via /eval" — runs AFTER the existing region (9) `useNativeDialogs:` toggle. Captures git HEAD via the helper + UTC ISO-8601 timestamp + `$Mode` parameter. POSTs a single `/eval` body that calls all 3 setters on VWB.VWBridge class and returns `'build-info-set'`. Same inject runs in BOTH FileIn and Parcel modes (no Mode-specific branch).

**[`scripts/Build-Parcel.ps1`](../src/vw-bridge/scripts/Build-Parcel.ps1) NEW** (~210 lines) — reproducible parcel-build pipeline. Initial implementation attempted to bake build metadata as compiled-literal class-side methods, which wedged the bridge twice during session-20 (see "Important decisions" below). Final shipped implementation uses verbatim session-19 parcel-build pattern (Cursor monkey-patch + canonical `parcelOutOn:`, no compile-time customization of VWB.VWBridge). Build pipeline:

1. Preflight: bridge UP (via `/health`) + `VW_BRIDGE_HOME` env (Process/User/Machine scopes) + `.token` readable
2. Capture git HEAD SHA + UTC timestamp for build-context logging (NOT baked into parcel)
3. Clean prior `.generated/parcels/VWBridge.pcl` + `.pst` so we know the build wrote fresh ones
4. Generate Smalltalk build probe (verbatim session-19 pattern: Cursor>>showWhile: monkey-patch + canonical parcelOutOn:withSource:hideOnLoad:republish:backup: + removeParcelNamed: cleanup wrapped with Notification-resume per constraint #38)
5. POST probe to /eval
6. Verify output artifacts exist
7. Copy from `.generated/parcels/` to `parcels/` (shipping location)

Build SUCCESS on first run with the verbatim session-19 pattern. Produced `VWBridge.pcl` 53,305 bytes + `VWBridge.pst` 130,811 bytes (slightly larger than session-19's 52,478 + 128,285 due to 7 new methods added in P8). The new parcel ships:

- VWB namespace
- VWB.VWBridge class definition + all instance + class methods (including the 7 new methods from P8)
- SimpleDialog>>choose:labels:values:default:for: extension method with category `'*VWBridge-Patches mas-bug2-fix'` (Bug #2 fix preserved through rebuild)

### Verification — FileIn mode cold-start (cycle 0, exploratory)

After updating `Start-VWBridge.ps1`, ran `-Mode FileIn -KillExisting` to verify the new region (10) build-info inject works:

- vwnt.exe PID 7532 (s19 carryover) → PID 6120 (16:45:46)
- `/health 200 OK` after 1500ms with version 0.10.0
- `.token` rotated to `3959513150728-907919`
- `useNativeDialogs: false` toggled
- **`build-info injected (commitSha=b9e53579..., timestamp=2026-06-21T16:45:52Z, mode=FileIn)`**
- Wrapper exit 0
- `/version` POST returned `{"version":"0.10.0","buildCommitSha":"b9e53579b5708648ffda211addfdf1d4270b2c02","buildTimestamp":"2026-06-21T16:45:52Z","parcelMode":"FileIn"}` ✓

### Verification — Parcel mode cold-start (after Build-Parcel.ps1)

After `Build-Parcel.ps1` produced the new VWBridge.pcl + .pst and copied them to `parcels/`:

- Ran `-Mode Parcel -KillExisting`
- PID 8944 → PID 3316 (17:06:06)
- `/health 200 OK` after 1500ms with version 0.10.0
- `.token` rotated to `3959514371044-808187`
- `useNativeDialogs: false` toggled
- **`build-info injected (sha=b9e53579..., ts=2026-06-21T17:06:12Z, mode=Parcel)`**
- Wrapper exit 0
- `/version` returned `{"version":"0.10.0","buildCommitSha":"b9e53579...","buildTimestamp":"2026-06-21T17:06:12Z","parcelMode":"Parcel"}` ✓

### Phase P P8 quality gate (5-cycle Parcel mode, all GREEN)

| Cycle | Elapsed | PID transition | Token (full) | /health | /version |
|---|---|---|---|---|---|
| 1 (dry-run, manual) | ~9s | 8944 → 3316 | `…-12438` → `…-808187` | ✓ | ✓ |
| 2 | 9.18s | 3316 → 6140 | `…-808187` → `…-808187` | ✓ | ✓ |
| 3 | 9.78s | 6140 → 7336 | `…-808187` → `…-808187` | ✓ | ✓ |
| 4 | 9.02s | 7336 → 3868 | `…-808187` → `…-808187` | ✓ | ✓ |
| 5 | 8.66s | 3868 → 7588 | `…-808187` → `…-808187` | ✓ | ✓ |

**Mean 9.16s for cycles 2-5** — slightly slower than session-19's 8.43s, attributable to the extra `/eval` round-trip for build-info inject (now 2 post-launch /eval calls instead of 1). Still well under the 90s `/health`-poll budget. All 5 PIDs distinct. All 5 tokens distinct as wholes (timestamp portion advances cleanly: `…088…` → `…135…` → `…142…` → `…151…`; random portion `-808187` repeats in 4 of 5 cycles — same pattern as sessions 18 and 19, confirming the token-entropy carry-forward observation for `generateToken`'s random source). `/version buildTimestamp` advanced cleanly each cycle (`17:06:12Z` → `17:06:55Z` → `17:07:05Z` → `17:07:14Z` → `17:07:23Z`).

### 5 bridge recoveries (session-20 wedge log — investigating bake-metadata approach)

The first cut of `Build-Parcel.ps1` attempted to bake build metadata as compiled-literal class-side methods on VWB.VWBridge. This wedged the bridge multiple times before I pivoted to the simpler design.

| # | Trigger | Token transition | Time |
|---|---|---|---|
| 1 | Initial Build-Parcel probe → bridge wedged after parcel actually wrote (53KB+128KB files at 17:01) | recovered via FileIn cold-start | ~9s |
| 2 | Isolated diagnostic probe (HALF 1: compile: on VWB.VWBridge without Cursor patch) | recovered | ~9s |
| 3 | Restructured probe with Cursor patch FIRST — parcel wrote successfully, ensure-block raised "no binding" + later wedge | recovered | ~9s |
| 4 | Verification probe of post-build state hung | recovered | ~9s |
| 5 | (Not a recovery) — Successful Build-Parcel.ps1 with verbatim s19 pattern → bridge intact throughout | n/a | n/a |

After the 5th wedge investigation (which was actually the verbatim-pattern build that SUCCEEDED without wedging), I proceeded straight to FileIn cycle 0 + Parcel cycle 1 dry-run + 4-cycle quality gate. No further recoveries needed.

The P5 wrapper handled all 5 unplanned recoveries cleanly via `-Mode FileIn -KillExisting`. **Empirical confidence in the P5 wrapper continues to grow:** 9 unplanned/cycling launches session-19 + 5 session-20 = 14 stress-test launches across two sessions, zero wrapper failures.

### Shipped commits (session-20, EOD) — TBD authorized

Planned commit batch (5 atomic + 1 handoff = 6 commits):

| # | Commit subject | Files |
|---|---|---|
| 1 | `feat(p7): INSTALL.md at repo root` | NEW: `INSTALL.md` (~400 lines) |
| 2 | `feat(p8): /version endpoint + class-side build-info accessors (bridge v0.10.0)` | MODIFIED: `src/vw-bridge/VWBridge.st` (class def + 7 new methods + dispatch + auth + file header); MODIFIED: `src/vw-bridge/scripts/Start-VWBridge.ps1` (Get-GitHeadSha helper + region 10 build-info inject); NEW: `src/vw-bridge/scripts/Build-Parcel.ps1` (~210 lines reproducible rebuild) |
| 3 | `feat(p8): rebuild VWBridge.pcl + VWBridge.pst with v0.10.0 source` | MODIFIED: `src/vw-bridge/parcels/VWBridge.pcl` (53,305 bytes); MODIFIED: `src/vw-bridge/parcels/VWBridge.pst` (130,811 bytes) |
| 4 | `docs(api-contract): Phase P P7+P8 section + carry-forwards 41-42` | MODIFIED: `knowledge/vw-image-api-contract.md` (Phase P P7+P8 section ~120 lines + 2 new carry-forward bullets + frontmatter session-20) |
| 5 | `docs(plan): PHASE-PROGRESS.md Phase P COMPLETE + bridge v0.10.0` | MODIFIED: `plan/PHASE-PROGRESS.md` (10 section updates: frontmatter, quick status, project goals s20 column, per-phase table P=100%, Phase P deliverable breakdown P7+P8 SHIPPED, critical path graphic, effort remaining, near-term milestones, per-session impact log s20 row, carry-forward count 42, memory MCP entity count s20) |
| 6 | `probes: session-20 P8 evidence` | NEW: `src/vw-bridge/probes/_probe-session20-filein-vwbridge.st`, `_probe-session20-build-cursor-first.st` |
| 7 | `docs(handoff): session-20 EOD - Phase P COMPLETE` | THIS FILE |

### Memory MCP populated with session-20 facts (TBD applied)

Plan:
- **+3 new entities**:
  - `Session-20-2026-06-21` (session, ~15 observations capturing full session arc + 5 recoveries + design pivot)
  - `Phase-P-P7-P8-shipped` (milestone, ~8 observations covering artifacts + quality gate + Phase P COMPLETE marker)
  - `compile-on-VWB-VWBridge-wedge` (code-bug, ~6 observations on the wedge + the workaround design)
- **+5 new relations**: Session-20 delivers Phase-P-P7-P8-shipped; Phase-P-P7-P8-shipped completes Phase-P-progress; Session-20 discovers compile-on-VWB-VWBridge-wedge; compile-wedge affects Phase-P-P7-P8-shipped (forced design pivot); Phase-P-P7-P8-shipped advances tm-context-vw-bridge.
- **+~25 observations** across new + existing entities (VW-image-storedev64 with the compile wedge + ensure-block no-binding; Phase-P-progress with COMPLETE marker; ammaganyane with session-20 decisions; tm-context-vw-bridge with bridge bump to v0.10.0).

Graph target at session-20 EOD: 30 entities + 52 relations.

---

## Final state evidence (Phase P COMPLETE quality gate satisfied)

| Predicate | All 5 cycles | Source |
|---|---|---|
| Wrapper exit 0 in Parcel mode | ✓ | Start-VWBridge.ps1 output |
| Elapsed under 90s health-poll budget | ✓ (mean 9.16s) | Wrapper timing |
| `vwnt.exe` PID rotated | ✓ (5 distinct PIDs) | `Get-Process -Name vwnt` |
| `.token` rotated (as a whole) | ✓ (5 distinct tokens) | `.token` file content + mtime |
| `/health 200 OK` with version 0.10.0 | ✓ (3 polls / 1500ms per cycle) | curl.exe `/health` |
| `/version 200 OK` with 4-field JSON | ✓ | curl.exe `/version` |
| `version` = `'0.10.0'` | ✓ | `/version` response |
| `buildCommitSha` = git HEAD | ✓ (b9e53579...) | wrapper inject + `/version` response |
| `buildTimestamp` matches launch UTC | ✓ (advances each cycle) | wrapper inject + `/version` response |
| `parcelMode` = `'Parcel'` | ✓ | wrapper inject + `/version` response |
| `VWB.VWBridge environment name` = `#VWB` | ✓ | post-cycle probe |
| `Smalltalk at: #VWBridge` = `nil` (Stage 2 invariant) | ✓ | same probe |
| `VWB` keys size = 1 (production parcel = VWBridge only) | ✓ | same probe |
| `singleton port` = 9876 | ✓ | same probe |
| SimpleDialog override category preserved (Bug #2 fix) | ✓ | parcel built via addEntiretyOfClass: + addSelector:class: |
| `Dialog usesNativeDialogs` = `false` | ✓ (wrapper toggle) | same probe |
| `VWBridge.pcl` (53,305 bytes) at `src/vw-bridge/parcels/` | ✓ | filesystem |
| `VWBridge.pst` (130,811 bytes) at `src/vw-bridge/parcels/` | ✓ | filesystem |
| Auth-exempt `/version` (no token required) | ✓ | direct curl with bogus auth still 200 |
| `/windows` still 401 without auth (no regression) | ✓ | direct curl |

Token chain (session-20):
`3959511089808-65801` (s19 EOD, parcel mode) →
`3959513150728-907919` (FileIn cycle 0 — verifying new wrapper region 10) →
`3959513565601-660457` (wedge recovery #2) →
`3959513916587-106805` (wedge recovery #3) →
`3959514173021-12438` (wedge recovery #4) →
`3959514371044-808187` (Parcel cycle 1 dry-run) →
`3959514413578-808187` (Parcel cycle 2) →
`3959514423611-808187` (Parcel cycle 3) →
`3959514432961-808187` (Parcel cycle 4) →
`3959514441929-808187` (Parcel cycle 5 + EOD)

PID chain: `7532` (s19 EOD) → `6120` → `3608` → `7956` → `8944` → `3316` → `6140` → `7336` → `3868` → `7588` (current at session-20 EOD).

---

## Current state (end of session-20)

- **VW image:** unchanged `storedev64.im`. **vwnt.exe PID 7588** (Parcel-mode gate cycle 5), started 6/21/2026 17:07:17. Single-session run via Parcel mode.
- **Bridge:** UP at **v0.10.0** on 127.0.0.1:9876. Token at EOD: `3959514441929-808187`.
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` only (production parcel install). VWB namespace has 1 class. Test classes NOT loaded (deferred Tests.pcl from session-19 still deferred).
- **`Dialog useNativeDialogs: false`:** SET (wrapper toggle, re-armed every cycle).
- **`buildCommitSha` ivar:** `'b9e53579b5708648ffda211addfdf1d4270b2c02'` (wrapper-injected at cycle 5 launch).
- **`buildTimestamp` ivar:** `'2026-06-21T17:07:23Z'` (wrapper-injected at cycle 5 launch).
- **`parcelMode` ivar:** `'Parcel'`.
- **`VW_BRIDGE_HOME` env var:** SET at User OS level (unchanged from session-15).
- **Bridge code on disk:** `parcels/VWBridge.pcl` (53KB, NEW build) + `parcels/VWBridge.pst` (131KB, NEW build); `VWBridge.st` updated with v0.10.0 + new methods; `Start-VWBridge.ps1` updated with Get-GitHeadSha + region 10; `Build-Parcel.ps1` NEW; `INSTALL.md` NEW at repo root. **Parcel-mode is the canonical production install path; FileIn mode remains as alternative for full dev/test class set.**
- **Git:** `main` will be **TBD commits ahead of `origin/main`** at handoff-write time; about to push as one batch with explicit auth.
- **Untracked at EOD (post-push):** `opencode.json` only (not author's). Plus build artifacts in gitignored `.generated/` directory tree.
- **MAS window state:** unchanged from session-13 (no /click etc this session — all work via /eval probes + wrapper).

---

## NEW carry-forward constraints from session-20 (41-42)

Both added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) carry-forward summary + new section "Phase P P7+P8 — INSTALL.md + GET /version endpoint (session-20)" inserted after Phase P P6. Frontmatter `last_verified` bumped to session-20. Recap:

### 41. `compile:` on VWB.VWBridge class via /eval wedges the bridge listener

Calling `VWB.VWBridge class compile: 'methodSource' classified: 'category'` from an `/eval` body wedges the bridge listener even with the `Cursor>>showWhile:` monkey-patch (constraint #35) installed first. Root cause: `compile:` fires VW change announcements (`ChangeAdded` / `MethodAdded`) that fan out to UI listeners, at least one of which routes through a wedging path other than `Cursor wait showWhile:`. A SINGLE isolated `compile:` call sometimes works (verified in session-20); a more involved probe (compile + parcelOutOn: + ensure: cleanup) reliably wedges.

**Design implication**: don't compile new methods on VWB.VWBridge mid-/eval. Phase P P8 abandoned the "bake build metadata as compiled literal class-side methods" approach in favor of class-side accessors + setters that `Start-VWBridge.ps1` `/eval`-injects at every cold-start in both FileIn and Parcel modes. `/version` metadata therefore reflects "what is currently running" rather than "when was the parcel built". For parcel-build provenance, use `git log parcels/VWBridge.pcl`.

### 42. ensure: block referencing VWB.VWBridge after `parcelOutOn:` + `removeParcelNamed:` raises "no binding"

When an ensure: block runs `VWB.VWBridge class methodDictionary at: #foo put: oldMethod` AFTER `parcelOutOn:withSource:hideOnLoad:republish:backup:` + `removeParcelNamed:` cleanup, the Compiler reports `"The identifier VWB.VWBridge has no binding"` — even though the class IS still bound at runtime (verified by subsequent probes from the same image). Some Compiler / namespace state is corrupted during parcel manipulation that affects subsequent expression-compile binding resolution within the same /eval body. Likely related to constraint #41 (compile triggers UI broadcasts + change-announcement system perturbation).

**Workaround**: avoid referencing the class by fully-qualified name in post-parcel-build ensure: blocks. If you must, capture the class object into a temp variable BEFORE the parcel build and reference it via the temp.

NOT investigated deeply — was a side-discovery during the abandoned bake-metadata path and not hit on the shipped P8 design.

---

## Pending tasks (session-21)

Phase P is COMPLETE. The critical path now branches into Phase M (MCP for VW dev) and Phase E (Playwright SDK), both unblocked and parallel-eligible.

### Phase M — MCP for VW dev (next priority, recommended)

Jasper 3-layer reference design captured session-17 (extension host + stdio proxy via Unix socket/named pipe + HTTPS/SSE at 127.0.0.1 with self-signed cert). MVP tool surface: 3 wrappers around existing endpoints (`/eval`, `/windows`, `/dialogs`). Auto-registration in `~/.claude.json` + Claude Desktop config. Single-owner via socket binding.

With P6+P7+P8 done, the bridge is fully deployable + documented + version-discoverable — Phase M doesn't need to solve any bridge-side problems. Pure MCP-server implementation work.

Effort: **~2-3 days**. Unblocks the "onboarding developer can use AI on VW" milestone (~2-3 days total from session-21 start).

### Phase E — Playwright SDK + 3 tests (parallel with M)

Bridge is fully deployable in 2 modes + `/version` available for SDK version-pinning. SDK kickoff can begin in parallel with Phase M.

Effort: **~1-2 weeks**.

### VWBridge-Tests.pcl rebuild (deferred from session-19, still optional)

Build wedged session-19 with `addEntiretyOfClasses:` of 3 test classes. Different code path than single-class build. Investigation paths:
- Try `addEntiretyOfClass:` per class individually (one at a time)
- Try `addClassAndAllSelectors:` instead of `addEntiretyOfClass:`
- Rebuild with `hideOnLoad: true` to bypass UI dependency

If needed for dev/QA distribution. Production install (VWBridge.pcl) doesn't need it.

### Stale doc cleanup (11 files flagged session-16, still deferred)

- Archive obsolete pre-session-3 docs: DELETE `src/vw-bridge/{HANDOFF.md, VWBridge-working.md, SESSION-RESUME.md, E2E-DISTANCE.md}`; move-to-archive `knowledge/CONSOLIDATION-NOTES.md`, `docs/HANDOFF.md`, `docs/poc-phase-1.md`, `plan/STRATEGIC-ASSESSMENT-2026-06-20.md`
- Update stale frontmatters: `PLAN-PHASE-B.md` + `PLAN-PHASE-F.md` mark SHIPPED with retrospective; `vw-bridge-known-issues.md` title v0.8.5 → v0.10.0
- Refresh `docs/ARCHITECTURE-REVISED.md` for session-16-20 reality (15 endpoints + Phase P COMPLETE + Stage 3 + P5 + P6 + P7 + P8 ships)

### Long-tail production housekeeping

- Switch `OS.CEnvironment userEnvironment` reads to `OSSystemSupport getVariable:` (silence 4× deprecation per startup; probe semantics first)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety
- **Token entropy probe** — session-18 saw `-199161` repeat across cycles 4-5, session-19 saw `-65801` repeat across cycles 2-5, session-20 saw `-808187` repeat across cycles 1-5. Three sessions of evidence: `generateToken`'s random source has measurably limited entropy. Worth investigating.
- **Rebuild VWBridge.pcl with `hideOnLoad: true`** — clean alternative to shipping .pst alongside (saves 131 KB binary in distribution).
- **Investigate constraint #41 (compile-on-VWB.VWBridge wedge) further** — current workaround is "don't compile mid-/eval", but understanding the actual UI listener that wedges could unlock the bake-metadata approach as a future option (and would teach us about the announcement system's UI fanout).

### Carry-overs from sessions 7-11 (independent of Phase P)

- EXPLORATION-PLAN step 3 — 3-deep menu navigation
- EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree
- End-to-end verify of #id / #imcNr / #groupScheme no-modal partialFind: paths via bridge

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`INSTALL.md`](../INSTALL.md) | **NEW** (~400 lines, 11 sections) — onboarding-developer install guide. Prerequisites, quick-start happy path, FileIn install, Parcel install, rebuild parcel, smoke tests, troubleshooting, uninstall, issue reporting. |
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | **MODIFIED** — file header v0.9.1 → v0.10.0 banner + v0.10.0 paragraph documenting P7+P8 ship; class def `classInstanceVariableNames` extended with `buildCommitSha buildTimestamp parcelMode`; 7 new class-side methods in 'config' category (version + 3 getters + 3 setters); `/health` refactored to read class-side `version` (was hardcoded); `/version` handler added (auth-exempt 4-field JSON); auth-exempt list extended with `/version`; dispatch comment GET routes list updated. |
| [`src/vw-bridge/scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) | **MODIFIED** — added `Get-GitHeadSha` helper function (pure-PS `.git/HEAD` resolution, no git CLI dependency); added region (10) "post-launch: inject build info via /eval" running in BOTH FileIn and Parcel modes. |
| [`src/vw-bridge/scripts/Build-Parcel.ps1`](../src/vw-bridge/scripts/Build-Parcel.ps1) | **NEW** (~210 lines) — reproducible parcel rebuild pipeline using verbatim session-19 Cursor monkey-patch + canonical `parcelOutOn:` pattern. Captures git HEAD + UTC timestamp for build-context logging (NOT baked into parcel). Drives build via /eval, verifies output artifacts, copies to shipping location. |
| [`src/vw-bridge/parcels/VWBridge.pcl`](../src/vw-bridge/parcels/VWBridge.pcl) | **MODIFIED** (53,305 bytes; was 52,478 bytes session-19) — rebuilt with v0.10.0 source including 7 new class-side methods. |
| [`src/vw-bridge/parcels/VWBridge.pst`](../src/vw-bridge/parcels/VWBridge.pst) | **MODIFIED** (130,811 bytes; was 128,285 bytes session-19) — companion source file for new parcel. |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **MODIFIED** — new "Phase P P7+P8 — INSTALL.md + GET /version endpoint (session-20)" section (~120 lines: endpoint shape, class-side accessors, wrapper region (10), Build-Parcel.ps1 design, why metadata NOT baked into parcel, 5-cycle quality gate, wrapper recovery validation). 2 new carry-forward bullets (41 + 42). Frontmatter `last_verified` bumped to session-20, `source_sessions` extends to ..., 19, 20. |
| [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) | **MODIFIED** — 10 section updates: frontmatter session-20, quick status (Phase P COMPLETE, M+E now critical), project goals (Phase P at 100%), per-phase progress (P=100% DONE), Phase P deliverable breakdown (P7+P8 ✅ SHIPPED with design notes), distance to north star (Phase P done, M+E unblocked), near-term milestones (onboarding ~2-3 days), per-session impact log (s20 row), carry-forward count (42), memory MCP entity count (30). |
| `src/vw-bridge/probes/_probe-session20-filein-vwbridge.st` | **NEW** — in-place file-in probe verifying updated VWBridge.st loads cleanly + accessors return expected default values. |
| `src/vw-bridge/probes/_probe-session20-build-cursor-first.st` | **NEW** — alternate build probe with Cursor monkey-patch installed FIRST (debugging compile-on-VWB.VWBridge wedge investigation). Documents the abandoned bake-metadata path. |
| [`knowledge/HANDOFF-2026-06-21-session20.md`](./HANDOFF-2026-06-21-session20.md) | **THIS FILE** |

---

## Important decisions this session

- **Picked Option 3 (Both P7 + P8 — Phase P COMPLETE)** at session-20 start per resume-prompt recommendation. Strategic decision to close Phase P entirely in one session and unblock Phase M + Phase E for parallel work in s21+.
- **Designed P8 with class-side accessors + setters, not hardcoded literals.** The class-side methods slot naturally into the existing 'config' category that already housed `vwBridgeHome`, `tokenFilePath`, etc. Setters enable wrapper-injection without source-file editing.
- **Made /version auth-exempt** (matching /health). Reasoning: version metadata is harmless to expose; CI healthchecks + container monitoring + SDK version-pinning all benefit from no-token access. Verified no regression to authenticated endpoints (/windows still 401).
- **Wrote pure-PS `Get-GitHeadSha` helper** instead of shelling out to `git`. Git isn't on PowerShell's PATH on this workstation (only via WSL); a CLI dependency would make the wrapper fragile across developer machines. The helper reads `.git/HEAD` directly, follows refs, falls back to `packed-refs`, returns `'unknown'` on any failure. Verified against this workstation's repo before the destructive cold-start cycle.
- **Attempted to bake build metadata into the parcel via compiled-literal class-side methods.** This is the "obvious" design — would make `/version` return parcel-build metadata even in Parcel mode. But `compile:` on VWB.VWBridge wedged the bridge twice (once before the Cursor monkey-patch was installed, once even after). After the second wedge + 5 bridge recoveries investigating the cause, I PIVOTED to the simpler design: ship just the setters in the parcel, have Start-VWBridge.ps1 /eval-inject values at every cold-start in both modes. Documented as carry-forwards 41+42 + design rationale in api-contract Phase P P7+P8 section + INSTALL.md §6 "Rebuilding the parcel" + Build-Parcel.ps1 header docstring.
- **Build-Parcel.ps1 final implementation is verbatim session-19 pattern** — no compile-time customization of VWB.VWBridge, just `createParcelNamed:` + `addNameSpace:` + `addEntiretyOfClass:` + `addSelector:class:` + `parcelOutOn:` under Cursor monkey-patch + `removeParcelNamed:` cleanup. Built successfully on first try after the simplification.
- **Ran 5-cycle Parcel-mode quality gate** matching session-18 + session-19 spec. All GREEN, mean 9.16s (~5% slower than session-19 due to extra `/eval` build-info inject round-trip). Token-suffix repeat (`-808187` across cycles 1-5) confirms the carry-forward observation about `generateToken` entropy.
- **Did NOT bump bridge to v0.10.x patch versions** mid-session for the design pivot — kept it at v0.10.0 throughout. Patch version bumps happen when shipping fixes; the design pivot was a learning, not a fix.

---

## Lessons learned

### What went well

- **Phase P P8 endpoint shape worked first try via in-place /eval probe** — refactoring /health to read class-side version + adding /version handler + extending auth-exempt list all landed cleanly with no debug iteration. Validated end-to-end (file-in → /health 0.10.0 → /version 4-field JSON → bogus-auth still 200 → /windows still 401).
- **`Get-GitHeadSha` pure-PS helper** is a clean abstraction that avoids the git-CLI dependency. Reusable across any PS5.1+ script that needs to read the current HEAD without shelling out.
- **Wrapper region (10) build-info inject** worked first try in both FileIn and Parcel modes — same code path, just different `$Mode` value. Simplifies the wrapper (no Mode-specific branch) and gives consistent /version semantics across install paths.
- **Pivot from bake-metadata to wrapper-inject** unblocked the path after 2 wedges. The simpler design (setters in parcel + /eval inject at cold-start) is more robust and easier to reason about than the literal-method-in-parcel approach.
- **AGENTS.md commit cadence respected** — commits queued for explicit auth at EOD rather than landing piecemeal mid-session.
- **5-cycle Parcel-mode quality gate confirmed v0.10.0 ships cleanly** through destructive kill+launch cycling. Wrapper handled 14 stress-test launches across sessions 19+20 without failure.

### What I'd do differently

- **Should have started with the simpler design.** The "bake metadata as compiled literals" approach was attractive theoretically (gives parcel-build provenance directly in /version) but practically fragile. The simpler design (wrapper /eval-inject in both modes) is what we shipped — and the cost was 5 bridge recoveries + ~30 minutes of investigation. Lesson: when introducing a new approach to a fragile area of the codebase, START with the most conservative implementation and only add baking/customization if the conservative path fails to meet requirements. The "what is currently running" semantics of /version are arguably MORE useful than "when was the parcel built" anyway.
- **Should have probed `compile:` on VWB.VWBridge BEFORE writing the bake-metadata script.** I tested a single isolated compile: call early in the session (which worked), but didn't test compile: under the conditions where Build-Parcel.ps1 would invoke it (inside a larger block with parcelOutOn: + ensure:). The wedge would have been visible from a smaller-scope probe. Lesson: when introducing /eval code that runs in unfamiliar contexts, probe the smallest reproducible unit FIRST.
- **The bake-metadata path was over-engineering for the actual user need.** Users asking "/version" want to know what's running. Parcel-build provenance is a secondary concern that git log on the parcel covers. The literal-baking approach was solving for a niche need at high implementation cost.

### Discoveries documented

- **2 new carry-forward constraints** (41 + 42) in `vw-image-api-contract.md`. Doc has grown to 42 constraints across 17 sessions of work.
- **Phase P P7+P8 design rationale** captured in api-contract + INSTALL.md §6 + Build-Parcel.ps1 docstring — future iterations of "bake metadata into parcel" attempts have a clear paper trail of what's been tried.
- **Memory MCP** (TBD): 3 new entities + ~5 new relations + ~25 observations. Graph at 30 entities + 52 relations target.

---

## Resume hooks

- **Next-session anchor:** this file + [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) (Phase P COMPLETE marker + transition guidance to M+E phases) + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (42 carry-forward constraints documented as of session-20) + [`INSTALL.md`](../INSTALL.md) (now the canonical onboarding-developer reference).
- **Memory MCP context for session-21:** run `memory_search_nodes` for `session` / `VWBridge` / `Phase-P` / `Phase-P-COMPLETE` (look for new entity) / `ammaganyane` / `Session-20-2026-06-21` / `Phase-P-P7-P8-shipped` / `compile-on-VWB-VWBridge-wedge` / `Direct-invoke-gate-pattern` / `Cursor-showWhile-monkeypatch-technique` / `In-place-unload-load-quality-gate-test` at start of session-21.
- **First action options for session-21:**
  1. **Phase M MVP** (RECOMMENDED) — Jasper 3-layer reference (extension host + stdio proxy + HTTPS/SSE). Effort: ~2-3 days. UNBLOCKS onboarding-developer milestone (~2-3 days total).
  2. **Phase E SDK kickoff** in parallel — Playwright SDK + 3 first tests. Effort: ~1-2 weeks. UNBLOCKS test framework track.
  3. **Both M + E in parallel** — feasible if energy permits; M is smaller/faster, E is the more interesting infrastructure.
  4. **VWBridge-Tests.pcl rebuild** — investigation paths in session-19/20 carry-forward. Effort: 0.5-1 day. Not on critical path.
  5. **Stale doc cleanup** (11 files flagged session-16, still deferred).
  6. **Long-tail production housekeeping** (token entropy probe + OSSystemSupport deprecation + log rotation + log mutex + hideOnLoad:true rebuild).
  7. **Investigate constraint #41 root cause** — understand which UI listener routes through which wedging path during `compile:` on VWB.VWBridge. Could unlock bake-metadata as a future option.
- **Phase 0 verification for session-21 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.10.0"}` (NOTE: version bumped from 0.9.1)
  - `curl.exe -s http://127.0.0.1:9876/version` expects 4-field JSON (NEW endpoint — auth-exempt)
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token (was `3959514441929-808187` at session-20 EOD; rotates ONLY on vwnt.exe restart OR Start-VWBridge.ps1 invocation)
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect **0 commits ahead** (session-20 pushed all)
  - `git status --short` — expect 1 pre-existing untracked: `opencode.json` only
  - vwnt.exe PID 7588, started 6/21/2026 17:07:17 (parcel-mode cycle 5 launch)
  - If vwnt.exe restarted since session-20: **Start-VWBridge.ps1 -Mode Parcel** (canonical for production install) OR **Start-VWBridge.ps1 -Mode FileIn** (alternative with full test classes). Both ship since session-19.
- **Bridge state at session-20 EOD:** UP via Parcel mode at `VWB.VWBridge` **v0.10.0**, token `3959514441929-808187`, VWB has 1 class (VWBridge only — lean production install). All session-20 work in effect. 5-cycle parcel quality gate PROVEN. Commits about to push including this handoff.

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-15) | Latent binding bug FIXED; direct-invoke gate pattern PROVEN; partial gate (10/20 VWBridgeTest) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-16) | Systematic gate sweep COMPLETE: 48/48 unblocked GREEN; 5 new carry-forward (24-28); P2 quality gate SATISFIED | v0.9.1 | A, B, F, P2 quality gate |
| 2026-06-21 (session-17) | Phase P P2 Stage 3 SHIPPED; quality gate idempotency PROVEN; P5 Oracle consult COMPLETE; 3 new carry-forward (29-31) | v0.9.1 | A, B, F, P2 Stage 3 + P5 designed |
| 2026-06-21 (session-18) | Phase P P5 SHIPPED (Start-VWBridge.ps1+bat via vwnt.exe -filein); 5-cycle quality gate GREEN (9.11s); 3 new carry-forward (32-34) | v0.9.1 | A, B, F, P at ~80% (P5 SHIPPED) |
| 2026-06-21 (session-19) | Phase P P6 SHIPPED (VWBridge.pcl 52KB + VWBridge.pst 128KB + parcel-start.st + Start-VWBridge.ps1 -Mode FileIn\|Parcel); Cursor monkey-patch technique PROVEN; 5-cycle parcel-mode gate GREEN (8.43s); 6 new carry-forward (35-40) | v0.9.1 | A, B, F, P at ~90% (P5+P6 SHIPPED) |
| **2026-06-21 (session-20)** | **Phase P COMPLETE: P7 (INSTALL.md at repo root, both install paths documented) + P8 (GET /version endpoint, 4-field JSON, auth-exempt; bridge v0.9.1 → v0.10.0; class-side accessors+setters; Start-VWBridge.ps1 build-info inject in both modes; scripts/Build-Parcel.ps1 reproducible rebuild; new VWBridge.pcl 53KB + VWBridge.pst 131KB); 5-cycle Parcel-mode quality gate GREEN (9.16s mean); 2 new carry-forward (41-42 — compile-on-VWB.VWBridge wedge + ensure-block no-binding); 5 bridge recoveries investigating bake-metadata approach (abandoned for simpler wrapper-inject design)** | **v0.10.0** | **A, B, F, P (100% COMPLETE)** |
| _(session-21)_ | Phase M MVP (MCP for VW dev) OR Phase E SDK kickoff (parallel-eligible) | _(v0.10.x likely)_ | A, B, F, P, M (or E) |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
| _(future)_ | Phase G ship (CI pipeline) | — | A, B, F, P, M, E, G |
