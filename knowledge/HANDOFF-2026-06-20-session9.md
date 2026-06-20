# Handoff — v0.9.0 /wait endpoint + Phase B complete + parcel discovery (session 2026-06-20 session-9 EOD)

**Written:** end of session-9 that (1) executed Phase A1 (`bodyOf:` 1-arg → 2-arg `indexOfSubCollection:startingAt:` fix in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) - the trivial warmup), (2) executed Phase A2 - probed parcel availability per the ROADMAP-QUALITY-FIRST and **discovered that session-8's "no Smalltalk-level auto-start mechanism" inference was a false negative**: `Kernel.Parcel` exists in this image with 86 class-side + 224 instance-side selectors, NOT in top-level `Smalltalk`, so `Smalltalk includesKey: #Parcel` returned false but the parcel infrastructure is fully present (26 classes across `Kernel.`, `Tools.`, `FileTools.`, `UI.` plus the 37-class `RuntimePackager` namespace), (3) drilled into the auto-load operational unknown - found that no class in the image auto-calls `findAndLoadParcels` at boot (only sender is `VisualLauncher>>menuItemLoadParcelByName` UI menu action; current `vwnt.exe` PID 5624 was launched as plain `vwnt.exe storedev64.im` from `explorer.exe` with no startup script arg), so **D-parcel-pure is still not viable but D-parcel-with-external-trigger and D-snapshot remain viable**, (4) wrote A3 - [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) consolidating session-3..8 carry-forwards + session-9 parcel discovery + probe patterns into a single fast-lookup contract doc (~492 lines), (5) fired Oracle for Phase B1 `/wait` predicate language consult (bg_b8ac84ac, 2m30s) which produced the design adopted in this wave (4 MVP predicates, 408 for timeout, polling-on-serve-process, fake-clock test seams, refactor `/windows`+`/dialogs` to extract internal snapshot methods so `/wait` never recurses through HTTP dispatch), (6) wrote [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) capturing Oracle synthesis + D1-D7 decisions + 19-step B2+B3 + sharp edges (~489 lines), (7) executed Phase B2 - refactored [`VWBridge.st`](../src/vw-bridge/VWBridge.st) to extract `windowsSnapshotForWait` (uses existing `windowSummaries`) + `dialogsSnapshotForWait` + `computeDialogsSnapshot` (was `doListDialogs`, refactored to return collection not JSON), added 4 new ivars (`clockOverride`, `sleepOverride`, `scriptedWindowSnapshots`, `scriptedDialogSnapshots`) + 10 wait-helper methods (`waitClockMilliseconds`, `waitForMilliseconds:`, 4 setters, `clearWaitOverrides`), verified the 5 `/eval`-friendly tests still GREEN, then wrote [`VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) NEW (~322 lines, 25 tests + 12 fixture helpers using fake-clock + sticky-queue snapshot scripting) - all 25 RED initially with clean assertion-failure pattern, (8) executed Phase B3 - implemented `handleWait:` + `parseAndValidateWaitRequest:` + `evaluateWaitPredicate:` dispatcher + 4 predicate evaluators (`evaluateWindowAppears:`, `evaluateDialogAppears:`, `evaluateWindowCloses:`, `evaluateDialogCloses:`) + 5 helper methods including substring/equality matchers with `caseSensitive` flag + response builders (`waitSuccessBodyFor:result:polls:elapsedMs:`, `waitTimeoutBodyFor:result:polls:elapsedMs:`, `jsonBadRequestBody:`, `waitErrorWithMessage:`, `waitResultNotSatisfied`, `windowMatches:filter:spec:`, `waitEquals:to:caseSensitive:`, `waitSubstring:in:caseSensitive:`), extended `jsonParseFlat:` + `parseAnyValue:` to support nested objects via new `parseObject:cursor:` (was flat-only), added 408 to `httpResponse:type:body:`, wired POST `/wait` into dispatcher, bumped version to v0.9.0 at 4 canonical sites + test assertion, (9) **hit a test-isolation bug in B3 verification round 1 (23/25 GREEN)** - the 2 failing tests were both `*ClosesTimeout` because the loop polls one extra time after the deadline check (loop iter N+1 polls then exits), so a 4-snapshot timeout test had its 5th poll (final-check) see an empty queue, which for `*-closes` predicates incorrectly means "satisfied" - fixed with sticky-queue snapshot semantics (when queue size > 1, dequeue; when 1 left, keep returning it so steady-state pattern works without exact poll counting), (10) re-ran tests: **25/25 wait tests GREEN, 5/5 regression GREEN**, (11) live POST `/wait` verification via curl with real `Delay` - timeout test returned HTTP 408 with structured body (polls=6, elapsedMs=1202) and success test against the LIVE running MAS `PortfolioView` window returned HTTP 200 with full window descriptor (`matched:{appClass:PortfolioView,title:Portfolio,bounds:805@281 corner:1758@1121}`, polls=1, elapsedMs=0, matchCount=1), (12) committed 4 atomic commits per the recommended structure: `d22d273` (docs A3), `17ac0a0` (docs plan), `587178d` (feat v0.9.0), `cc2abe5` (test 25 new + A1 + version bump), (13) writing this handoff.

**For:** session-10 - (1) decide push of the 6 ahead-of-origin commits (4 from this session + 2 carry-over from session-8), (2) optionally execute B4 real-usage 10x verification (needs a chosen MAS workflow run with `/click` + `/wait` predicates replacing `Start-Sleep`s, repeated 10x sequentially with zero flakes per the Phase B quality gate), (3) decide next roadmap phase to tackle - Phase C (API freeze + OpenAPI spec - logical follow to v0.9.0 release), Phase D (auto-start architecture - now unblocked by session-9 parcel evidence; would be D-parcel-with-external-trigger or D-snapshot), Phase E (Playwright SDK scaffold + first 3 tests against v0.9.0 bridge), Phase F (`/screenshot` endpoint - largest scope), (4) carry-overs from session-7 + session-8 still pending (EXPLORATION-PLAN steps 3+4, end-to-end verification of `#id`/`#imcNr`/`#groupScheme`, end-to-end `#surname` Bug #2 verification, stale-doc updates for `vw-input-recovery.md` / `vw-dialogs.md` / `vw-eval-cookbook.md`, SUnit test for v0.8.11 `purgeWedgedDialogProcesses`).

**Supersedes:** nothing. [`HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) is the historical session-8 EOD; this file is session-9 EOD. Note: session-9 also produced one CORRECTION to session-8's narrative - session-8 stated "ZERO conventional Smalltalk-level image-boot hooks" and "Auto-start cannot be implemented at the Smalltalk level in this image" based on Smalltalk-class probes, but session-9's deeper probe found that the PARCEL mechanism is fully present (in `Kernel.` namespace), so the auto-start blocker is narrower than originally framed - it's "no SessionManager / `Smalltalk addToStartUpList:` hooks AND no class auto-calls `findAndLoadParcels` at boot," meaning parcels can still be the deployment artifact but need an external trigger to load.

---

## User direction in this session (session-9, condensed)

- Opened with a tight copy-pasteable prompt that loaded HANDOFF-2026-06-20-session8.md + ROADMAP-QUALITY-FIRST.md, did Phase 0 resume verification, executed Phase A1 + A2 per roadmap, and asked for checkpoint before any Phase D pivot or further phase work.
- Picked **Yes - update knowledge + drill into unknown + start next phase** (consolidate A3 first, then drill operational unknown, then start Phase B).
- Picked **lets implement with proposed defaults** (D1=YES dialog-closes in MVP, D2=408, D3=caseSensitive default false, D4=plan-to-disk, D5=B2+B3 one push, D6=atomic commits at end, D7=defer commit auth to end).
- Picked **save that plan to markdown and lets implement** (plan-to-disk wave for the implementation).
- Picked **you can commit using wsl** (after Phase B verified complete - 4 commits authorized, push NOT yet authorized).
- Picked **update session handoff** (this file).

Commit auth: 4 atomic commits explicitly authorized after Phase B complete. Push NOT yet authorized.

---

## Work completed in session-9

### Phase 0 - Resume verification (~5 min)

- `curl /health` -> `{"status":"ok","version":"0.8.13"}` ✓
- Token from [`.token`](../src/vw-bridge/.token): `3959432705430-137025` (matched session-8 EOD; vwnt.exe NOT restarted, no re-toggle needed)
- `git status`: 2 commits ahead of origin/main, both unpushed per session-8 user choice (`8e4e7ca` ROADMAP + `eec1879` HANDOFF correction)
- [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) L77 read - confirmed 1-arg `indexOfSubCollection: sep` ready for A1 fix

### Phase A1 - bodyOf: 2-arg fix (~5 min)

Single edit at [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) L72-82: replaced `idx := aResponse indexOfSubCollection: sep` with `idx := aResponse indexOfSubCollection: sep startingAt: 1`. Added comment citing the session-8 carry-forward constraint.

File-in via `/eval`: `{"ok":true,"result":"nil"}` clean. Class probe: `selCount=18 testCount=12 cat='VW-TestBridge-Tests'`. Belt-and-suspenders verification via `CompiledMethod>>messages`: `has2arg=true has1arg=false` confirmed.

### Phase A2 - Parcel availability probe (~45 min, READ-ONLY)

#### A2 round 1 - top-level lookup (false negative)

Probed `Smalltalk includesKey: #Parcel` and friends:
- `Parcel = false`
- `ParcelLoader = false`  
- `ParcelInstaller = false`
- All Parcel* candidates = false except `RuntimePackager = true`

Initial conclusion: "Parcel class absent" - aligning with session-8 framing.

#### A2 round 2 - deep namespace walk (correction)

Walked `Smalltalk allNameSpaces` (312 total) for `*Parcel*` and `*ackag*` patterns. **Found 26 parcel-related classes in non-top-level namespaces:**

| Namespace | Classes |
|---|---|
| `Kernel.` | `Parcel`, `ParcelLoadedChange`, `ParcelSavedChange`, `ParcelMissingError`, `ParcelError`, `ParcelAlreadyLoadedError`, `ParcelContainsAlreadyLoadedComponentsError` (7) |
| `Tools.` | `ParcelManager`, `ParcelPrereqCollector`, `ParcelPropertiesTool`, `ParcelDirectory`, `ParcelListTool`, `ParcelLoadedTool`, `ParcelGroup`, `ParcelPrereqItem`, `ParcelSelectionTool`, `ParcelFileItem`, `ParcelDirectoriesTool`, `ParcelInImageItem`, `ParcelFavoritesTool`, `ParcelManagerTool`, `ParcelPrereqReference`, `ParcelCommentTool`, `ParcelPrereqTreeTool` (17) |
| `FileTools.` | `ParcelFileViewer` (1) |
| `UI.` | `ParcelPropertiesInspector` (1) |

Plus `RuntimePackager` is a `NameSpace` (not a class) containing 37 `Runtime*` classes for deployment image building.

**`Kernel.Parcel` introspection:**
- Superclass: `CodeComponent`
- 86 class-side selectors: `createParcelNamed:`, `findAndLoadParcels`, `findAndLoadParcelsInCache`, `loadParcelByName:`, `loadParcelFrom:`, `ensureLoadedParcel:withVersion:` (and 4 keyword variants), `searchPathModel`, `classParcelMap`, `parcelsForClass:`, `triggerParcelLoaded:`, etc.
- 224 instance-side selectors including the callback mechanism: **`postLoad:` block** (set at build time, fires on load), `runClassExtensionPostLoadMethods`, `doComponentLoadedActions`, `postUnloadBlock`

**Callback mechanism is NOT `parcelInitialize`** (0 implementors anywhere). It's:
1. `Parcel>>postLoad:` instance method (a Block) - fires on load
2. `Parcel class>>triggerParcelLoaded:` - broadcasts `Kernel.ParcelLoadedChange` announcement
3. `Kernel.ParcelLoadedChange` is `ComponentLoadedChange` subclass - listeners subscribe via standard Announcement framework

#### Drilling into parcel-autoload operational unknown

Probed `searchPathModel value`: returns ValueHolder on OrderedCollection of 36 `PortableFilename` entries, all `$(VISUALWORKS)\*` paths plus `'.'` (current dir). Canonical drop point: `$(VISUALWORKS)\parcels`.

`findAndLoadParcels` compiled-method messages: `#findAndLoadParcelsInCache #withFileCachesDo:` - a thin delegator.

`findAndLoadParcelsInCache` calls `incrementallySearchForParcelsInCache` which has UI selectors (`#window`, `#firstLabel:`, `fork` via `userBackgroundPriority`) - **calling `findAndLoadParcels` from /eval would POP an interactive dialog**. For headless programmatic load, use `ensureLoadedParcel:withVersion:`.

**Sender scan** (585 classes / 15812 methods in scope: Kernel + Tools + RuntimePackager namespaces + classes with `*Startup*` or `*Boot*` in name):

| Selector | Senders | Implication |
|---|---|---|
| `#findAndLoadParcels` | 1: `VisualLauncher>>menuItemLoadParcelByName` | UI menu only |
| `#findAndLoadParcelsInCache` | 1: `Parcel class>>findAndLoadParcels` | Internal delegation |
| `#ensureLoadedParcel:withVersion:` | 1: `GeneralBindingReference>>valueIfUndefinedLoadFrom:` | Lazy-load on undefined binding reference - useful on-demand mechanism |
| `#loadParcelByName:` | 1: `Parser>>choosePragmaFor:startingAt:` | Method-pragma-driven |
| `#loadParcelFrom:` | 6: includes `ParcelLoadedChange>>fileIn`, `ParcelManager>>loadParcels:`, etc. | UI / change-replay |
| `#fileIn` | 18: all UI tools (FileBrowser, Workspace, Inspector, ChangeSet) | UI-driven |

**No boot-time / startup caller exists.**

`RuntimePackager.RuntimeStartupController` (despite suggestive name): superclass `ApplicationStandardSystemController`, **class-side selectors `#()`** (empty), instance-side `#(#saveFinalImage)` only. Used by RuntimePackager UI for the "save final image" workflow, NOT a boot-time mechanism.

#### File system findings

- vwnt.exe location: `C:\visualworks931\bin\win64\vwnt.exe` (PID 5624 at session-9 start, parent `explorer.exe`)
- Image: `C:\visualworks931\image\storedev64.im` (~188 MB)
- Working dir: `C:\visualworks931\image\`
- vwnt.exe command line: `"C:\visualworks931\bin\win64\vwnt.exe" "C:\visualworks931\image\storedev64.im"` - **no startup script argument**
- Canonical parcel dir `C:\visualworks931\parcels\`: 103 stock VW `.pcl` files (Browser-*, BOSS, Compression-*, Database, etc.)
- Working dir contents include `WealthWS-startup.st` (26 bytes, dated 2/6/2006) containing literally `GemStoneInterface startup.` - proves convention of small startup scripts exists somewhere in MAS deployment pipeline but is NOT auto-fed at image boot in current launch sequence. Plus `iferror.topaz` + `version.topaz` recent files (touched today via deployment pipeline). Plus `deploy.gs` (~36 MB) and `testCases.gs` (~18 MB) Test Mentor artifacts.

#### Phase D verdict (final, evidence-backed)

| Path | Status | Trigger required |
|---|---|---|
| D-parcel (pure) | NOT viable as "drop in parcels dir and forget" | No boot-time `findAndLoadParcels` caller in this image |
| D-parcel + external | VIABLE | Build `VWBridge.pcl` with `postLoad: [VWBridge start]` block, drop in `C:\visualworks931\parcels\`, external script triggers `Kernel.Parcel ensureLoadedParcel: 'VWBridge' withVersion: nil` |
| D-snapshot | VIABLE | File-in bridge + `ObjectMemory snapshotAs:thenQuit:`; listener fork doesn't survive snapshot so external trigger still needed for `VWBridge start` |
| D-external (pure) | VIABLE | PowerShell/batch wrapper launches `vwnt.exe`, injects file-in via Topaz stdin or CLI |

**All three viable paths converge on needing an external trigger.** Phase D design decision narrows to which external mechanism is least brittle, AND whether in-image code ships as parcel (hygiene) vs raw `.st` file-in (current).

### Phase A3 - Knowledge consolidation (~45 min)

Wrote [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) (~492 lines). Sections:
- Image identity (paths, versions, launch sequence)
- Quick lookup table (~25 most-asked "does X work?" answers with alternatives)
- Namespace organization (Kernel.Parcel, Tools.ParcelManager, MAS top-level, etc.)
- APIs ABSENT (5+ "this image lacks X" entries from session-3..8 + session-9 additions)
- APIs PRESENT with surprising behavior (Character>>asString, Filename>>writeStream, findAndLoadParcels UI dialog, chunk format gotchas)
- Probe patterns that WORK (boilerplate, defensive lookup, cross-namespace scan, behavioral fingerprint, sender scan, error recovery, PowerShell idioms)
- Probe anti-patterns (top-level Smalltalk for namespaced, String streamContents:, Character asString, 1-arg indexOfSubCollection:, Smalltalk imageFileName, SystemNavigation, etc.)
- Startup hook landscape (definitive evidence-backed coverage)
- Parcel infrastructure (full session-9 discovery)
- File system layout near image
- Carry-forward constraints (one-line per item)
- How to maintain this doc

This doc captures session-9's parcel discovery + ALL prior carry-forwards in one fast-lookup reference.

### Phase B1 - Oracle consult (2m 30s + synthesis)

Fired Oracle (bg_b8ac84ac) with comprehensive prompt covering: project context, 12 existing endpoints, bridge architecture (listener-forks-serve-process, UI process via `onUIDo:`, Stage 1/2 re-entry guards), image API quirks from session-3..9, hard constraints (no MAS code mod, no /eval polling, no test gaming), specific design questions (eval-truthy in MVP? poll interval? where loop lives? state query strategy? compound predicates? timeout status code? boundary race? idempotence? cancellation? multi-tenancy?).

**Oracle output (2m 30s):**
- **4 MVP predicates**: window-appears, dialog-appears, window-closes, dialog-closes (was 3 - my pushback added dialog-closes given Bug #2/#5 history of dialog-DISMISSAL centrality)
- **Defer**: value-equals (widget identity not yet probed)
- **Exclude**: eval-truthy (duplicates /eval, safety hole, blocks serve process)
- **Compound predicates**: excluded - tests compose multiple `/wait` calls
- **REST shape**: POST /wait + JSON; 200 success / 408 timeout / 400 bad-request; defaults timeoutMs=5000 (bounds 1-60000), intervalMs=100 (bounds 50-1000)
- **Polling**: serve-process polling, no backoff, fixed interval; final-check after deadline so success wins boundary race
- **Test seams**: `waitClockMilliseconds` + `waitForMilliseconds:` for fake clock; refactor `/windows` + `/dialogs` to extract internal `windowsSnapshotForWait` + `dialogsSnapshotForWait` so /wait reuses without recursive HTTP dispatch
- **TDD test design**: 5 tests per predicate kind + 5 shared validation
- **Sharp edges**: 10 risks enumerated with mitigations

### Phase B2 - Refactor + 25 RED tests (~3h)

#### B2.1 - Extract windowsSnapshotForWait

`/windows` handler already delegated to `windowSummaries` (existing method). Added `windowsSnapshotForWait` in new `'wait helpers'` category that wraps `onUIDo: [self windowSummaries]` with scripted-override check. Simplified `handleWindows` from 5 lines to 3.

#### B2.2 - Extract dialogsSnapshotForWait + computeDialogsSnapshot

`/dialogs` handler previously called `onUIDo: [self doListDialogs]` where `doListDialogs` returned a JSON STRING. Refactored: `computeDialogsSnapshot` returns OrderedCollection of dialog Dictionaries (UI-side work), `dialogsSnapshotForWait` wraps `onUIDo: [self computeDialogsSnapshot]` + scripted-override check, `handleDialogsQuery` calls `dialogsSnapshotForWait` then JSON-wraps. Deleted `doListDialogs` from source. **Note: chunk file-in is additive - had to explicitly `removeSelector: #doListDialogs` to clean up the residual method from the image (NEW carry-forward).**

#### B2.3 - Test seams (4 ivars + 10 methods)

Added 4 ivars to VWBridge class definition: `clockOverride sleepOverride scriptedWindowSnapshots scriptedDialogSnapshots`. All nil by default; production behavior unchanged.

10 new methods in `'wait helpers'` category:
- `waitClockMilliseconds` - returns clockOverride OR `Core.Time millisecondClockValue`
- `waitForMilliseconds:` - calls sleepOverride block with ms OR `(Delay forMilliseconds: ms) wait`
- `windowsSnapshotForWait`, `dialogsSnapshotForWait`, `computeDialogsSnapshot` (from B2.1, B2.2)
- `clockOverride:`, `sleepOverride:`, `scriptedWindowSnapshots:`, `scriptedDialogSnapshots:` (setters)
- `clearWaitOverrides` - sets all 4 to nil; called from VWBridgeWaitTest>>tearDown

#### B2.4 - Regression verification

File-in clean. All 5 `/eval`-friendly tests still GREEN: `testBug2DialogConfirmYesReturnsTrue`, `testBug2DialogConfirmNoReturnsFalse`, `testLogWritesNDJSONToFile`, `testLogLevelDistinction`, `testLogJsonLineWellFormed`. Other 7 tests (3 health + 2 auth + 2 eval) go through `dispatch:` so they fail via /eval per existing Bug #5 pattern - unchanged from session-8.

#### B2.5-B2.9 - 25 wait tests RED

Created new file [`VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) (~322 lines). Class `VWBridgeWaitTest extends TestCase`, ivars `bridge authHeaders`, category `VW-TestBridge-WaitTests`. 12 fixture helpers including:
- `setUp` (grab singleton, build auth headers)
- `tearDown` (clear wait overrides)
- `waitResponseFor:` (invoke `bridge handleWait:` directly to bypass re-entry guard; uses `self assert: false description:` (NOT `self fail:` - that selector doesn't exist in this VW SUnit, NEW carry-forward) when handler not yet implemented)
- `withFakeClockAndScriptedWindows:do:` / `withFakeClockAndScriptedDialogs:do:` / `withFakeClockOnly:` (set up overrides, run block)
- `windowSnapshotWith:title:`, `windowSnapshotWith:title:id:`, `dialogSnapshotWith:` (build fake snapshot dictionaries)
- `bodyContains:in:`, `statusLineOf:`, `bodyOf:` (response parsing)

25 tests across 5 categories:
- `'tests - shared validation'` (5): missing kind, eval-truthy rejected, compound rejected, invalid timeout bounds, defaults applied
- `'tests - window-appears'` (5): immediate success, delayed success, timeout, malformed missing match, multiple matches deterministic
- `'tests - dialog-appears'` (5): immediate, delayed, timeout, malformed missing messageContains, substring multi-line match
- `'tests - window-closes'` (5): already closed (alreadySatisfied:true), delayed close, timeout, malformed missing target, boundary race
- `'tests - dialog-closes'` (5): already closed, delayed close, timeout, malformed, boundary race

#### B2.10 - Verify all 25 RED

First run: all 25 reported `err=1` (exception, not assertion failure). Root cause: my helper used `self fail: 'msg'` which doesn't exist as a selector in this VW SUnit - raised Message not understood. Fixed helper to use `self assert: false description: 'msg'`. Re-ran: **25/25 cleanly fail=1 (assertion-based RED), 0 err, 0 GREEN**. Existing 5 regression tests still GREEN.

### Phase B3 - /wait implementation (~3h)

#### B3.1-B3.6 - Full implementation in one push

Made 3 edits to VWBridge.st before file-in:

**Edit A: Parser extension for nested objects.** `jsonParseFlat:` was flat-only per its doc comment. Refactored: `jsonParseFlat:` becomes a thin wrapper that delegates to new `parseObject:cursor:` (extracted from old body); `parseAnyValue:` adds `${ ifTrue: [^self parseObject: aString cursor: cursor]` branch. Now fully recursive. Name `jsonParseFlat:` kept for backward compat (now a misnomer; doc updated).

**Edit B: 408 status code.** Added `code = 408 ifTrue: ['Request Timeout']` to the chain in `httpResponse:type:body:`.

**Edit C: Wait handler section.** Inserted new `'wait handler'` methodsFor: section between `'http'` and SimpleDialog Bug #2 extension (~220 lines):
- `handleWait:` (main entry; parses, validates, runs poll loop, final-check, returns 200/408/400)
- `parseAndValidateWaitRequest:` (full validation with structured Dictionary result)
- `waitErrorWithMessage:` (build error result Dictionary)
- `jsonBadRequestBody:` (build 400 JSON body)
- `evaluateWaitPredicate:` (dispatcher to per-kind evaluator)
- `evaluateWindowAppears:`, `evaluateDialogAppears:`, `evaluateWindowCloses:`, `evaluateDialogCloses:` (4 predicate evaluators)
- `waitResultNotSatisfied` (sentinel result Dictionary)
- `windowMatches:filter:spec:` (window-filter matcher: all-of-the-fields semantics for appClass/title/titleContains, honors caseSensitive)
- `waitEquals:to:caseSensitive:`, `waitSubstring:in:caseSensitive:` (string matchers honoring case)
- `waitSuccessBodyFor:result:polls:elapsedMs:` (build 200 JSON body; includes matched+matchCount for appears, closed+alreadySatisfied for closes-on-first-poll)
- `waitTimeoutBodyFor:result:polls:elapsedMs:` (build 408 JSON body)

#### B3 verification round 1 (23/25 GREEN)

After file-in, ran 25 wait tests: **23 GREEN, 2 RED** (testWindowClosesTimeout + testDialogClosesTimeout). Diagnosis: my poll loop does N iterations then 1 final-check = N+1 polls total. With timeoutMs=300 + intervalMs=100, loop runs 4 iterations + 1 final = 5 polls. Tests provided only 4 snapshots → 5th poll hit empty queue → for `*-closes` predicates, empty snapshot = "no matching entry" = SATISFIED (closed!) = wrong answer (returns 200 not 408).

#### Sticky-queue fix

Edited `windowsSnapshotForWait` + `dialogsSnapshotForWait`: when `scriptedXxxSnapshots size > 1`, dequeue first; when only 1 left, return it WITHOUT dequeueing (sticky). Empty queue still returns empty collection. Re-filed. **Re-ran: 25/25 GREEN ✓.** Verified all 23 previously-passing tests still pass.

#### B3.7 - Dispatcher wiring

Added `path = '/wait' ifTrue: [^self handleWait: bodyString]` to the POST routes in `doDispatch:headers:body:`. Updated the dispatcher comment that lists all routes to include `/wait`.

#### B3.8 - Version bump to v0.9.0

4 canonical sites in [`VWBridge.st`](../src/vw-bridge/VWBridge.st):
- L1 header comment (with full v0.9.0 description)
- L458 dispatch:headers:body: comment "Main dispatcher (v0.9.0)"
- L488 doDispatch:headers:body: comment "Actual dispatch logic (v0.9.0)"
- L507 /health body `'{"status":"ok","version":"0.9.0"}'`

Plus VWBridge-Test.st L100-101 (version assertion).

#### B3.9 - Final verification

File-in both VWBridge.st + VWBridge-Test.st. Verified:
- `/health` -> `{"status":"ok","version":"0.9.0"}` ✓
- 25 wait tests: **all GREEN** ✓
- 5 regression tests: **all GREEN** ✓
- **Live POST /wait timeout**: real `Delay`, returned HTTP 408 with structured body (polls=6, elapsedMs=1202)
- **Live POST /wait success against REAL MAS Portfolio window**: HTTP 200 with `matched:{appClass:PortfolioView,title:Portfolio,viewClass:ScheduledWindow,bounds:"805 @ 281 corner: 1758 @ 1121"}, polls=1, elapsedMs=0, matchCount=1`. Used `titleContains:"Portfolio"` (case-insensitive default per D3). End-to-end working with live MAS UI state.

Dispatcher routing proven independently: an inline curl JSON that PowerShell mangled returned `{"ok":false,"error":"bad-request","message":"malformed JSON body"}` - which is the BRIDGE's own structured 400 response (not a 404 unknown-route), proving the dispatcher correctly routed POST /wait → handleWait: which correctly parsed/validated.

### Phase B - Commits

4 atomic commits per user authorization (push NOT authorized):

| # | Hash | Subject | Files |
|---|---|---|---|
| 1 | `d22d273` | `docs: knowledge/vw-image-api-contract.md - consolidated probe-derived API contract for MAS storedev64 image (session-9 A3, captures session-3..8 carry-overs + session-9 parcel discovery + probe patterns)` | [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) (NEW, 492 lines) |
| 2 | `17ac0a0` | `docs: plan/PLAN-PHASE-B-WAIT-ENDPOINT.md - Phase B /wait endpoint working plan based on Oracle B1 consult (D1-D7 decisions, 19-step B2+B3, sharp edges, success criteria)` | [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) (NEW, 489 lines) |
| 3 | `587178d` | `feat: VWBridge v0.9.0 - POST /wait endpoint with 4 predicates (window-appears/dialog-appears/window-closes/dialog-closes) + nested-object JSON parser + 408 Request Timeout status + 4 test-seam ivars (clockOverride/sleepOverride/scriptedWindowSnapshots/scriptedDialogSnapshots, sticky-queue semantics) + refactor /windows + /dialogs to extract windowsSnapshotForWait/dialogsSnapshotForWait internal methods (avoids recursive HTTP dispatch per Bug #5)` | [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (+435/-51) |
| 4 | `cc2abe5` | `test: VWBridgeWaitTest - 25 new wait tests (5 per predicate kind: window-appears/dialog-appears/window-closes/dialog-closes + 5 shared validation) with fake-clock + sticky-queue snapshot fixture; VWBridgeTest - A1 bodyOf: 1-arg to 2-arg indexOfSubCollection fix + B3.8 version assertion bump to v0.9.0` | [`VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) (NEW, 322 lines) + [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) (+6/-4) |

Working tree clean post-commit. 6 commits ahead of `origin/main` (2 from session-8 + 4 from session-9), all unpushed.

---

## Current state (end of session-9)

- **VW image**: still up at `vwnt.exe` (PID 5624, launched ~13:07 today via Explorer). ~270+ baseline procs across the bridge churn (file-ins, test runs).
- **Bridge**: UP at v0.9.0 on `127.0.0.1:9876`. Last token rotation `3959443064454-247528` (post B3.9 file-in). Reading [`.token`](../src/vw-bridge/.token) for current value is mandatory before any /eval.
- **`Dialog useNativeDialogs: false`**: SET (carried over from session-7 + 8, survived all v0.9.0 file-ins). Resets on `vwnt.exe` restart.
- **Bridge code on disk**: v0.9.0 in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (~2194 lines, +384 from session-8). New `'wait handler'` category between `'http'` and the SimpleDialog Bug #2 extension. New `'wait helpers'` category between `'logging'` and `'initialization'`.
- **SUnit scaffold on disk**: 18 selectors in `VWBridgeTest` (unchanged from session-8). NEW: 37 selectors in [`VWBridgeWaitTest`](../src/vw-bridge/VWBridge-WaitTest.st) (25 tests + 12 helpers).
- **Test fixture pattern**: established sticky-queue + fake-clock fixture in VWBridgeWaitTest reusable for future test classes that need to simulate UI state sequences.
- **NEW knowledge doc**: [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) - the canonical probe-derived API contract. Read before writing new probes.
- **NEW plan doc**: [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) - this wave's working plan with D1-D7 captured.
- **Log file** at [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log): grew through session-9 with NDJSON entries for every wait satisfied/timeout/bad-request. Gitignored. Still no rotation (revisit before production packaging).
- **Image globals from session-9 probes** (clear on `vwnt.exe` restart):
  - `TEST_BUG2_YES_RET=true`, `TEST_BUG2_NO_RET=false` (re-set by Bug #2 regression tests this session)
  - No new named globals from session-9 (probes used stream-based output or inline writers; no PHASE_* globals)
  - Plus all session-3..8 globals still present
- **Git**:
  - `main` at `cc2abe5` locally, **6 commits ahead of origin/main** (`b4d1d2b..cc2abe5`).
  - origin/main: `b4d1d2b` (session-8 Wave 1 wrap, last pushed).
  - 4 net new commits this session.
- **Known bugs**:
  - **Bug #1: FIXED in v0.8.7**
  - **Bug #2: FIXED in v0.8.12**
  - **Bug #3: not a bug**
  - **Bug #4: FIXED in v0.8.6**
  - **Bug #4b: FIXED in v0.8.10**
  - **Bug #5: FIXED in v0.8.8** (re-entry guard pattern; reinforced by session-9 by-design of /wait NOT going through dispatch:)
  - **Bug #6: FIXED in v0.8.13** (session-8)
  - **No new bugs identified in session-9.**
- **Known limitations (carried + NEW)**:
  - From session-8: log file no rotation, concurrent log writes might drop on Windows sharing violations
  - From session-8: auto-start blocked at Smalltalk level - **REFINED in session-9**: parcel mechanism IS present in `Kernel.Parcel`, so auto-start path now narrows to "external trigger" (parcel-with-external-trigger / snapshot / pure-external script). Still blocked from "pure self-bootstrapping in this image" but no longer architecturally impossible.
  - **NEW session-9**: Chunk file-in is additive - methods removed from source survive in image until explicitly `removeSelector:`'d. Be defensive when refactoring (`doListDialogs` example).
  - **NEW session-9**: `self fail:` doesn't exist on TestCase in this VW SUnit - use `self assert: false description: 'msg'` for explicit test failure.
  - **NEW session-9**: Stage 1 substring guard in `dispatch:` scans `/eval` body for both 'VWBridge' AND 'dispatch' substrings - **including in COMMENTS**. Avoid the word 'dispatch' in /eval probe comments. (Bug #5 prevention working as designed; just sharp edge for probe authors.)
  - **NEW session-9**: `findAndLoadParcels` is INTERACTIVE (opens UI dialog via `incrementalSearchDialogForParcelsIn:`). Use `ensureLoadedParcel:withVersion:` for headless programmatic load.

---

## Pending tasks (session-10)

### Immediate on resume

1. **Restart `vwnt.exe`?** Functionally clean (0 wedged procs at session wrap, 25/25 + 5/5 tests GREEN). Image accumulated globals across 4 prior sessions but no observed issues. Restart not strictly required.
2. **If `vwnt.exe` restarted**: re-toggle `Dialog useNativeDialogs: false` via /eval, then file-in v0.9.0 via Workspace (NOT /eval since bridge would be DOWN): `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn` then `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn` then `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-WaitTest.st' asFilename fileIn`.
3. **Verify state**: `curl /health` -> v0.9.0, re-read [`.token`](../src/vw-bridge/.token).
4. **Decide push** of 6 ahead-of-origin commits (4 from this session + 2 from session-8).
5. **Decide next direction** (options below).

### Highest-value next directions

6. **B4 real-usage 10x verification** (~30-60 min). The Phase B quality gate per [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) is "zero flakes across 10 consecutive sequential runs of the real-usage flow." Needs a chosen MAS workflow run repeatedly. Candidate workflow: `/click partySearch findID button → /wait dialog-appears Continue? → /dialogs/respond Yes → /wait window-appears Portfolio`. Could ship as a PowerShell test driver script committed under `scripts/`.

7. **Phase C - API freeze + OpenAPI spec** (per roadmap). With v0.9.0 shipped and 13 endpoints, freezing the contract before more endpoints / SDK work is the natural next step. Hand-write OpenAPI 3.0 spec at `docs/openapi.yaml`, add CI check that spec matches actual bridge responses. ~4-6h.

8. **Phase D - Auto-start architecture** (now unblocked by session-9 parcel evidence). Three viable paths converge on "external trigger." Build `VWBridge.pcl` + drop-in script OR snapshot-based OR pure external bootstrap. Needs Oracle consult on the trade-offs given the test-framework deployment context (we own the CI runner). ~1 session.

9. **Phase F - /screenshot endpoint** (largest scope per roadmap). Probe VW graphics APIs first (likely `Image fromUser:` or `Screen default`), then UI-process dispatch (same pattern as /dialogs), base64 encoding, JSON transport. Oracle consult mandatory. ~8-12h.

10. **Phase E - Playwright TypeScript SDK** (per roadmap). With v0.9.0 + frozen API, write the first SDK + 3 tests. Depends on Phase C ideally.

### Trivial cleanups

11. **Stale doc updates** flagged in session-6+7+8 (still not done):
    - [`vw-input-recovery.md`](./vw-input-recovery.md): wedge accumulation prevented by v0.8.11+
    - [`vw-dialogs.md`](./vw-dialogs.md): "ValueHolder on: false. Modal exits when set to true." is incorrect - modal loop polls EventQueue>>next on a Semaphore
    - [`vw-eval-cookbook.md`](./vw-eval-cookbook.md): add wedged-dialog stack-walk recipe + compiled-method introspection-without-Decompiler recipe + WriteStream-on-String-new boilerplate

12. **SUnit test for v0.8.11 `purgeWedgedDialogProcesses`** - still untested (carry from session-7).

### Carry-overs from session-7 / 8 (still pending)

13. **EXPLORATION-PLAN step 3** - 3-deep menu navigation.
14. **EXPLORATION-PLAN step 4** - leaf dispatch catalog across MAS menu tree.
15. **End-to-end verification of `#id` / `#imcNr` / `#groupScheme`** (no-modal `partialFind:` paths) - still UNVERIFIED via bridge per session-3 calibration.
16. **End-to-end verify Bug #2 fix for `#surname` broad search**.

### Production-grade packaging (medium-term)

17. SUnit coverage expansion - particularly value-equals when Phase D widget identity probed (deferred from MVP).
18. Log rotation.
19. Class-side log mutex for concurrent fork safety.
20. Env-var externalization of log file path + .token path + port + parcel deployment path.
21. OpenAPI spec for bridge endpoints (Phase C above).
22. Parcel build script - depends on Phase D decision.

---

## Key files

| File | Role |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | **CANONICAL v0.9.0** - all fixes from sessions 3-9 applied. /wait handler at L1900+ in new `'wait handler'` category. Wait helpers at L180+ in new `'wait helpers'` category. 4 new ivars on class definition (L10). Bug #2 Symptom A fix preserved at L2050+. File via Workspace or `/eval`. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold v0.9.0. 18 selectors (6 helpers + 9 tests + 3 logging). A1 fix at L72-82. Version assertion at L100-101. Filed via `/eval` or Workspace. |
| [`src/vw-bridge/VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) | **NEW v0.9.0** - 37 selectors (25 tests + 12 fixture helpers). Uses sticky-queue + fake-clock pattern. All tests safe for /eval (bypass dispatch: by calling handleWait: directly). Filed via /eval or Workspace. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token. Rotates on every `VWBridge start`. Re-read after every file-in of VWBridge.st. |
| [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log) | NDJSON log file. Gitignored. Grows unbounded (no rotation yet). |
| [`.gitignore`](../.gitignore) | Excludes `.token`, `.dialog-probe*.txt`, `*.png`, `*.jpg`, `test-results/*.txt`, `vw-bridge.log`. |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **NEW v0.9.0** - the canonical probe-derived API contract. ~492 lines. READ FIRST before writing new probes. Lookup table at top; absent APIs + surprising APIs sections; probe patterns + anti-patterns; startup hook landscape; parcel infrastructure. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#6 - all FIXED. No new bugs in session-9. |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. Bug #2 workaround marked OPTIONAL for v0.8.12+. |
| [`knowledge/HANDOFF-2026-06-20-session7.md`](./HANDOFF-2026-06-20-session7.md) | Session-7 EOD handoff. |
| [`knowledge/HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) | Session-8 EOD handoff. Note: session-8's "auto-start blocked at Smalltalk level" framing was REFINED in session-9 (parcel mechanism IS present; blocker narrows to "no boot-time caller of findAndLoadParcels"). |
| [`knowledge/HANDOFF-2026-06-20-session9.md`](./HANDOFF-2026-06-20-session9.md) | **THIS FILE.** Session-9 EOD. |
| [`plan/STRATEGIC-ASSESSMENT-2026-06-20.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-20.md) | Strategic snapshot. /wait endpoint completion moves us through Phase B per [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md). |
| [`plan/ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) | Quality-shaped phase roadmap. Phase A (A1+A2+A3) done this session; Phase B (B1+B2+B3) done this session except B4. |
| [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) | **NEW v0.9.0** - working plan for /wait endpoint with all D1-D7 decisions, 19-step B2+B3 sequence, sharp edges, success criteria, resume hooks. Step status table at top tracks progress (all steps marked completed except B4). |

---

## Important decisions (this session)

- **Phase A1 first, before A2 / Phase B.** Trivial warmup that proves the resume path works. Also fixed a real pending issue documented in session-8.
- **Phase A2 expanded into deeper probe when initial result looked suspicious.** Session-8's "no auto-start" inference was based on Smalltalk-class probes. Session-9's deeper namespace walk corrected the inference. **Lesson: when an existence check returns false, walk all namespaces before concluding the class is absent.** Now codified in [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md).
- **Knowledge consolidation (A3) BEFORE further phases.** Capturing the parcel discovery + session-3..8 carry-forwards in one fast-lookup doc means future agents won't re-discover known limitations. Pays off on every new probe.
- **D1 = YES dialog-closes in MVP** (my pushback against Oracle's "defer to v0.9.x"). Rationale: Bug #2 and Bug #5 history makes dialog-DISMISSAL central to the test loop. Without dialog-closes, tests would still need `Start-Sleep` after responding to dialogs. Added 30 min of work + 5 tests; worth it.
- **D2 = 408 for timeout** (accepted Oracle's call). Cleaner semantic for "predicate not satisfied within deadline" than 200+ok:false.
- **D3 = caseSensitive default false on substring predicates** (my pushback - Oracle's planning chatter mentioned it but final spec dropped it). Rationale: MAS window titles observed to have case variation.
- **D4 = plan-to-disk** (explicit user pick on this session).
- **D5 = B2+B3 in one push** (sequential dependency chain).
- **D6 = atomic commits at end** (matches session-7 + 8 pattern).
- **Sticky-queue snapshot semantics** (my fix after B3 round 1 caught the test-isolation bug). When scripted snapshot queue has more than 1 element dequeue per call; when 1 left, repeat it (steady-state). Tests don't have to count exact poll counts. More intuitive AND fixes the boundary-race bug.
- **Test seams as 4 ivars on production VWBridge** (not subclass-based). Pros: no class-side singleton swap needed, tearDown is clean. Cons: 4 production ivars exist just for testing. Documented in code comments. Acceptable trade-off.
- **/wait poll loop on serve process** (per Oracle). Listener already forks per request; blocking serve process is fine. UI process must NEVER block (would freeze MAS).
- **Internal `windowsSnapshotForWait` + `dialogsSnapshotForWait` methods instead of recursive HTTP dispatch** (per Oracle). Bug #5 history proves recursive `dispatch:` is fatal. Refactor extracts the snapshot logic so both /windows + /wait use it directly without recursion.
- **JSON parser extension to support nested objects** (my work-around for `match: {appClass: X}` shape). Extends `jsonParseFlat:` from flat-only to fully recursive via new `parseObject:cursor:`. Backward compat preserved.
- **4 atomic commits** (docs A3 + docs plan + feat + test). Matches session-7 + 8 atomic-commit convention. Each commit conceptually independent.
- **Held push.** User authorized commits but NOT push. 6 commits stay local until next direction.

---

## Explicit constraints (carry forward - session-9 additions noted)

All session-8 constraints carry forward unchanged unless noted. Full consolidated reference in [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md). Highlights + NEW additions from session-9:

### Carry-forward unchanged from session-8

- **NEVER commit, amend, or push** without explicit user request. Session-9 had auth for: 4 atomic commits after Phase B verified. Push NOT authorized. Session-10 needs fresh auth.
- **NEVER call `VWBridge singleton dispatch:` from inside /eval.** Stage 1 substring + Stage 2 per-process re-entry guards return 400.
- **OFF-LIMITS widgets** without explicit OK: `commitWidget`, `loginRpcWidget`, `removeWidget`. MAS menu leaves with mutation verbs need OK before any `/menu/click`.
- **`windowTitle` is CASE-SENSITIVE substring match** (legacy; the new /wait `titleContains` defaults to case-INsensitive per D3 design).
- **For Workspace file-in (bridge DOWN scenario)**: `'path' asFilename fileIn.`
- **For /eval file-in (bridge UP, v0.8.8+)**: PowerShell + `curl.exe` with `--data-binary @file`. Token rotates afterward - re-read `.token`.
- **Character literal in chunk file-in**: `$'` unreliable. Use `(Core.Character value: 39)`.
- **GBS namespace qualification**: `Root.Smalltalk`, `Core.String`, `Core.Character`, `Core.Error`, `Core.Array`, `Core.Integer`, `Core.OrderedCollection`, `Core.Dictionary`.
- **/eval runs on bridge serve process**, not UI process. `mgr activeControllerProcess` returns nil during modals - `onUIDo:` falls back to direct execution.
- **Image sources are STRIPPED.** Use `CompiledMethod>>messages`, `>>literals`, `>>numArgs`, `>>numTemps` for behavioral fingerprint.
- **`SystemNavigation` does NOT exist** - manual literal walks.
- **String `indexOf:startingAt:` does NOT exist** - use `nextIndexOf:from:to:`.
- **String 1-arg `indexOfSubCollection:` errors in some receiver contexts** - use 2-arg `:startingAt:`.
- **String `includesSubString:` does NOT exist** - use `(s indexOfSubCollection: sub startingAt: 1) > 0`.
- **`DateAndTime` class does NOT exist** - use `Timestamp now printString` or `Core.Time millisecondClockValue`.
- **`SessionManager instance` returns nil** - standard VW startup hook pattern unusable.
- **`Filename` (NTFSFilename) has NO `appendingWriteStream`** - use `readWriteStream` + `setToEnd`. `writeStream` ALWAYS truncates.
- **`instVarNames` is CLASS-SIDE**: `model class instVarNames`.
- **`isCollection` does NOT exist as generic selector** - use `respondsTo: #do:`.
- **`canUnderstand:` is CLASS-SIDE**: `instance class canUnderstand: #sel`.
- **`Process allInstances` works; `Processor allProcesses` does NOT exist.**
- **`Character>>asString` calls `printString`** - use `String with: aChar` for 1-char string.
- **PowerShell `-Body` with literal JSON inline = QUOTE-HELL** - use `--data-binary "@path/to/file.json"`.
- **PowerShell here-strings `@'...'@` do NOT require doubled single quotes.**
- **Git is in WSL**: `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git ...`.
- **PowerShell auto-table-formats arrays from `Invoke-RestMethod`** - use `Invoke-WebRequest -UseBasicParsing` + `ConvertFrom-Json` for raw JSON.
- **VW chunk-file format**: comment-only chunks REJECTED. Every chunk needs an executable expression.
- **VW comment escaping**: multi-line `"..."` comments terminate at first inner `"`. Use bracket markers `[...]` for example tags.

### NEW carry-forward from session-9

- **`Parcel` lives in `Kernel.` namespace, NOT top-level `Smalltalk`.** `Smalltalk includesKey: #Parcel` returns false. Use `Kernel.Parcel` or walk `Smalltalk allNameSpaces`. Same applies to other `Tools.`, `FileTools.`, `UI.` namespaced classes - 312 total namespaces in this image. **Always walk all namespaces before concluding a class is absent.**
- **`Smalltalk imageFileName` does NOT exist** - use `ObjectMemory imageName`. Returns e.g. `'C:\visualworks931\image\storedev64.im'`.
- **`String streamContents:` does NOT exist** - use `WriteStream on: String new` + `s contents`. Single most common probe-failure pattern.
- **`selectorsDo:` does NOT exist** - use `selectors do: [...]` (two words).
- **`self fail: 'msg'` does NOT exist on TestCase in this VW SUnit** - use `self assert: false description: 'msg'` for explicit test failure.
- **Chunk file-in is ADDITIVE.** Methods removed from source survive in the image until explicitly `cls removeSelector: #foo`. When refactoring a method into a different name, explicitly remove the old one or it lingers. Bit me on `doListDialogs` rename to `computeDialogsSnapshot`.
- **Stage 1 substring guard scans /eval body for 'VWBridge' AND 'dispatch' substrings including in COMMENTS.** Don't use the word 'dispatch' in /eval probe comments even if your code doesn't actually call `dispatch:`. Working as designed; just sharp edge for probe authors. Use synonyms like 'router' or 'route handler' instead.
- **`findAndLoadParcels` is INTERACTIVE** (calls `incrementalSearchDialogForParcelsIn:` which opens a UI dialog with forks via `userBackgroundPriority`). For headless programmatic parcel load, use `ensureLoadedParcel:withVersion:` (delegates to `:forPundle:` variant).
- **`RuntimePackager` is a `NameSpace`, not a class** (37 `Runtime*` classes inside it). `RuntimeStartupController` despite its name is a UI controller for "save final image" workflow, NOT a boot-time mechanism (class-side selectors empty, instance-side just `#saveFinalImage`).

---

## Context for continuation (read this before resuming)

- **Phase B is DONE.** v0.9.0 ships /wait endpoint with 4 predicates (window-appears/dialog-appears/window-closes/dialog-closes). 25 SUnit tests GREEN + 5 regression tests GREEN + live POST /wait verified end-to-end against real MAS Portfolio window. **B4 (real-usage 10x verification with chosen MAS workflow) is the final Phase B gate** and is deferred per agent recommendation.
- **Phase A is DONE** (A1 + A2 + A3). A4 (`/capabilities` endpoint per roadmap) is optional polish, not done.
- **Phase D evidence is COMPLETE.** Three external-trigger paths viable; design decision is "which external mechanism" not "is this possible at all" (which was the session-8 framing).
- **For ANY bridge change in v0.9.1+**: same protocol - edit [`VWBridge.st`](../src/vw-bridge/VWBridge.st), reload via /eval file-in, bump version at 4 canonical sites + test assertion. Re-read `.token` after every file-in.
- **For ANY new SUnit test**: choose between `VWBridgeTest` (general bridge tests) or `VWBridgeWaitTest` (anything involving /wait or scripted state). New test classes should follow the pattern: call handler methods DIRECTLY (not `bridge dispatch:`) so /eval-friendly + Workspace-friendly. For state simulation, use the 4 test seams (clockOverride / sleepOverride / scriptedWindowSnapshots / scriptedDialogSnapshots) with `clearWaitOverrides` in tearDown.
- **For ANY new probe**: read [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) FIRST. Use the probe-pattern boilerplate at top. Use `WriteStream on: String new` (not `String streamContents:`). Use `String with: Core.Character lf` (not `Core.Character lf asString`). Use `ObjectMemory imageName` (not `Smalltalk imageFileName`). Use 2-arg `indexOfSubCollection:startingAt:`. Walk all namespaces, don't trust top-level `Smalltalk includesKey:`.
- **8 carry-forward constraints from session-9** added to the constraints section above + image API contract. These bite hard if forgotten - reference them when writing new probes / tests / handler refactors.

---

## To continue in a new session

1. Press `n` in OpenCode TUI to open a new session, or run `opencode` in a new terminal.
2. Paste this entire file as your first message.
3. Add your request - pick one based on focus:
   - "Continue from handoff above. Push the 6 ahead-of-origin commits." - simplest wrap-up.
   - "Continue from handoff above. Execute B4 real-usage 10x verification with a chosen MAS workflow." - finishes Phase B's quality gate.
   - "Continue from handoff above. Start Phase C - API freeze + OpenAPI spec." - locks down v0.9.0 API surface before SDK work.
   - "Continue from handoff above. Start Phase D - design the auto-start architecture (parcel-with-external-trigger vs snapshot vs pure-external). Oracle consult first." - unblocks the long-deferred auto-start work.
   - "Continue from handoff above. Start Phase E - scaffold Playwright TypeScript SDK + write 1-3 first tests against v0.9.0." - Test Mentor replacement begins.
   - "Continue from handoff above. Start Phase F - /screenshot endpoint. Probe VW graphics APIs + Oracle consult first." - unblocks failure-investigation visibility for tests.
   - "Continue from handoff above. Stale-doc pass: update vw-input-recovery.md, vw-dialogs.md, vw-eval-cookbook.md per session-3..9 findings." - docs hygiene.

The new session will have full context to continue seamlessly.
