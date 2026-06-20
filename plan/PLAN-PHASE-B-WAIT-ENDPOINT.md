---
title: Phase B — `/wait` endpoint implementation plan
purpose: Working document for B2 (TDD red) + B3 (implementation) of the `/wait` endpoint. Step-by-step plan agent can follow without re-deriving design decisions.
status: ACTIVE (session-9, started 2026-06-20)
target_version: v0.9.0
based_on: Oracle consult (bg_b8ac84ac, session-9, 2m30s)
parent_roadmap: [`plan/ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) Phase B
references:
  - [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md) — image API surface
  - [`knowledge/HANDOFF-2026-06-20-session8.md`](../knowledge/HANDOFF-2026-06-20-session8.md) — bridge architecture, recent bugs
  - [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) — bridge source (v0.8.13)
  - [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) — existing SUnit scaffold
---

# Phase B — `/wait` endpoint

## Why this exists

`Start-Sleep` is currently the only way tests synchronize on UI state, which makes every test fundamentally flaky. `/wait` lets tests sync on **state, not time**. This is the single highest-leverage missing piece in the bridge — without it, the test framework can't reach the "zero flakes across 10 consecutive runs" quality gate.

## Status / progress

Step status updated as work proceeds. Use this section as the source of truth on where the implementation is.

| Phase | Step | Status |
|---|---|---|
| Plan | this doc | IN PROGRESS |
| B2.1 | extract `windowsSnapshotForWait` | pending |
| B2.2 | extract `dialogsSnapshotForWait` | pending |
| B2.3 | add `waitClockMilliseconds` + `waitForMilliseconds:` seams | pending |
| B2.4 | verify existing 12 tests still GREEN | pending |
| B2.5 | shared `/wait` tests RED (5) | pending |
| B2.6 | `window-appears` tests RED (5) | pending |
| B2.7 | `dialog-appears` tests RED (5) | pending |
| B2.8 | `window-closes` tests RED (5) | pending |
| B2.9 | `dialog-closes` tests RED (5) | pending |
| B2.10 | verify 25 new RED + 12 existing GREEN | pending |
| B3.1 | `/wait` request parser + validation | pending |
| B3.2 | poll loop + boundary check | pending |
| B3.3 | `window-appears` evaluator | pending |
| B3.4 | `dialog-appears` evaluator | pending |
| B3.5 | `window-closes` evaluator | pending |
| B3.6 | `dialog-closes` evaluator | pending |
| B3.7 | wire `/wait` into dispatcher | pending |
| B3.8 | bump to v0.9.0 (4 sites + assertion) | pending |
| B3.9 | full re-file + 37 tests GREEN | pending |
| Checkpoint | check-in before B4 + commits | pending |
| B4 | real-usage verification (10 sequential runs) | DEFERRED to separate session |

## Decisions captured (D1-D7)

These were checked-in but answered by "save that plan to markdown and lets implement" — interpreted as accept-with-defaults. If wrong, revise this section and adjust downstream.

| # | Question | Decision | Rationale |
|---|---|---|---|
| **D1** | `dialog-closes` in MVP or defer per Oracle? | **IN MVP** (agent pick, not user-confirmed) | Bug #2 / #5 history makes dialog-DISMISSAL central to the test loop — after `/dialogs/respond Yes` we currently have no way to wait for the dialog to actually disappear before clicking next. Without it, tests still need `Start-Sleep`. ~30min extra; same pattern as window-closes. Test count rises from 20 → 25. |
| **D2** | Timeout HTTP status: 408 or 200+ok:false? | **408 Request Timeout** (Oracle's call) | Cleaner semantic; easier to grep in logs. Test client wrappers handle 408 as expected-failure. |
| **D3** | `caseSensitive` flag on substring predicates? | **Add `caseSensitive` optional field, default `false`** (agent pick) | MAS window titles have observed case variation. Default-false reduces test friction; opt-in case sensitivity available when needed. |
| **D4** | Plan-to-disk vs inline? | **plan-to-disk (this file)** | User said "save that plan to markdown". Resolved. |
| **D5** | B2+B3 in one push or split? | **One push** | Sequential dependency chain; checkpointing mid-implementation invites context drift. |
| **D6** | Commit strategy | **Atomic at end** (refactor + test-red + feat); no commits until B3.9 verified GREEN | Matches session-7/8 wrap pattern. NO commit auth granted yet — explicit check-in before any `git commit`. |
| **D7** | (combined with D6 above) | — | — |

## Oracle design summary (condensed)

Full output preserved in conversation transcript (session-9, `bg_b8ac84ac`). Key calls reproduced here so this plan stands alone.

### Predicate language (MVP scope)

| Kind | In MVP? | Args | Success return | Semantics |
|---|---|---|---|---|
| `window-appears` | YES | `match.appClass`, `match.title`, `match.titleContains`; ≥1 required; `caseSensitive` optional (default false) | `matched: {id,title,appClass}, matchCount` | Succeeds when any current window snapshot entry matches ALL provided filters. Idempotent. |
| `dialog-appears` | YES | `messageContains`; optional `titleContains`; `caseSensitive` optional (default false) | `matched: dialog object, matchCount` | Succeeds when any current dialog snapshot has message containing the substring. Idempotent. |
| `window-closes` | YES | Prefer `windowId`; optionally `match` (same as window-appears) | `closed: true, lastSeenWindow: ...optional` | Succeeds when no current window with given id/match. If already absent: succeeds with `alreadySatisfied: true`. |
| `dialog-closes` | YES (D1=YES) | Prefer `messageContains`; optional `match` | `closed: true, alreadySatisfied: bool` | Succeeds when no current dialog matches. |
| `value-equals` | DEFERRED v0.9.x | `target.windowId`, `target.widgetId` or `target.aspect`; `comparator`; `expected` | — | Defer until widget identity is probed. |
| `eval-truthy` | EXCLUDED | — | — | Too dangerous; duplicates `/eval`; safety hole. Returns 400 if requested. |
| Compound predicates | EXCLUDED | — | — | Tests compose multiple `/wait` calls. |

### REST API shape

Endpoint:
```
POST /wait
Authorization: Bearer <token>
Content-Type: application/json
```

Defaults + bounds:
| Field | Default | Bounds |
|---|---:|---:|
| `timeoutMs` | 5000 | 1..60000 |
| `intervalMs` | 100 | 50..1000 |
| `caseSensitive` (when applicable) | false | bool |

Status codes:
| Outcome | Status | Body shape |
|---|---|---|
| Success | 200 | `{ok: true, kind, satisfied: true, elapsedMs, polls, matched: {...}, matchCount}` |
| Timeout | **408** | `{ok: false, kind, error: "timeout", message, elapsedMs, polls, lastObservation: {...}}` |
| Bad request | 400 | `{ok: false, error: "bad-request", message}` |
| Not found (routing only) | 404 | reserve for unknown sub-path, NOT for "predicate not true yet" |

Example requests:

```json
// window-appears
{"kind": "window-appears", "timeoutMs": 5000, "intervalMs": 100,
 "match": {"appClass": "MAS.PolicyApplication", "titleContains": "Policy"},
 "caseSensitive": false}

// dialog-appears
{"kind": "dialog-appears", "timeoutMs": 3000, "messageContains": "Do you want to save"}

// window-closes (by id)
{"kind": "window-closes", "timeoutMs": 5000, "windowId": "win-42"}

// dialog-closes
{"kind": "dialog-closes", "timeoutMs": 5000, "messageContains": "Continue?"}
```

### Architecture decisions

| Decision | Choice | Why |
|---|---|---|
| Polling vs event-driven | **Polling**, 100ms fixed, no backoff | Event-driven requires probing VW announcement coverage (another investigation wave). Polling reuses proven enumeration. |
| Process placement | **Serve process** blocks request thread | Listener already forks per request. Forked-from-serve adds complexity. UI process would block MAS. |
| Internal state query | Internal methods (`windowsSnapshotForWait`, `dialogsSnapshotForWait`) — **NEVER** recursive HTTP dispatch | Bug #5 history proves recursive `dispatch:` is fatal. |
| Test seams | `waitClockMilliseconds`, `waitForMilliseconds:` | Fake clock for non-flaky TDD; the only way to test timeout/race behavior without real delays |
| Boundary race | Final predicate check before timeout — **success wins** | Critical for flake reduction at deadline |
| Logging | NDJSON via existing `log:`, `logWarn:` | Wait satisfied/timeout/bad-request all logged for debugging |

## Test fixture design

### Existing test pattern (from [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st))

- `VWBridgeTest extends TestCase`, ivars `bridge` + `authHeaders`
- `setUp` captures live singleton: `bridge := VWBridge singleton`
- Tests dispatch via `bridge dispatch: requestLine headers: hdrs body: aBody`
- For `/eval` execution, tests must NOT call `dispatch:` (re-entry guard). They call handler methods directly.

### New wait test pattern

`/wait` tests need fake clock + scripted snapshots, neither of which can be achieved by going through the real singleton with real time. Approach:

**Add 4 instance variables to `VWBridge`** for test override:
```
clockOverride                 nil | Integer       — when non-nil, waitClockMilliseconds returns it
sleepOverride                 nil | Block         — when non-nil, waitForMilliseconds: calls it with ms arg
scriptedWindowSnapshots       nil | OrderedCollection — when non-nil, windowsSnapshotForWait dequeues from it
scriptedDialogSnapshots       nil | OrderedCollection — when non-nil, dialogsSnapshotForWait dequeues from it
```

Seam methods:
```smalltalk
waitClockMilliseconds
    ^clockOverride ifNil: [Core.Time millisecondClockValue]

waitForMilliseconds: ms
    sleepOverride 
        ifNil: [(Delay forMilliseconds: ms) wait]
        ifNotNil: [sleepOverride value: ms]

windowsSnapshotForWait
    scriptedWindowSnapshots ifNotNil: [
        scriptedWindowSnapshots notEmpty ifTrue: [^scriptedWindowSnapshots removeFirst]].
    ^self computeWindowsSnapshotReal  "real implementation"

dialogsSnapshotForWait
    scriptedDialogSnapshots ifNotNil: [
        scriptedDialogSnapshots notEmpty ifTrue: [^scriptedDialogSnapshots removeFirst]].
    ^self computeDialogsSnapshotReal
```

`VWBridgeWaitTest>>setUp` sets the overrides; `tearDown` clears them. This pattern:
- Keeps tests fully synchronous (no real time, no real UI calls)
- Doesn't require subclassing or singleton swap
- Allows scripting snapshot sequences for delayed-success and timeout cases
- Clears cleanly on tearDown — no leaked state between tests

**Tradeoff**: adds 4 ivars to production code. Acceptable cost for the dramatic test reliability gain. Documented in code comments.

### File structure

| File | Purpose |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | Modified: refactor /windows + /dialogs, add seams, add /wait handler, add 4 ivars |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | Unchanged (except version bump). Existing 12 tests verify refactor preserves behavior. |
| `src/vw-bridge/VWBridge-WaitTest.st` (NEW) | New `VWBridgeWaitTest` class with 25 tests + fixture helpers for scripted snapshots |

## Step-by-step plan

Each step has: input (current state), action (what to do), output (verified result). Verification commands inline.

### B2.1 — Extract `windowsSnapshotForWait`

**Input**: `/windows` handler builds + serializes the snapshot inline.

**Action**:
1. Read current `/windows` handler in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (line ~447+ per dispatcher map at L402)
2. Identify the snapshot-building code (whatever returns the OrderedCollection of window descriptions)
3. Extract into a new method `windowsSnapshotForWait` in `'helpers'` category — returns the OrderedCollection (no JSON serialization)
4. Modify `/windows` handler to call `windowsSnapshotForWait` then JSON-serialize the result

**Output**: 
- New method `windowsSnapshotForWait` exists
- `/windows` handler is ~2-3 lines shorter
- Behavior unchanged externally

**Verification**:
- File-in via /eval: `{"ok":true,"result":"nil"}`
- Probe: `(VWBridge singleton windowsSnapshotForWait) class name` returns `'OrderedCollection'` (or similar collection class)
- Re-run `testWindowsAcceptsValidAuth` + `testWindowsRequiresAuth` via /eval — both GREEN

### B2.2 — Extract `dialogsSnapshotForWait`

**Input**: `/dialogs` handler at L1200-1234 builds dialogs collection inline.

**Action**:
1. Read [`VWBridge.st`](../src/vw-bridge/VWBridge.st) L1200-1234 — the `handleDialogsQuery` method
2. The interesting part is L1228-1231: builds `dialogs` OrderedCollection by walking `mgr scheduledControllers`
3. Extract that walk into `dialogsSnapshotForWait` in `'helpers'` category — returns the OrderedCollection
4. `/dialogs` handler now calls `self dialogsSnapshotForWait` then JSON-wraps

**Output**:
- New method exists
- `handleDialogsQuery` simpler
- Bug #2 tests still pass

**Verification**:
- File-in: clean
- Probe: `VWBridge singleton dialogsSnapshotForWait` returns OrderedCollection
- Re-run `testBug2DialogConfirmYesReturnsTrue` + `testBug2DialogConfirmNoReturnsFalse` via /eval — both GREEN

### B2.3 — Add test seams + 4 ivars

**Input**: VWBridge has its current ivar set; no `clockOverride` etc.

**Action**:
1. Modify the class definition to add 4 ivars: `clockOverride sleepOverride scriptedWindowSnapshots scriptedDialogSnapshots`
2. Add seam methods in a new `'wait helpers'` category:
   - `waitClockMilliseconds` (checks override)
   - `waitForMilliseconds:` (checks override; uses `Delay forMilliseconds:` otherwise)
3. Modify `windowsSnapshotForWait` + `dialogsSnapshotForWait` from B2.1/B2.2 to honor the scripted override (queue-dequeue pattern)
4. Add accessors: `clockOverride:`, `sleepOverride:`, `scriptedWindowSnapshots:`, `scriptedDialogSnapshots:`, plus `clearWaitOverrides` (sets all to nil)

**Output**:
- Bridge has the seam infrastructure
- Real behavior unchanged when overrides are nil (the default)
- 4 ivars + 6 new methods (`clearWaitOverrides` + 4 setters + accessor for clock override read)

**Verification**:
- File-in: clean
- Probe: `VWBridge singleton clockOverride: 12345. VWBridge singleton waitClockMilliseconds` returns `12345`
- Then: `VWBridge singleton clearWaitOverrides. VWBridge singleton waitClockMilliseconds` returns a real ms count (large positive integer)

### B2.4 — Verify existing test suite still GREEN

**Input**: B2.1+B2.2+B2.3 changes filed in.

**Action**:
1. Probe class state: `VWBridgeTest selectors size = 18` ✓ (no new tests added yet)
2. Run all 12 tests:
   - 3 health tests via direct handler calls (these run via /eval since the test file's helpers don't use `dispatch:` recursively)
   - Bug #2 tests (run cleanly via /eval per Bug #5 workaround pattern)
   - Logging tests (no `dispatch:` involvement)
   - Auth tests (might use dispatch — they go RED via /eval per session-7+8 docs; need to verify in Workspace)

**Output**: 12 tests still pass (any subset that ran green before should run green now). Auth/eval/health tests that go through `dispatch:` may go RED via /eval but should be GREEN in Workspace — same as before B2.

**Verification**: explicit `/eval` per test that doesn't use `dispatch:`, plus a note in handoff if any test changes status (none expected).

### B2.5 — `VWBridgeWaitTest` class + 5 shared tests (RED)

**Input**: B2.4 verified.

**Action**:
1. Create new file `src/vw-bridge/VWBridge-WaitTest.st`
2. Define class `VWBridgeWaitTest` extends `TestCase`, category `'VW-TestBridge-WaitTests'`, ivars `bridge authHeaders`
3. Implement `setUp`: capture singleton, build auth headers
4. Implement `tearDown`: call `bridge clearWaitOverrides`
5. Implement helper methods: `scriptWindowSnapshots:`, `scriptDialogSnapshots:`, `fakeClock:`, `fakeSleep:` (set overrides)
6. Implement helper: `waitRequest: aDictionary` — builds POST /wait request, dispatches, returns response
7. Add 5 shared tests:
   - `testWaitRejectsMissingKind`
   - `testWaitRejectsUnsupportedKindEvalTruthy`
   - `testWaitRejectsCompoundPredicate`
   - `testWaitRejectsInvalidTimeoutBounds`
   - `testWaitUsesDefaults`

**Output**: new test file with 5 tests. All RED (because /wait handler doesn't exist yet — dispatcher returns 404).

**Verification**:
- File-in: `{"ok":true,"result":"nil"}`
- Probe: `VWBridgeWaitTest selectors size` returns ≥ (5 tests + helpers + setUp/tearDown)
- Run each test via /eval: 5 RED with assertion-failure messages matching "expected 400" or similar

### B2.6 — `window-appears` tests (RED)

5 tests in `VWBridgeWaitTest`:
- `testWindowAppearsImmediateSuccess` — first scripted snapshot has matching window; expect 200, polls=1
- `testWindowAppearsDelayedSuccess` — first 2 snapshots empty, 3rd matches; expect 200, polls=3
- `testWindowAppearsTimeout` — no scripted snapshot matches; expect 408 with `error: "timeout"`
- `testWindowAppearsMalformedMissingMatch` — request without `match` field; expect 400
- `testWindowAppearsMultipleMatchesDeterministic` — snapshot has 2 matching windows; expect 200 with `matchCount: 2` and deterministic first `matched`

**Verification**: file-in, probe selectors, run each — all 5 RED.

### B2.7 — `dialog-appears` tests (RED)

5 tests:
- `testDialogAppearsImmediateSuccess`
- `testDialogAppearsDelayedSuccess`
- `testDialogAppearsTimeout`
- `testDialogAppearsMalformedMissingMessageContains`
- `testDialogAppearsUsesTwoArgIndexOfSubCollection` — explicitly verify substring matching uses 2-arg form (set substring that the 1-arg form would error on — actually this is hard to test directly; alternative: just verify a substring match works with multi-line message)

**Verification**: 5 RED.

### B2.8 — `window-closes` tests (RED)

5 tests:
- `testWindowClosesAlreadyClosed` — first snapshot doesn't contain windowId; expect 200 with `alreadySatisfied: true`
- `testWindowClosesDelayedClose` — first 2 snapshots have window, 3rd doesn't; expect 200, polls=3
- `testWindowClosesTimeout` — window present in all snapshots; expect 408
- `testWindowClosesMalformedMissingTarget` — neither `windowId` nor `match`; expect 400
- `testWindowClosesBoundaryRace` — fake clock reaches deadline on same iteration that final snapshot removes window; expect 200 (NOT 408)

**Verification**: 5 RED.

### B2.9 — `dialog-closes` tests (RED)

Same pattern as B2.8 but for dialogs. 5 tests.

### B2.10 — Verify all 25 RED + 12 existing GREEN

**Action**:
1. File-in VWBridge-WaitTest.st
2. Probe: `VWBridgeWaitTest selectors size` = expected count
3. Run all 25 wait tests → all RED
4. Re-run 12 existing tests → all GREEN (Workspace-friendly subset GREEN via /eval, rest GREEN in Workspace)

**Verification**: explicit per-test reports.

### B3.1 — `/wait` request parser + validation

**Action**: New method `handleWait: aBodyString` in `'handlers'` category. Parse JSON. Validate:
- `kind` required + ∈ supported set
- `timeoutMs` in [1, 60000]
- `intervalMs` in [50, 1000]
- Per-kind required fields (match, messageContains, windowId)
- Reject `eval-truthy`, compound (e.g. `predicates` field), unknown kinds → 400

Returns 400 with `{ok:false, error:"bad-request", message: "..."}` on any failure.

**Verification**: shared tests from B2.5 go GREEN.

### B3.2 — Poll loop + boundary check

**Action**: After validation passes, run the poll loop on the serve process (the request thread). Use seams `waitClockMilliseconds` + `waitForMilliseconds:`. Final predicate check before returning timeout.

Skeleton (per Oracle):
```smalltalk
handleWait: aBodyString
    | spec start deadline polls result |
    spec := self parseAndValidateWaitRequest: aBodyString.
    spec isError ifTrue: [^self jsonBadRequest: spec errorMessage].
    
    start := self waitClockMilliseconds.
    deadline := start + spec timeoutMs.
    polls := 0.
    
    [   result := self evaluateWaitPredicate: spec.
        polls := polls + 1.
        result satisfied ifTrue: [
            ^self jsonOk: (self waitSuccessBodyFor: spec result: result polls: polls start: start)].
        self waitClockMilliseconds >= deadline
    ] whileFalse: [
        self waitForMilliseconds: spec intervalMs].
    
    "Final check — success wins boundary race"
    result := self evaluateWaitPredicate: spec.
    polls := polls + 1.
    result satisfied ifTrue: [
        ^self jsonOk: (self waitSuccessBodyFor: spec result: result polls: polls start: start)].
    
    self logWarn: 'wait timeout kind=' , spec kind.
    ^self jsonRequestTimeout: (self waitTimeoutBodyFor: spec result: result polls: polls start: start)
```

**Verification**: doesn't fully GREEN yet (predicates not implemented), but the timeout test (one of the predicate-specific tests) should start showing real timeout behavior.

### B3.3-B3.6 — Predicate evaluators

Each evaluator takes the `spec` and returns a `WaitResult` (a small dictionary with `satisfied: bool`, `matched: ...`, `lastObservation: ...`).

- `B3.3 window-appears`: call `windowsSnapshotForWait`, filter by match criteria (case-sensitive flag honored), return matched + matchCount
- `B3.4 dialog-appears`: call `dialogsSnapshotForWait`, filter by `messageContains` using 2-arg `indexOfSubCollection:startingAt: 1 > 0`
- `B3.5 window-closes`: call `windowsSnapshotForWait`, return satisfied=true if no matching entry
- `B3.6 dialog-closes`: call `dialogsSnapshotForWait`, similar

After each predicate evaluator lands, the relevant 5 tests should go GREEN.

### B3.7 — Wire `/wait` into dispatcher

**Action**: Edit dispatcher (around L402-414 in VWBridge.st). Add:
```smalltalk
(method = 'POST' and: [path = '/wait']) ifTrue: [^self handleWait: bodyString].
```

(Exact pattern matches the existing dispatcher style — check L414 for `/dialogs/respond` POST pattern.)

**Verification**: a basic `curl POST /wait` reaches the handler.

### B3.8 — Version bump to v0.9.0

**Action**: 4 canonical sites in VWBridge.st (L1 header, L290 dispatcher comment, L320 doDispatch comment, L339 /health body — per session-8 convention). Plus test assertion in VWBridge-Test.st (~L98-99).

### B3.9 — Full re-file + 37 tests GREEN

**Action**: File-in full VWBridge.st + VWBridge-Test.st + VWBridge-WaitTest.st via /eval. Verify:
- `/health` returns `{"status":"ok","version":"0.9.0"}`
- All 12 existing tests still pass (Workspace-friendly subset GREEN via /eval)
- All 25 new wait tests GREEN

If any test RED, fix and re-run until GREEN. Pre-existing failures (like `testHealthReturnsCurrentVersion` failing cleanly via /eval) are still acceptable IF they fail the same way.

### Checkpoint — before B4 + commits

**STOP HERE.** Show user:
- All 37 tests GREEN proof
- Version bump verified (/health = v0.9.0)
- Files modified: VWBridge.st (substantial), VWBridge-Test.st (version assertion), VWBridge-WaitTest.st (NEW)
- Files unmodified: knowledge/vw-image-api-contract.md (A3 — could be committed separately or together)
- Git state: A1 fix + A3 doc + B2/B3 changes all uncommitted

**Ask:**
- Real-usage verification scope (which MAS workflow to wait-test)?
- Commit strategy: separate commits per phase (A1 / A3 / refactor / test / feat / docs) or batch?
- Push or hold?

### B4 (DEFERRED) — Real-usage verification

Real-usage verification needs a real MAS workflow that exercises the wait predicates end-to-end. This is best done in a separate session with the user driving the workflow. Pre-criteria:
- 10 consecutive sequential runs of a representative MAS test flow with `/wait` replacing all `Start-Sleep`s
- Zero flakes

The quality gate per [`plan/ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) Phase B is "zero flakes across 10 consecutive sequential runs of the real-usage flow."

## Sharp edges and mitigations

From Oracle, refined for our concrete code:

| Risk | Mitigation in this plan |
|---|---|
| Predicate never becomes true | Hard timeout cap (60000ms max); structured 408; warning log with kind/polls/elapsed |
| UI mutates during poll | Each poll calls `windowsSnapshotForWait` which snapshots via the same path as `/windows` — `onUIDo:` snapshot pattern (immutable copy) |
| Predicate true exactly at timeout | B3.2 final predicate check before timeout — success wins |
| Re-entry guard clash | NEVER call `dispatch:` / `/eval` / `/windows` / `/dialogs` over HTTP internally. Use the extracted internal methods directly. |
| Concurrent `/wait` calls collision | Per-request state local to serve process (since listener forks per request). No global wait registry in MVP. |
| `onUIDo:` hang | Keep snapshot blocks tiny. Per-poll snapshot completes in <50ms typical. |
| Generic aspect/eval overreach | Deferred `value-equals` per D1 / Oracle; `eval-truthy` excluded permanently. |
| Client disconnect (test gives up) | Serve process continues polling until timeout. Acceptable in MVP. |
| Stripped sources | Method introspection via `messages`/`literals`/`numArgs` — not source. Already established pattern. |
| `String streamContents:` absent | All JSON serialization uses existing `WriteStream on: String new` pattern via `safeJsonFor:` / bridge's existing JSON helpers. |
| `String includesSubString:` absent | All substring matching uses `(s indexOfSubCollection: sub startingAt: 1) > 0` — 2-arg form. |
| `selectorsDo:` absent | All selector iteration uses `selectors do:` |

## Success criteria

Per [`plan/ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) Phase B:

- 5 SUnit tests green per predicate × 5 predicates = 25 tests GREEN
- 12 existing tests still GREEN (no regression)
- /health returns `{"status":"ok","version":"0.9.0"}`
- Real-usage verification (B4) achieves zero flakes across 10 consecutive sequential runs of a representative MAS workflow with `/wait` replacing all `Start-Sleep`s — DEFERRED to separate session

This plan's local success: B3.9 completes with all 37 tests GREEN, all files filed-in cleanly, version bump verified, ready for B4 + commits.

## Resume hooks

If this plan is interrupted and resumed in a new session:

1. **Read this file first** + [`plan/ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) + [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md)
2. Check `Status / progress` table at top to see where we stopped
3. Check `git status` for uncommitted changes
4. Verify bridge state: `curl /health` (should be v0.8.13 if pre-B3.8, v0.9.0 if post)
5. If `vwnt.exe` was restarted: re-toggle `Dialog useNativeDialogs: false`, re-read .token, re-file-in bridge files
6. Continue from the first `pending` step in the progress table
