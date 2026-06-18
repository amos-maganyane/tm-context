# VWBridge — working scripts

VisualWorks/GBS HTTP bridge exposing the running image's widget tree
over `127.0.0.1:9876` for external test automation.

## Files in this directory

| File | Status | Purpose |
|---|---|---|
| `VWBridge.st` | **v0.5 — proven** | Base bridge: GET `/health`, `/windows`, `/windows/tree`. Read-only. |
| `VWBridge-phaseA.st` | **v0.7 — new** | Adds POST `/click`, POST `/type`, GET/PUT `/value` + Bearer-token auth. Files in ON TOP of v0.5. Click fires via `model value: true` (PluggableAdaptor pattern — probe-confirmed). |
| `probes/phaseA_probe.st` | v2 | Read-only API discovery probe for Phase A. Run before relying on Phase A. |
| `probes/phaseA_results.txt` | output | Latest probe report (rewritten on each run). |
| `VWBridge-phaseA-workspace.st` | deprecation stub | Old broken installer — kept as a hint pointing to the right command. |

## Why these scripts work in this image

- Written in **chunk format** for VW File-In (not workspace Do It).
- All globals qualified — `Root.Smalltalk`, `Core.Error`, `Core.String`, etc.
  Unqualified `Smalltalk` / `String` / `Character` are AMBIGUOUS in this
  GBS image (`VisualAgeCompatibility.*` and `GemStoneClasses.*` shadow kernel names).
- Socket layer uses `SocketAccessor newTCPserverAtPort:` + `listenFor:`
  + `accept` + `readAppendStream` (probe-confirmed in this image).
- `Semaphore` timeout is implemented with a `Delay` watchdog process —
  this image has no native `waitTimeout*:` API.
- HTTP framing protected by `stream lineEndTransparent` (VW external
  streams otherwise rewrite CR/LF on the wire).

## Install order

### Base only (v0.5 — read-only)

In the VW File Browser → select `VWBridge.st` → **File In**.

Or, in a workspace, evaluate:

```smalltalk
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn
```

Transcript should show `VWBridge: listening via SocketAccessor`.

### Adding Phase A (v0.6 — interactive)

1. Run `probes/phaseA_probe.st` first (paste into a workspace, Do It).
   It writes `probes/phaseA_results.txt`. Confirm:
   - `spec action` selector exists on ActionButtonSpec
   - `model value:` exists on the input field's ValueHolder
2. **After** v0.5 is filed in, file in `VWBridge-phaseA.st` the same way.
   It auto-runs `VWBridge stop. VWBridge start` so the new dispatcher
   takes effect.
3. Note the **token** printed to the Transcript — every non-`/health`
   request needs `Authorization: Bearer <token>`.

## Endpoints

| Method | Path | Auth | Body | Notes |
|---|---|---|---|---|
| GET | `/health` | no | — | liveness — `{"status":"ok","version":"0.7"}` |
| GET | `/windows` | yes | — | window summaries |
| GET | `/windows/tree` | yes | — | full widget tree (aspect, label, value) |
| GET | `/value` | yes | — | `?aspect=X&windowTitle=Y` — read widget value |
| POST | `/click` | yes | `{"aspect":"X","windowTitle":"Y"}` | fires `model value: true` (PluggableAdaptor) |
| POST | `/type` | yes | `{"aspect":"X","value":"hi","windowTitle":"Y"}` | sets `model value: newValue` (ValueHolder) |
| PUT | `/value` | yes | `{"value":"new"}` | alt to POST `/type` (aspect in query) |

`windowTitle` is a **substring** match against `view label` — leave
it off to match the first window with that aspect.

## Lifecycle

| Action | How |
|---|---|
| Stop | `VWBridge stop` |
| Restart (same code) | `VWBridge start` |
| Show running version | `curl http://127.0.0.1:9876/health` |
| Show current token | `VWBridge singleton token` |

The bridge lives in image memory only — it dies with the image unless
the image is saved. After an image restart, file-in again.
