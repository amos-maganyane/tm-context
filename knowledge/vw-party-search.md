# PartySearchView via the bridge

How to drive MAS's PartySearchView end-to-end through the v0.8.5+ bridge. Originally documented around two bridge bugs affecting this surface: [Bug #1 RadioButtonSpec](./vw-bridge-known-issues.md#bug-1-click-on-radiobuttonspec-writes-literal-true-instead-of-specselect) (still active) and [Bug #2 Dialog confirm: return](./vw-bridge-known-issues.md#bug-2-dialog-confirm-dismissal-via-closeandunschedule-doesnt-propagate-properly) (**FIXED in v0.8.12** — the `Dialog confirm:` bypass below is now optional for `#contractNumber` and `#surname`; `/click findID` round-trips cleanly end-to-end).

## Opening the window

Via menu navigation:
```powershell
$body = '{"path":["Party & Contract","Client & Contract search"],"windowTitle":"MOMENTUM"}'
Invoke-RestMethod -Uri http://127.0.0.1:9876/menu/click -Method POST -Headers $h `
  -Body $body -ContentType 'application/json'
```

Response includes `windows.opened` with the new `Party Search` window (`appClass=PartySearchView`).

Multiple clicks open multiple Party Search windows — MAS does not focus-existing for this menu item. Dismiss extras manually if you want a clean baseline.

## Widget surface (26 widgets at top level)

Key aspects (Symbol keys for `model builder namedComponents at:`):

| Aspect | Spec | Purpose |
|---|---|---|
| `searchCriteriaString` | InputFieldSpec | The search term you type |
| `findID` | ActionButtonSpec ("Search") | Triggers `find` → `find:` → `partialFind:` / `exactFind:` |
| `closeRequestID` | ActionButtonSpec ("Close") | Closes the window |
| `helpID` | ActionButtonSpec | Help |
| `exactMatchID` | CheckBoxSpec ("Exact match") | Exact-match vs broad-match toggle |
| `partialMatchResults` | ComboBoxSpec | Currently-selected partial-match result (writable) |
| `searchResultsListID` | SequenceViewSpec | Final selected parties list — usually has `nil` model |
| `partyCanvasId` | SubCanvasSpec | Embedded SubCanvas for selected party details |
| `cb_showPartyDetailsID` | CheckBoxSpec | Toggle party-details view |
| `cb_useNewPortfolioViewID` | CheckBoxSpec | Toggle new portfolio view |
| `searchCriteriaTypecontract numberID` | RadioButtonSpec | "contract number" radio (note: aspect name has spaces) |
| `searchCriteriaTypeIDID` | RadioButtonSpec | "ID" radio |
| `searchCriteriaTypeIMC nrID` | RadioButtonSpec | "IMC nr" radio |
| `searchCriteriaTypesurnameID` | RadioButtonSpec | "surname" radio |
| `searchCriteriaTypegroup schemeID` | RadioButtonSpec | "group scheme" radio |
| `searchCriteriaTypeMMIPartyRef` | RadioButtonSpec | "MMI Party Ref Number" radio |
| `CMSNumberId` | RadioButtonSpec | "CDI Number" radio |

All seven `searchCriteriaType*` radios share the **single** `searchCriteriaType` ValueHolder on the model — clicking one is supposed to set that ValueHolder to the radio's `spec.select` symbol. **The bridge's `/click` does this wrong**, see [Bug #1](./vw-bridge-known-issues.md#bug-1-click-on-radiobuttonspec-writes-literal-true-instead-of-specselect).

## Search-criteria-type symbols

Discovered via `(model builder namedComponents at: #<radio>) spec select` and from the `partialFind:` source:

| Radio label | Symbol |
|---|---|
| contract number | `#contractNumber` |
| ID | `#id` |
| IMC nr | `#imcNr` |
| surname | `#surname` |
| group scheme | `#groupScheme` |
| MMI Party Ref Number | `#mmiPartyReferenceNumber` |
| CDI Number | `#cdiNumber` |

## Model instance variables (19 total)

```
dependents builder uiSession eventHandlers tabbedWindowId parentApplication
readOnly dialogSubSpecSymbol domainChannel domainIsChanging searchCriteriaType
searchCriteriaString exactMatch partialMatchResults partialMatchResultsChoices
searchResultsList partyCanvas showPartyDetails useNewPortfolioView
```

Of these, the ones that matter for driving search:

| InstVar | Purpose |
|---|---|
| `searchCriteriaType` | ValueHolder on a Symbol like `#contractNumber` |
| `searchCriteriaString` | ValueHolder on the search term String |
| `exactMatch` | ValueHolder on Boolean |
| `partialMatchResultsChoices` | **Where broad-match results land** (List of contract numbers / party identifiers) |
| `partialMatchResults` | ValueHolder on the currently-selected partial result, or `'No match found'` |
| `searchResultsList` | SelectionInList for the final results list (often the widget's model is nil — read via this instVar instead) |
| `partyCanvas` | The SubCanvas's loaded PartyTypeView (after a party is "selected" — but stays an empty shell unless action handler runs to completion) |
| `domainChannel` | ValueHolder on the currently-loaded domain party object |

## Workarounds for the bridge bugs

> **Quick reference** (calibrated 2026-06-19 session-2; updated 2026-06-20 session-7 for the Bug #2 v0.8.12 fix):
>
> - **`exactFind:`** (any search type, `exactMatch=true`): bridge-drivable end-to-end. No Bug #2 involvement. See [exactFind: via bridge](#exactfind-via-bridge-verified-2026-06-19-session-2) below.
> - **`partialFind:`** (broad search, `exactMatch=false`): **as of v0.8.12** (`SimpleDialog>>choose:labels:values:default:for:` override in category `mas-bug2-fix`), `/click findID` for `#contractNumber` and `#surname` round-trips correctly — the `'This search can take a while. Continue?'` Yes/No modal is dismissed and `partialMatchResults`/`partialMatchResultsChoices` populate as expected. End-to-end verified 2026-06-20 session-7 for `#contractNumber='PP0'` → canonical 19-contract result set (`PP020000019..`). The bypass recipe below is retained as a fallback / for skipping modal latency in tests / for historical context. `#id`/`#imcNr`/`#groupScheme` skip the modal entirely and should be bridge-drivable via plain `/click findID` (still unverified). `#mmiPartyReferenceNumber`/`#cdiNumber` always warn-redirect to exact match.
> - **Radio buttons** (`searchCriteriaType*`): always set via `/eval` — Bug #1 affects all `RadioButtonSpec`.

### Setting the search type (Bug #1 workaround)

Don't `/click` the radios — it corrupts `searchCriteriaType` to literal `true`. Use `/eval`:

```smalltalk
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
(model instVarNamed: 'searchCriteriaType') value: #contractNumber.
"or #id, #surname, #imcNr, #groupScheme, #mmiPartyReferenceNumber, #cdiNumber"
```

Verify:
```smalltalk
(model instVarNamed: 'searchCriteriaType') value printString
```

### Running a broad search (Bug #2 workaround — OPTIONAL in v0.8.12+)

> **STATUS (2026-06-20 session-7):** Bug #2 Symptom A is **FIXED in v0.8.12** via a 1-method override on `SimpleDialog>>choose:labels:values:default:for:` (the frame-22 thin delegator for `Dialog confirm:`). Bridge-dismissed `Yes`/`No` on a 2-button confirm now returns the correct boolean, and the `partialFind:` action handler runs to completion. **The bypass recipe below is no longer required for `#contractNumber` or `#surname`** — `/click findID` round-trips end-to-end (verified 2026-06-20 session-7 for `#contractNumber='PP0'` → 19-contract result set). Kept here as a fallback (e.g. if the override is ever rolled back, or for tests that prefer to skip modal latency) and for historical context. See [Bug #2 in vw-bridge-known-issues.md](./vw-bridge-known-issues.md#bug-2-dialog-confirm-dismissal-via-closeandunschedule-doesnt-propagate-properly) for the fix architecture, Phase 1 findings, Oracle verdict, and pre-probes.

> **Scope (calibrated 2026-06-19 session-2):** Bug #2 only applies to `#contractNumber` and `#surname` (the two broad-search types that wrap their query in `Dialog confirm:`). For `#id`/`#imcNr`/`#groupScheme`, `partialFind:` does NOT pop a `Dialog confirm:` — bridge `/click findID` should round-trip cleanly (unverified — try it). For `#mmiPartyReferenceNumber`/`#cdiNumber`, `partialFind:` always warn-redirects to exact match.

In v0.8.11 and earlier: `/click findID` (for `#contractNumber` or `#surname`) → opens `'This search can take a while.  Continue?'` confirm modal → bridge dismisses with Yes → action handler **silently fails** to populate results (Bug #2 Symptom A). In v0.8.12+, this round-trip works cleanly — the action handler runs through and `partialMatchResultsChoices` populates.

Bypass: invoke `ContractManager` / `PartyManager` / etc. directly and populate UI state manually:

```smalltalk
| ctrl model results sorted |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
"set state"
(model instVarNamed: 'searchCriteriaType') value: #contractNumber.
(model instVarNamed: 'searchCriteriaString') value: 'PP0'.
(model instVarNamed: 'exactMatch') value: false.
"run query directly"
results := ContractManager default contractNumbersContaining: 'PP0'.
sorted := results asSortedCollection.
"populate UI state to match what the action handler would have done"
model partialMatchResultsChoices value: sorted.
sorted notEmpty ifTrue: [model partialMatchResults value: sorted first].
'populated: ', sorted size printString, ' results'
```

For other search types, dispatch to the right Manager (extracted from `(PartySearchView compiledMethodAt: #partialFind:) asSourceCodeDocument string`):

| Type | Bug #2? | Manager call |
|---|---|---|
| `#contractNumber` | YES — needs bypass | `ContractManager default contractNumbersContaining: <upper'd term>` (upper-case any lowercase `p`) |
| `#id` | NO | `PartyManager default partiesWithPartialIdentificationNumberFromOracle: <term>` — **validates `term size < 10` and warns** |
| `#imcNr` | NO | `PartyManager default identityNumbersWithOasysNumber: <term>` (side-effect: changes type to `#id`) |
| `#mmiPartyReferenceNumber` | n/a | partialFind: always warns "Please use exact match search" — use `exactFind:` instead |
| `#groupScheme` | NO | `GroupSchemeController instance groupSchemeNamesWithString: <term>` |
| `#surname` | YES — needs bypass | `PartyManager default surnamesContaining: <term>` |
| `#cdiNumber` | n/a | partialFind: always warns "Please use exact match search" — use `exactFind:` instead |

After the query, `partialFind:` auto-populates `partialMatchResultsChoices`, then calls `self partialMatchResultsChanged` which **calls `self exactFind: selection`** on the first result — opening a Portfolio. The full UI flow is: query → populate choices → auto-select first → exactFind it → Portfolio opens. The bypass recipe above replicates the first two steps only; if you want Portfolio to auto-open like the real UI does, also send `model partialMatchResultsChanged` after populating (see "Row selection mechanism" below).

Decompile the source for the full action handler:
```smalltalk
(PartySearchView compiledMethodAt: #find) asSourceCodeDocument string
(PartySearchView compiledMethodAt: #find:) asSourceCodeDocument string
(PartySearchView compiledMethodAt: #partialFind:) asSourceCodeDocument string
(PartySearchView compiledMethodAt: #exactFind:) asSourceCodeDocument string
```

## exactFind: via bridge (verified 2026-06-19 session-2)

`exactFind:` is fully bridge-drivable end-to-end with no Bug #2 involvement (no `Dialog confirm:` modal in `exactFindOnContractNumber:`, `exactFindOnSurname:`, etc.).

Working recipe for `#contractNumber`:

```powershell
$tok = (Get-Content -LiteralPath '.\src\vw-bridge\.token').Trim()
$h = @{"Authorization" = "Bearer $tok"}

# 1. set state via /eval (skip Bug #1 radio click for type; safer to set exactMatch via /eval too)
$setup = @"
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
(model instVarNamed: 'searchCriteriaType') value: #contractNumber.
(model instVarNamed: 'exactMatch') value: true.
'set'
"@
Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST -Headers $h `
    -Body $setup -ContentType 'text/plain'

# 2. set search string via /type (canonical bridge input path)
$typeBody = '{"aspect":"searchCriteriaString","value":"PP020000019","windowTitle":"Party Search"}'
Invoke-RestMethod -Uri http://127.0.0.1:9876/type -Method POST -Headers $h `
    -Body $typeBody -ContentType 'application/json'

# 3. /click findID (use Start-Job so a surprise modal can't hang you)
$job = Start-Job -ScriptBlock {
    param($t); $h = @{"Authorization" = "Bearer $t"}
    Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h `
        -Body '{"aspect":"findID","windowTitle":"Party Search"}' `
        -ContentType 'application/json' -TimeoutSec 30
} -ArgumentList $tok
Start-Sleep 2

# 4. /dialogs (expect EMPTY for exactFind:)
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs -Method GET -Headers $h

# 5. /windows — expect a new "Portfolio" [PortfolioView] window after ~5-10 s
Start-Sleep 8
Invoke-RestMethod -Uri http://127.0.0.1:9876/windows -Method GET -Headers $h
```

Outcome verified end-to-end:

- Portfolio window opens (`appClass=PortfolioView`).
- `Portfolio model.contract = InvestmentContract` with `contractNumber='PP020000019'`.
- `Portfolio model.contractDetails = ContractDetailsView`.
- `Portfolio model.domainChannel value = 'Branch:Momentum Head Office'` (PP020000019's owner is an `Organisation` named "Momentum Head Office").
- `searchResultsList` on the Party Search model gets ONE entry (the contract's owner party) via `showContract:`'s `list: (OrderedCollection with: contract owner party)`.

Two transient "Please Wait" `Notice` windows appear during `showContract:` (it wraps the load in `PleaseWaitView openWith:`); both auto-close. A few `Notice` instances may linger in `ApplicationWindow allInstances` (unscheduled, harmless).

**Important side-effect:** after a successful contract show, `exactFindOnContractNumber:` does:

```smalltalk
self searchCriteriaString value: BaseContract initialContractNumber.
```

which resets the search field to `BaseContract initialContractNumber` (in storedev64, that value is `'PP0'`). So after calling exactFind: with a valid contract number, expect `searchCriteriaString` to revert to `'PP0'` afterwards. NOT a bug, it is the action handler returning the form to a "ready for next search" state.

To close the Portfolio when done:

```smalltalk
| ctrl |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Portfolio'] on: Error do: [:e | false]] ifNone: [nil].
ctrl ifNotNil: [ctrl closeAndUnschedule]
```

## Row selection mechanism (verified 2026-06-19 session-2)

`PartySearchView>>partialMatchResultsChanged` (the SequenceView's selection-changed action) is:

```smalltalk
partialMatchResultsChanged
  | selection |
  selection := self partialMatchResults value.
  selection
    ifNotNil: [self exactFind: selection]            "← calls full exactFind: chain!"
    ifNil: [self partialMatchResultsChoices value size = 1
              ifTrue: [self partialMatchResults
                value: self partialMatchResultsChoices value first]]
```

So **selecting a row triggers the entire `exactFind:` chain on the selected value** — which means another Portfolio window opens. That is the production behavior: pick a row in the broad-search results, Portfolio for that party/contract opens.

To simulate a row click via the bridge after populating `partialMatchResultsChoices`:

```smalltalk
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
model partialMatchResults value: 'PP020000019'.   "or any value from partialMatchResultsChoices"
model partialMatchResultsChanged
"-> Portfolio opens for PP020000019"
```

`displayPartialResults` is **only a layout call** — `(self wrapperAt: #partialMatchResults) beVisible. (self wrapperAt: #partialMatchResultsLabel) beVisible`. It does NOT load party data into `partyCanvas`.

Observation: even after `partialMatchResultsChanged` → `exactFind:` → Portfolio opens cleanly, `partyCanvas` (the embedded `PartyTypeView` SubCanvas on Party Search) keeps all 15 of its instVars `nil` (`typeOfClient`, `clientDetails`, `searchClientDetails`, `readOnlyClientDetails`, `viewPartyAs`, etc.). The SubCanvas data-loading path is different — likely tied to `showPartyDetails` (the `cb_showPartyDetailsID` checkbox) or to the Portfolio's own `cmsAndKYCCanvas` loading. Untested.

## Known-good test data (storedev64, 2026-06-19)

`PP0` as a broad `#contractNumber` search returns **19 contracts**:
```
PP020000019  PP020000031  PP020000054  PP020000108  PP020000114
PP020000120  PP020000137  PP020000143  PP020000150  PP020000166
(+ 9 more)
```

Useful as a sanity-check value for new test cycles.

## Result inspection

After populating `partialMatchResultsChoices`:

```smalltalk
| ctrl model pmrc psl |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
model := ctrl model.
pmrc := (model instVarNamed: 'partialMatchResultsChoices') value.
psl := model instVarNamed: 'searchResultsList'.
'pmrc class=', pmrc class name asString,
 ' size=', pmrc size printString,
 ' | selected=', (model instVarNamed: 'partialMatchResults') value printString,
 ' | searchResultsList list size=', psl list size printString
```

The bridge's `/value?aspect=searchResultsListID` returns `[]` even when the underlying instVar has data — because the WIDGET's model is `nil` (action handler never linked it). Read the instVar directly via `/eval` for ground truth.

## Open questions (future work)

- ~~**What does `Dialog confirm:` actually return after `closeAndUnschedule`?**~~ **ANSWERED 2026-06-20 session-7.** The framework hard-codes `nil` for both Yes AND No bridge dismissals via force-close (Q3 of session-7 Phase 1). The v0.8.12 fix synthesizes the correct boolean from `SimpleDialog`'s `accept`/`cancel` ValueHolders in frame 22 of the confirm chain — pre-probe 2 verified the bridge-set ValueHolder values survive the force-close unwind (`accept_after='true'`). See [vw-bridge-known-issues.md Bug #2 session-7 deep-dive](./vw-bridge-known-issues.md#bug-2-dialog-confirm-dismissal-via-closeandunschedule-doesnt-propagate-properly).
- ~~**Row-selection mechanism for SequenceViewSpec.**~~ **ANSWERED 2026-06-19 session-2.** `partialMatchResultsChanged` calls `self exactFind:` on the selection → opens Portfolio. `displayPartialResults` only toggles widget visibility. See "Row selection mechanism" above.
- **`partyCanvas` SubCanvas activation.** Starts as `nil`, becomes `a PartyTypeView` after any `findID` click. Even after a SUCCESSFUL `partialMatchResultsChanged` → `exactFind:` → Portfolio opens cleanly (verified 2026-06-19 session-2), `partyCanvas`'s 15 instVars (`typeOfClient`, `clientDetails`, `searchClientDetails`, `readOnlyClientDetails`, `viewPartyAs`, etc.) all stay `nil`. Activation must be on a different path — likely tied to `showPartyDetails` (the `cb_showPartyDetailsID` checkbox) or to the Portfolio's own `cmsAndKYCCanvas` loading. Untested.
- **Untested `partialFind:` paths via `/click`.** Bug #2 scope calibration shows `#id`, `#imcNr`, `#groupScheme` don't use `Dialog confirm:` and should round-trip via the bridge. Confirm by `/click findID` with a valid term for each type (mind `#id`'s min-10-digit validation).
- **`PartyManager` / `GroupSchemeController` availability** — these are referenced in `partialFind:` but unverified that they're loaded in every session. Probe with `Root.Smalltalk includesKey: #PartyManager` etc. (Note: storedev64 confirmed `ContractManager default` and `ContractManager instance` both resolve; `default` and `instance` may be aliased on the class side.)
- **Buttons that open `ExtendedSimpleDialog` modals.** `helpID` confirmed. Others on PartySearchView untested but worth a sweep — see [Bug #4 in `vw-bridge-known-issues.md`](./vw-bridge-known-issues.md#bug-4-dialogs-enumeration-misses-extendedsimpledialog-and-other-simpledialog-subclasses).
