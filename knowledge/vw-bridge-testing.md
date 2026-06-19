# VW Bridge Testing Methodology

Lessons learned the hard way. **Read before starting a new test cycle.**

## The cardinal rule

**Restart the bridge (re-file all `.st` files in order) between major test cycles.** Don't accumulate wedged `/click` jobs across cycles.

Why: each `/click` that triggers a long-running action forks a serve-process (Phase B+1.A) that stays alive until the action completes. If the action triggers a modal you don't dismiss, OR if your PowerShell job handle gets lost between bash calls, that serve-process can persist. Over time:
- Multiple zombie domain processes spawn (e.g. "Party Search" processes from the search action)
- `UnhandledException` instances accumulate
- VW's internal scheduling state can degrade

A clean bridge restart clears the forked-process slate.

## Pre-test checklist

Before firing `/click` on an action that might pop a modal:

1. **Verify bridge state is clean:**
   ```powershell
   curl http://127.0.0.1:9876/health   # should match expected version
   ```
2. **Snapshot baseline window count** via `/windows` so you can detect modals opening.
3. **If working with dialogs, confirm native is off:**
   ```smalltalk
   Dialog usesNativeDialogs    # should be false
   ```
   See [`vw-dialogs.md`](./vw-dialogs.md) for why this matters.
4. **Verify no zombie processes:**
   ```smalltalk
   (Process allInstances select: [:p | [p name asString = '<action name>'] on: Error do: [:ex | false]]) size
   ```
   Should be 0 (or your known baseline).

## Test cycle pattern

For each test:

```
1. Trigger action (e.g. /click findID) - PowerShell Start-Job
2. Wait ~2s for any modal to appear
3. GET /dialogs - confirm modal is what you expect
4. POST /dialogs/respond {choice: ...} - dismiss
5. Check for cascade modal: GET /dialogs again
6. Repeat respond+check until /dialogs returns empty
7. Wait briefly, then check /click job - should be Completed
8. VERIFY EXPECTED STATE (window count, /value reads, etc.)
9. Clean up: Remove-Job
```

## Anti-patterns observed in this codebase's history

### ❌ Polling `/click` job state across bash calls
**Doesn't work.** Each PowerShell `bash` invocation is a fresh PowerShell session. `Start-Job` handles die with the session. The bridge-side serve-process keeps running but you've lost the ability to `Receive-Job`.

**Fix:** do all of trigger + dismiss + receive in ONE bash call.

### ❌ Triggering action then re-querying state in a different bash call
**Same root cause.** State (job, /click in flight, etc.) is lost between calls.

**Fix:** orchestrate the entire test sequence in one bash call. If you need long-lived state, write it to a file the next call can read.

### ❌ Relying on `Dialog allInstances` to find live modals
**Stale instances accumulate** — old SimpleDialog instances persist after dismissal. Plus the `Dialog dialogSupplier` singleton always shows.

**Fix:** filter via `scheduledControllers`:
```smalltalk
ScheduledControllers scheduledControllers select: [:c | c model class == SimpleDialog]
```

### ❌ Setting ValueHolders (`accept`, `cancel`, `close`) from a foreign process
**ValueHolders get set but the modal's wedged loop doesn't notice** — change notifications fire on the setter's process, not the modal's wait process. The UI process is stuck and won't yield.

**Fix:** use `target closeAndUnschedule` on the ScheduledController. This forces the OS to send a window-close event, which wakes the modal loop. See [`vw-dialogs.md`](./vw-dialogs.md) for the full explanation.

### ❌ Toggling `Dialog useNativeDialogs: false` and forgetting about it
**This setting persists** as long as the VW image is running. Other apps in the image will get Smalltalk dialogs too. Usually fine for dev but document loudly.

### ❌ Accumulating /click wedges then "trying to recover"
**Eventually you break VW input dispatch.** This session ended with `activeControllerProcess: nil`, multiple zombie processes, and 3 `UnhandledException` instances — VW input became unresponsive. Recovery options short of image restart were exhausted.

**Fix:** when you notice things are getting weird (more than 1-2 wedged jobs, zombie processes appearing), **restart the bridge BEFORE the wedges compound into something irrecoverable**. Re-file all 7 `.st` files in order.

## Bridge restart procedure

In a VW workspace (one chunk, "Do It"):

```smalltalk
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseA.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseB.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseB1.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseB2.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseB3.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseB4.st' asFilename fileIn
```

The last file in the chain writes the new token to `.token` automatically. Pick it up via:

```powershell
$tok = (Get-Content C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\.token).Trim()
$h = @{"Authorization" = "Bearer $tok"}
```

Note: bridge restart does NOT reset `Dialog useNativeDialogs:` (that's set on the `Dialog` class which lives in the image, not in the bridge). You may need to re-toggle if the VW image itself was restarted.

## When things go really wrong

See [`vw-input-recovery.md`](./vw-input-recovery.md). TL;DR: if you can't recover via the bridge, kill `vwnt.exe` in Task Manager and relaunch the image cleanly.

## Use `/eval` for incremental verification

This was the single biggest workflow win this session. Instead of writing a probe `.st` file, file'ing it in, reading its output file — just send the Smalltalk via `POST /eval`. See [`vw-eval-cookbook.md`](./vw-eval-cookbook.md) for recipes.
