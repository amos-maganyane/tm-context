# VW Widget Bridge -- Session Handoff

**Last update:** end of session that delivered Phase A v0.7.
**Image:** `storedev64.im` on the Windows VM, VW 9.3.1 of 2023-08-16, GBS for GemStone/S 3.7.4.3.
**Working dir for everything new:** `C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\`.
**Sandbox dir (older artifacts):** `C:\Users\ammaganyane\forge\` -- same v0.5 bridge lives there as `phase2_bridge_v2.st` (sha256-identical to `VWBridge.st`).

---

## TL;DR -- where we are

- **PoC fully proven for read-only widget exposure** (v0.5 bridge, port 9876, `GET /health` `/windows` `/windows/tree`). 3 windows, 29 widgets, live values came back as parser-validated JSON via `curl`.
- **Phase A v0.7 ready to install** -- adds `/click` `/type` `/value` + Bearer-token auth. Probe-tuned: click fires via PluggableAdaptor pattern (`model value: true`), not via `app perform: spec action` (which returns `nil` in this image).
- **Bridge is currently NOT running** -- image was restarted; bridge lives in image memory only. Next session installs both files.
- **Probe results captured** in `probes/phaseA_results.txt`. Read them before changing click/type strategy.

---

## Broader goal

Expose the WEALTH / MAS (Momentum Metropolitan) VW desktop app over network so external test automation (pytest, Playwright, Karate) and AI agents can drive it. Original 3-channel architecture in `C:\Users\ammaganyane\tm\remote-desktop\remote-desktop\visual-works\HANDOFF.md`. We are building **Channel 1: VW in-image agent** (TCP listener on localhost) -- the other two channels (GciForPython, WebGS) are for GemStone-side data, not widget interaction.

The first PoC question was *can we expose the widget tree at all?* -- answered **yes** by v0.5. Phase A is the next question: *can we drive it?* (click, type, read).

---

## Files in `tm-context/src/vw-bridge/`

| File | Version | Purpose |
|---|---|---|
| `VWBridge.st` | v0.5 | Base bridge (file-in first). Read-only `/windows`, `/windows/tree`, `/health`. **Don't edit** -- sha256-identical to `forge\phase2_bridge_v2.st`. |
| `VWBridge-phaseA.st` | v0.7 | Extension methods (file-in after v0.5). Adds `/click`, `/type`, `/value`, auth, headers/body, JSON parser. Auto-restarts the bridge. |
| `VWBridge-phaseA-workspace.st` | stub | Old broken self-contained installer -- replaced with a 1.4 KB deprecation hint. Safe to delete eventually. |
| `VWBridge-working.md` | doc | End-user install + endpoint reference (the file you'd show a tester). |
| `HANDOFF.md` | doc | **This file.** Cross-session context. |
| `probes/phaseA_probe.st` | v2.2 | Read-only API probe. Writes `phaseA_results.txt`. Non-invasive (no clicks, no value-sets). |
| `probes/phaseA_results.txt` | output | Latest probe run. Source of truth for what the image supports. |
| `probes/phase1_probe_v4.st`, `probes/phase1_results.txt` | reference | Original Phase 1 probe that proved widget tree access. |

---

## Image-specific gotchas (CRITICAL -- burnt in via 4 iterations)

This is a **GBS image** with `VisualAgeCompatibility` and `GemStoneClasses.Globals` packages that **shadow kernel names**. Unqualified references hit a VW "Ambiguous class or variable" dialog at compile time. Always qualify:

| Kernel name | Use |
|---|---|
| `Smalltalk` | `Root.Smalltalk` |
| `String`, `Character`, `WriteStream`, `ReadStream`, `OrderedCollection`, `Dictionary`, `Semaphore`, `Error`, `Number`, `Collection`, `Time`, `Delay`, **`Array`**, **`Integer`** | `Core.<name>` |

The list above is **proven** -- every name on it tripped a dialog at least once during this work. When writing new VW code for this image, just default to qualifying anything that looks like a class.

Other image-specific things baked into v0.5 / v0.7:

- **No `Semaphore` timeout API** (`waitTimeoutMSecs:`, `waitTimeoutMilliseconds:`, `waitTimeoutSeconds:` all absent). The bridge uses a `Core.Delay` watchdog process that signals the semaphore after N ms. See `VWBridge>>wait:timeoutMs:`.
- **VW external streams rewrite CR/LF** by default -> HTTP framing breaks. `[stream lineEndTransparent] on: err do: [:ex | nil]` is mandatory before writing/reading the socket stream.
- **No HTTP server classes in image** (`HTTPServer`, `SimpleHTTPClient` etc. absent). Hand-rolled HTTP is necessary.
- **No `UIProcess` global**. The bridge uses `ScheduledControllers activeControllerProcess interruptWith: [...]` to hop onto the UI thread.
- **No `UUID` / `UUIDGenerator`**. Bridge tokens are `Time millisecondClockValue , '-' , self identityHash`.
- **VW forbids assigning to method parameters.** The Phase A JSON parser uses a 1-element-`Core.Array` cursor instead of mutating an arg `pos`. (This is the bug that broke the previous AI's Phase A draft.)

---

## Probe findings summary (`phaseA_results.txt`)

| Area | Result | Bridge consequence |
|---|---|---|
| `Display` global | Is the **`Screen` class itself**, not an instance | `Display contentsOfArea: Display boundingBox` fails (`#boundingBox` not understood) -> screenshot deferred |
| `PNGReadWriter` / `ImageReadWriter` | Both **missing** | No PNG encoding path -> screenshot deferred |
| `Base64MimeConverter` / `Base64Encoder` / `MIMEBase64` / `Base64Coder` | All **missing** | Would need hand-rolled base64 -> screenshot deferred |
| `ActionButtonSpec>>action` | Returns **nil** in this image | **Cannot use `app perform: spec action`** -- was the broken click strategy in v0.6 |
| Button's `widget model` | `PluggableAdaptor` with `value` + `value:` OK | `model value: true` triggers the action via the adaptor's setter block -- the v0.7 click strategy |
| Button's `widget controller` | `ViewEventControllerForLegacyWidgets` -- has none of `performAction` / `pressAction` / `action` / `invokeAction` / `simulateClick` / `clicked` | Controller-side click strategy is a dead end |
| Input field's `widget model` | `ValueHolder` with `value:` + `setValue:` OK | `model value: text` for `/type` |
| `Filename writeStream` | works OK | Report files / temp PNG paths OK |

Sample widgets seen during probe (windows that were open at the time): GbxVisualLauncher (`addWidget`, `loginRpcWidget`, `commitWidget`, `abortWidget`, `parametersListWidget` ...), Workbook (`importSummary` = `'All'`, `pageExplanation`), VisualLauncher (`statusBar`, `transcript`, `launcherToolBar`).

---

## Install & verify

1. **Open VW workspace** in the running image (or start image if down: `C:\visualworks931\bin\win64\vwnt.exe storedev64.im`).
2. **Paste + Do It**:

   ```smalltalk
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn.
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseA.st' asFilename fileIn
   ```

3. Transcript ends with `VWBridge: listening via SocketAccessor` + a token line `VWBridge token: NNNN-NNNN`.
4. From outside the image:

   ```powershell
   curl http://127.0.0.1:9876/health
   # {"status":"ok","version":"0.7"}

   $tok = "NNNN-NNNN"   # from Transcript
   curl -H "Authorization: Bearer $tok" http://127.0.0.1:9876/windows
   curl -H "Authorization: Bearer $tok" "http://127.0.0.1:9876/value?aspect=importSummary&windowTitle=Workspace"
   curl -H "Authorization: Bearer $tok" -X POST http://127.0.0.1:9876/type `
        -d '{"aspect":"importSummary","windowTitle":"Workspace","value":"hello bridge"}'
   curl -H "Authorization: Bearer $tok" -X POST http://127.0.0.1:9876/click `
        -d '{"aspect":"abortWidget","windowTitle":"GemStone Launcher"}'
   ```

Lifecycle: `VWBridge stop` / `VWBridge start` / `VWBridge singleton token` in any workspace.

---

## What works (proven end-to-end before this handoff)

- v0.5 `/health`, `/windows`, `/windows/tree` -- `curl` tested, JSON parser-validated, 29 widgets across 3 windows, live values including button states (`false`), radio button state (`nil`), input field text (`'All'`), and the GBS sessions list (`List ('x' on 'development64' @ 'invgemdev101' 'pipsuper' on 'prested3' ...)`).
- Probe v2.2 -- produces `phaseA_results.txt` end-to-end, no compile dialogs, no unused-variable warnings.

## What's verified by the probe (one step short of curl-tested)

- v0.7 click strategy (`model value: true`) -- surface confirmed (PluggableAdaptor has `value:`), but **not yet curl-tested** against a real button click. The first thing the next session should do.
- v0.7 type strategy (`model value: text`) -- same: surface confirmed, not yet curl-tested.

---

## What's pending

1. **IMMEDIATE -- finish Phase A acceptance tests.** User pastes the token from Transcript after install; this session was going to run:

   | Test | Expected |
   |---|---|
   | `GET /health` (no token) | 200, `version: 0.7` |
   | `GET /windows` (no token) | 401 |
   | `GET /windows` (with token) | array of 3+ windows |
   | `GET /value?aspect=importSummary&windowTitle=Workspace` | `{"ok":true,"value":"All"}` |
   | `POST /type` `importSummary` <- `"hello bridge"` then re-GET | echoes back |
   | `POST /click` `abortWidget` on GemStone Launcher | 200 (Abort with no transaction is a no-op) |

   **DO NOT** test `commitWidget` / `loginRpcWidget` / `removeWidget` without explicit user permission -- those have real side effects against the GemStone stone (`invgemprd101.metmom.mmih.biz`).

2. **Phase B -- screenshot.** Probe says it's not feasible with the obvious APIs in this image. Options to investigate next session:
   - Look for `Screen default` instance and what it understands (probe showed Display = Screen class only).
   - Investigate `GraphicsContext` / `Surface` / `Bitmap` APIs.
   - Drop PNG, output BMP or raw form-data (Form has `bits` accessor in many VWs).
   - Or shell out to OS-level screen capture via `OS.OSProcess` / `CEnvironment` and serve the file.

3. **Persistence.** Bridge lives in image memory only; dies with image. Options:
   - Save the image after install -- survives until next mass image deploy.
   - Bake `VWBridge` into a Store package and load on image boot -- proper CI story.
   - Add an `application/post-snapshot` startup hook that auto-starts the bridge.

4. **Token security.** Token is per-instance random, printed to Transcript. Good for localhost-only dev. For shared environments, add IP allowlisting and/or rotate tokens.

5. **`HANDOFF.md` (the original)** at `C:\Users\ammaganyane\tm\remote-desktop\remote-desktop\visual-works\HANDOFF.md` is outdated -- it still says Phase 2 has known issues. Update it to point at this file when convenient.

---

## ! Known broken thing (out of scope for VW bridge but worth a flag)

The **Jasper GemStone MCP** in this opencode session has been returning `Error: a CompileError occurred (error 1001), Internal logic error in compiler: ComStrmSetCursor: new cursor out of range` on every single call, including `gemstone_status`. Did **not** affect the VW work (every Jasper call failed read-only -- no GemStone-side changes ever committed), but next session needs a Jasper restart or it cannot touch the GemStone image at all.

---

## How to resume in a new session

1. Read this file + `VWBridge-working.md` + `probes/phaseA_results.txt` -- that's the full state.
2. Check whether the bridge is up: `curl http://127.0.0.1:9876/health`. If not, install per "Install & verify" above.
3. Continue from "What's pending" item 1 -- run the Phase A acceptance tests once the token is available.
4. Ask the user before any destructive button click or before saving the image.

## VM safety reminders (from original HANDOFF)

- **Sandbox**: `C:\Users\ammaganyane\forge\` and `C:\Users\ammaganyane\tm\tm-context\` are safe to write.
- **NEVER modify**: running VW images, `C:\WEALTH\`, anything under `C:\visualworks931\` system files.
- **Headless VW eval** (`vwntconsole.exe test.im -filein script.st`) works but image copies can hang at startup trying to connect to GemStone. Prefer the running GUI image (PID seen during this session: 7724, `storedev64`).
