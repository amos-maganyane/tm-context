# VW Input Recovery

What to do when VW input locks up — you can't click on the image, windows don't respond, etc.

> **STATUS (2026-06-20 session-10):** The original wedge-accumulation failure mode that motivated this doc is **largely prevented in v0.8.11+** via the bridge's automatic `purgeWedgedDialogProcesses` call from `/dialogs/respond` (see [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) Bug #2 session-6 / v0.8.11 fix). Each dialog dismissal now cleans up its own wedged modal-loop fork. The postmortem in [§ "How we got into this state"](#how-we-got-into-this-state-postmortem-from-session-2026-06-19) describes the pre-v0.8.11 behavior. **You can still wedge the bridge** by:
>   - Running SUnit `suite run` with multiple modal-forking tests in one /eval (session-10 lesson — run /eval-friendly subset only, or use Workspace for the full suite)
>   - Calling `Dialog confirm:` / `Dialog request:` / `Dialog warn:` directly from /eval (the serve-process gets wedged inside the modal wait — `purgeWedgedDialogProcesses` from a DIFFERENT serve-process can recover it)
>   - Stacking modals faster than the bridge processes dismiss requests
>
> When wedged: try Levels 1-3 below. If Level 3 (bridge restart via re-file-in) doesn't recover (image gone), Level 4 (vwnt.exe restart) loses image state.

## Symptoms

- Mouse clicks on VW windows don't register
- VW windows look fine on screen but are unresponsive
- Bridge `/eval` still works (the listener is fine; only the UI is wedged)
- `Dialog usesNativeDialogs` returns false (we toggled it during dialog work)
- No visible Win32 dialog blocking input (verify via Task Manager or PowerShell window enumeration)

## Diagnostic checklist

Run these via `/eval` to characterize the wedge:

### 1. Is `activeControllerProcess` nil?

```smalltalk
ScheduledControllers activeControllerProcess printString
```

If this returns `'nil'`, **input dispatch MAY be broken** — but is not necessarily wedged.

**Calibration (2026-06-19 PM):** Session-end probing proved bridge `/click`, `/dialogs`, `/dialogs/respond`, `/menu/click`, and `/eval` all work with `activeControllerProcess=nil`. The "smoking gun" framing in earlier versions of this doc is overstated.

`activeControllerProcess=nil` is a real concern only when combined with:

- Multiple `UnhandledException` instances (>0) — see step 3
- Hidden `ApplicationWindow` instances with `isOpen=true` and unfamiliar labels — see step 2
- Zombie domain processes that don't terminate — see step 4
- Manual mouse clicks in MAS not registering
- Bridge `/click` / `/menu/click` actually failing (not just appearing to)

In isolation, `activeControllerProcess=nil` is most likely transient state from modal-event-loop nesting or normal idle. See [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) for the full calibration evidence.

### 2. Hidden ApplicationWindow instances?

```smalltalk
| sched extras |
sched := IdentitySet new.
ScheduledControllers scheduledControllers do: [:c | sched add: c view].
extras := ApplicationWindow allInstances reject: [:w | sched includes: w].
extras collect: [:w |
    (w class name asString), ' | label=', ([w label asString] on: Error do: [:ex | '?']),
    ' | isOpen=', ([w isOpen printString] on: Error do: [:ex | '?'])]
```

Look for `'Unhandled exception: ...'` window labels with `isOpen=true` — those are notifier/debugger windows that may have grabbed input but aren't visible.

### 3. UnhandledException instances?

```smalltalk
UnhandledException allInstances size
```

> 0 means there are unresumed exceptions in the image. Each typically has an associated suspended process.

### 4. Zombie domain processes?

```smalltalk
(Process allInstances select: [:p |
    [p name asString = 'Party Search'] on: Error do: [:ex | false]]) size
```

(Substitute 'Party Search' for whatever domain action you were testing.) `> 1` means accumulated wedges from earlier tests.

### 5. Any Win32 dialog hidden at the OS level?

From PowerShell (NOT via /eval — this checks the OS):
```powershell
# Lists all visible top-level Win32 windows. Look for #32770 (dialog class) or unfamiliar titles.
Add-Type @'
using System; using System.Runtime.InteropServices; using System.Text;
public class W32 {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowProc f, IntPtr p);
  public delegate bool EnumWindowProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
'@
$rows = New-Object System.Collections.Generic.List[Object]
[W32]::EnumWindows({param($h, $l)
  if ([W32]::IsWindowVisible($h)) {
    $pid = 0; [void][W32]::GetWindowThreadProcessId($h, [ref]$pid)
    $t = New-Object Text.StringBuilder 256; [void][W32]::GetWindowText($h, $t, 256)
    $c = New-Object Text.StringBuilder 256; [void][W32]::GetClassName($h, $c, 256)
    $rows.Add([PSCustomObject]@{PID=$pid; Class=$c; Title=$t})
  }; return $true
}, [IntPtr]::Zero) | Out-Null
$rows | Where-Object { $_.Class -match 'Dialog|MessageBox|#32770' }
```

If empty, there's no native dialog hidden. The lock is internal to VW.

## Recovery attempts (in order of escalation)

### Level 1 — Terminate zombie processes

```smalltalk
| killed |
killed := 0.
(Process allInstances select: [:p | [p name asString = 'Party Search'] on: Error do: [:ex | false]]) do: [:p |
    [p terminate. killed := killed + 1] on: Error do: [:ex | nil]].
killed
```

Then re-check `activeControllerProcess`. If it comes back, you may be out of the wedge.

⚠️ **Watch for respawning** — if zombie processes come back, something on the bridge side (an old serve-process for `/click`) is recreating them. Restart the bridge (see Level 3).

### Level 2 — Discard unhandled exceptions

```smalltalk
| killed |
killed := 0.
UnhandledException allInstances do: [:ex |
    | p |
    p := [ex incomingProcess] on: Error do: [:e | nil].
    p ~~ nil ifTrue: [
        [p terminate. killed := killed + 1] on: Error do: [:e | nil]]].
killed
```

Note: `incomingProcess` may not exist on all UnhandledException subtypes. The terminate-count may be lower than the instance count.

### Level 3 — Restart the bridge

Re-file all 7 `.st` files in order (see [`vw-bridge-testing.md`](./vw-bridge-testing.md)). This clears bridge-side forked serve-processes that may be repeatedly retrying actions and keeping zombies alive.

The VW image stays running but the bridge starts fresh. Token rotates — pick up from `.token`.

### Level 4 — Restart the VW image (drastic but reliable)

When in-image recovery has failed:

1. **Save anything important.** During testing this is usually nothing (we don't commit to the stone), but check.
2. **Find the VW process:**
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -eq 'vwnt' }
   ```
3. **Kill it:**
   ```powershell
   Stop-Process -Name vwnt -Force
   ```
4. **Re-launch** the VW image via normal startup (whatever shortcut/script the user uses to launch it).
5. **Login** to GemStone as usual.
6. **Re-file the bridge** (all 7 files in order — see [`vw-bridge-testing.md`](./vw-bridge-testing.md)).
7. **Re-toggle native dialogs if needed:**
   ```smalltalk
   Dialog useNativeDialogs: false
   ```

## How we got into this state (postmortem from session 2026-06-19)

> Pre-v0.8.11 behavior. The wedge-accumulation pattern described here is largely prevented in v0.8.11+ (`purgeWedgedDialogProcesses` auto-called from `/dialogs/respond`). Kept for archaeology.

A test cycle accumulated wedged `/click` jobs without ever cleanly restarting the bridge. Each `/click findID` that hit a modal:
- Forked a serve-process (Phase B+1.A) that waited indefinitely on the modal
- When dismissed late (via various mechanisms), the action completed, but spawned domain processes that didn't get cleaned up
- The action sometimes errored (`Message not understood: #items`, `primitive has failed`) producing `UnhandledException` instances
- `UnhandledException` instances opened notifier windows that the user dismissed without resuming the exception process

Eventually `activeControllerProcess` went to nil and VW input dispatch broke. Recovery via terminate-processes failed (the bridge kept respawning Party Search processes from retrying serve-processes). The only clean recovery was image restart.

**Prevention:** restart the bridge between major test cycles. See [`vw-bridge-testing.md`](./vw-bridge-testing.md) for the full discipline.

## Related

- [`vw-bridge-testing.md`](./vw-bridge-testing.md) — how to avoid getting here in the first place
- [`vw-dialogs.md`](./vw-dialogs.md) — why modal cascades + ValueHolder tricks contributed to the wedge
- [`vw-eval-cookbook.md`](./vw-eval-cookbook.md) — quick reference for the diagnostic queries above
