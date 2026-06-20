# VW Dialog Mechanics

How `Dialog confirm:` actually works in VW 9.3.1 (the storedev64 image), and what the bridge needs to know to interact with modals programmatically.

## The big picture

```
Dialog class >> confirm:
    ↓ delegates to
Dialog class >> confirm:for:
    ↓ delegates to
Dialog class >> confirm:initialAnswer:for:
    ↓ delegates to
Dialog class >> choose:labels:values:default:for:
    ↓ calls
self dialogSupplier choose:labels:values:default:for:
    ↑
    Dialog dialogSupplier returns an instance of SimpleDialog
```

So **every confirmation dialog is ultimately driven by a `SimpleDialog` instance**, NOT by an instance of `Dialog`. Important consequence: `Dialog allInstances` always returns 0 because `Dialog` is a static-method facade with no instance state (its only instVar is `parentVisual`, no instance-side methods at all).

## Native vs Smalltalk dialogs — `Dialog useNativeDialogs:`

| Setting | Where the modal lives | VW can introspect it? | Blocks workspace? |
|---|---|---|---|
| `Dialog useNativeDialogs: true` (DEFAULT) | Win32 native dialog (OS-owned) | NO — invisible to `scheduledControllers`, `SimpleDialog allInstances`, everything | YES (system-modal) |
| `Dialog useNativeDialogs: false` | Smalltalk `SimpleDialog` modal | YES — appears in `scheduledControllers` with widgets in `/windows/tree` | YES (still system-modal in VW 9.3.1) |

**Bridge implication:** if you want to enumerate / dismiss modals programmatically via VW introspection, you MUST set `Dialog useNativeDialogs: false` first. Otherwise the modal is a real Win32 window completely outside VW's reach.

Check current state via `POST /eval`:
```smalltalk
Dialog usesNativeDialogs    "→ true or false"
```

Toggle:
```smalltalk
Dialog useNativeDialogs: false
```

The toggle persists across bridge restarts (it's a class-side setting on `Dialog`), but does NOT persist across VW image restarts.

## SimpleDialog structure (when `useNativeDialogs: false`)

A live modal `SimpleDialog` instance has these key instVars:
- `accept` — `ValueHolder on: false`. Set to true to record "user clicked Yes/OK". **Read by the v0.8.12 `SimpleDialog>>choose:labels:values:default:for:` override to synthesize the boolean return value when the framework's force-close yields nil.**
- `cancel` — `ValueHolder on: false`. Set to true to record "user clicked No/Cancel". Same v0.8.12 override.
- `close` — `ValueHolder on: false`. **Setting `close value: true` does NOT exit the modal loop in this image.** Verified session-5+6: `close value` is observed to be `true` BEFORE dismissal AND the modal stays up regardless. The modal loop is wedged at `ApplicationDialogController>>eventLoop → WindowManager>>processNextEvent → EventQueue>>next → Semaphore>>waitIfCurtailedSignal` and exits only when (a) `closeAndUnschedule` destroys the OS window AND (b) something purges the wedged fork (see v0.8.11 `purgeWedgedDialogProcesses` in [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) Bug #2).
- `builder` — UIBuilder with `namedComponents` dictionary holding the dialog's widgets.

Superclass chain: `SimpleDialog → ApplicationModel → Model → Object`.

The modal runs a **nested event loop** on the UI process. The loop blocks on `EventQueue>>next` which waits on a Semaphore. Setting any of `accept`/`cancel`/`close` ValueHolders from a DIFFERENT process (e.g. the bridge's serve-process via `/eval`) **does NOT wake the loop** — the framework polls events, not ValueHolders. Use `closeAndUnschedule` + `purgeWedgedDialogProcesses` together to dismiss + unwedge.

## Widget aspects (from `/windows/tree` on a live modal)

A confirm-style SimpleDialog modal exposes these aspects in `builder namedComponents`:

| aspect | specClass | label |
|---|---|---|
| `YesButton` | ActionButtonSpec | "Yes" |
| `NoButton` | ActionButtonSpec | "No" |
| `displayMessageString` | LabelSpec | spec.label is a ComposedText (NOT a String!) |

Other dialog types (`Dialog request:`, `Dialog choose:fromList:`, etc.) have different aspect sets.

## Extracting the message text

The `displayMessageString` widget's `spec.label` is a `ComposedText`, not a `String`. Sending `widget model value` errors out. The right extraction:

```smalltalk
(builder namedComponents at: #displayMessageString) spec label asString
"→ 'This search can take a while.  Continue?'"
```

`asString` works on `String`, `Text`, AND `ComposedText` — safe fallback.

## Dismissing a live modal — what works and what doesn't

### Works ✓
```smalltalk
"Find the live modal's ScheduledController and force-close."
| target |
target := ScheduledControllers scheduledControllers detect: [:c |
    [c model class == SimpleDialog] on: Error do: [:ex | false]
] ifNone: [nil].
target ~~ nil ifTrue: [
    "Optional: record outcome via ValueHolders BEFORE closing"
    target model cancel value: true.   "or: target model accept value: true"
    target closeAndUnschedule           "this is the key call - bypasses the wedged loop"
].
```

### Doesn't work reliably ✗
- `model close` — sets `close value: true` but the wedged modal loop doesn't notice until it yields. Foreign-process change notifications fire on the setter's process, not on the wait process.
- `model doCancel` — same problem: sets the ValueHolder but the loop doesn't wake.
- `controller close` (vs `closeAndUnschedule`) — returns ok but the modal stays up.
- `view close` — same.
- `interruptWith:` on `activeControllerProcess` — `activeControllerProcess` returns `nil` while a modal is up, so there's nothing to interrupt.

### Why `closeAndUnschedule` works when others don't
`closeAndUnschedule` removes the controller from `scheduledControllers` and triggers the OS-level window close. The OS close event propagates back into VW's event queue, which the modal's loop processes on its next iteration (and the OS event arrival forces such an iteration). **For the modal to fully unwind**, the OS-destroy event must reach the fork's WindowManager EventQueue — which doesn't always happen automatically. The v0.8.11 fix (`purgeWedgedDialogProcesses`) walks `Process allInstances`, finds any fork stuck in `ApplicationDialogController>>eventLoop`, and sends `purgeDeadWindows` to its WindowManager. That triggers the loop to notice its `scheduledWindows` is empty and exit. The bridge's `/dialogs/respond` does both steps automatically (v0.8.11+).

**Status (2026-06-20 session-7):** Bug #2 is **FIXED in v0.8.12** by a `SimpleDialog>>choose:labels:values:default:for:` override that synthesizes the return value from `accept value` / `cancel value` after the force-close unwinds. Bridge-dismissed `Yes`/`No` confirms now return correct booleans, and partialFind:-style action handlers run to completion. See [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) Bug #2 for the full architecture.

## Cascade modals (CRITICAL)

In MAS, dismissing the first modal often triggers a SECOND modal. Example sequence for the Party Search "find" button:

1. `/click findID` → first modal opens: "This search can take a while. Continue?" (Yes/No)
2. Click **No** → first modal closes → **second modal opens**: "Search cancelled" (OK)
3. Click **OK** → second modal closes → `/click findID` action completes

The bridge's `/dialogs/respond` is a single-shot operation. Callers MUST orchestrate the cascade:

```
POST /dialogs/respond {"choice":"No"}
GET  /dialogs                          # check for next modal
POST /dialogs/respond {"choice":"OK"}  # if there is one
GET  /dialogs                          # confirm empty
```

A test runner should loop: respond → check empty → done; respond → check non-empty → respond again.

## Live vs stale `SimpleDialog allInstances`

After a session of testing, `SimpleDialog allInstances` accumulates stale instances:
- The `Dialog dialogSupplier` singleton (always present, isn't a live modal)
- Old SimpleDialog instances from previous modals that haven't been GC'd

**Filter to LIVE modals only by checking `scheduledControllers`:**
```smalltalk
ScheduledControllers scheduledControllers select: [:c |
    [c model class == SimpleDialog] on: Error do: [:ex | false]
]
```

The bridge's v0.8.5 `doListDialogs` uses this pattern. v0.8.4 incorrectly used `allInstances reject: [:s | s == supplier]` and reported stale instances.

## See also

- [`vw-bridge-testing.md`](./vw-bridge-testing.md) — how to test bridge dialog handling without breaking VW
- [`vw-eval-cookbook.md`](./vw-eval-cookbook.md) — `/eval` snippets for dialog probing
- [`vw-input-recovery.md`](./vw-input-recovery.md) — what to do when dialog testing breaks VW input
- [`../src/vw-bridge/VWBridge-phaseB4.st`](../src/vw-bridge/VWBridge-phaseB4.st) — v0.8.5 implementation of `/dialogs` + `/dialogs/respond`
