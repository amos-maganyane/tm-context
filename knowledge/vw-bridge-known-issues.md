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

---

## Bug #2: `Dialog confirm:` dismissal via `closeAndUnschedule` doesn't propagate properly

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
