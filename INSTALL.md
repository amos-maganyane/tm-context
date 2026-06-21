# VW Bridge — Install Guide

The VW Bridge is an HTTP service that exposes a live VisualWorks 9.3.1 image (MAS / Old Mutual Wealth WEALTH deployment, `storedev64.im`) at `http://127.0.0.1:9876`. External tools (test runners, AI agents, CI) drive widgets in the running image through documented endpoints (`/health`, `/version`, `/windows`, `/eval`, `/click`, `/type`, `/wait`, `/screenshot`, …).

This guide gets you from a freshly cloned repository to a `curl /health` response in under five minutes.

---

## 1. Prerequisites

| Requirement | How to verify |
|---|---|
| **Windows 10 / 11 (x64)** | `[Environment]::OSVersion` in PowerShell |
| **VisualWorks 9.3.1** installed at `C:\visualworks931\` with `bin\win64\vwnt.exe` + `image\storedev64.im` + `image\storedev64.cha` | `Test-Path C:\visualworks931\bin\win64\vwnt.exe` should return `True` |
| **PowerShell 5.1 or newer** (ships with Windows) | `$PSVersionTable.PSVersion` |
| **`curl.exe`** (ships with Windows 10 1803+) | `curl.exe --version` |
| **Git** (only if you clone the repo) | `git --version` |

The bridge assumes a stock VW install path. If yours differs, edit the `$vwnt` / `$image` / `$imageDir` constants near the top of `Start-VWBridge.ps1` (the only paths it hardcodes — `vwnt.exe`, `storedev64.im`, and the image working directory).

---

## 2. Quick start — happy path

```powershell
# 1. Clone the repo (or unpack the tarball)
git clone https://github.com/amos-maganyane/tm-context.git
cd tm-context

# 2. Set VW_BRIDGE_HOME at User scope (persists across reboots)
[Environment]::SetEnvironmentVariable(
    'VW_BRIDGE_HOME',
    "$PWD\src\vw-bridge",
    'User')

# 3. Re-open your terminal so the new env var is inherited, then:
cd <path to your clone>

# 4. Launch the bridge (default: FileIn install)
.\src\vw-bridge\scripts\Start-VWBridge.bat

# 5. Smoke test
curl.exe -s http://127.0.0.1:9876/health
curl.exe -s http://127.0.0.1:9876/version
```

Expected output of step 5:

```json
{"status":"ok","version":"0.10.0"}
{"version":"0.10.0","buildCommitSha":"<git HEAD SHA>","buildTimestamp":"<ISO UTC>","parcelMode":"FileIn"}
```

If you got both responses, you're done. Skip to [§7 Smoke test details](#7-smoke-test-details) and [§8 Next steps](#8-next-steps).

If anything failed, see [§9 Troubleshooting](#9-troubleshooting).

---

## 3. Choose your install mode

The bridge ships two install paths. Both produce a running `VWB.VWBridge` listener on port 9876; they differ in **what gets loaded into the image**.

| Mode | What loads | Image footprint | Test classes | When to use |
|---|---|---|---|---|
| **FileIn** (default) | All 5 source files (`VWBridge.st` + `VWBridge-Patches.st` + 3 `VWBridge-*Test.st`) | ~larger | **Yes** — 60+ SUnit selectors loaded | Development, QA, contributing code, running the test suite |
| **Parcel** | Pre-built binary parcel (`VWBridge.pcl`) | ~smaller, faster | **No** — only the core `VWBridge` class | Production, lean deployment, CI runners that don't need to run SUnit |

Both modes share the same wrapper (`Start-VWBridge.ps1`) and the same end-state for `VWB.VWBridge`. Only the load mechanism differs.

You can switch modes at any time by killing `vwnt.exe` and re-running the wrapper with a different `-Mode`. No state migration needed (the bridge is stateless beyond the `.token` file).

**If unsure, start with FileIn** — it's the development default and matches what the project's automated tests assume.

---

## 4. Install — FileIn mode (dev / test / default)

### 4.1 Clone the repository

```powershell
cd C:\Users\<you>\
git clone https://github.com/amos-maganyane/tm-context.git
cd tm-context
```

(Or unpack a tarball. The folder structure must contain `src\vw-bridge\` with `VWBridge.st`, `load.st`, `scripts\Start-VWBridge.ps1`, etc.)

### 4.2 Set `VW_BRIDGE_HOME`

The bridge derives all install-relative paths (the `.token` file, log file, screenshot helper, parcels) from this single env var.

```powershell
[Environment]::SetEnvironmentVariable(
    'VW_BRIDGE_HOME',
    'C:\Users\<you>\tm-context\src\vw-bridge',
    'User')
```

Replace the path with **the absolute path to `src\vw-bridge` inside your clone**. Use `User` scope (persists across reboots, doesn't require admin).

**Re-open your terminal** after setting the variable — child processes inherit env vars from their parent at creation time, not at use time.

To verify:

```powershell
[Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User')
# Should print: C:\Users\<you>\tm-context\src\vw-bridge
```

### 4.3 Launch the bridge

```powershell
.\src\vw-bridge\scripts\Start-VWBridge.bat
```

The wrapper:

1. Reads `VW_BRIDGE_HOME` (falls back to User / Machine scope if not in Process scope)
2. Confirms `vwnt.exe`, `storedev64.im`, and `load.st` all exist
3. Checks if a bridge is already running (idempotent — exits 0 silently if `/health` already responds)
4. Generates a chunk-wrapped startup file at `$VW_BRIDGE_HOME\.generated\load-startup.st`
5. Launches `vwnt.exe storedev64.im -filein <generated>` with working directory set to the image directory
6. Polls `/health` for up to 90 seconds (typically responds within 1.5 s)
7. Verifies the `.token` file timestamp advanced
8. Toggles `Smalltalk.Dialog useNativeDialogs: false` via `/eval` (re-arms the SimpleDialog Bug #2 fix)
9. Injects build metadata (commit SHA, build timestamp, parcel mode) via `/eval`

Total cold start: **~9 seconds** on a typical dev machine.

Expected console output (abbreviated):

```
[Start-VWBridge] preflight OK (VW_BRIDGE_HOME=..., Mode=FileIn)
[Start-VWBridge] generated ...\load-startup.st (4138 chars from ...\load.st)
[Start-VWBridge] launching: C:\visualworks931\bin\win64\vwnt.exe ...
[Start-VWBridge] vwnt.exe PID: 12345, started 6/21/2026 4:11:25 PM
[Start-VWBridge] /health 200 OK after 3 poll(s) (1500ms): {"status":"ok","version":"0.10.0"}
[Start-VWBridge] .token rotated at <UTC>, value=3959511...
[Start-VWBridge] Smalltalk.Dialog useNativeDialogs: false (Bug #2 fix active)
[Start-VWBridge] Start-VWBridge.ps1 SUCCESS
```

### 4.4 Verify

See [§7 Smoke test details](#7-smoke-test-details).

---

## 5. Install — Parcel mode (lean production)

### 5.1 Steps 1–2

Same as [§4.1](#41-clone-the-repository) and [§4.2](#42-set-vw_bridge_home). Clone, set `VW_BRIDGE_HOME`, re-open terminal.

### 5.2 Verify the parcel + source companion exist

```powershell
Test-Path "$env:VW_BRIDGE_HOME\parcels\VWBridge.pcl"  # should be True
Test-Path "$env:VW_BRIDGE_HOME\parcels\VWBridge.pst"  # should be True
```

Both files **must** be present alongside each other. `VWBridge.pcl` embeds a reference to its `.pst` source companion; without `.pst` the image pops a confirmation dialog at startup that wedges the headless launch.

If the `.pst` is missing (e.g. someone stripped it to save 128 KB in the distribution), either:

- Rebuild the parcel with `hideOnLoad: true` via `scripts\Build-Parcel.ps1` (see [§6 Rebuilding the parcel](#6-rebuilding-the-parcel)), or
- Restore the `.pst` from git history: `git checkout HEAD -- src/vw-bridge/parcels/VWBridge.pst`

### 5.3 Launch in Parcel mode

The `.bat` shim doesn't expose a `-Mode` flag — invoke the `.ps1` directly:

```powershell
.\src\vw-bridge\scripts\Start-VWBridge.ps1 -Mode Parcel
```

The wrapper:

1. Same preflight as FileIn mode, plus a check that the `.pcl` exists at `$VW_BRIDGE_HOME\parcels\VWBridge.pcl` (override with `-Parcel <path>`)
2. Generates a chunk-wrapped post-load script at `$VW_BRIDGE_HOME\.generated\parcel-start-startup.st`
3. Launches `vwnt.exe storedev64.im -pcl <path>\VWBridge.pcl -filein <generated>`. Per AppDevGuide.pdf p470, image-level switches process left-to-right: `-pcl` loads the parcel (adds `VWB` namespace + `VWBridge` class + `SimpleDialog` override), THEN `-filein` runs `parcel-start.st` which calls `VWB.VWBridge start` and writes `.token`
4. Polls `/health`, verifies token rotation, toggles `useNativeDialogs:`, injects build metadata — same as FileIn mode

Total cold start: **~8.4 seconds** on a typical dev machine (slightly faster than FileIn since `parcel-start.st` is shorter than the 5-file file-in `load.st`).

### 5.4 Verify

Same smoke test as below. In Parcel mode, the `/version` response shows `parcelMode: "Parcel"`. The `buildCommitSha` + `buildTimestamp` reflect the **current cold-start moment** (git HEAD of your clone, UTC timestamp of launch), not the parcel's original build time. For parcel-build provenance, check `git log` on `parcels/VWBridge.pcl`.

---

## 6. Rebuilding the parcel

Use this when you change `VWBridge.st` and want a new `VWBridge.pcl` shipping the updated source.

```powershell
.\src\vw-bridge\scripts\Build-Parcel.ps1
```

The script:

1. Requires the bridge to be UP (it drives the build via `/eval`)
2. Captures the current git HEAD SHA and a UTC ISO-8601 build timestamp (logged for traceability, not embedded into the parcel)
3. Sends an `/eval` body that wraps `Kernel.Parcel parcelOutOn:withSource:hideOnLoad:republish:backup:` in a temporary `Cursor>>showWhile:` monkey-patch (the canonical `parcelOutOn:` wedges headless bridges via `Cursor wait showWhile:` — see [Phase P P6 carry-forward #35](knowledge/vw-image-api-contract.md))
4. Writes `VWBridge.pcl` + `VWBridge.pst` to `$VW_BRIDGE_HOME\.generated\parcels\`
5. Copies the produced binaries to `$VW_BRIDGE_HOME\parcels\` (overwriting `VWBridge.pcl` + `VWBridge.pst`)

The parcel ships:

- VWB namespace
- VWB.VWBridge class definition + all its methods (including the new `version` / `buildCommitSha` / `buildTimestamp` / `parcelMode` accessors and setters)
- SimpleDialog>>choose:labels:values:default:for: extension (Bug #2 fix)

Build metadata is intentionally NOT baked into the parcel as compiled literals — that approach wedges this image during `compile:` on `VWB.VWBridge` (UI announcement during compile routes through `Cursor wait showWhile:` even after the Cursor monkey-patch is installed). Instead, `Start-VWBridge.ps1` injects `buildCommitSha` / `buildTimestamp` / `parcelMode` via `/eval` setters at every cold-start in both modes. `/version` therefore answers "what bridge is running right now" rather than "when was the parcel built".

After a rebuild, kill `vwnt.exe` and relaunch with `-Mode Parcel -KillExisting` to validate the new parcel from a cold start.

You don't need `Build-Parcel.ps1` for routine development — `Start-VWBridge.bat` in FileIn mode files in source directly, no parcel build required. Rebuild only when shipping a binary release or when you've changed the bridge's persistent contract.

---

## 7. Smoke test details

### 7.1 `/health`

```powershell
curl.exe -s http://127.0.0.1:9876/health
```

Expected:

```json
{"status":"ok","version":"0.10.0"}
```

`/health` is **auth-exempt**: no token required. Use this for liveness probes, container health checks, monitoring.

### 7.2 `/version`

```powershell
curl.exe -s http://127.0.0.1:9876/version
```

Expected (FileIn mode, launched now):

```json
{"version":"0.10.0","buildCommitSha":"b9e5357...","buildTimestamp":"2026-06-21T16:11:25Z","parcelMode":"FileIn"}
```

Expected (Parcel mode):

```json
{"version":"0.10.0","buildCommitSha":"<git HEAD at launch>","buildTimestamp":"<UTC at launch>","parcelMode":"Parcel"}
```

`/version` is also auth-exempt. Fields:

- `version` — bridge release version, bumped per release (currently `0.10.0`).
- `buildCommitSha` — git HEAD when **this bridge instance** was launched (NOT when the parcel was originally built). Set by `Start-VWBridge.ps1` post-launch via `/eval` in both FileIn and Parcel modes. For parcel-build provenance, check `git log` on `parcels/VWBridge.pcl`.
- `buildTimestamp` — ISO-8601 UTC of the same launch event.
- `parcelMode` — `"FileIn"` or `"Parcel"`, tells you which install path is active.

### 7.3 Authenticated endpoint (`/windows`)

```powershell
$token = Get-Content "$env:VW_BRIDGE_HOME\.token"
curl.exe -s -H "Authorization: Bearer $token" http://127.0.0.1:9876/windows
```

You should get a JSON array of currently-open VW windows. The `.token` is rotated on every `VWB.VWBridge start` (i.e. on every cold start) — do not hardcode it anywhere.

For long-running automation, read `.token` each request, or watch its file mtime and reload on change.

---

## 8. Next steps

- **API surface** — Full endpoint list with shapes is documented in `knowledge/vw-image-api-contract.md` and `docs/ARCHITECTURE-REVISED.md`.
- **AI agent rules** — If you'll work on the bridge code with an AI agent, read `AGENTS.md` (at the repo root) for operating discipline and `knowledge/vw-image-api-contract.md` for image-API quirks.
- **Running the test suite** — Switch to FileIn mode (`Start-VWBridge.bat`), then via VW Workspace run `VWB.VWBridgeTest buildSuiteFromLocalSelectors run` (and the same for `VWBridgeWaitTest`, `VWBridgeScreenshotTest`). See `knowledge/vw-image-api-contract.md` "SUnit semantics in this image" for direct-invoke gate pattern.
- **Stopping the bridge** — `Stop-Process -Name vwnt -Force`. There is no graceful shutdown endpoint by design (CI runners can be ungraceful; the image survives `Stop-Process` cleanly).

---

## 9. Troubleshooting

### 9.1 `Start-VWBridge.ps1` exits with code 2 — `VW_BRIDGE_HOME` not set

Set it at User scope, then **re-open your terminal**:

```powershell
[Environment]::SetEnvironmentVariable(
    'VW_BRIDGE_HOME',
    'C:\path\to\your\clone\src\vw-bridge',
    'User')
```

Verify with `[Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User')`.

The wrapper checks Process / User / Machine scopes in that order, but if your current PowerShell session was opened **before** you set the variable, the Process scope is empty and the User scope only takes effect for terminals opened after the `SetEnvironmentVariable` call.

### 9.2 Exit code 3 — required file missing

The wrapper checks for `vwnt.exe`, `storedev64.im`, `load.st` (FileIn) or `parcel-start.st` + `VWBridge.pcl` (Parcel). The error message names the missing file.

- `vwnt.exe` / `storedev64.im` missing → your VW install path is non-standard. Edit the `$vwnt` / `$image` / `$imageDir` constants at the top of `Start-VWBridge.ps1`.
- `load.st` / `parcel-start.st` missing → your clone is corrupt or `VW_BRIDGE_HOME` points to the wrong directory.
- `VWBridge.pcl` missing in Parcel mode → either rebuild it (`Build-Parcel.ps1`) or restore from git history (`git checkout HEAD -- src/vw-bridge/parcels/`).

### 9.3 Exit code 4 — `load.st` contains `!`

The chunk parser would split at the `!` even inside comments, breaking the chunk-wrap. Find and rewrite the `!` (e.g. `!=` → `not equal to`, `!exists` → `does not exist`).

### 9.4 Exit code 5 — `/health` did not respond

Most common cause: the headless image popped a confirmation dialog and is waiting for user input. Check:

- **`.pst` companion missing in Parcel mode** → image pops `'Failed to find source file VWBridge.pst. Ok to load without target source?'`. Restore the `.pst` or rebuild with `hideOnLoad: true`.
- **`vwbridge-autostart.err` content** → the wrapper tails the last 50 lines. Look for Smalltalk stack traces or syntax errors in `load.st` / `parcel-start.st`.
- **Port 9876 already bound by something else** → `Get-NetTCPConnection -LocalPort 9876` to investigate. The bridge fails to start the listener if the port is taken.

The bridge image WILL be running as `vwnt.exe` even if the listener didn't start — kill it before retrying: `Stop-Process -Name vwnt -Force` or use `-KillExisting`.

### 9.5 Exit code 6 — `.token` did not rotate

Means `vwnt.exe` came up but `load.st` (or `parcel-start.st`) failed at step 5 (the `.token` write). Most likely:

- `VW_BRIDGE_HOME` value inside the image differs from what the wrapper saw (rare — only happens if you edit env vars mid-launch).
- Filesystem permissions prevent writing `.token`.

Open VW Workspace, paste the contents of `load.st` (FileIn) or `parcel-start.st` (Parcel) and Do It. The Transcript will show the failure line. Use `Core.WriteStream` and `Core.String` qualifications if the Workspace pops an ambiguity dialog (GemBuilder collisions — see `knowledge/vw-image-api-contract.md` §"Workspace vs /eval namespace resolution").

### 9.6 `vwnt.exe` is wedged — no `/health` response, no dialog

```powershell
.\src\vw-bridge\scripts\Start-VWBridge.ps1 -KillExisting
```

This force-kills any running `vwnt.exe`, waits 2 seconds for port 9876 to clear, then re-launches. The image survives `Stop-Process` cleanly (storedev64.im on disk is not corrupted; the in-memory state is just discarded).

### 9.7 The `/version` endpoint shows `buildCommitSha: "unknown"`

In FileIn mode this means the wrapper's post-launch `/eval` inject step failed. Check the wrapper output for `useNativeDialogs:` and `buildInfo:` toggle responses. If `useNativeDialogs:` worked but `buildInfo:` did not, you may be on an old wrapper version — pull a recent commit.

In Parcel mode it means the parcel was built without the metadata embed step. Rebuild with `Build-Parcel.ps1`.

### 9.8 Native (Win32) dialogs keep appearing instead of the SimpleDialog override

The wrapper toggles `Smalltalk.Dialog useNativeDialogs: false` automatically after launch. If you see native dialogs anyway, the toggle failed (look for a yellow warning in the wrapper output). Re-toggle manually:

```powershell
$token = Get-Content "$env:VW_BRIDGE_HOME\.token"
curl.exe -X POST http://127.0.0.1:9876/eval `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: text/plain" `
    --data-binary "Smalltalk.Dialog useNativeDialogs: false. ^'native-dialogs-OFF'"
```

The setter and getter are asymmetric: setter is `useNativeDialogs:` (keyword), getter is `usesNativeDialogs` (with an extra `s`). The toggle resets on every `vwnt.exe` restart — that's why the wrapper re-arms it every launch.

### 9.9 I changed `VWBridge.st`. How do I reload without restarting `vwnt.exe`?

```powershell
$token = Get-Content "$env:VW_BRIDGE_HOME\.token"
curl.exe -X POST http://127.0.0.1:9876/eval `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: text/plain" `
    --data-binary "@$env:VW_BRIDGE_HOME\load.st"
```

`load.st` is idempotent — it stops the existing listener, files in all 5 sources, restarts the listener, rotates the `.token`. After this, re-read `.token` for the new value.

This is the canonical reload path used by AI agents during development (see `AGENTS.md` §"AI drives /eval file-ins").

---

## 10. Uninstall

```powershell
# Kill the bridge image
Stop-Process -Name vwnt -Force

# Remove env var
[Environment]::SetEnvironmentVariable('VW_BRIDGE_HOME', $null, 'User')

# Optional: remove the .generated build artifacts
Remove-Item -Recurse -Force "$env:VW_BRIDGE_HOME\.generated"

# Optional: remove the working tree
Remove-Item -Recurse -Force C:\path\to\your\clone
```

The VW install (`C:\visualworks931\`) is independent of the bridge — leave it alone unless you also want to uninstall VisualWorks itself.

The `storedev64.im` image on disk is unchanged by anything the bridge does at runtime; bridge state lives only in the running `vwnt.exe` process. No image snapshot is taken.

---

## 11. Reporting issues

When reporting an install issue, include:

1. `Start-VWBridge.ps1` output (full, from `[Start-VWBridge] preflight OK` through the exit line)
2. Contents of `vwbridge-autostart.err` if it exists (note: it's only populated under Runtime-Packager builds; for stock VW images this file is silently empty)
3. `Get-Process -Name vwnt | Select-Object Id, StartTime`
4. `[Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User')`
5. `curl.exe -v http://127.0.0.1:9876/health` (verbose mode shows the TCP connection state)
6. Output of `/version` if the bridge responds at all

Issues filed at: https://github.com/amos-maganyane/tm-context/issues (or via team Jira — see `AGENTS.md` §Jira).
