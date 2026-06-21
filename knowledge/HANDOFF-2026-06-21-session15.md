# Handoff — Phase P P2 binding bug fix + direct-invoke gate pattern (session 2026-06-21 session-15 EOD)

**Written:** session-15 EOD after a long but productive debugging spiral. Three atomic commits shipped local (not yet pushed to `origin/main`): [`cac044f`](#binding-fix) (fix test bindings), [`aeb4a82`](#docs) (docs api-contract session-15 additions), [`d096ac6`](#probes) (17 probe diagnostic trail). 5 additional probe files untracked at EOD.

**For session-16:** (1) **push** the 3 local commits to `origin/main`; (2) **systematic gate sweep** chosen by user but deferred to next session — run WaitTest + ScreenshotTest gates first, then fix all latent bugs in one batch, then re-run all gates; (3) commit the 5 leftover probes from the gate-experiment work; (4) Stage 3 (`load.st` + `unload.st`) still pending from session-14; (5) Phase P P5/P6/P7/P8 still pending.

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session14.md`](./HANDOFF-2026-06-21-session14.md) remains the session-14 EOD; this file is session-15 EOD.

---

## User direction this session (condensed)

- Resume prompt with 4 anchor docs + Phase 0 verification. Picked **Option 1 (Push 8 commits to origin/main)** as the recommended first action.
- After push: picked **SUnit Workspace gate (safe, ~5 min)** when offered choice between Workspace gate / Stage 3 / parallel / stop.
- After Workspace expression I provided syntax-errored: user noted **"syntax error which is why eval safe eval could have helped"** — rightly criticized me for not /eval-verifying the Smalltalk before handing to Workspace paste. Lesson absorbed.
- After Workspace expression triggered runaway test run (TestCase.testClasses MAS-customization walks whole image): picked **Kill vwnt.exe → full restart** when Task Manager couldn't kill the wedged process.
- After restart + binding bug diagnosis: picked **Option A (source fix + re-file-in + retest)** for the bindings.
- After binding fix verified: picked **Yes, set VW_BRIDGE_HOME at OS User env level (Recommended)** so future vwnt.exe launches inherit automatically.
- Pushed back twice on workflow: (a) "normally files ins are things you did yourself" — reasserted that I should drive `/eval`-based file-ins, not punt to Workspace; (b) "syntax error which is why eval safe eval could have helped" — establishing /eval pre-flight as a discipline.
- After P1 gate green: picked **/eval experiment for one dispatching test** to test the TestFailure-catch theory.
- After full VWBridgeTest gate via direct-invoke pattern (10/20 pass + bugs discovered): picked **Systematic: all gates → all fixes → all gates again** then immediately halted with **"carry to next session, update handoff, note memory MCP"** — recognized the systematic option was a session-16 scope of work.

---

## Work completed in session-15

### Pushed session-14's 8 commits to `origin/main`

`090b89a..460f903 main -> main` clean. Now `origin/main` matches `460f903` (session-14 EOD docs commit). 0 commits ahead of origin/main immediately after push.

### Discovered + fixed latent binding bug from session-14 Stage 2

**Root cause** (proved via `_probe-session15-bindings.st`):

- Chunk file-in via `'path' asFilename fileIn` compiles methods in **Smalltalk's namespace context, NOT the class's own environment**
- Bare `VWBridge` references in `VWB.VWBridgeTest>>setUp` and 20+ other test methods compiled into `(ResolvedDeferredBinding key: #VWBridge)` pointing at the now-empty `Smalltalk.VWBridge` slot (removed in Stage 2)
- At runtime, `binding value` returned `nil` → `nil singleton` → MNU
- Latent because session-14 never ran the full SUnit suite end-to-end after Stage 2

**Fix** (commit [`cac044f`](#binding-fix)): targeted replaceAll `VWBridge ` → `VWB.VWBridge ` across 3 test files via Edit tool. 22 line edits total. Symbol literals (`#VWBridgeTest`) and HTTP header strings (`X-VWBridge-Screenshot-Width:`) preserved (trailing-space pattern doesn't match them).

**Verification**: post-fix `(VWB.VWBridgeTest compiledMethodAt: #setUp) literals first` shows `#{VWB.VWBridge}` (hard qualified ref, not deferred). Smoke test `testVwBridgeHomeOverrideTakesPriority` returns `1 run, 1 passed, 0 failed, 0 errors` via /eval.

### Discovered MAS-customized `TestCase>>testClasses`

This image's `TestCase class >> testClasses` is defined as `^ServerTestCase testClasses , ClientTestCase testClasses` (verified via CompiledMethod literals introspection in `_probe-session15-buildsuite-diag.st`). Walks the ENTIRE union of GemStone+VW server-side and client-side test class trees — hundreds of `GemStoneClasses.Pip*Tests.*`, `GemStoneClasses.PPParty*Tests.*`, `GemStoneClasses.PipInstructionTests.*`, etc.

**Consequence**: `cls suite run` on ANY `TestCase` subclass aggregates the whole MAS test universe. This is what walked the runaway when user first pasted the Workspace expression. Bridge wedged.

**Workaround discovered**: `cls buildSuiteFromLocalSelectors run` uses ONLY the class's local `test*` selectors (bypasses the `testClasses` walk). For selective subsets: `TestSuite new addTest: (cls selector: sel)` per selector.

### Discovered direct-invoke gate pattern (PROVEN SAFE)

**Pattern**:
```smalltalk
| tc |
tc := cls new.
[[tc setUp.
  tc perform: aTestSelector]
    on: Core.Exception
    do: [:ex | "handle"]]
    ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]]
```

**Why safe**: bypasses SUnit's `TestCase>>runCase` which has the debugger-popping path (session-12 constraint #2). Exceptions bubble to our outer handler cleanly.

**Verified empirically** on all 20 VWBridgeTest selectors (per `_probe-session15-full-gate-VWBridgeTest.st`):
- Bridge survived the full sweep (no wedge)
- 10 PASS, 0 FAIL (TestFailure), 10 ERROR (caught Exception/Error)
- No debugger pops
- Per-selector isolation worked (tearDown ran for every test)

**Also verified separately** (per `_probe-session15-testfailure-api.st`):
- `TestFailure signal` (unary class-side) raises TestFailure cleanly
- `on: Core.Exception do:` CATCHES TestFailure at the language level (TestFailure inherits from Exception, not Error)
- `TestFailure signal: 'msg'` (keyword form) is ABSENT in this image — MNU
- So session-12 debugger-pop is a SUnit-internal mechanism (probably `Debugger openOn:` in runCase), NOT a language-level escape — our outer-handler pattern dodges it cleanly

### VWBridgeTest gate result via direct-invoke (PARTIAL — 10/20 pass)

| Result | Count | Selectors |
|---|---|---|
| ✅ PASS | 10 | testClearVwBridgeHomeOverrideRestoresEnvLookup, testLogFilePathDerivesFromVwBridgeHome, testLogJsonLineWellFormed, testLogLevelDistinction, testLogWritesNDJSONToFile, testPurgeWedgedDialogProcessesIdempotentOnCleanImage, testPurgeWedgedDialogProcessesReturnsNonNegativeInteger, testScreenshotHelperScriptPathDerivesFromVwBridgeHome, testTokenFilePathDerivesFromVwBridgeHome, testVwBridgeHomeOverrideTakesPriority |
| ❌ ERR — `#indexOfSubCollection:` MNU | 7 | testEvalEvaluatesArithmetic, testEvalReturnsErrorForBadCode, testHealthDoesNotRequireAuth, testHealthReturnsCurrentVersion, testHealthReturnsStatusOK, testWindowsAcceptsValidAuth, testWindowsRequiresAuth |
| ❌ ERR — `Notification` (empty msg) | 3 | testBug2DialogConfirmNoReturnsFalse, testBug2DialogConfirmYesReturnsTrue, testPurgeWedgedDialogProcessesUnwedgesActiveModalFork |
| ⚠️ FAIL (actual TestFailure) | 0 | None — every failing test errored BEFORE reaching its assertion |

### Discovered 2 NEW latent test code bug classes

1. **`#indexOfSubCollection:` 1-arg form in test code** — production bridge code was fixed session-13 (v0.8.13+session-9 A1 swap to 2-arg `:startingAt: 1` form). Test code was NEVER fixed. 7 VWBridgeTest selectors hit it; likely many more in WaitTest + ScreenshotTest (not yet gate-checked). Same mechanical replaceAll fix as binding bug.
2. **`Notification` (empty message)** in 3 dialog-interaction tests. Root cause UNKNOWN. Needs investigation in session-16.

### Set `VW_BRIDGE_HOME` at OS User env level

`[System.Environment]::SetEnvironmentVariable("VW_BRIDGE_HOME", "C:\Users\ammaganyane\tm\tm-context\src\vw-bridge", "User")`. Persistent across vwnt.exe restarts. Closes the recurring "env var missing on new process launch" gap permanently. All future vwnt.exe processes inherit automatically.

### Shipped 3 atomic commits

| Commit | Subject | Files |
|---|---|---|
| [`cac044f`](#binding-fix) | fix(vw-bridge): qualify VWBridge refs in test classes (session-15) | 3 test files, 24/24 lines |
| [`aeb4a82`](#docs) | docs(api-contract): chunk file-in scope + SUnit semantics (session-15) | knowledge/vw-image-api-contract.md, 136/5 lines |
| [`d096ac6`](#probes) | probes: session-15 SUnit semantics + bindings investigation | 17 probe files, 324 lines |

### Populated `memory` MCP knowledge graph

8 entities + 12 relations capturing: user preferences/behaviors, project state, VWB.VWBridge class facts, VW image runtime quirks, session-15 events, latent bug catalog, direct-invoke gate technique, Phase P progress. Future sessions should `memory_search_nodes` at startup to absorb context.

---

## Current state (end of session-15)

- **VW image:** RESTARTED mid-session. Was `vwnt.exe` PID 5624 (7-session continuous run started 6/20/2026 1:07:31 PM); now PID **6236** started 6/21/2026 11:40:56 AM.
- **Bridge:** UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: `3959495310063-903045` (read from [`.token`](../src/vw-bridge/.token); rotated on the restart's auto-start chunk).
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` (preserved through restart; namespace migration survives file-in cycle).
- **`Dialog useNativeDialogs: false`:** SET (re-toggled after restart via Workspace Block A).
- **`VW_BRIDGE_HOME` env var:** SET at User OS level (`C:\Users\ammaganyane\tm\tm-context\src\vw-bridge`). Persistent.
- **Bridge code on disk:** matches image AFTER the binding fix re-file-in (3 test files updated + filed-in via /eval). Production bridge file (`VWBridge.st`) unchanged this session — was already correctly qualified.
- **Git:** `main` is **3 commits ahead of `origin/main`** at EOD ([`cac044f`](#binding-fix), [`aeb4a82`](#docs), [`d096ac6`](#probes)). Push deferred to session-16.
- **Untracked at EOD:** [`opencode.json`](../opencode.json) (not author's), [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) (session-13 deferred), 5 new probe files (post-commit-3 gate-experiment work — should commit in session-16):
  - `src/vw-bridge/probes/_probe-session15-testfailure-experiment.st`
  - `src/vw-bridge/probes/_probe-session15-testhealth-direct.st`
  - `src/vw-bridge/probes/_probe-session15-direct-testfailure.st`
  - `src/vw-bridge/probes/_probe-session15-testfailure-api.st`
  - `src/vw-bridge/probes/_probe-session15-full-gate-VWBridgeTest.st`
- **MAS window state:** unchanged from session-13 (no /click etc this session — all dispatch tests run via direct bridge method invocation through `tc perform:`, not real MAS workflow exercise).

---

## NEW carry-forward constraints from session-15

All added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) in 3 new sections + 6 summary bullets. Recap:

### 15. Chunk file-in compile scope is Smalltalk, NOT the class's environment

`'path' asFilename fileIn` compiles methods in Smalltalk's namespace context. Bare class refs in chunk-filed methods resolve against Smalltalk's namespace chain, not the receiving class's own environment.

**Cross-namespace refs MUST be fully-qualified** (`VWB.VWBridge` not bare `VWBridge`). Affects test classes that reference classes in OTHER namespaces. Session-14 claim "Bare VWBridge inside VWB-scoped methods resolves via namespace lookup" was empirically wrong for chunk file-in scope.

### 16. `TestCase class>>testClasses` is MAS-customized

Returns `^ServerTestCase testClasses , ClientTestCase testClasses` (verified via CompiledMethod literals). `cls suite` for ANY `TestCase` subclass aggregates the entire MAS test universe.

**Use `cls buildSuiteFromLocalSelectors run` for per-class scope** (no testClasses walk). Or `TestSuite new addTest: (cls selector: sel)` for selective subsets.

### 17. `on: Core.Exception do:` catches TestFailure at the language level

Verified empirically via `[TestFailure signal] on: Core.Exception do: [:ex | ...]` — TestFailure inherits from Exception (not Error). The session-12 debugger-pop is a SUnit-internal mechanism inside `runCase`, NOT a language-level escape problem.

**Direct-invoke `tc perform: sel` bypasses SUnit's runCase** and lets the outer `on: Core.Exception do:` catch any exception (MNU, Error, TestFailure) cleanly. Verified across 20 VWBridgeTest selectors with no debugger pops.

### 18. Workspace requires `Core.*` qualification

This image has GemBuilder-imported namespaces (`GemStone.Gbs.ServerClasses.WriteStreamLegacy`, `GemStoneClasses.Globals.String`, etc.) that collide with VW stock class names. Workspace pops disambiguation OR auto-picks the wrong candidate. `/eval` doesn't trigger this (different namespace resolution).

**Smalltalk handed to a human for Workspace paste MUST use `Core.String`, `Core.WriteStream`, `Core.Character`** etc.

### 19. /eval pre-flight rule

While the bridge is up, verify any Smalltalk syntax via /eval BEFORE handing to a human for Workspace paste. Catches syntax errors, Workspace-vs-/eval namespace ambiguity, and MNU on speculative API names. Cheap (~1 sec). Saves the human a paste-error round-trip.

### 20. `CEnvironment class>>#userEnvironment` is DEPRECATED

Recommended replacement: `OSSystemSupport getVariable: 'X'` / `setVariable:value:`. The deprecation warning fires 4× per VWB.VWBridge startup. Functional but noisy. Future cleanup: switch reads to OSSystemSupport API (probe semantics first — missing-key behavior may differ).

### 21. Latent test code bug class: `#indexOfSubCollection:` 1-arg form

7 dispatching tests in VWBridgeTest use the absent 1-arg form. Production fix from session-13 (`bodyOf:` v0.8.13+session-9 A1) never propagated to tests. Same class of latent bug as the binding bug — fix is mechanical replaceAll to 2-arg `:startingAt: 1` form. Likely affects WaitTest + ScreenshotTest too (not yet gate-checked).

### 22. Latent test code bug class: `Notification` empty-msg in dialog tests

3 dialog-interaction tests in VWBridgeTest error with bare `Notification` and empty messageText. Root cause UNKNOWN. Needs investigation in session-16 — likely a dialog mock/test infrastructure interaction post-namespace-migration.

### 23. Direct-invoke gate pattern as the canonical safe /eval SUnit runner

The pattern in `_probe-session15-full-gate-VWBridgeTest.st` is the proven safe way to drive a full SUnit gate via /eval without bridge wedge risk. Use this for all future per-class gates.

---

## Pending tasks (session-16)

### Immediate (resume order)

1. **Push** the 3 local commits to `origin/main` (deferred this session per session-14 cadence; get explicit auth then `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git push`)
2. **Commit 5 leftover probes** from the gate-experiment work (testfailure-experiment, testhealth-direct, direct-testfailure, testfailure-api, full-gate-VWBridgeTest) as a 4th probe commit (or fold into the systematic-gate commit batch)

### Systematic SUnit gate sweep (user's chosen direction, deferred to session-16)

Per user's last decision (`Systematic: all gates → all fixes → all gates again`):

1. **Run WaitTest gate** via direct-invoke pattern (25 selectors) — copy/adapt `_probe-session15-full-gate-VWBridgeTest.st`
2. **Run ScreenshotTest gate** via same pattern (10 selectors)
3. **Catalog ALL latent bugs** discovered across the 3 gates
4. **Fix `indexOfSubCollection:` 1-arg → 2-arg** sweep across all test files (mechanical replaceAll like the binding fix)
5. **Investigate `Notification` empty-msg** in 3 dialog tests; identify root cause and fix
6. **Re-run all 3 gates** — target GREEN across the board (55 selectors expected: 20 + 25 + 10)
7. **Commit fixes** as atomic batch (1 fix commit + 1 docs update + 1 probes if any)

### Phase P P2 Stage 3 — `load.st` + `unload.st` (per Oracle plan)

Still pending from session-14. Oracle plan captured in [`HANDOFF-2026-06-21-session14.md`](./HANDOFF-2026-06-21-session14.md) "Pending tasks → Phase P P2 Stage 3" section. Two deliverables:

- **`load.st`**: orchestrates file-in of Core+Patches+Tests, then `VWB.VWBridge start`, then writes `.token`. Replaces the auto-start chunk currently at end of `VWBridge.st`.
- **`unload.st`**: defensive idempotent cleanup — saves tokenPath, stops bridge, deletes `.token`, removes SimpleDialog patch, removes 4 VWB classes in reverse-dep order, removes empty VWB namespace.
- **Quality gate**: load+unload+load is idempotent; post-unload image byte-equivalent to pre-load (Kernel.Parcel introspection shows zero residual VWBridge classes; `Smalltalk at: #VWB` returns nil).

Important: Stage 3 must REPLACE the auto-start chunk currently at end of `VWBridge.st` (which calls `VWB.VWBridge start` directly). Move the start logic to `load.st` so `VWBridge-Core.st` can be filed-in without auto-starting (parcel-readiness for P6).

### Phase P remaining deliverables (P5, P6, P7, P8)

Unchanged from session-14 handoff:

| # | Deliverable | Status | Notes |
|---|---|---|---|
| P5 | Auto-start trigger Oracle consult | ⏳ Oracle consult needed | Three external-trigger paths (Topaz stdin, CLI arg, file watcher) per session-9 analysis |
| P6 | Build `.pcl` parcel via `Kernel.Parcel loadParcelFrom: aFilename` | ⏳ Depends on P5 | Headless parcel-load API verified session-11 |
| P7 | `INSTALL.md` (env-var setup + parcel load + smoke test) | ⏳ Depends on P6 | Zero-context developer reaches /health on first try |
| P8 | `GET /version` endpoint (parcel version + build timestamp + commit SHA) | ⏳ Depends on P6 | Augments existing /health |

### Carry-overs (still pending from sessions 7–11)

- EXPLORATION-PLAN step 3 — 3-deep menu navigation
- EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree
- End-to-end verify of `#id` / `#imcNr` / `#groupScheme` no-modal `partialFind:` paths via bridge

### Housekeeping

- Commit [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) (session-13 deferred — still untracked through session-15)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety
- Switch `OS.CEnvironment userEnvironment` reads to `OSSystemSupport getVariable:` (silence the deprecation warning that fires 4× per startup)

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | Qualify VWBridge → VWB.VWBridge (20 code-ref lines + 2 comment-doc lines, 22 total via replaceAll) |
| [`src/vw-bridge/VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) | Same fix — 1 setUp line |
| [`src/vw-bridge/VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) | Same fix — 1 setUp line |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **+136 lines** — 3 new sections (Chunk file-in compile scope, SUnit semantics, Workspace vs /eval namespace resolution) + 6 new carry-forward summary bullets + frontmatter update (last_verified session-15, source_sessions adds 14+15) + env-var quick-lookup deprecation note + Environment variables deprecation subsection |
| `src/vw-bridge/probes/_probe-session15-phase0.st` | Phase 0 namespace verification |
| `src/vw-bridge/probes/_probe-session15-sunit-syntax.st` | Stubbed structure compile check |
| `src/vw-bridge/probes/_probe-session15-sunit-suite-probe.st` | Triggered the bridge wedge (cls suite walked the MAS universe) |
| `src/vw-bridge/probes/_probe-session15-core-quals.st` | Core.* qualification verify |
| `src/vw-bridge/probes/_probe-session15-sunit-semantics.st` | TestCase>>suite + buildSuite literals |
| `src/vw-bridge/probes/_probe-session15-buildsuite-diag.st` | Discovered MAS testClasses customization |
| `src/vw-bridge/probes/_probe-session15-testclasses.st` | Full testClasses dump (hundreds of MAS test classes) |
| `src/vw-bridge/probes/_probe-session15-list-selectors.st` | Listed VWBridgeTest's 20 test selectors |
| `src/vw-bridge/probes/_probe-session15-smoke-single.st` | First smoke (errored on MNU, no wedge) |
| `src/vw-bridge/probes/_probe-session15-error-detail.st` | TestResult inspection (errors are TestCase instances) |
| `src/vw-bridge/probes/_probe-session15-direct-invoke.st` | Isolated setUp vs body MNU — identified setUp errored on `VWBridge singleton` |
| `src/vw-bridge/probes/_probe-session15-bindings.st` | Confirmed ResolvedDeferredBinding → nil for the bare reference |
| `src/vw-bridge/probes/_probe-session15-recompile-fix.st` | `recompile:` failed (sources stripped, EndOfStreamNotification) |
| `src/vw-bridge/probes/_probe-session15-namespace-api.st` | Confirmed no namespace-context API exists in this image |
| `src/vw-bridge/probes/_probe-session15-refilein.st` | Re-file-in via /eval after binding source fix |
| `src/vw-bridge/probes/_probe-session15-smoke-after-fix.st` | Smoke GREEN + literals fixed to #{VWB.VWBridge} |
| `src/vw-bridge/probes/_probe-session15-p1-gate.st` | 5 P1 config tests GREEN |
| `src/vw-bridge/probes/_probe-session15-testfailure-experiment.st` | **UNCOMMITTED** — first TestFailure catch experiment |
| `src/vw-bridge/probes/_probe-session15-testhealth-direct.st` | **UNCOMMITTED** — direct-invoke testHealth (revealed indexOfSubCollection: bug) |
| `src/vw-bridge/probes/_probe-session15-direct-testfailure.st` | **UNCOMMITTED** — direct TestFailure raise (wrong API attempt) |
| `src/vw-bridge/probes/_probe-session15-testfailure-api.st` | **UNCOMMITTED** — found correct TestFailure signal API (unary, not keyword) |
| `src/vw-bridge/probes/_probe-session15-full-gate-VWBridgeTest.st` | **UNCOMMITTED** — full 20-selector gate, 10 pass / 10 error |
| [`knowledge/HANDOFF-2026-06-21-session15.md`](./HANDOFF-2026-06-21-session15.md) | **THIS FILE** |

---

## Important decisions this session

- **Pushed session-14's 8 commits** (decision Option 1 at session start; clean push, no surprises).
- **Set `VW_BRIDGE_HOME` at User OS level** instead of per-session Workspace mutation. Persistent, closes a recurring gap permanently.
- **Force-killed `vwnt.exe`** via PowerShell `Stop-Process -Force` after Task Manager couldn't reach it (process reported `Responding=True` but ignored WM_CLOSE). Broke the 7-session continuous run — necessary cost.
- **Source fix over alias workaround** for the binding bug (Option A over Oracle-rejected Option B). Mechanical replaceAll, audit-friendly, no architectural debt.
- **Direct-invoke `tc perform:` pattern** over `cls suite run` for full gate. Bypasses SUnit's runCase debugger-pop. Provably safe across 20 VWBridgeTest selectors.
- **Carried systematic gate sweep to session-16** rather than continuing in session-15. Recognized the depth of work involved (3 gates + 2 bug class fixes + re-verification) was a fresh-session scope.
- **Memory MCP populated** for first time (was empty graph). 8 entities + 12 relations captured. Future sessions should `memory_search_nodes` at startup.
- **Did NOT push session-15's 3 commits** — defer to session-16 per established cadence (ask + wait for OK on push).

---

## Lessons learned (session-15 was unusual)

This session was a 30%-fix, 70%-debugging-spiral. The debugging surfaced THREE latent bugs that had shipped to `origin/main`:

1. **Bare VWBridge bindings in test methods** (FIXED session-15 commit `cac044f`)
2. **`indexOfSubCollection:` 1-arg form in test code** (DISCOVERED, pending fix in session-16)
3. **`Notification` empty-msg in dialog tests** (DISCOVERED, root cause unknown)

All three slipped through session-14 because **the full SUnit suite was never run end-to-end before commit**. The session-14 verification said "tests pass when invoked directly via /eval" — true for the specific methods invoked, but not for full-suite execution which exposes `setUp` and dispatching tests.

**Process improvements for session-16+:**

- **Always /eval-verify Smalltalk before handing to a human for Workspace paste** — the syntax-error round-trip cost us 15 min this session. Cheap pre-flight saves time AND reinforces correctness.
- **Run direct-invoke gate AFTER any test file change** before declaring "done". The pattern is proven safe; no excuse to skip it.
- **Capture each diagnostic insight in vw-image-api-contract.md** ASAP — the carry-forward constraints file is the single source of truth for image quirks. Session-15 added 9 new constraints/sections.
- **Use memory MCP for cross-session continuity** — session-15 found the graph empty; populated it now so session-16 starts with full context.

The good news: the direct-invoke gate pattern + the cleared workflow (env var at User level, /eval pre-flight rule, /eval drives file-ins) means session-16 can move much faster than session-15 did.

---

## Resume hooks

- **Next-session anchor:** this file + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (23 carry-forward constraints documented as of session-15).
- **Memory MCP context:** run `memory_search_nodes` for "session" / "VWBridge" / "Phase-P" / "ammaganyane" at start of session-16 to absorb stored facts.
- **First action options for session-16:**
  1. **Push** the 3 local commits to `origin/main` (deferred this session)
  2. **Commit 5 leftover probes** from the gate-experiment work
  3. **Systematic gate sweep** (user's chosen direction): WaitTest + ScreenshotTest gates → fix `indexOfSubCollection:` 1-arg + investigate Notification → re-run all 3 gates GREEN
  4. **Phase P P2 Stage 3** (`load.st` + `unload.st`) per Oracle plan — depends on gate being GREEN first OR running independently if user prioritizes
  5. **Phase P P5** Oracle consult on auto-start trigger
- **Phase 0 verification for session-16 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.9.1"}`
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token (was `3959495310063-903045` at session-15 EOD; will rotate ONLY if vwnt.exe restarted)
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect 3 unpushed commits if push deferred carries to session-16: `cac044f` → `aeb4a82` → `d096ac6`
  - `git status --short` — expect 2 pre-existing untracked + 5 untracked probe files from session-15
  - If vwnt.exe restarted since session-15: file-in via /eval (drive this myself — user explicitly preferred /eval over Workspace paste). Order: VWBridge.st (auto-starts bridge + rotates token), VWBridge-Patches.st, 3 test files. Re-read .token after VWBridge.st file-in. Re-toggle `Dialog useNativeDialogs: false`. `VW_BRIDGE_HOME` env var will auto-inherit (set at User OS level session-15).
- **Bridge state at session-15 EOD:** UP at `VWB.VWBridge` v0.9.1, all session-14 work + session-15 binding fix in effect, 10 VWBridgeTest selectors verified GREEN via direct-invoke /eval gate.

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits local-only) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-15) | **Pushed session-14 commits; fixed latent binding bug; direct-invoke gate pattern proven; partial gate (10/20 VWBridgeTest)** | **v0.9.1** | **A, B, F, partial P (more verified)** |
| _(session-16)_ | Systematic gate sweep + indexOfSubCollection: fix + Stage 3 ship | _(v0.9.x)_ | A, B, F, P partial++ |
| _(future)_ | Phase P P5 + P6 + P7 + P8 ship | _(v0.10.0 likely)_ | A, B, F, P |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
