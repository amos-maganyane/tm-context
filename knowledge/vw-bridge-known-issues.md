# VW Bridge Known Issues (v0.8.5)

Bugs and rough edges in the v0.8.5 bridge discovered during testing. Each entry: symptom, reproduction, root cause (or hypothesis), workaround, proposed fix.

---

## Bug #1: `/click` on `RadioButtonSpec` writes literal `true` instead of `spec.select`

**Discovered:** session 2026-06-19 PM, while testing Party Search via the bridge.

### Symptom
Calling `POST /click` on a radio-button aspect (e.g. `searchCriteriaTypeIDID`) appears to "succeed" but **corrupts** the underlying shared ValueHolder. After the click, the shared model has the boolean `true` instead of the radio's selection symbol (e.g. `#id`).

### Reproduction
With a Party Search window open and `searchCriteriaType` initially `#contractNumber`:

```powershell
$body = '{"aspect":"searchCriteriaTypeIDID","windowTitle":"Party Search"}'
Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h `
  -Body $body -ContentType 'application/json'
# Returns: {"ok":true,"aspect":"searchCriteriaTypeIDID","method":"model_value_true","oldValue":"#contractNumber"}
```

Verify via `/eval`:
```smalltalk
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
'searchCriteriaType=', (model instVarNamed: 'searchCriteriaType') value printString
"-> 'searchCriteriaType=true'  ← should be #id"
```

### Root cause
The bridge's `doClick:` treats every widget the same way: set `widget.model.value := true`. For `ActionButtonSpec` (e.g. Save buttons) that fires the action correctly. For `CheckBoxSpec`, also correct. For `RadioButtonSpec`, **wrong** — the radio's actual selection value lives in `spec.select`, and a click should set `model.value := spec.select`.

For PartySearchView all seven `searchCriteriaType*` radios share `model = #searchCriteriaType` (the shared `searchCriteriaType` ValueHolder). Setting that holder to `true` corrupts the shared state for every other radio.

### Workaround
Don't `/click` radio buttons. Use `/eval` to set the underlying ValueHolder directly:

```smalltalk
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
(model instVarNamed: 'searchCriteriaType') value: #id.
```

To discover the right symbol for any radio, probe its `spec.select`:
```smalltalk
(model builder namedComponents at: #searchCriteriaTypeIDID) spec select   "-> #id"
```

### Proposed fix (Phase B+1)
In `doClick:`, special-case `RadioButtonSpec`:
```smalltalk
spec class == RadioButtonSpec
  ifTrue: [widget model value: spec select]
  ifFalse: [widget model value: true]
```

Then callers can `/click` any radio cleanly and the shared ValueHolder gets the correct symbol.

### Status: FIXED in v0.8.7 (2026-06-19 session-3)

`VWBridge>>doClick:` now probes `w spec` and branches on `isKindOf: RadioButtonSpec`:

```smalltalk
spec := [w spec] on: err do: [:ex | nil].
radioCls := self globalNamed: #RadioButtonSpec.
(spec ~~ nil and: [radioCls ~~ nil and: [spec isKindOf: radioCls]])
  ifTrue:  [clickValue := [spec select] on: err do: [:ex | true].
            method := 'model_value_spec_select']
  ifFalse: [clickValue := true.
            method := 'model_value_true'].
```

Response shape extended (backwards-compatible — fields ADDED, none removed):
- `method`: now either `model_value_true` (non-radio, unchanged) or `model_value_spec_select` (radio, new)
- `newValue`: the value actually written to `model value:` (new field, helps debugging)

Verified live in storedev64 v0.8.7 across all 7 PartySearchView search-criteria radios — each click sets `searchCriteriaType` to the correct Symbol (`#id`, `#surname`, `#groupScheme`, `#mmiPartyReferenceNumber`, `#cdiNumber`, `#imcNr`, `#contractNumber`). Backwards-compat confirmed: `/click findID` (ActionButtonSpec) still uses `model_value_true` and fires the action normally.

Bonus implication: the `searchCriteriaType` value verified ON ROUND-TRIP (`/eval` probe of the model immediately after the `/click` returns) shows the bridge's `/click` is now SAFE to use for radios in any other MAS view with similarly shared ValueHolders. The Bug #1 workaround in `vw-party-search.md` is no longer required for the Bug-#1-affected aspect of radio dispatch in v0.8.7+ — though `/eval` set is still preferred when you want to skip the action-handler side-effects entirely.

---

## Bug #2: `Dialog confirm:` dismissal via `closeAndUnschedule` doesn't propagate properly (PARTIALLY MITIGATED in v0.8.11)

**Discovered:** session 2026-06-19 PM, while testing Party Search end-to-end.

### Symptom A (UI-driven path)
A `/click` on an action button that opens `Dialog confirm:` "completes" (the bridge dismisses the modal via `closeAndUnschedule` with `recordedAccept=true`) **but the action handler's `ifTrue:` branch does not fire**. The handler exits silently — no second modal, no exception, no state change.

PartySearchView's `partialFind:` for `#contractNumber`:
```smalltalk
[(Dialog confirm: 'This search can take a while.  Continue?')
 ifTrue: [
   number := aSearchString copyReplaceAll: 'p' with: 'P'.
   searchResult := ContractManager default contractNumbersContaining: number]
 ifFalse: [^Dialog warn: 'Search cancelled']]
```

After bridge-driven Yes:
- `searchResult` remains `nil` (ifTrue branch never fired)
- `partialMatchResultsChoices` stays empty
- No "Search cancelled" warn modal (ifFalse never fired either)
- No `UnhandledException` raised

`Dialog confirm:` returned something that is neither `true` nor `false` — both branches silently skipped.

### Symptom B (serve-process path)
`Dialog confirm:` called directly via `/eval` from the bridge's serve-process **never returns** after `closeAndUnschedule`. The HTTP request hangs indefinitely. The Smalltalk process is wedged inside the modal's nested event loop even though the modal is gone from `scheduledControllers`.

### Reproduction (Symptom B, serve-process)
```powershell
$tok = "<your token>"; $h = @{"Authorization" = "Bearer $tok"}
$job = Start-Job -ScriptBlock {
  param($t); $h = @{"Authorization" = "Bearer $t"}
  Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST -Headers $h `
    -Body "Dialog confirm: 'test'" -ContentType 'text/plain' -TimeoutSec 60
} -ArgumentList $tok

Start-Sleep -Seconds 2
# Modal is up - dismiss with Yes
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs/respond -Method POST -Headers $h `
  -Body '{"choice":"Yes"}' -ContentType 'application/json'
# Returns: {ok=true, choice=Yes, method=closeAndUnschedule, recordedAccept=True}

Wait-Job -Job $job -Timeout 30  # still "Running" after 30s
```

### Reproduction (Symptom A, UI-driven)
With `searchCriteriaType=#contractNumber`, `searchCriteriaString='PP0'`, `exactMatch=false`:

```powershell
$body = '{"aspect":"findID","windowTitle":"Party Search"}'
Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h `
  -Body $body -ContentType 'application/json' -TimeoutSec 3

# Modal up: "This search can take a while.  Continue?"
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs/respond -Method POST -Headers $h `
  -Body '{"choice":"Yes"}' -ContentType 'application/json'
# Wait 24s polling -> partialMatchResultsChoices stays empty

# But direct query confirms the data IS there:
# ContractManager default contractNumbersContaining: 'PP0'  -> IdentitySet (19 items)
```

### Root cause (hypothesis)
The bridge's `closeAndUnschedule` removes the controller from `scheduledControllers` and triggers an OS-level window-close. That OS event reaches VW's event queue.

For the UI-process caller: the UI thread's modal loop wakes (it was watching for events on its display); `Dialog confirm:` returns _something_ but **not `true`** — probably `nil` (since the loop exited via OS close rather than a button click). Both `ifTrue:` and `ifFalse:` branches are skipped, the action handler silently falls through.

For the serve-process caller: the OS close event doesn't reach the serve-process at all (it is not the display owner). The serve-process's `Dialog confirm:` wait loop never wakes.

The existing `vw-dialogs.md` statement "`closeAndUnschedule` is the only path that reliably wakes the wedged loop" is true for **dismissing the modal visually** and **freeing the scheduledController slot**, but is **NOT true for waking the caller-process with a sensible return value** in all cases.

### Workaround (UI-driven searches)
Bypass the action handler entirely. Run the underlying query directly via `/eval` and populate the result state manually:

```smalltalk
| ctrl model results sorted |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
results := ContractManager default contractNumbersContaining: 'PP0'.
sorted := results asSortedCollection.
model partialMatchResultsChoices value: sorted.
sorted notEmpty ifTrue: [model partialMatchResults value: sorted first].
```

See [`vw-party-search.md`](./vw-party-search.md) for the full PartySearchView bypass recipe.

### Workaround (serve-process callers)
**Don't call `Dialog confirm:` / `Dialog request:` / `Dialog warn:` from `/eval`.** Direct introspection only (no UI-blocking calls). If you need to test dialog behavior, trigger it via `/click` on a button that opens the dialog from the UI process — even though Symptom A applies there.

### Proposed fix (Phase B+1 or Phase C)
Two stages:

**Stage 1: confirm the return value.** Instrument `SimpleDialog>>openInterface` (or wrap `Dialog confirm:` in a debug build) to log what gets returned when `closeAndUnschedule` exits the modal. Until we know, the fix is shooting in the dark.

**Stage 2 (likely): simulate the YesButton click instead of using `closeAndUnschedule`.** The YesButton's action handler properly sets `accept`, then triggers `close`, then unschedules — that is the path the action handler is waiting for. Sketch:

```smalltalk
target model accept value: true.
target view subViews
    detect: [:v | (v isKindOf: ActionButton) and: [v label asString = 'Yes']]
    ifFound: [:btn | btn controller doClick]
    ifNone: [target closeAndUnschedule]   "fallback"
```

If button-simulation doesn't wake the loop either, fall back to `accept value: true; close value: true` and accept the latency until the UI process yields naturally.

**Stage 3: guard the serve-process path.** `/eval` should reject (or warn loudly about) bodies containing `Dialog confirm:` / `Dialog request:` / `Dialog warn:`. These hang the serve-process.

### Scope (calibrated 2026-06-19 session-2)

Bug #2 is **NOT universal across broad-search types.** Decompiling `PartySearchView>>partialFind:` shows only TWO cases use `Dialog confirm:`:

| `searchCriteriaType` | Uses `Dialog confirm:`? | Bug #2 applies? |
|---|---|---|
| `#contractNumber` | yes | YES |
| `#surname` | yes | YES |
| `#id` | no (validates `size < 10` first, no modal) | NO — bridge-drivable end-to-end |
| `#imcNr` | no (side-effect: switches type to `#id`) | NO |
| `#groupScheme` | no | NO |
| `#mmiPartyReferenceNumber` | n/a — always warns "Please use exact match search" | n/a |
| `#cdiNumber` | n/a — always warns "Please use exact match search" | n/a |

**Verified 2026-06-19 session-2:**

- **`#contractNumber`**: confirmed prior session.
- **`#surname`**: `searchCriteriaString='Momentum'`, `exactMatch=false`, `/click findID`. Modal pops 5-8 s after `/click` (slower than `#contractNumber`'s ~1 s — likely `self abort` + `Switch>>case:` overhead on first hit). `/dialogs/respond Yes` returns `recordedAccept:true`. After 8 s wait: `pmrcSize=0`, `pmr=''` — both `ifTrue:` AND `ifFalse:` branches silently skipped. NO Portfolio opens. Identical symptom to `#contractNumber`.
- **`exactFind:`** (any type): NOT affected. `exactFindOnContractNumber:` and siblings do not use `Dialog confirm:`. Proven by driving `'PP020000019'` end-to-end through the bridge → Portfolio opens with `contract=InvestmentContract`, `contractDetails=ContractDetailsView`, `domainChannel value='Branch:Momentum Head Office'`. See [`vw-party-search.md`](./vw-party-search.md) "exactFind: via bridge".

**Practical implication:** the Bug #2 workaround in [`vw-party-search.md`](./vw-party-search.md) ("Running a broad search") is REQUIRED for `#contractNumber` and `#surname`. For `#id`/`#imcNr`/`#groupScheme`, `/click findID` should round-trip cleanly via partialFind: — but those three no-modal types remain UNVERIFIED end-to-end via the bridge. Worth confirming in a follow-up session.

### Session-5 investigation findings (2026-06-20)

**Status: NOT FIXED, but diagnosis sharpened with concrete runtime evidence.**

Session-5 reproduced Symptom A end-to-end on v0.8.10 and uncovered evidence the session-3 writeup missed.

#### Phase A — what `Dialog confirm:` actually returns

Stage 1 of the proposed fix was "instrument Dialog confirm: to see what it returns after closeAndUnschedule." Sources are stripped in this image (`getSource` returns nil for all methods), so direct method instrumentation isn't available. Instead, session-5 forked a process that calls `Dialog confirm:` and captures the return into a `Root.Smalltalk` global:

```smalltalk
| proc |
Root.Smalltalk at: #BUG2_RESULT put: 'pending'.
proc := [
    | ret info |
    ret := Dialog confirm: 'BUG2 Stage 1: ...'.
    info := Core.Dictionary new.
    info at: 'isTrue' put: ret == true.
    info at: 'class' put: ret class name asString.
    info at: 'printString' put: ret printString.
    Root.Smalltalk at: #BUG2_RESULT put: info
] forkAt: Processor userSchedulingPriority.
```

**Standalone result (first call, fresh image state):** `BUG2_RESULT = {class: 'True', printString: 'true', isTrue: true, isNil: false}`. `Dialog confirm:` returned `true` cleanly after `accept value: true` + `closeAndUnschedule`. This contradicts the session-3 "returns nil" hypothesis for the standalone case.

#### Phase B — partialFind: context differs

Reproducing Symptom A exactly per session-3 (preconditions set, `findID` triggered via fork, dismiss via `/dialogs/respond Yes`):

| Step | Result |
|---|---|
| Fork `findBtn widget model value: true` | Confirm modal opens: "This search can take a while. Continue?" ✓ |
| `/dialogs/respond Yes` (current accept+closeAndUnschedule path) | `recordedAccept=true`, modal closes ✓ |
| Wait 23 s | `partialMatchResultsChoices.value` size=0, `partialMatchResults.value`=nil |
| **`/windows` poll** | **NEW WINDOW APPEARED**: `appClass=GbxDebuggerClient`, `title='Unhandled exception: NonBoolean receiver--proceed for truth.'` |

The debugger window is the **smoking gun** session-3 missed. The session-3 doc says "No `UnhandledException` raised" — but the exception IS raised, just into a `GbxDebuggerClient` window that the bridge's `/dialogs` enumeration doesn't catch (it filters for `SimpleDialog`-class only). From outside, the action handler appears to silently exit; in reality it's wedged inside the debugger.

#### What this confirms about Dialog confirm:'s return in partialFind: context

`NonBoolean receiver--proceed for truth` is raised when `ifTrue:` (or `ifFalse:`) is sent to a value that is neither `true` nor `false`. The only `ifTrue:` in the relevant partialFind: branch (per the prior session-3 quote) is:

```smalltalk
(Dialog confirm: 'This search can take a while.  Continue?')
 ifTrue: [...] ifFalse: [...]
```

So `Dialog confirm:` in this context **does return a non-boolean** (almost certainly `nil`) — which means the session-3 hypothesis was structurally right; only the "no exception" detail was wrong. The exception fires, the debugger opens (invisible to the bridge), and the action handler stays wedged inside the debugger forever.

#### Why standalone works but partialFind: doesn't

This remains the open question. Session-5 directly invoked `model partialFind: 'PP0'` on a fork (bypassing the ActionButton dispatch entirely) — the modal STILL opened and `Dialog confirm:` STILL returned a non-boolean. So the ActionButton/PluggableAdaptor pipeline is NOT the difference. Something about partialFind:'s own setup (`Cursor wait showWhile:`? `self abort`? some `ensure:` block? a transaction context?) makes Dialog confirm: behave differently from a fresh fork.

Could not investigate further: after multiple confirm dismissals in one image session, **wedge state accumulates** — subsequent standalone `Dialog confirm:` forks ALSO hang (not just the partialFind: ones). The image needs to be restarted between fix attempts to get a clean diagnostic baseline.

#### Probe findings useful for the fix

While the confirm modal was up, structural probing yielded:

- `namedComponents` aspects: `#(#displayMessageString #NoButton #YesButton)` (three widgets, no others)
- **YesButton**: `spec class=ActionButtonSpec`, `spec isDefault=true`, `widget class=ActionButtonView`, `widget.model class=PluggableAdaptor`, `model value=false`
- **NoButton**: `spec class=ActionButtonSpec`, `spec isDefault=false`, identical structure to YesButton otherwise
- **Dialog state mid-modal** (probed BEFORE dismiss): `accept value=false`, `cancel value=false`, **`close value=true`** (already true! the dialog's close ValueHolder is pre-set to true when the modal is live — this contradicts vw-dialogs.md's "ValueHolder on: false. Modal exits when set to true." The actual exit semantic must use a different mechanism than checking `close value`)

#### What did NOT work (failed fix attempts)

- **`widget model value: true` on YesButton** (the PluggableAdaptor setter): modal stays up, action does NOT fire. This works for PartySearchView's `findID` ActionButton (per Bug #1) but does NOT work for SimpleDialog's YesButton. Different action wiring.
- (Could not test further fix attempts because of wedge accumulation in the image.)

#### Probable fix direction (for the next dedicated session)

Given that `close value=true` already and the modal still doesn't exit cleanly via accept-checking, the modal loop must use some OTHER mechanism to decide its return value. Probable candidates to investigate in a clean image:

1. **Simulate the YesButton click via OS event injection**, not via `model value:`. The Bug #1 PluggableAdaptor pattern that works for PartySearchView ActionButtons does NOT work for SimpleDialog YesButton — different action wiring. Need to find the actual click pipeline (maybe `widget controller pressedButton` or `widget controller buttonAction` or a process-input-event-injection path).
2. **Investigate what partialFind: wraps Dialog confirm: in.** Bug #2 ONLY affects the partialFind: + Dialog confirm: combination — standalone confirm works. Something in partialFind: changes the modal's return semantics. Could be a `withWaitCursor:`, a `Cursor wait showWhile:`, an `ensure:` block, or some transaction/exception-handler context. Without source access this is empirical — instrument fresh forks and bisect.
3. **Stage 3 (still valid)**: Guard `/eval` against bodies containing `Dialog confirm:` / `Dialog request:` / `Dialog warn:`. These hang the bridge's serve-process even with Bug #5's v0.8.8 per-process re-entry guard, because the hang is in the UI modal loop, not the dispatcher.

### Session-6 investigation findings + v0.8.11 partial fix (2026-06-20)

**Status: PARTIALLY MITIGATED in v0.8.11. Symptom A (partialMatchResults never populates) PERSISTS but is now RECOVERABLE (no silent wedges, no accumulating debugger windows).**

Session-6 attempted Direction A (simulate YesButton click) first, then pivoted to Direction B (investigate the wrap) when Direction A required OS event construction this image's API doesn't simply expose. Direction B yielded the architectural root cause AND a partial fix that ships in v0.8.11.

#### The wrap is in the dialog framework, not partialFind:

Session-5's Direction B hypothesis was that `partialFind:` wraps `Dialog confirm:` in something that breaks the return. Session-6 disproved that by stack-walking the wedged fork process in BOTH standalone `Dialog confirm:` AND `partialFind:` scenarios. The wrap is IDENTICAL and lives in the dialog framework:

```
ScheduledWindow>>openTransientIn:type:postOpen:
  ApplicationDialogController>>openTransientViews
    Cursor>>showWhile:                            ← THE WRAP
      BlockClosure>>openTransientViews
        BlockClosure>>ensure:
          BlockClosure>>openTransientViews
            ApplicationDialogController>>startUp
              ...
                ApplicationDialogController>>eventLoop
                  WindowManager>>processNextEvent
                    EventQueue>>next
                      Semaphore>>waitIfCurtailedSignal  ← stuck here
```

`Dialog confirm:` itself runs inside `Cursor showWhile:` + nested `ensure:` blocks. This is the FRAMEWORK's wrap, not the caller's. Both standalone confirms and partialFind: confirms wedge IDENTICALLY when dismissed via `closeAndUnschedule`.

#### Session-5's "standalone returns true" was misleading

Session-5 captured `BUG2_RESULT = {class:'True', isTrue:true}` for a standalone `Dialog confirm:` fork — but didn't document the dismissal mechanism. Session-6 confirmed the bridge's `/dialogs/respond Yes` (which does `accept value: true + closeAndUnschedule`) ALSO leaves a standalone fork wedged silently forever (no MustBeBoolean, no debugger, just hung — captured as `B_TEST1_RET = 'nil-returned'` AFTER manual `wm.purgeDeadWindows` unwedged it). Session-5's "true" return must have been from a manual user click — bridge dismissal returns nil for standalone too.

The difference between standalone and partialFind: outcomes is COSMETIC, not structural:
- **Standalone**: fork wedges silently forever; nothing downstream checks the (nil) return; image accumulates wedged procs across calls
- **partialFind:**: fork wedges, then eventually escapes (mechanism unclear — possibly MAS-side timer); `(Dialog confirm:) ifTrue:` raises MustBeBoolean; debugger window opens (invisible to `/dialogs`); MustBeBoolean catchable by `on:do:`

#### Why closeAndUnschedule leaves the fork wedged

`closeAndUnschedule` destroys the OS window but does NOT push a Destroy event into the fork's `WindowManager` `EventQueue`. The fork's modal loop is blocked at `Semaphore>>waitIfCurtailedSignal` waiting for the next event. After closeAndUnschedule:
- Window is gone
- EventQueue has no pending events
- Semaphore stays unsignaled
- Loop never returns from `EventQueue>>next`

Signaling the Semaphore alone doesn't help — the loop wakes, finds no event, re-sleeps on the next semaphore (verified empirically — `sema signal` and 6x signal both ineffective).

#### v0.8.11 fix: `purgeWedgedDialogProcesses`

The bridge's `doRespondDialog:` now calls a new helper after `closeAndUnschedule`:

```smalltalk
purgeWedgedDialogProcesses
    "Find any Process suspended inside ApplicationDialogController>>eventLoop
     and call purgeDeadWindows on its WindowManager. Wakes the wedged modal loop."
    "(see VWBridge.st L1392 for full implementation)"
```

How it works:
1. Walk `Process allInstances` (~200-300 procs in this image, fast filter)
2. Select: top stack contains `ApplicationDialogController` as a receiver
3. For each match: walk the stack to find a `WindowManager` receiver
4. Send `purgeDeadWindows` to that WindowManager
5. Return count of purged-and-unwedged procs (response JSON: `"purgedWedged": N`)

When the WindowManager purges its dead windows, the modal loop notices its `scheduledWindows` is empty and exits. The fork's `Dialog confirm:` returns (with **nil**, NOT the accept value — see "remaining limitation" below) and the fork's stack unwinds normally.

#### NEW SELECTOR DISCOVERIES from session-6 probing

- **`Process allInstances`** — works in this image (returns 247 processes); `Processor allProcesses` does NOT exist (session-3 was right) but `Process allInstances` is a viable substitute for process enumeration
- **`WindowManager`** has `#close`, `#purgeDeadWindows`, `#unscheduleModalWindow:`, `#addEvent:`, `#scheduleModalWindow:`, `#processOutstandingEvents`, `#purgeInvalidWindows`
- **`EventQueue`** has `#nextPut:`, `#nextPutAtFrontOfQueue:`
- **`EventSensor`** has `#eventButtonPress:`, `#eventButtonRelease:`, `#eventBlueButtonPress:`, `#eventBlueButtonRelease:`, `#eventDamage:`, `#eventDestroy:`, `#eventDoubleClick:`, `#anyButtonPressed`, `#addMetaInput:` — full OS event injection API
- **`sdCtrl`** (ApplicationDialogController) has **`#closeDrainEventsAndUnschedule`** — closes WITHOUT MustBeBoolean BUT leaves fork wedged (strictly worse than closeAndUnschedule because no visible failure either); NOT used in v0.8.11
- **`ActionButtonView`** has `#guiSimulateMouseClick` — calls non-existent `#simulateMousePress`; the wrapper exists but the primitive doesn't (stripped or missing pundle); dead end in this image
- **`SimpleDialog`** has methods: `#accept`, `#cancel`, `#close`, `#closeAccept`, `#closeCancel`, `#closeRequest`, `#closeAndUnschedule` — ALL no-ops cross-process (calling from serve process does NOT dismiss; modal loop polls EventQueue, not these ivars)
- **`spec model`** (on ActionButtonSpec for YesButton) IS a `BlockClosure` defined in `SimpleDialog>>addLabels:values:default:storeInto:takeKeyboard:equalize:columns:` — but evaluating it (`spec model value`) returns `self` (the SimpleDialog) with no observable side effect; the BlockClosure is not the actual click action handler
- **`mgr activeControllerProcess`** returns nil during modals (which is why bridge's `onUIDo:` falls back to direct execution for modal work — confirmed by reading L1372 of VWBridge.st)

#### What v0.8.11 fixes

| Scenario | Pre-v0.8.11 | v0.8.11 |
|---|---|---|
| Standalone `Dialog confirm:` + bridge respond Yes | SILENT FOREVER WEDGE (worst — invisible) | Fork unwedges cleanly; Dialog confirm: returns nil |
| `partialFind: + Dialog confirm:` + bridge respond Yes | MustBeBoolean → invisible debugger window (session-5 finding) | Fork unwedges; MustBeBoolean catchable by caller's `on:do:` |
| Image hygiene across multiple respond Yes calls | Wedged procs accumulate, image needs `vwnt.exe` restart | No accumulation; each respond Yes cleans up its wedged proc |
| `/dialogs/respond` JSON response | `{ok:true, method:"closeAndUnschedule", recordedAccept:bool, recordedCancel:bool}` | `{..., method:"closeAndUnschedule+purgeDeadWindows", purgedWedged:N}` |

#### What v0.8.11 does NOT fix (Symptom A remains)

`Dialog confirm:` still returns **nil** when dismissed externally. The dialog framework's force-close return path is hardcoded; setting `accept value: true` before `closeAndUnschedule` does NOT propagate (verified — `accept value` stays true at exit but `Dialog confirm:` returns nil regardless). For partialFind:'s `(Dialog confirm:) ifTrue: [search-code]` pattern this still raises MustBeBoolean and the `search-code` does NOT run.

`partialMatchResults` therefore still stays `nil` after `/dialogs/respond Yes`. The workaround in [`vw-party-search.md`](./vw-party-search.md) — bypass `partialFind:` and call `ContractManager default contractNumbersContaining:` directly — **REMAINS REQUIRED** for `#contractNumber` and `#surname`.

#### Remaining paths for a full Symptom A fix (session-7+)

1. **OS event injection** via `sensor eventButtonPress:` + `sensor eventButtonRelease:` constructing a real `MouseButtonEvent` on YesButton's bounds. The sensor has the API; constructing the right event object requires probing the event class — `MouseButtonEvent`, `ButtonPressedEvent`, `RedButtonPressedEvent`, `InputEvent`, `UIEvent` are NOT in `Root.Smalltalk` globals as of session-6 (probed all 7 candidates). Look in pundles like `UIPainter` or `EventManager`, or `getPerformerIn:` from spec.
2. **MAS-side override**: extend `Dialog class>>confirm:` (or a parallel method) to read `dialog accept value` at force-close instead of returning the framework default. Requires MAS-side commit, not bridge. Lowest-risk if MAS team is willing.
3. **Process surgery**: walk the wedged fork's stack to its modal loop frame, mutate the return value or unwind the stack with a value-carrying exception before resuming. Brittle, image-version-specific, not recommended.

Direction A's original "simulate click" intent is achievable via #1 but is significantly more complex than the handoff anticipated. Session-6's verdict: ship the v0.8.11 partial fix now (real improvement, low risk, no behavior regressions); plan #1 or #2 for session-7+ if Bug #2 full fix is still desired.

---

## Bug #3 (calibration, not a bug): `activeControllerProcess=nil` is NOT a smoking gun

**Discovered:** session 2026-06-19 PM.

### Symptom
`ScheduledControllers activeControllerProcess` returns `nil` even when the VW image is functioning normally. The bridge's `/click`, `/dialogs`, `/dialogs/respond`, `/menu/click`, and `/eval` all work in this state.

### Why this matters
[`vw-input-recovery.md`](./vw-input-recovery.md) historically described `activeControllerProcess=nil` as "the smoking gun" indicating broken input dispatch. Session 2026-06-19 PM proved that's overstated:

- `/click findID` opened a modal ✓
- `/dialogs/respond Yes` dismissed cleanly with `recordedAccept=true` ✓
- All `/eval` introspection worked ✓
- `/menu` enumerated the full MAS menu tree ✓
- The MAS launcher itself remained navigable

ALL of this happened with `activeControllerProcess=nil` throughout.

### When to actually worry
`activeControllerProcess=nil` IS a concern only if combined with:
- Multiple `UnhandledException` instances (>0)
- Hidden `ApplicationWindow` instances with `isOpen=true` and unfamiliar labels
- Zombie domain processes (Party Search, etc.) that don't terminate
- Manual mouse clicks in MAS not registering
- Bridge `/click` / `/menu/click` actually failing (not just appearing to)

In isolation, it is most likely a transient state from modal-event-loop nesting or normal idle. See the recalibrated section in [`vw-input-recovery.md`](./vw-input-recovery.md).

---

## Bug #4: `/dialogs` enumeration misses `ExtendedSimpleDialog` (and other `SimpleDialog` subclasses)

**Discovered:** session 2026-06-19 session-2, while testing `/click helpID` on Party Search.

### Symptom

`/click helpID` (PartySearchView's Help button) opens a modal `Help` window. The `/click` HTTP request wedges (action handler blocked inside the modal). `GET /dialogs` returns `{"dialogs":[], "ok":true}` — **empty**, despite a visible modal blocking the action.

### Reproduction

```powershell
# With Party Search open:
$job = Start-Job -ScriptBlock {
    param($t); $h = @{"Authorization" = "Bearer $t"}
    Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h `
        -Body '{"aspect":"helpID","windowTitle":"Party Search"}' `
        -ContentType 'application/json' -TimeoutSec 15
} -ArgumentList $tok
Start-Sleep 2
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs -Method GET -Headers $h
# -> {"dialogs":[], "ok":true}  ← WRONG, Help modal is up

# Verify modal exists via /windows:
Invoke-RestMethod -Uri http://127.0.0.1:9876/windows -Method GET -Headers $h
# -> includes {title: "Help", appClass: "ExtendedSimpleDialog"}
```

### Root cause (hypothesis)

The bridge's `/dialogs` endpoint filters scheduledControllers via `c model class == SimpleDialog` (exact class equality) instead of `c model isKindOf: SimpleDialog`. The Help dialog's `model class` is `ExtendedSimpleDialog`, which **is** a `SimpleDialog` subclass (`ExtendedSimpleDialog → SimpleDialog → ApplicationModel → Model → Object`), so `isKindOf:` would catch it but `==` does not.

Verified via `/eval`:
```smalltalk
((ScheduledControllers scheduledControllers select: [:c | c model isKindOf: SimpleDialog])
    collect: [:c | c view label asString, ' [', c model class name asString, ']']) asArray
"-> #('Help [ExtendedSimpleDialog]')"
```

### Workaround

When `/click` wedges and `/dialogs` returns empty, probe directly via `/eval`:

```smalltalk
((ScheduledControllers scheduledControllers select: [:c | c model isKindOf: SimpleDialog])
    collect: [:c | c view label asString, ' [', c model class name asString, ']']) asArray
```

To dismiss the dialog, use `closeAndUnschedule` on the controller — same mechanism as `SimpleDialog`:

```smalltalk
| ctrl |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Help'] on: Error do: [:e | false]] ifNone: [nil].
ctrl closeAndUnschedule
```

Confirmed in session 2026-06-19 session-2: `closeAndUnschedule` on the `ExtendedSimpleDialog` works the same as on `SimpleDialog`, and the wedged `/click` HTTP request returns once the modal closes.

### Proposed fix (Phase B+1)

Change the filter in the `/dialogs` endpoint handler (and any sibling code, e.g. `/dialogs/respond` lookup paths) from class equality to `isKindOf:`:

```smalltalk
"old"
ScheduledControllers scheduledControllers select: [:c | c model class == SimpleDialog]

"new"
ScheduledControllers scheduledControllers select: [:c | c model isKindOf: SimpleDialog]
```

Sweep the bridge source for any other `class == SimpleDialog` checks and convert them all to `isKindOf:` to keep enumeration and response paths consistent.

### Known additional buttons affected

So far observed:

| Button | Surface | Dialog class | Bug #4 visible? |
|---|---|---|---|
| `helpID` (Party Search) | `/click helpID` | `ExtendedSimpleDialog` (label `Help`) | yes |

Other MAS buttons that open `ExtendedSimpleDialog`-class modals are likely affected the same way. Worth a sweep when fixing.

### Status: FIXED in v0.8.6 (2026-06-19 session-3)

Both `class == sdClass` sites in `VWBridge.st` swapped to `isKindOf: sdClass`:

- `doListDialogs` (the `GET /dialogs` enumeration)
- `doRespondDialog:` (the `POST /dialogs/respond` controller lookup)

Version bumped `0.8.5` → `0.8.6`. Verified live in storedev64 by reloading the bridge via `/eval` (`'...VWBridge.st' asFilename fileIn`) and re-running the helpID reproduction:

- `/click helpID` opens Help (`ExtendedSimpleDialog`)
- `/dialogs` returns the Help dialog (was empty before fix)
- `/dialogs/respond` dispatches `closeAndUnschedule` and the wedged `/click` returns

Probe confirmed across-the-board:
```
isKindOf: SimpleDialog -> 1 (catches Help ExtendedSimpleDialog)
class == SimpleDialog  -> 0 (old broken behavior)
```

### Bug #4b (sub-finding, lower priority): `describeDialog:` returns null message + empty buttons for `ExtendedSimpleDialog`

After the Bug #4 fix, `/dialogs` enumerates `ExtendedSimpleDialog` instances correctly, but `describeDialog:` returns a partial structure for them:

```json
{"class":"ExtendedSimpleDialog","message":null,"id":"992572","buttons":[]}
```

vs. the rich `{message, buttons:[...]}` shape it produces for a plain `SimpleDialog`.

**Impact:** callers can detect that a dialog is up (now also see WHICH subclass via the `class` field added in v0.8.9) and they can dismiss it via `closeAndUnschedule` (which doesn't need button knowledge), but they can't make an informed Yes/No/OK choice based on the dialog's button labels. For Help-style modals this is fine (single Close path); for any subclassed confirm-style modal it would matter.

### Investigation (2026-06-20 session-4)

Live probe of an `ExtendedSimpleDialog` (Help modal from PartySearchView):

| Probe | Result |
|---|---|
| `ExtendedSimpleDialog instVarNames` | `#()` (the prior doc speculation about extra inst vars was wrong) |
| Superchain | `ExtendedSimpleDialog -> SimpleDialog -> ApplicationModel -> Model -> Object` |
| Override methods (9) | `builder initialize preBuildWith: allButOpenFrom: openFor:interface:at: noticeOfWindowClose: requestForWindowClose simulateEscapeKey windowLabelPrefix` |
| Live Help dialog's `builder namedComponents` | **EMPTY (`#()`)** |
| Source's builder (`builder source builder`) | **Same object as `dialog builder`** (`srcBuilderSameAsDialog: true`) — also empty |
| Source class | `QueriesHelpView` (an ApplicationModel) |
| Source inst vars | `dependents builder uiSession eventHandlers tabbedWindowId parentApplication readOnly dialogSubSpecSymbol domainChannel domainIsChanging` — no direct widget references |

**Real cause:** `namedComponents` is **completely empty** for `ExtendedSimpleDialog`. The dialog's widgets (the message text and the Close button visible in the UI) are NOT registered as named aspects on the builder. They must live somewhere else:

- Built dynamically into the View tree (subviews of the dialog window) without ever being registered via `name:` on the builder
- OR addressed via a `dialogSubSpecSymbol`-based windowSpec resolved at dynamic-build time (the source's `dialogSubSpecSymbol` instVar hints at this)
- OR held as inst vars on the source object's superclass chain (not the immediate inst vars probed)

The doc's prior diagnosis ("ExtendedSimpleDialog's instVarNames include close accept cancel ..." and "its own builder layout") was speculation. The actual situation requires walking the View tree or resolving the sub-spec — neither of which is a quick polish fix.

### Status: PARTIALLY FIXED in v0.8.9 (2026-06-20 session-4)

Two improvements landed in [`VWBridge.st`](../src/vw-bridge/VWBridge.st):

1. **New `class` field on `describeDialog:` response.** Callers can now see `"class":"ExtendedSimpleDialog"` (or whichever of the 47 SimpleDialog subclasses they're dealing with) without round-tripping `/eval`. Backwards-compat (field ADDED only).

2. **`describeDialog:` refactored into orchestrator + 2 helpers** (`extractDialogMessageFrom:`, `extractDialogButtonsFrom:`). The new helpers try multiple message aspect names (`#displayMessageString`, `#message`, `#text`, `#displayText`, `#labelString`, `#messageText`) and iterate ALL widgets matching `*Button*` spec class substring. Defense-in-depth that benefits any future SimpleDialog subclass that DOES register aspects — but does NOT help `ExtendedSimpleDialog` specifically, because that dialog's `namedComponents` is empty regardless of which aspect names we probe.

**What still doesn't work:** for `ExtendedSimpleDialog` (and presumably some of the other 45+ SimpleDialog subclasses with similar dynamic-build patterns), `describeDialog:` still returns `message: null, buttons: []`. The new `class` field is the only useful new info for this dialog class.

### Proposed fix (deferred, requires deeper investigation)

Probable path forward: walk the View tree of `aDialog window` looking for `ActionButton`-class widgets and `Label`-class widgets, collecting their displayed text. This bypasses the builder/namedComponents abstraction entirely and reads the rendered widget tree directly. Requires probing the correct view-child selectors for this VW image (`subViews` doesn't exist here — `components`, `subComponents`, `subwidgets`, `children`, `submorphs`, `childrenComponents` were all tried in session-4 and none matched). May need to dig into `View` / `ScheduledWindow` class hierarchy or use `View allSubInstances`-style reflection.

Estimated effort: 1-2 hours of focused VW view-tree archaeology. Not done in session-4 because Bug #4b was framed as "polish ~30min" and the rabbit hole exceeded that budget. Genuine full fix should probably be its own session.

### Status: FIXED in v0.8.10 (2026-06-20 session-5)

Three-tier extraction in [`describeDialog:`](../src/vw-bridge/VWBridge.st) with a NEW view-tree walk helper `extractDialogFromView:`. Latent `indexOf:startingAt:` MNU in `extractLabelText:` also repaired (this VW image does NOT implement that selector on String — the menu walking path never triggered it because menu items have plain String labels, but the new view-tree walk hits LabelWithAccessor wrappers which DO trigger printString quote-parsing).

#### Key findings overturning session-4's "no selector matched" claim

Session-4 said `children` was tried and didn't match. **It does match — universally** — but the prior probes applied it to the wrong receiver (likely the `SimpleDialog` instance itself or the `UIBuilder`, neither of which understands `children`). Probe-confirmed in session-5 via `canUnderstand:` on the runtime view classes:

| Class | Super | `children`? | Used as |
|---|---|---|---|
| `View` | `DependentPart` | ✓ | base UI element |
| `Wrapper` | `VisualPart` | ✓ | single-child container (`component` instVar) |
| `CompositeView` | `DependentComposite` | ✓ | multi-child container (`components` instVar) |
| `VisualPart` | `VisualComponent` | ✓ | abstract view base |
| `ScheduledWindow` | `Window` | also has `component` | top-level window |
| `SimpleDialog` | `ApplicationModel` | ✗ | use `mainWindow component` to enter view tree |
| `UIBuilder` | `Object` | ✗ | use `window` (instVar) for top-level |

The correct walk path is `aDialog mainWindow component children` (recursive), NOT anything sent to the SimpleDialog instance directly.

#### Live tree shape for SimpleDialog (`Dialog warn:` probe target)

```
0> CompositePart            (root, from mainWindow component)
1>  SpecWrapper
2>   LayoutWrapper
3>    PassiveLabel    label=a ComposedText      ← THE MESSAGE
1>  SpecWrapper
2>   BoundedWrapper
3>    WidgetStateWrapper
4>     CompositePart
5>      SpecWrapper
6>       BoundedWrapper
7>        ActionButtonView  label=LabelWithAccessor for 'OK'   ← THE BUTTON
```

Depth-7 leaves on a vanilla `Dialog warn:`. The walker is depth-capped at 12 for comfortable headroom.

#### Widget-label unwrapping (probe-confirmed table)

| Widget class | `label` returns | `asString` | `string` | `printString` | `extractLabelText:` returns |
|---|---|---|---|---|---|
| `PassiveLabel` | `ComposedText` | raw text ✓ | raw text ✓ | `'a ComposedText'` ✗ | raw text (via `#string` fallback) |
| `ActionButtonView` | `LabelWithAccessor` | `"LabelWithAccessor for ''OK''"` ✗ | MNU ✗ | same as asString | `'OK'` (via printString quote-parse) |
| (plain String label) | String | — | — | — | self (via `isString` early return) |

The fallback chain in `extractLabelText:` was reordered in v0.8.10 to put `#string` BEFORE `#displayString` — `displayString` on `ComposedText` returns the class-name placeholder `'a ComposedText'`, while `#string` returns the raw text. The old ordering would have skipped past the correct accessor.

#### Tier 2 algorithm

DFS via `children`, classifying leaves by class-name substring:

- `*Button*` → button widget (matches `ActionButtonView`, `PluggableActionButtonView`, future `*Button*View` variants)
- `*Label*` (and NOT also `*Button*`) → label widget (matches `PassiveLabel`, `ActiveLabel`)
- First non-empty label in DFS order → message; all buttons collected in DFS order

Stack-based iteration with `reverseDo:` push so children pop in original order (true DFS). Tier 2 only fires when Tier 1 returned `msg=nil AND btnLabels empty` — conservative condition that won't overwrite partial Tier 1 results.

#### Latent bug fix (`extractLabelText:`)

`txt indexOf: qch startingAt: p1 + 1` was the existing call at line 732. **This VW image does not implement `String>>indexOf:startingAt:`** (probe-confirmed; the index-related selectors that DO exist are `indexOf:`, `indexOf:ifAbsent:`, `indexOfSubCollection:startingAt:`, and `nextIndexOf:from:to:`). The bug never surfaced because menu items in this image always have plain String labels (handled by the `isString` early return) so the printString quote-parse path was never entered in production. The new view-tree walk DOES exercise that path for `ActionButtonView` labels (`LabelWithAccessor` wrappers), so the latent bug had to be repaired before Tier 2 could function. v0.8.10 uses `nextIndexOf: qch from: p1 + 1 to: txt size` with a defensive `on: Core.Error` wrap.

#### Verification (2026-06-20 session-5)

| Probe | Expected | Result |
|---|---|---|
| `/health` post-reload | `version:0.8.10` | ✓ `{"status":"ok","version":"0.8.10"}` |
| Regression: fork `Dialog warn:`, `/dialogs` | `SimpleDialog` Tier 1 unchanged | ✓ `{class:SimpleDialog, message:"BUG4B PROBE - leave me up briefly", buttons:["OK"]}` |
| **NEW**: fork PartySearchView, fork `helpID` click, `/dialogs` | `ExtendedSimpleDialog` Tier 2 populated | ✓ `{class:ExtendedSimpleDialog, message:"1. Select the search type eg: Name.", buttons:["Close"]}` |
| Tier 2 simulation on warn dialog (algorithm validation before code edit) | Same as Tier 1 output | ✓ `#('BUG4B PROBE - leave me up briefly' #('OK'))` |
| Dismiss Help via `/dialogs/respond OK` | `closeAndUnschedule` succeeds | ✓ `{ok:true, method:closeAndUnschedule}` |
| Post-cleanup `/windows` | back to 5-window baseline | ✓ |

Both message and button extraction now work for `ExtendedSimpleDialog`. Tier 1 unchanged for `SimpleDialog` (no regression risk). The same approach should work for the remaining 45+ SimpleDialog subclasses in this image — Tier 2 only fires when Tier 1 fails, so even if a future subclass needs different handling, the bridge gracefully falls back to view-tree walking.

#### Files changed

- [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) — `extractLabelText:` (latent MNU fix + reordered fallback chain), `describeDialog:` (Tier 2 dispatch), NEW `extractDialogFromView:` method, 4 version sites bumped 0.8.9→0.8.10
- [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) — `testHealthReturnsCurrentVersion` assertion bumped 0.8.9→0.8.10

---

## Bug #5: Recursive `bridge dispatch:` from inside `/eval` wedges the listener (HARD)

**Discovered:** session 2026-06-19 session-3, while trying to run the new `VWBridgeTest` SUnit suite via `/eval`.

**Severity:** HIGH. The bridge's TCP listener went fully unresponsive (port 9876 actively refused new connections); the image's UI dispatch also degraded to the point where manual clicks stopped registering, requiring a full image restart to recover.

### Symptom

`POST /eval` with a body that calls `bridge dispatch: ... headers: ... body: ...` synchronously on `VWBridge singleton` — even a trivial `dispatch: 'GET /health HTTP/1.1' headers: (Dictionary new) body: ''` — hangs (HTTP request times out). On a second or third call, the listener no longer accepts TCP connections at all (`Unable to connect` / `target machine actively refused it`).

Triggers observed in this session:

```smalltalk
"trivial probe - timed out, then listener died"
(VWBridge singleton dispatch: 'GET /health HTTP/1.1' headers: (Dictionary new) body: '') copyFrom: 1 to: 80

"full SUnit suite - same outcome"
VWBridgeTest suite run

"single SUnit test - same outcome"
((VWBridgeTest selector: #testHealthReturnsStatusOK) run) printString
```

After the wedge, even external HTTP probes (`curl http://127.0.0.1:9876/health` from PowerShell) return "Unable to connect". `Test-NetConnection 127.0.0.1 -Port 9876` confirms the port is no longer bound or the accept loop has died.

### Root cause (hypothesis)

`/eval` runs Smalltalk on the bridge's **serve process** — one of the per-connection forks spawned by the v0.8.2 non-blocking listener. When the evaluated Smalltalk synchronously calls `VWBridge singleton dispatch: ... headers: ... body: ...` AGAIN on the same singleton, it re-enters the dispatcher on the same process. Suspected mechanisms:

1. **Shared mutable state on the singleton** (e.g. a per-request buffer, in-flight response stream, or a `currentRequest` slot) gets clobbered by the re-entrant call.
2. **Per-connection fork bookkeeping** in the listener loop assumes one logical "dispatch" per forked process; nested dispatch confuses the lifecycle (e.g. the inner dispatch's response cleanup closes the outer dispatch's socket).
3. **GUI message-pump cross-talk**: nested calls to `onUIDo:` (which uses `interruptWith:` on the UI process) may deadlock when the outer call is itself running on a process that's waiting for a UI interrupt to complete.

The fact that subsequent TCP connects are also refused suggests the issue propagates to the listener's accept loop — either the listener process raised an unhandled exception and terminated, or its socket was closed by the in-flight serve process's cleanup path.

### Reproduction (DO NOT RUN — confirmed image-killing)

```powershell
$tok = (Get-Content .\src\vw-bridge\.token).Trim()
$h = @{"Authorization" = "Bearer $tok"}

# Single recursive call is enough to wedge the listener:
Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST -Headers $h `
    -Body "(VWBridge singleton dispatch: 'GET /health HTTP/1.1' headers: (Dictionary new) body: '') copyFrom: 1 to: 80" `
    -ContentType 'text/plain' -TimeoutSec 10
# Times out.

# Subsequent calls confirm listener is dead:
curl http://127.0.0.1:9876/health
# -> Unable to connect.
```

### Workaround

**Never call `VWBridge singleton dispatch:` from inside `/eval`.** Two safe alternatives for in-image testing:

1. **Call handler methods directly, bypassing `dispatch:`:**
   ```smalltalk
   "instead of dispatching, hit the handler"
   VWBridge singleton handleWindows.   "returns the HTTP response string"
   VWBridge singleton handleDialogsQuery.
   ```
   The dispatcher's sole jobs are auth-checking and routing — both unnecessary in a same-image test where you already have the singleton.

2. **Run SUnit tests from a VW workspace (NOT via `/eval`):**
   ```smalltalk
   "in a VW workspace - prints results to Transcript"
   VWBridgeTest suite run printString
   ```
   This runs the suite on the workspace's foreground process, completely separate from the bridge's serve processes. No re-entrancy.

The current [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) scaffold uses `dispatch:` because it was designed before this bug was known. Once Bug #5 is properly fixed (see below), `dispatch:`-based tests can run via either path; until then, use Workaround #2 OR refactor the tests to call handlers directly.

### Recovery

Once the listener is wedged, you cannot recover via the bridge itself (no `/eval` access). Two paths:

1. **Re-file `VWBridge.st` from a VW workspace** — `VWBridge stop. VWBridge start.` in the auto-start block rebuilds the listener. May work if only the listener is dead but the image is otherwise responsive.
2. **Kill `vwnt.exe` and relaunch the image** — required if the wedge has propagated to UI dispatch (this session: manual clicks stopped working, full restart was needed).

### Proposed fix (Phase B+1, two stages)

**Stage 1: contain the damage.** In the `/eval` handler, reject (or log+warn loudly about) bodies that reference `VWBridge` (or `singleton` / `dispatch:`). Cheap, brittle, but stops the foot-gun. Sketch:

```smalltalk
handleEvalBody: aSource
  (aSource includesSubstring: 'VWBridge') ifTrue: [
    ^self httpResponse: 400 type: 'application/json'
      body: '{"error":"recursive_dispatch_forbidden","hint":"/eval cannot call back into VWBridge - see Bug #5"}'].
  ...
```

**Stage 2: actually understand and fix the re-entrancy.** Instrument `dispatch:headers:body:` with a per-process counter (`Process activeProcess at: #vwbridgeDepth`) and either:

- (a) detect re-entry and bypass auth/routing for the inner call (treat as a same-image call that's already been authorised), OR
- (b) detect re-entry and explicitly fail-fast with a clear error so callers see the foot-gun immediately rather than after the wedge propagates.

Combined with refactoring `VWBridgeTest` to call handler methods directly (workaround #1), this would eliminate the re-entrancy surface entirely.

### Status: FIXED in v0.8.8 (2026-06-20 session-4)

Two-stage fix in [`VWBridge.st`](../src/vw-bridge/VWBridge.st):

**Stage 1 — substring filter in `handleEvalBody:`.** New helper `looksLikeRecursiveDispatch:` rejects bodies containing BOTH `'VWBridge'` AND `'dispatch'` substrings (case-sensitive). Returns `400 recursive_dispatch_forbidden` pre-compilation. Allows the documented workaround #1 (`VWBridge singleton handleWindows` — no `'dispatch'` substring) and any code that touches neither name. Brittle by design — the real defence is Stage 2.

**Stage 2 — per-process re-entry counter in `dispatch:headers:body:`.** Class-side `incrementDispatchDepthFor:` / `decrementDispatchDepthFor:` (mutex-protected IdentityDictionary keyed by `Process`) track per-process dispatch depth. The original method becomes a guard wrapper around the renamed `doDispatch:headers:body:`. On `depth > 1` the guard returns `400 recursive_dispatch` with a `depth` field, balanced by an `ensure:` block on the happy path. Catches re-entry at runtime regardless of how the caller textually obscures the dispatch (constructed selectors, `perform:` with split strings, indirect handles, etc.).

Two class instance variables added: `dispatchDepthByProcess` (IdentityDictionary) + `dispatchDepthMutex` (`Semaphore forMutualExclusion`), both lazy-initialized on first dispatch.

**Verification (storedev64, 2026-06-20 session-4) — six probes, all green:**

| Probe | Result | Time |
|---|---|---|
| `GET /health` (pre-check) | `{"status":"ok","version":"0.8.8"}` | — |
| `GET /windows` (auth) | JSON array of 4 windows (GbxVisualLauncher / MAS / Workspace / VisualLauncher) | — |
| **Stage 1**: literal `VWBridge singleton dispatch: 'GET /health HTTP/1.1' headers: (Dictionary new) body: ''` | **HTTP 400 `recursive_dispatch_forbidden`** + hint pointing to workaround #1 | **3.6 ms** |
| **Stage 2**: constructed `Smalltalk at: ('V' , 'WBridge') asSymbol ... perform: ('disp' , 'atch:headers:body:') asSymbol ...` (evades Stage 1 substring filter) | **HTTP 200 wrapping inner 400 `"depth":2 recursive_dispatch`** | **16.3 ms** |
| Legit `VWBridge singleton token` | HTTP 200 returns token literal | 2.7 ms |
| Post-abuse `GET /health` | `{"status":"ok","version":"0.8.8"}` — **bridge alive** | — |

**Response semantics for Stage 2:** the inner `dispatch:` returns the 400 HTTP response *string* (status line + headers + body). That string becomes the value of the evaluated /eval expression. The outer /eval handler wraps it via `safeJsonFor: printed` into `{"ok":true,"result":"<400 response>"}`. So callers see HTTP 200 with the rejection embedded — Stage 2 caught the foot-gun at runtime and the outer eval reports faithfully. No wedge.

**Bug #5 contained, not fully eliminated.** The bridge no longer wedges on recursive dispatch attempts, but tests that depend on `dispatch:` from inside `/eval` will now FAIL CLEANLY (each request gets 400). Run [`VWBridgeTest`](../src/vw-bridge/VWBridge-Test.st) suite from a VW workspace for green results — the workspace's foreground process is not a per-connection serve process, so depth starts at 0 and the guard is transparent. Alternatively refactor the tests to call handler methods directly (workaround #1).

Recovery scenario is gone: prior to v0.8.8 the wedge required a full `vwnt.exe` restart. In v0.8.8+ the same attack pattern returns 400 in ≤16 ms and the listener stays bound.
