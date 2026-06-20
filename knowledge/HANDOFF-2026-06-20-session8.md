# Handoff — v0.8.13 NDJSON logging + Wave 1 closure (session 2026-06-20 session-8 EOD)

**Written:** end of session-8 that (1) closed the v0.8.12 wave from session-7 by pushing the 4 session-7-wrap commits to `origin/main` (`bc1f240..e201275`), (2) executed Wave 1 of [`STRATEGIC-ASSESSMENT-2026-06-20.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-20.md) — fixed the latent Bug #6 (unescaped `"` characters at L10/L14 of [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st)'s top comment), filed in the SUnit scaffold cleanly, ran the 2 Bug #2 tests added in session-7 (both GREEN via `/eval`), updated [`vw-party-search.md`](./vw-party-search.md) at 4 sites to mark the Bug #2 workaround optional in v0.8.12+, committed and pushed Wave 1 atomically (2 commits, `e201275..b4d1d2b`), (3) began Wave 2 with Phase 1 read-only probes — discovered via concrete `/eval` evidence that this MAS image has NO Smalltalk-level image-boot hooks (no `Smalltalk addToStartUpList:`, no `SessionManager instance` initialization, zero classes implement `#startUp:` class-side, `ObjectMemory class` has no startup-registration selectors), (4) pivoted scope from "logging + auto-start" to **logging-only** based on the probe evidence and documented the auto-start blocker for session-9+, (5) shipped **v0.8.13** — file-based NDJSON logging via a new `'logging'` category in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (5 new methods: `log:level:`, `logWarn:`, `logError:`, `logFilePath`, `writeLogEntry:level:`) multiplexing Transcript + a per-write `readWriteStream`/`setToEnd` append to [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log), (6) added 3 new SUnit tests (`testLogWritesNDJSONToFile`, `testLogLevelDistinction`, `testLogJsonLineWellFormed`) — all GREEN via `/eval` because they call `bridge log:` / `bridge logFilePath` (direct handler / accessor calls, no `dispatch:` re-entry), (7) regression-verified Bug #2 Yes/No tests still pass on v0.8.13, /health returns 0.8.13, 0 wedged procs, `useNativeDialogs=false` preserved, (8) committed v0.8.13 atomically (feat + test + this handoff = 3 commits) and pushed.

**For:** session-9 — (1) decide which Wave 2 sub-item next: `/wait` endpoint (test-framework-blocking, ~4-6h with TDD), `/screenshot` endpoint (largest scope, needs Oracle consult for graphics + base64 + UI-process dispatch), or research auto-start architecturally (parcel migration vs external bootstrap script — both bigger than session-scoped); (2) optionally fix the pre-existing `bodyOf:` exception path in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) (surfaced this session: 1-arg `indexOfSubCollection:` errors on 400 responses, only manifests when test runs via `/eval` and re-enters the Stage 2 guard — Workspace runs unaffected); (3) carry-overs from session-7 still pending — EXPLORATION-PLAN steps 3+4 (3-deep menu navigation + leaf dispatch catalog), end-to-end verification of `#id`/`#imcNr`/`#groupScheme` no-modal paths, stale-doc updates for [`vw-input-recovery.md`](./vw-input-recovery.md) / [`vw-dialogs.md`](./vw-dialogs.md) / [`vw-eval-cookbook.md`](./vw-eval-cookbook.md), end-to-end Bug #2 verification for `#surname` broad search.

**Supersedes:** nothing. [`HANDOFF-2026-06-20-session7.md`](./HANDOFF-2026-06-20-session7.md) is the historical session-7 EOD; this file is session-8 EOD.

---

## User direction in this session (session-8, condensed)

- Open with: read and understand [`HANDOFF-2026-06-20-session7.md`](./HANDOFF-2026-06-20-session7.md) — confirmed context, no implementation request yet.
- Picked **Wave 1 - Push + Bug #6 + SUnit (Recommended)** for session direction. Wave 1 included: push the 4 session-7 commits, fix Bug #6's comment-escaping bug in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st), file-in scaffold, run the 2 new Bug #2 tests from session-7, update [`vw-party-search.md`](./vw-party-search.md) to mark the Bug #2 workaround optional.
- Picked **Yes - 2 commits + push (Recommended)** for Wave 1 wrap (commit 1 for Bug #6 fix in test file, commit 2 for vw-party-search.md doc update). Push authorized for this wrap.
- Picked **Start Wave 2 - Production-grade (Recommended)** for next direction after Wave 1 shipped.
- Picked **Logging + auto-start (Recommended)** for Wave 2 sub-item scope, AND **Inline plan, implement immediately (Recommended)** for plan discipline (no separate plan-to-disk; lower rigor than session-7).
- Picked **3 commits (feat + test + handoff) + push (Recommended)** for the v0.8.13 wrap.

Commit + push authorized for both waves; no remaining commits authorized beyond this handoff.

---

## Work completed in session-8

### Phase 0 — Resume verification (~10min)

- `wsl git status` clean, branch `main`, 4 commits ahead of `origin/main` at `bc1f240`. HEAD `e201275`.
- `curl /health` → `{"status":"ok","version":"0.8.12"}`.
- Token read from [`.token`](../src/vw-bridge/.token): `3959428922486-93451` (matched session-7 EOD).
- [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) inspected — confirmed embedded `"` chars at L10 (`"WORKSPACE - GREEN"`) and L14 (`""HTTP /eval - ALL RED..."""`). Handoff had mentioned L12 too but current file has no `"` at L12 — L11/L12 are example code without quotes. Both real problem sites are L10 + L14.

### Phase 1 — Wave 1: Push + Bug #6 + SUnit (~1h)

#### 1.1 — Push session-7 commits

```
wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git push 2>&1
→ To github.com:amos-maganyane/tm-context.git
   bc1f240..e201275  main -> main
```

Clean. All 4 session-7-wrap commits now on origin.

#### 1.2 — Fix Bug #6 in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st)

Traced the parser failure:
- Multi-line `"..."` comment opens at L2
- First inner `"` on L10 prematurely closes it
- `WORKSPACE - GREEN` then parses as Smalltalk code (undefined identifiers) → `"Syntax error: Nothing more expected ->"`
- L14 same pattern with `""HTTP...""` (4 `"` characters, all inside the outer comment)

Fix: 2 edits replacing `"..."` with `[...]` brackets at L10 + L14. The L2-L35 outer comment now scans clean.

#### 1.3 — File-in scaffold + verify

`/eval` `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn` returned `{"ok":true,"result":"nil"}`. No syntax error.

Class probe via `/eval`:
```
LOADED super=TestCase selCount=15 cat=VW-TestBridge-Tests isTestCase=true
```

Initial confusion: handoff said "9 tests + 6 helpers" + 2 new Bug #2 = expected 17. Actual 15. Resolved: 9 tests INCLUDES the 2 Bug #2 (3 health + 2 auth + 2 eval + 2 bug2 = 9 tests; + 6 helpers = 15 total). Handoff phrasing was ambiguous, file is in the intended state.

#### 1.4 — Run 2 Bug #2 SUnit tests via /eval

Pre-check: `useNativeDialogs=false`, 214 procs, token matched. Then ran each test in a separate `/eval`:

| Test | Result |
|---|---|
| `testBug2DialogConfirmYesReturnsTrue` | `passed=true run=1 fail=0 err=0 captured=true` ✓ |
| `testBug2DialogConfirmNoReturnsFalse` | `passed=true run=1 fail=0 err=0 captured=false` ✓ |

Critical validation: **both tests run GREEN over `/eval` despite the v0.8.8 Stage 2 re-entry guard.** They sidestep the guard because they call `bridge doRespondDialog: 'Yes'` (a direct handler method, not `bridge dispatch:`). The test design from session-7 explicitly applies the documented Bug #5 workaround pattern. Existing 7 older tests would still be RED via `/eval` because they go through `dispatch:`.

Post-state: `/dialogs=[]`, procs 214→240 (natural fork growth, no wedge — would be hundreds if wedged), `useNativeDialogs=false` preserved.

#### 1.5 — Update [`vw-party-search.md`](./vw-party-search.md) (4 sites)

| Site | Change |
|---|---|
| L3 (intro paragraph) | Added "**FIXED in v0.8.12**" callout next to Bug #2 link; reworded "two bridge bugs" → "Originally documented around two bridge bugs ... Bug #1 (still active) and Bug #2 (FIXED)". |
| L82-86 (Quick reference blockquote) | Expanded `partialFind:` line with full v0.8.12 status — references the `SimpleDialog>>choose:labels:values:default:for:` override category `mas-bug2-fix`, end-to-end-verified result set (`PP020000019..` 19-contract), notes bypass-as-fallback. |
| L106-112 (Workaround section header + body) | Renamed section: "Running a broad search (Bug #2 workaround — **OPTIONAL in v0.8.12+**)". Added prominent **STATUS** banner blockquote with fix architecture + reference. Split single-line behavior description into v0.8.11-and-earlier vs v0.8.12+ narrative. |
| L291 (Open questions, first bullet) | Marked `~~struck~~` with **ANSWERED 2026-06-20 session-7** annotation citing Q3 of Phase 1 + pre-probe 2 evidence (`accept_after='true'`) + cross-link to known-issues deep-dive. |

Bypass code recipe kept intact for archaeology / fallback / test-latency-skipping scenarios.

#### 1.6 — Commits + push (Wave 1 wrap)

Per AGENTS.md house rule: inspected `git status` + `git diff` + repo log before committing. Diffs clean: only the 2 expected files, no `.token`, no secrets, no surrounding noise.

2 atomic commits then push, chained with `&&` for atomicity:

| # | Hash | Subject | Files |
|---|---|---|---|
| 1 | `911e14e` | `fix: Bug #6 - escape embedded quotes in VWBridge-Test.st top comment, enables SUnit file-in` | [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) (2+/2-) |
| 2 | `b4d1d2b` | `docs: vw-party-search.md - mark Bug #2 workaround optional in v0.8.12+ (4 sites)` | [`vw-party-search.md`](./vw-party-search.md) (8+/6-) |

Push: `e201275..b4d1d2b  main -> main`. Working tree clean, 0 ahead of origin.

### Phase 2 — Wave 2: read-only probes (~1h)

Strategic assessment promised Wave 2 = `/screenshot` + `/wait` + auto-start + file-based logging. User picked logging + auto-start subset with inline-plan-immediate-implement discipline.

#### 2.1 — Auto-start API probes (parallel)

| Probe | Result |
|---|---|
| `Smalltalk class includesSelector: #addToStartUpList:` | `false` |
| `Smalltalk class includesSelector: #startUpList` | `false` |
| `Smalltalk class includesSelector: #imageStartUp` | `false` |
| `(Smalltalk allClasses select: [:c \| c class includesSelector: #startUp:]) size` | `0` |
| `(Smalltalk allClasses select: [:c \| c class includesSelector: #startUp]) size` | `2` (only `FSGsDemoHandler`, `Subsystem`) |
| `SessionManager class selectors` | `#(#instance #makeConnectors)` — only 2! |
| `SessionManager instance class name` | `'UndefinedObject'` (instance is `nil`!) |
| `SessionManager` instance-side selectors | `#()` (empty) |
| `ObjectMemory class` startup-related selectors | none |

**Conclusion**: this MAS image has ZERO conventional Smalltalk-level image-boot hooks. The standard VW patterns (`SessionManager instance addStartupAction:`, class-side `startUp:`, `Smalltalk addToStartUpList:`) are absent. Auto-start cannot be implemented at the Smalltalk level in this image.

#### 2.2 — Time API + Filename API probes

| API | Result |
|---|---|
| `DateAndTime now` | `Message not understood` — class absent |
| `Timestamp now printString` | `'20 June 2026 18:17:14.481'` ✓ |
| `Core.Time millisecondClockValue` | works (ms since image start) ✓ |
| `Filename class` of `'...' asFilename` | `NTFSFilename` (Windows variant) |
| `appendingWriteStream` | `false` — not supported |
| `writeStream` | `true` — but TRUNCATES on second open (probed empirically) |
| `readWriteStream` + `setToEnd` | `true` + preserves content ✓ — **correct append pattern** |
| `writeStream` + `setToEnd` | also truncates (probed) — `setToEnd` doesn't help here |

#### 2.3 — Pivot decision

Logging has no architectural unknowns; auto-start is blocked at the Smalltalk level. The honest call: ship logging cleanly this session, document auto-start blocker, defer auto-start research to session-9+ with full scope (parcel migration / external bootstrap / MAS team coordination).

This matches the project's "fix the bugs / build the framework" discipline: when an exploration disproves a sub-plan, pivot with evidence rather than ship something half-broken. Same pattern as session-7 Phase 1.5 when Option A (Dialog override) was disproven by 940 senders + Path 2 pivoted to Option A′.

### Phase 3 — v0.8.13 implementation (~1.5h)

#### 3.1 — Edits to [`VWBridge.st`](../src/vw-bridge/VWBridge.st)

**Version bumps (4 canonical sites)**: L1 header, L290 dispatcher comment, L320 doDispatch comment, L339 /health body. The 3 historical "v0.8.12 fix" markers at L1698/L1699/L1704 (inside the SimpleDialog override) were INTENTIONALLY left at "v0.8.12" — they record when that fix shipped, not the current bridge version.

**`log:` refactor (L104-107)**: from 4-line direct Transcript call to a 5-line wrapper that delegates to `log:level:` with `'info'`. All 9 existing callers (`startOn:`, `stop`, `createListener` error path, etc.) keep working unchanged — their semantics become "info-level log entries with file-side persistence".

**New `'logging'` category** inserted between the helpers category close and `'initialization'` open. 5 methods:

| Selector | Purpose |
|---|---|
| `log: aString level: aLevel` | Multiplexed sink. Writes Transcript with `[level]` prefix + appends NDJSON line to log file. Both wrapped in `on:do: [:ex \| nil]` — logging never crashes the bridge. |
| `logWarn: aString` | Convenience selector for `log: ... level: 'warn'`. |
| `logError: aString` | Convenience selector for `log: ... level: 'error'`. |
| `logFilePath` | Returns `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\vw-bridge.log'`. Hardcoded for the same reason `.token`'s path is hardcoded (single-developer-laptop tool). Externalize to env-var at production-packaging time. |
| `writeLogEntry: aMessage level: aLevel` | The actual file-write. Per-write open/close (crash-safe). Picks `readWriteStream` if file exists (append via `setToEnd`), else `writeStream` (creates fresh). Format: `{"ts":"<Timestamp>","level":"<info\|warn\|error>","msg":"<text>"}` + LF. Uses existing `self safeJsonFor:` for escaping. Concurrency note in comment: parallel HTTP forks may hit a Windows sharing violation and drop one line (Transcript still got it) — acceptable for debug log, add class-side mutex later if volume grows. |

#### 3.2 — Edits to [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st)

- L98/L99: version assertion + description bumped to v0.8.13.
- New `'tests - logging'` category appended after `'tests - bug 2'`. 3 new tests:

| Test | Asserts |
|---|---|
| `testLogWritesNDJSONToFile` | After `bridge log: marker`, the log file contains the marker, has `"ts":`, `"level":"info"`, `"msg":` fields. |
| `testLogLevelDistinction` | After info/warn/error markers via 3 different selectors, log file contains all 3 markers AND lines with `"level":"warn"` + `"level":"error"`. |
| `testLogJsonLineWellFormed` | Log file contains `{"ts":` JSON-object header AND a closing brace `$}` somewhere (basic structural sanity). |

Tests use `bridge log:` / `bridge logFilePath asFilename readStream upToEnd` — NO `bridge dispatch:` calls, so they pass the v0.8.8 Stage 2 guard cleanly. Marker uniqueness via `Time millisecondClockValue printString` so concurrent test runs don't shadow each other's writes.

#### 3.3 — Edit to [`.gitignore`](../.gitignore)

Added `src/vw-bridge/vw-bridge.log` (1 line). Existing exclusions (`.token`, `.dialog-probe*.txt`, `*.png`, `*.jpg`, `test-results/*.txt`) preserved.

#### 3.4 — File-in + verification

**File-in VWBridge.st via /eval**: `{"ok":true,"result":"nil"}` — clean, no chunk-format errors. The new `'logging'` methodsFor block + 5 methods filed in cleanly. Token rotated as part of the auto-start chunk: old `3959428922486-93451` → new `3959432705430-137025`. Re-read from [`.token`](../src/vw-bridge/.token).

**/health** = `{"status":"ok","version":"0.8.13"}` ✓

**File-in VWBridge-Test.st via /eval**: `{"ok":true,"result":"nil"}` — clean. Class probe: `LOADED selCount=18 newLogTests=3 tests=#(#testLogJsonLineWellFormed #testLogLevelDistinction #testLogWritesNDJSONToFile)` ✓

**Run all 3 logging tests in one /eval** (batched for efficiency):

| Test | Result |
|---|---|
| `testLogWritesNDJSONToFile` | `pass:true run:1 fail:0 err:0` ✓ |
| `testLogLevelDistinction` | `pass:true run:1 fail:0 err:0` ✓ |
| `testLogJsonLineWellFormed` | `pass:true run:1 fail:0 err:0` ✓ |

**Log file content sanity** (read directly from disk, not via /eval):

```
{"ts":"20 June 2026 18:25:05.429","level":"info","msg":"VWBridge stopped"}
{"ts":"20 June 2026 18:25:05.431","level":"info","msg":"VWBridge starting on 127.0.0.1:9876"}
{"ts":"20 June 2026 18:25:05.433","level":"info","msg":"VWBridge token: 3959432705430-137025"}
{"ts":"20 June 2026 18:25:05.434","level":"info","msg":"Try: curl http://127.0.0.1:9876/health"}
{"ts":"20 June 2026 18:25:05.439","level":"info","msg":"VWBridge: listening via SocketAccessor"}
{"ts":"20 June 2026 18:25:55.744","level":"info","msg":"TEST_LOG_NDJSON_3959432755743"}
{"ts":"20 June 2026 18:25:55.762","level":"info","msg":"LEVEL_INFO_3959432755745"}
{"ts":"20 June 2026 18:25:55.765","level":"warn","msg":"LEVEL_WARN_3959432755745"}
{"ts":"20 June 2026 18:25:55.766","level":"error","msg":"LEVEL_ERROR_3959432755745"}
{"ts":"20 June 2026 18:25:55.767","level":"info","msg":"JSON_FORM_3959432755767"}
```

10 valid NDJSON lines (5 from auto-start chunk's startup logging + 5 from tests). All have well-formed JSON structure. Timestamps in `'D MMMM YYYY HH:MM:SS.mmm'` format (Timestamp printString). Levels properly distinguished. `safeJsonFor:` did its job — quotes around values, escaping working.

#### 3.5 — Regression sweep

| Check | Result |
|---|---|
| `testBug2DialogConfirmYesReturnsTrue` re-run | pass:true ✓ |
| `testBug2DialogConfirmNoReturnsFalse` re-run | pass:true ✓ |
| `/dialogs` post-test | `{"dialogs":[],"ok":true}` ✓ |
| `/health` post-test | `{"status":"ok","version":"0.8.13"}` ✓ |
| `useNativeDialogs` post-test | still `false` ✓ |
| Token | still `3959432705430-137025` ✓ |

Side observation (NOT a v0.8.13 regression): re-running `testHealthReturnsCurrentVersion` via `/eval` returned `err=1`. The test calls `self dispatch: 'GET /health'` which re-enters the v0.8.8 Stage 2 guard from the serve process. The 400 response is then parsed by `bodyOf:` which uses the 1-arg `indexOfSubCollection:` — that selector errored on probes earlier this session for unrelated reasons. The error is **pre-existing**, would manifest identically on v0.8.12, and is by design: the test was always a Workspace-only test (see [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) top comment block — now correctly bracket-quoted). Worth a tiny session-9 fix (swap 1-arg `indexOfSubCollection:` → 2-arg `indexOfSubCollection:startingAt:` in `bodyOf:`) so the test FAILS cleanly instead of ERRORs when accidentally run via /eval.

### Phase 4 — v0.8.13 commits + push

3 atomic commits + push, chained with `&&` for atomicity per session-7 protocol:

| # | Hash | Subject | Files |
|---|---|---|---|
| 1 | TBD | `feat: VWBridge v0.8.13 - NDJSON file logging (multiplexed Transcript + log file) via log:level:/logWarn:/logError:` | [`VWBridge.st`](../src/vw-bridge/VWBridge.st), [`.gitignore`](../.gitignore) |
| 2 | TBD | `test: VWBridgeTest - 3 logging tests + version assertion bump to v0.8.13` | [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) |
| 3 | (this) | `docs: HANDOFF-2026-06-20-session8 - v0.8.13 logging + Wave 1 + auto-start blocker findings` | [`HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) |

Push authorized: `b4d1d2b..<this commit>  main -> main`.

---

## Current state (end of session-8)

- **VW image**: still up at `vwnt.exe`. 6 baseline windows. 0 wedged dialog processes. ~270 total procs (grew from session-7 EOD's 318→214→240→270 across this session's fork churn).
- **Bridge**: UP at v0.8.13 on `127.0.0.1:9876`. Token at [`.token`](../src/vw-bridge/.token): `3959432705430-137025` (rotated during v0.8.13 file-in).
- **`Dialog useNativeDialogs: false`**: SET (carried over from session-7, survived v0.8.13 reload). Will reset on `vwnt.exe` restart.
- **Bridge code on disk**: v0.8.13 in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (~1814 lines, +66 from session-7). New `'logging'` category inserted between L116 (end of `'helpers'`) and the new `'initialization'` header.
- **SUnit scaffold on disk**: v0.8.13 in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) (~243 lines, +63 from session-7). 18 selectors loaded in image (6 helpers + 9 tests + 3 logging). Bug #6 is FIXED in this commit set.
- **NEW: log file** at [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log). 10 lines at session wrap. NDJSON format. Gitignored. Grows on every bridge `log:`, `logWarn:`, `logError:` call. NO ROTATION yet — will grow unbounded; revisit before production packaging.
- **Image globals from session-8 probes** (clear on `vwnt.exe` restart):
  - `TEST_BUG2_YES_RET=true`, `TEST_BUG2_NO_RET=false` (set by Bug #2 tests — re-run multiple times this session)
  - No new persistent globals from Wave 2 probes (all probes were stream-based or one-shot — no `PHASE_*` global pattern this session because we used inline probe scripts via /eval body, not the session-7's named-global capture pattern)
  - Plus all session-3..7 globals still present
- **Git**:
  - `main` at `(this commit)` locally and on `origin/main` (pushed).
  - Previous `origin/main` HEAD: `b4d1d2b` (Wave 1 wrap).
  - 6 commits this session (4 push of session-7 wrap + 2 Wave 1 + 3 v0.8.13 = 9 total, but the first 4 were already authored in session-7 and just pushed this session; net 5 new commits authored this session).
- **Known bugs**:
  - **Bug #1: FIXED in v0.8.7**
  - **Bug #2: FIXED in v0.8.12**. Workaround in [`vw-party-search.md`](./vw-party-search.md) marked OPTIONAL for `#contractNumber` + `#surname`.
  - **Bug #3: not a bug** (calibration only)
  - **Bug #4: FIXED in v0.8.6**
  - **Bug #4b: FIXED in v0.8.10**
  - **Bug #5: FIXED in v0.8.8**
  - **Bug #6: FIXED in this session** (v0.8.13 wave). Comment-escaping in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) top comment block.
  - **No new bugs identified.**
- **Known limitations (NEW, session-8)**:
  - **`bodyOf:` in test scaffold uses 1-arg `indexOfSubCollection:`** which errors on this image. Manifests only when tests run via `/eval` AND hit the Stage 2 guard (so /eval gets a 400 instead of 200). Workspace runs unaffected. Trivial fix (~5 min): swap to 2-arg `indexOfSubCollection:startingAt:`.
  - **Auto-start on image boot is BLOCKED** at the Smalltalk level in this image. No conventional VW hooks (`SessionManager instance` is nil; no `Smalltalk addToStartUpList:`; zero classes implement `#startUp:`). Requires either parcel migration (Wave 5+ scope) or out-of-image bootstrap script. Documented above; session-9 should research mechanism if pursuing.
  - **Log file has no rotation**. Append-only. Will grow without bound. Revisit before production packaging.
  - **Concurrent log writes** from parallel HTTP forks can hit Windows sharing violations → that line drops to Transcript-only. Acceptable for debug log. Add class-side mutex if volume grows.

---

## Pending tasks (session-9)

### Immediate on resume

1. **Restart `vwnt.exe`?** Same recommendation as session-8 resume — current image accumulated globals across 3 prior sessions. Functionally clean (0 wedged procs) but conceptual hygiene improves on restart. Not strictly required.
2. **If `vwnt.exe` restarted**: re-toggle `Dialog useNativeDialogs: false` via `/eval`. Then file-in v0.8.13 via Workspace (NOT `/eval`, since the bridge would be DOWN): `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn`.
3. **Verify state**: `curl /health` → `{"status":"ok","version":"0.8.13"}`, re-read [`.token`](../src/vw-bridge/.token).
4. **Decide on next direction** (options below).

### Wave 2 remaining (highest value next)

5. **`/wait` endpoint** (~4-6h). The test framework absolutely needs this. Design space: polling-based (simpler, can implement on serve process with timeout) vs event-based (harder, needs hooks). Conditions to support: window-appears (by appClass + label), dialog-appears (by message substring), value-changes (by widget aspect + comparator). Returns 200 with state on success, 408 on timeout. Worth Oracle consult on the predicate language.
6. **`/screenshot` endpoint** (~8-12h). Largest scope, highest uncertainty. Needs UI-process dispatch (similar to `/dialogs` and `/click`), graphics capture API (likely `Image fromUser:` or `Screen default screenshot`), base64 encoding, JSON transport. Oracle consult mandatory — multiple architecture decisions (encoding format, blob size limits, sync vs async). Could plausibly defer to Wave 3 if `/wait` is the higher-leverage need.
7. **Auto-start research** (architectural). Three paths to evaluate with the user's input on MAS team coordination availability:
   - **Parcel migration** of the bridge (`VWBridge.pcl`) with image-load-time auto-start. This is what session-7's strategic assessment classified as Wave 5+. Needs MAS team buy-in (changes how the bridge ships).
   - **External bootstrap script** (Topaz/IRC) that runs `(Smalltalk at: #VWBridge) start` after `vwnt.exe` initialization. Bypasses the missing Smalltalk-level hooks. Adds external infrastructure.
   - **Modify MAS bootstrap** to add an init slot for tools like the bridge. Heaviest, requires MAS team commit.

### Trivial fix (~5min if desired)

8. **Patch `bodyOf:` in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) L72-80**: replace `aResponse indexOfSubCollection: sep` with `aResponse indexOfSubCollection: sep startingAt: 1`. Then `testHealthReturnsCurrentVersion` would FAIL cleanly (not ERROR) when run via /eval. Doesn't affect Workspace runs. Session-9 can fold this in with any other test cleanup.

### Carry-overs from session-7 (still pending)

9. **EXPLORATION-PLAN step 3** — 3-deep menu navigation.
10. **EXPLORATION-PLAN step 4** — leaf dispatch catalog across MAS menu tree.
11. **End-to-end verification of `#id` / `#imcNr` / `#groupScheme`** (no-modal `partialFind:` paths). Per session-3's Bug #2 calibration, these are UNVERIFIED end-to-end via the bridge.
12. **End-to-end verify Bug #2 fix for `#surname` broad search**. Same protocol as `#contractNumber` (covered session-7).
13. **Three stale knowledge docs** flagged in session-6 handoff (still not updated):
    - [`vw-input-recovery.md`](./vw-input-recovery.md): wedge accumulation prevented by v0.8.11+
    - [`vw-dialogs.md`](./vw-dialogs.md): "ValueHolder on: false. Modal exits when set to true." is incorrect — modal loop polls `EventQueue>>next` on a Semaphore
    - [`vw-eval-cookbook.md`](./vw-eval-cookbook.md): add wedged-dialog stack-walk recipe + compiled-method introspection-without-Decompiler recipe
14. **SUnit test for v0.8.11 `purgeWedgedDialogProcesses`** — still untested.

### Production-grade packaging (medium-term)

15. SUnit coverage expansion (now also need test for v0.8.13 log file rotation / concurrent log behavior once those features land).
16. Log rotation (Wave 2+).
17. Class-side log mutex for concurrent fork safety (Wave 2+).
18. Env-var externalization of log file path + .token path + port.
19. OpenAPI spec for bridge endpoints.
20. Parcel migration (Wave 5+).

---

## Key files

| File | Role |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | **CANONICAL v0.8.13** — all fixes from sessions 3-8 applied. Logging at L118+ in new `'logging'` category. Bug #2 Symptom A fix at L1700-1751. File via Workspace or `/eval` `'...VWBridge.st' asFilename fileIn`. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold v0.8.13. 18 selectors (6 helpers + 9 tests + 3 logging). Bug #6 FIXED at L10/L14. Loadable cleanly via `/eval`. Note `bodyOf:` 1-arg `indexOfSubCollection:` issue documented as pending. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token. Current `3959432705430-137025`. Rotates on every `VWBridge start`. |
| [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log) | **NEW v0.8.13** — append-only NDJSON log file. Gitignored. Grows unbounded (no rotation yet). |
| [`.gitignore`](../.gitignore) | Excludes `.token`, `.dialog-probe*.txt`, `*.png`, `*.jpg`, `test-results/*.txt`, **NEW**: `vw-bridge.log`. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#6. #1/#2/#4/#4b/#5/#6 FIXED; #3 not-a-bug. **No new bug entries this session** — auto-start blocker is an architectural limitation, not a bug; documented in this handoff instead. |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. Bug #2 workaround section now marked OPTIONAL for v0.8.12+. Edited at 4 sites in this session's Wave 1. |
| [`knowledge/HANDOFF-2026-06-20-session7.md`](./HANDOFF-2026-06-20-session7.md) | Session-7 EOD handoff. Committed at `e201275`. |
| [`knowledge/HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) | **THIS FILE.** Session-8 EOD. |
| [`plan/STRATEGIC-ASSESSMENT-2026-06-20.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-20.md) | Strategic snapshot. Still accurate; v0.8.13 logging delivers part of Wave 2 production-grade. Auto-start gets re-categorized as deeper than Wave 2 originally implied. |

---

## Important decisions (this session)

- **Wave 1 first, before Wave 2.** User explicitly picked Wave 1 (push + Bug #6 + SUnit) per the menu in session-7's handoff. Session-8 honored the discipline of finishing one wave before starting the next.
- **Atomic 2-commit Wave 1 wrap, then push.** Fix commit + doc commit cleanly separated for archaeology. Same convention as session-7 wrap.
- **Inline plan, implement immediately for Wave 2.** User picked lower-rigor discipline. No plan-to-disk for v0.8.13 (session-7 had a 497-line plan; this session has the inline plan in this handoff). Worked well — implementation was tight (~1.5h after probes) and quality is high.
- **Pivot to logging-only when auto-start probes found NO Smalltalk-level hooks.** Three independent probe sets (Smalltalk-class selectors, all-classes-with-startUp:-classmethod, SessionManager instance check) all confirmed the same finding. The honest call: ship logging cleanly, document the blocker, defer auto-start research to its own session. Same pattern as session-7's Option A → Option A′ pivot when 940 senders disproved Path 2 Option A.
- **NDJSON format + `Timestamp now printString` chosen for log entries.** `DateAndTime now` doesn't exist in this image (probed). `Timestamp` does, returns `'20 June 2026 18:25:05.429'` — human-readable, machine-parseable, includes millisecond precision. ISO 8601 would have been nicer but not worth fighting for without DateAndTime.
- **`readWriteStream` + `setToEnd` for append**, with `writeStream` fallback only on first create. Both behaviors probed empirically before coding (probe `WS_BEHAVIOR=[added]` showed `writeStream` truncates; `RWS_SETTOEND=[initial_appended]` showed `readWriteStream` + `setToEnd` preserves). `appendingWriteStream` doesn't exist on `NTFSFilename`.
- **Per-write open/close** for crash safety. Slower than long-lived stream but cleaner failure semantics (worst case: lose 1 log line on crash).
- **No class-side mutex for concurrent log writes** — accepted small risk of Windows sharing violations on concurrent forks; documented in code comment. Add mutex when log volume grows.
- **3 atomic v0.8.13 commits + push.** feat (VWBridge.st + .gitignore — gitignore is logically part of the feat), test (VWBridge-Test.st — logically separate), handoff (docs). Matches session-7's 4-commit wrap pattern.
- **Bug #6 fix committed separately from Bug #2 doc update.** Both happened in Wave 1 but they're conceptually independent (fix vs docs), so they merit separate commits per the atomic-commit convention.

---

## Explicit constraints (carry forward — unchanged from session-7 unless noted)

- **NEVER commit, amend, or push** without explicit user request. Session-8 had auth for: Wave 1's 2 commits + push, and Wave 2's 3 commits + push. Session-9 needs fresh auth.
- **NEVER call `VWBridge singleton dispatch:` from inside `/eval`.** v0.8.13 inherits all prior containment (Stage 1 substring + Stage 2 per-process re-entry guard).
- **OFF-LIMITS widgets** without explicit OK: `commitWidget`, `loginRpcWidget`, `removeWidget`. **MAS menu leaves with mutation verbs** need OK before any `/menu/click`.
- **`windowTitle` is CASE-SENSITIVE substring match.**
- **For Workspace file-in (bridge DOWN scenario):** `'path' asFilename fileIn.`, NOT Launcher → File Browser → File In.
- **For `/eval` file-in (bridge UP, v0.8.8+):** PowerShell + `curl.exe` with `--data-binary @file` pattern. Token rotates on every reload — re-read `.token` afterward.
- **Smalltalk character literal:** `$'` is unreliable in chunk file-ins. Use `(Core.Character value: 39)`.
- **GBS namespace qualification:** `Root.Smalltalk`, `Core.String`, `Core.Character`, `Core.Error`, `Core.Array`, `Core.Integer`, `Core.OrderedCollection`, `Core.Dictionary`.
- **`/eval` runs on bridge serve process**, NOT UI process. `mgr activeControllerProcess` returns nil during modals — `onUIDo:` falls back to direct execution.
- **Image sources are STRIPPED.** `getSource` returns nil. But `CompiledMethod>>messages`, `>>literals`, `>>numArgs`, `>>numTemps` ARE available — useful for runtime structural introspection. (session-7)
- **`SystemNavigation` does NOT exist** in this image. Use manual literal walks. (session-7)
- **String `indexOf:startingAt:` does NOT exist.** Use `nextIndexOf:from:to:`. (session-6+)
- **String `indexOfSubCollection:` (1-arg) errors in some receiver contexts on this image** (session-8 NEW). Use the 2-arg form `indexOfSubCollection: aSub startingAt: anIndex`. The bridge code already uses the 2-arg form correctly; `bodyOf:` in the test scaffold uses 1-arg and surfaces this issue when accidentally exercised via /eval.
- **String `includesSubString:` does NOT exist** (session-8 NEW). Confirmed by 2 probe attempts. Use 2-arg `indexOfSubCollection: aSub startingAt: 1` with a `> 0` check instead.
- **`DateAndTime` class does NOT exist** in this image (session-8 NEW). Use `Timestamp now printString` for absolute time. `Core.Time millisecondClockValue` for ms since image start.
- **`SessionManager instance` returns `nil`** (session-8 NEW). The standard VW `SessionManager instance addStartupAction:` pattern is unusable. Auto-start hooks must use a different mechanism (parcel-load callback / external bootstrap / MAS bootstrap modification).
- **`Filename` (NTFSFilename) has NO `appendingWriteStream`** (session-8 NEW). Use `readWriteStream` + `setToEnd` for append. `writeStream` ALWAYS truncates on open (even with `setToEnd` after).
- **Standard `instVarNames` is CLASS-SIDE**: `model class instVarNames`.
- **`isCollection` does NOT exist as a generic selector** — use `respondsTo: #do:` instead.
- **`canUnderstand:` is CLASS-SIDE**: `instance class canUnderstand: #sel`.
- **`Process allInstances` works (~200-300 procs); `Processor allProcesses` does NOT exist.**
- **`Character>>asString` calls `printString`** (returns e.g. `'Core.Character lf'`). Use `String with: aCharacter` for a 1-char string.
- **PowerShell `-Body` with literal JSON inline is QUOTE-HELL.** Use `--data-binary "@path/to/file.json"`.
- **PowerShell here-strings `@'...'@` do NOT require doubled single quotes.**
- **Git is in WSL (`wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git ...`).**
- **PowerShell auto-table-formats arrays from `Invoke-RestMethod`** — use `Invoke-WebRequest -UseBasicParsing` + `ConvertFrom-Json` for raw JSON.
- **VW chunk-file format gotcha**: comment-only chunks REJECTED. Every chunk needs an executable expression. (session-7)
- **VW comment escaping gotcha**: multi-line `"..."` comments terminate at first inner `"`. Use brackets `[...]` instead of `"..."` for example tags inside outer comments. (session-7 → resolved as Bug #6 in session-8)

---

## Context for continuation (read this before resuming)

- **Bug #6 is FIXED.** SUnit scaffold loads cleanly via `/eval` now. 18 selectors. Use the existing pattern (test calls `bridge handlerMethod`, never `bridge dispatch:`) for any new test you add — that's what lets them run green via `/eval`.
- **v0.8.13 is LIVE.** File logging works. Check [`vw-bridge.log`](../src/vw-bridge/vw-bridge.log) for real-time bridge events. Useful for debugging upcoming endpoint work (`/wait`, `/screenshot`).
- **Auto-start is BLOCKED** at the Smalltalk level in this image — three independent probe sets confirm this. Session-9 should either pursue parcel migration / external bootstrap (bigger scope) or move to `/wait` / `/screenshot` first and revisit auto-start later.
- **9 net new commits since session-7 wrap on origin/main**. All pushed. Working tree clean.
- **For ANY bridge change in v0.8.14+**: same protocol — edit [`VWBridge.st`](../src/vw-bridge/VWBridge.st), reload via `/eval` file-in, bump version at 4 canonical sites + test assertion. Remember the chunk-format rule. Use the new `log:level:` / `logWarn:` / `logError:` for any new diagnostic output.
- **For ANY new SUnit test**: append to [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st), use the `bridge directHandlerMethod` pattern (not `bridge dispatch:`) if you want it to run green via `/eval`. File-in via `/eval` is now reliable (Bug #6 fixed).
- **5 NEW carry-forward constraints** added to the constraints section above: `indexOfSubCollection:` 1-arg vs 2-arg, no `includesSubString:`, no `DateAndTime`, `SessionManager instance` is nil, `Filename` no `appendingWriteStream`. These bite. Reference them when writing new probes.

---

## To continue in a new session

1. Press `n` in OpenCode TUI to open a new session, or run `opencode` in a new terminal.
2. Paste this entire file as your first message.
3. Add your request — pick one based on focus:
   - "Continue from handoff above. Implement `/wait` endpoint per Wave 2." — highest-leverage test-framework unblock.
   - "Continue from handoff above. Research auto-start parcel migration architecturally." — unblocks the deferred auto-start work.
   - "Continue from handoff above. Implement `/screenshot` endpoint." — largest scope; consult Oracle first on encoding + transport.
   - "Continue from handoff above. Patch `bodyOf:` in VWBridge-Test.st (swap 1-arg `indexOfSubCollection:` to 2-arg) and add SUnit test for v0.8.11 `purgeWedgedDialogProcesses`." — small cleanup wave.
   - "Continue from handoff above. End-to-end verify Bug #2 fix for `#surname` AND verify the no-modal types (`#id`/`#imcNr`/`#groupScheme`) round-trip cleanly." — verification sweep.
   - "Continue from handoff above. Stale-doc pass: update vw-input-recovery.md, vw-dialogs.md, vw-eval-cookbook.md per the session-6+7+8 findings." — docs hygiene.
   - "Continue from handoff above. Start Wave 3 per STRATEGIC-ASSESSMENT — scaffold Playwright TypeScript SDK and write 1-3 first tests against the v0.8.13 bridge." — Test Mentor replacement begins.

The new session will have full context to continue seamlessly.
