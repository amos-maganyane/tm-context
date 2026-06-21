# Handoff — Phase F3 Steps 10-16 GREEN; Step 17 BLOCKED on subprocess wait mechanism (session 2026-06-20 session-12 EOD)

**Written:** end of session-12 that executed Steps 10-16 of the [PLAN-PHASE-F-SCREENSHOT.md](../plan/PLAN-PHASE-F-SCREENSHOT.md) 20-step checklist (turning all 10 RED tests from session-11 CONCEPTUALLY GREEN via direct-invocation verification — full SUnit suite confirmation deferred), committed Steps 12-16 locally as 5 atomic commits ([`3ffae6d`](#step-12--binary-response-builder--handler-override-wiring--test-4-green), [`055f67b`](#step-13--success-headers-cache-control--screenshot-formattargetwidthheight--test-5-green), [`f01e744`](#step-14--maxbytes-413-check-test-6-green), [`8acf02a`](#step-15--window-targeting-404409-tests-78-green), [`f33d3f7`](#step-16--failure-outcome-408500-mapping-tests-910-green)) NOT YET pushed (per user "Commit only, don't push yet" pattern), pushed Steps 10+11 commit ([`38da008`](#step-1011--test-seams--validation--tests-13-green-committed--pushed)) to origin, wrote [`scripts/screenshot-helper.ps1`](../scripts/screenshot-helper.ps1) (PowerShell System.Drawing capture per Oracle F3 verdict, standalone-verified byte-faithful **594KB 2560×1440 PNG** via .NET Process API), landed Step 17 Smalltalk wrapper on disk (3 new methods + handler restructure to merge override + subprocess paths) and got it filing-in cleanly **after a 90-minute debug saga** (root cause: `!` inside `"..."` comments breaks VW chunk parser), and **HIT A HARD BLOCKER on the production capture path** — `OS.ExternalProcess>>wait` does NOT actually wait synchronously in this image (verified: even trivial `cmd /c echo hello` returns exit=259 = Windows STILL_ACTIVE after `proc wait`; `isExited` returns proc not Boolean; `isActive` polled 200× at 50ms = 10s timeout still returns true for sub-100ms commands).

**For:** session-13 — (1) decide commit + push authorization for the 5 local-only commits (Steps 12-16) + this handoff; (2) decide commit shape for Step 17 partial work on disk (PowerShell helper script + Smalltalk wrapper that files-in but production capture is broken); (3) **find the correct subprocess wait mechanism for `OS.ExternalProcess` on this VW image** — candidates: (a) `execute:arguments:do:errorStreamDo:` one-shot pattern (likely handles wait internally; session-11 probe-f3-winprocess.st found it on both class-side and instance-side), (b) poll on `exitStatus ~= 259` using Windows STILL_ACTIVE as a "running" sentinel, (c) temp-file approach (subprocess writes PNG to disk, VW reads from disk — sidesteps stdout pipe entirely; Oracle F3 listed this as the documented fallback), (d) `shOne:`/`cshOne:` convenience selectors, (e) Oracle consult on `OS.ExternalProcess` semantics in this image; (4) once Step 17 unblocked, complete Steps 18-20 per the 20-step checklist (add `/screenshot` route at L526 + verify ByteArray socket-write at L402 + real-usage live PartySearch window capture + v0.9.0 → v0.9.1 bump + `testHealthReturnsCurrentVersion` assertion update); (5) the standing decisions remain Phase C (API freeze + OpenAPI spec), Phase D (auto-start), Phase E (Playwright SDK) per the [ROADMAP](../plan/ROADMAP-QUALITY-FIRST.md); (6) carry-overs from session-7+8+9+10+11 still pending (EXPLORATION-PLAN step 3, step 4, end-to-end #id/#imcNr/#groupScheme verify).

**Supersedes:** nothing. [`HANDOFF-2026-06-20-session11.md`](./HANDOFF-2026-06-20-session11.md) remains the session-11 EOD; this file is session-12 EOD.

---

## User direction in this session (session-12, condensed)

- Opened with the standard resume prompt: read 3 anchor docs ([HANDOFF-session-11](./HANDOFF-2026-06-20-session11.md), [vw-image-api-contract](./vw-image-api-contract.md), [PLAN-PHASE-F-SCREENSHOT](../plan/PLAN-PHASE-F-SCREENSHOT.md)), do Phase 0 verification (all green: bridge v0.9.0, token matches session-11 EOD, 0 commits ahead), surface 3 standing decisions.
- Picked **Phase F3 implementation steps 10-20** (over Phase C / D / E / carry-overs).
- Picked **Commit + push** for Steps 10+11 (combined commit `38da008` — tests #1 #2 #3 GREEN).
- Picked **Commit only, don't push yet** for Step 12 (`3ffae6d`).
- Picked **Commit only, don't push yet** for Step 13 (`055f67b`).
- Picked **Commit only, don't push yet** for Step 14 (`f01e744`).
- Picked **Commit only, don't push yet** for Step 15 (`8acf02a`).
- Picked **Commit only, don't push yet** for Step 16 (`f33d3f7`).
- Captured assertion message from VW debugger after Step 10 file-in (manually dismissed debugger): `'screenshot endpoint not implemented yet (RED until session-12 lands). Missing: OrderedCollection (''handleScreenshotBody:'')'` — confirmed Step 10 effect exactly as predicted.
- Asked to **update the session handoff** (this file).

Commit auth: **GRANTED for 6 atomic commits this session** (38da008 pushed; 3ffae6d, 055f67b, f01e744, 8acf02a, f33d3f7 local-only).

---

## Work completed in session-12

### Phase 0 — Resume verification (~3 min)

- `curl.exe -s http://127.0.0.1:9876/health` → `{"status":"ok","version":"0.9.0"}` ✓
- Token from [`.token`](../src/vw-bridge/.token): `3959443064454-247528` — matched session-11 EOD, `vwnt.exe` PID 5624 unchanged, no re-toggle of `Dialog useNativeDialogs: false` needed
- `wsl ... git log --oneline -10` + `git status`: clean, on `main`, up to date with `origin/main`, 5 session-11 commits visible (`9db8c05..869692f` pushed)
- `Get-Process vwnt` → PID 5624 started 6/20/2026 1:07:31 PM (SAME instance as session-9/10/11/12 — 4-session continuous run)
- Standing decision question presented with 5 options. User picked **Phase F3 impl steps 10-20**.

### Step 10+11 — test seams + validation — tests #1-#3 GREEN (committed + pushed)

#### Step 10 (~30 min)

- Edited [`VWBridge.st`](../src/vw-bridge/VWBridge.st) L21 instance var list: appended `screenshotCaptureOverride scriptedWindowsForScreenshot` (preserving trailing space convention).
- Added new `'screenshot helpers'` methodsFor: section right after `clearWaitOverrides` at L291, BEFORE `'initialization'` section. 3 methods:
  - `screenshotCaptureOverride: aBlock` (test seam setter)
  - `scriptedWindowsForScreenshot: anOrderedCollection` (test seam setter — INTENTIONALLY SEPARATE from `scriptedWindowSnapshots` so /wait + /screenshot tests don't interfere)
  - `clearScreenshotOverrides` (clears both seams to nil — sibling to `clearWaitOverrides`)
- File-in via wrapper expression `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn` → `{"ok":true,"result":"nil"}`.
- Token rotated (`3959443064454-247528` → `3959452362719-213255`).
- Verified via direct `respondsTo:` probe: `handleScreenshotBody:` → false (still missing — correct), `screenshotCaptureOverride:` → true ✓, `scriptedWindowsForScreenshot:` → true ✓, `clearScreenshotOverrides` → true ✓. Both ivars present in `VWBridge instVarNames`.
- Attempted SUnit test #1 run via /eval to confirm `ensureScreenshotImplemented` message → **/eval hung at 120s timeout**.
- **NEW CONSTRAINT DISCOVERED**: SUnit assertion failures via /eval pop the VW debugger window which blocks the serve-process. `on: Error do:` does NOT catch the assertion — it routes through the debugger UI. User manually dismissed the debugger and captured the assertion message: `'screenshot endpoint not implemented yet (RED until session-12 lands). Missing: OrderedCollection (''handleScreenshotBody:'')'` — EXACTLY as `ensureScreenshotImplemented` was designed to emit. Step 10 doubly verified.

#### Step 11 (~45 min)

- Added new `'screenshot handler'` methodsFor: section between end of `'wait handler'` (L2170, just after `waitTimeoutBodyFor:`) and SimpleDialog override comment (L2172). 4 new methods:
  - `handleScreenshotBody: aBodyString` — main entry: parse + validate, return 400/415 envelope on validation failure, return 500 `screenshot-not-yet-implemented` placeholder on validation success (capture path comes in Step 13).
  - `parseAndValidateScreenshotRequest: aBodyString` — F1-spec validation (target REQUIRED — no implicit `{type:screen}` default, so empty body `{}` returns 400; target.type ∈ `{'screen', 'window'}`; format default `'png'`, non-png → 415 `screenshot-unsupported-format`; maxBytes integer in `[1, 16777216]` (16 MiB cap); timeoutMs integer in `[1, 30000]`; window target REQUIRES `appClass` and/or `titleContains`).
  - `screenshotErrorWithCode:status:message:` — failure result Dictionary factory.
  - `jsonScreenshotErrorBodyFor:` — JSON envelope builder using `safeJsonFor:`.
- File-in clean, token rotated again.
- Verified via DIRECT INVOCATION (NOT SUnit, per Step 10 lesson):
  - Test #1 (empty body `{}`) → `HTTP/1.1 400 Bad Request` + body has `invalid-screenshot-request` ✓
  - Test #2 (`{"target":{"type":"screen"},"format":"jpg"}`) → `HTTP/1.1 415 Error` (cosmetic — reason chain didn't cover 415 yet; fixed in Step 12) + body has `screenshot-unsupported-format` ✓
  - Test #3 (`{"target":{"type":"screen"},"format":"png","maxBytes":0}`) → `HTTP/1.1 400 Bad Request` + body has `maxBytes` ✓
- **Tests #1 #2 #3 GREEN.** Logical commit breakpoint.
- Committed Steps 10+11 as single commit (related: ivars unlock seam-using tests later) `38da008` and pushed to origin (`869692f..38da008  main -> main`).

### Step 12 — binary response builder + handler override wiring — test #4 GREEN

- Refactored `httpResponse:type:body:` at L1865 to use new `httpReasonPhraseFor:` helper. Extended reason chain with 409 Conflict + 413 Payload Too Large + 415 Unsupported Media Type (all needed by /screenshot errors). Behavior unchanged for the 7 pre-existing codes (200/400/401/404/405/408/500). Side effect: Step 11 cosmetic "HTTP/1.1 415 Error" now reads "HTTP/1.1 415 Unsupported Media Type".
- Added `httpBinaryResponse:type:body:extraHeaders:` (4-arg) — builds entire response (status line + headers + body) as ONE ByteArray so high-byte values round-trip without character-encoding mangling that String-backed streams impose. Pre-sizes buffer to `body+512` for 16 MiB PNG efficiency. `aHeaderCollection` accepts pre-formatted `'Name: value'` strings (Step 13 will use this for X-VWBridge-Screenshot-Width/Height).
- Added `httpBinaryResponse:type:body:` 1-arg convenience (calls 4-arg with `extraHeaders: #()`).
- Added `appendAsciiString:toByteStream:` helper — splices ASCII strings into the binary response via `aWriteStream nextPut: ch asInteger` per character (caller responsibility ASCII-only; pre-validated request fields cannot reach headers via `parseAndValidateScreenshotRequest:`).
- Modified `handleScreenshotBody:` to invoke `screenshotCaptureOverride` first (test seam, `ok=true` path) returning `httpBinaryResponse: 200 type: 'image/png' body: pngBytes` on success. Falls through to 500 `screenshot-not-yet-implemented` placeholder when override absent OR returns non-`ok=true`. Failure outcome mapping (408/500) is Step 16; width/height headers are Step 13; production capture is Step 17.
- File-in clean.
- Verified via DIRECT INVOCATION: response class **ByteArray** size 137 (115-byte header + 22-byte body), status `HTTP/1.1 200 OK`, `Content-Type: image/png` + `Content-Length: 22`, body byte-for-byte equals `fakeBytes #[137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 255 254 0 1 128 127]` GREEN. High bytes (255, 254, 137, 128, 127) + null bytes (0) + embedded CRLF (13, 10) ALL preserved.
- **Test #4 (binary safety lock) GREEN.**
- DEFERRED to Step 18: `serve:` L402 actual ByteArray socket-write through external stream (builder verified; serve sibling assumed compatible via `lineEndTransparent` — session-11 probe-f3-subprocess.st confirmed for stdout, socket variant unproven until `/screenshot` HTTP route exists).
- Committed locally `3ffae6d` (per user "Commit only, don't push yet").

### Step 13 — success headers (Cache-Control + Screenshot-Format/Target/Width/Height) — test #5 GREEN

- 1-line swap in `handleScreenshotBody:` success branch: replaced 3-arg `httpBinaryResponse:type:body:` with 4-arg variant. Build extraHdrs `Core.OrderedCollection` with 5 F1 spec headers:
  - `Cache-Control: no-store` (prevent intermediary caching of forensic captures)
  - `X-VWBridge-Screenshot-Format: ` + spec.format
  - `X-VWBridge-Screenshot-Target: ` + spec.targetType
  - `X-VWBridge-Screenshot-Width: ` + outcome.width printString
  - `X-VWBridge-Screenshot-Height: ` + outcome.height printString
- All extras ASCII-only so `appendAsciiString:toByteStream:` splices them safely. Net diff +9/-1 lines.
- Verified via DIRECT INVOCATION: width=1920 height=1080 override → ByteArray response size 306, header section (280 bytes) contains HTTP/1.1 200 OK + Content-Type image/png + Content-Length 22 + Cache-Control no-store + X-VWBridge-Screenshot-Format png + X-VWBridge-Screenshot-Target screen + X-VWBridge-Screenshot-Width 1920 + X-VWBridge-Screenshot-Height 1080 ALL GREEN. Step 12 regression: body bytes still equal fakeBytes byte-for-byte ✓.
- **Test #5 (capture success + extent headers) GREEN.**
- Committed locally `055f67b`.

### Step 14 — maxBytes 413 check — test #6 GREEN

- Hoisted `pngBytes` + `maxBytes` extraction above the response build in `handleScreenshotBody:` success branch. Added post-capture size check: `pngBytes size > maxBytes ifTrue: [...413 + screenshot-too-large...]`. Per F1 spec NO automatic downscaling — pathological capture is REJECTED not silently corrupted (preserves forensic fidelity). Net diff +16/-2 lines.
- Verified via DIRECT INVOCATION:
  - TEST #6 (200B oversized + maxBytes=100) → resp class ByteString size 229 + `HTTP/1.1 413` + body contains `screenshot-too-large` + reason `Payload Too Large` (new phrase from Step 12 `httpReasonPhraseFor:` refactor) GREEN.
  - REGRESSION test #5 (22B + default maxBytes 16 MiB) → resp ByteArray size 306 with all expected headers + body byte-for-byte equals fakeBytes GREEN.
- **NEW API CONTRACT FINDING** (probe-side only — production builder unaffected): `ByteArray indexOfSubCollection: aString startingAt:` returns 0 because element types don't match (ByteArray holds Integer bytes, String holds Characters). For probe-side substring checks on binary responses, convert ByteArray header section to String character-by-character via `WriteStream-on-String + nextPut: (Character value: byte)` loop — this is the reverse direction of the `appendAsciiString:toByteStream:` helper from Step 12.
- **Test #6 (maxBytes 413) GREEN.**
- Committed locally `f01e744`.

### Step 15 — window targeting 404/409 — tests #7 #8 GREEN

- Added 2 new methods to 'screenshot handler' section (after `jsonScreenshotErrorBodyFor:`, before SimpleDialog override):
  - `resolveWindowRectForScreenshot: aSpec` — dispatches by `targetType`. For `'screen'` returns `{ok:true, rect:nil}` no-op (subprocess captures full virtual screen via `[SystemInformation]::VirtualScreen` in Step 17). For `'window'` filters `scriptedWindowsForScreenshot` test seam (priority — SEPARATE from `scriptedWindowSnapshots`) OR falls back to `windowsSnapshotForWait` production snapshot (already runs `onUIDo:` internally + shape-compatible) by appClass + titleContains. 0 matches → 404 `screenshot-window-not-found`, 2+ matches → 409 `screenshot-window-ambiguous` (NEVER first-match-wins per F1 spec — test-flake generator), exactly 1 match → `{ok:true, rect:windowDict}`.
  - `windowMatchesScreenshotFilter: aWindowDict appClass: aClassName titleContains: aTitleSubstring` — predicate. appClass case-SENSITIVE exact match (Smalltalk class names are case-significant — matches /windows handler). titleContains case-INSENSITIVE substring (matches /wait `evaluateWindowAppears:` convention for human-friendly matching).
- Modified `handleScreenshotBody:` to call `resolveWindowRectForScreenshot:` BEFORE invoking `screenshotCaptureOverride` — if resolution fails returns 404/409 error response immediately so override is NEVER called for failed window resolution (test #7 #8 explicit assertion `captureCalled = false`). On resolution success extracts rect from resolution dict and passes to override.
- Net diff +79/-4 lines.
- Verified via DIRECT INVOCATION:
  - TEST #7 (empty `scriptedWindowsForScreenshot` + `appClass='NoSuchApp'`) → resp ByteString size 248 + `HTTP/1.1 404` + `screenshot-window-not-found` + `Not Found` reason + captureCalled false GREEN.
  - TEST #8 (2 scripted windows with `appClass='TestApp'` + target appClass='TestApp') → resp ByteString + `HTTP/1.1 409` + `screenshot-window-ambiguous` + `Conflict` reason + captureCalled false GREEN.
  - REGRESSION test #5 (screen target with override) → resp ByteArray size 306 + captureCalled true GREEN (Step 13 success path preserved — resolve returns rect=nil, falls through to existing override invocation).
- **Tests #7 #8 (window targeting 404/409) GREEN.**
- Committed locally `8acf02a`.

### Step 16 — failure outcome 408/500 mapping — tests #9 #10 GREEN

- Restructured `handleScreenshotBody:` success/failure branch from single `ifTrue:` to `ifTrue:ifFalse:` so single `(outcome at: 'ok') = true` predicate handles both branches.
- New `ifFalse:` branch maps override's failure outcome dict to HTTP response: `outcome.status` → HTTP code, `outcome.error` → F1 error code in JSON envelope, `outcome.message` → human detail. Defaults conservative (status=500, error=`screenshot-capture-failed`, message=`unspecified capture failure`) for outcomes missing fields. Routes through same `screenshotErrorWithCode:status:message:` + `jsonScreenshotErrorBodyFor:` + `httpResponse:` pipeline as validation/window-resolution failures — single consistent envelope across all 7 F1 error codes:
  - 400 `invalid-screenshot-request`
  - 404 `screenshot-window-not-found`
  - 408 `screenshot-timeout`
  - 409 `screenshot-window-ambiguous`
  - 413 `screenshot-too-large`
  - 415 `screenshot-unsupported-format`
  - 500 `screenshot-capture-failed`
- Net diff +37/-25 (indentation noise inflates count from new `ifFalse:` block).
- Verified via DIRECT INVOCATION:
  - TEST #9 (status=408 error=screenshot-timeout) → resp ByteString size 207 + `HTTP/1.1 408` + `screenshot-timeout` + `Request Timeout` reason + captureCalled true (override DID run — failure-outcome path correctly triggers) GREEN.
  - TEST #10 (status=500 error=screenshot-capture-failed) → resp ByteString + `HTTP/1.1 500` + `screenshot-capture-failed` + `Internal Server Error` reason + captureCalled true GREEN.
  - REGRESSION test #5 (success path) → resp ByteArray size 306 + captureCalled true GREEN.
  - REGRESSION test #7 (404 window path) → resp ByteString + `HTTP/1.1 404` + captureCalled false GREEN (Step 15 short-circuit preserved).
- **🎉 ALL 10 RED TESTS FROM SESSION-11 NOW CONCEPTUALLY GREEN via direct-invocation verification.** Full SUnit suite confirmation via VW Workspace deferred (cannot run via /eval per Step 10 lesson).
- Committed locally `f33d3f7`.

### Step 17 — PowerShell helper script + Smalltalk subprocess wrapper (PARTIAL, BLOCKED)

#### scripts/screenshot-helper.ps1 — CLEAN, STANDALONE-VERIFIED

- Written per Oracle F3 verdict + session-11 carry-forward constraints:
  - `System.Drawing.Graphics.FromImage($bm).CopyFromScreen(...)` — NOT `FromHwnd` (composited desktop capture)
  - `[SystemInformation]::VirtualScreen` for full multi-monitor including negative coords
  - `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)` for binary stdout — NEVER `Write-Output` / `Write-Host` (text mangling)
  - Validated INT-only args via `[ValidateSet(...)][string]$Mode` + `[int]$X/$Y/$W/$H`
  - Exit codes: 0 success, 2 capture failure
  - Stderr for diagnostic INFO/ERROR messages
- Initial standalone test via PowerShell `>` redirection **FAILED**: bytes came out as `255,254,112,0,111,0,...` = UTF-16 LE BOM + "powersh..." text-encoded. Root cause: PowerShell `>` operator applies Out-File semantics with default text encoding (UTF-16 LE) EVEN when the inner subprocess uses `[Console]::OpenStandardOutput().Write()` for raw bytes — the parent PowerShell intercepts and re-encodes.
- Retry via **.NET Process API** (`ProcessStartInfo` with `RedirectStandardOutput=true` + `BaseStream.CopyTo`) — **PASSED**: exit 0, **594,293-byte PNG**, first 16 bytes `137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82` (PNG magic + IHDR start), **PNG IHDR width: 2560, height: 1440** (matches real monitor resolution), stderr clean INFO messages.
- **The PowerShell script itself is correct.** The byte-faithful redirection requires either the .NET Process API (what `OS.ExternalProcess` should do internally) OR `cmd /c "powershell.exe ..." > file` (cmd redirection is byte-faithful). Smalltalk-side `OS.ExternalProcess>>outputPipe` reads raw bytes from the OS pipe — should be byte-faithful too (when wait+drain actually works).

#### VWBridge.st — 3 new methods added + handler restructure (FILES-IN AFTER `!`-in-comments DEBUG)

- 3 new methods added to 'screenshot handler' section after `windowMatchesScreenshotFilter:`:
  - `screenshotHelperScriptPath` — hardcoded constant `'C:\Users\ammaganyane\tm\tm-context\scripts\screenshot-helper.ps1'` (same convention as `logFilePath`).
  - `pngExtentFromBytes: aByteArray` — parses PNG IHDR chunk: magic check at byte 1 (=137), width BE uint32 at bytes 17-20, height BE uint32 at bytes 21-24. Returns `Array with: w with: h` or `#(0 0)` on malformed input.
  - `captureScreenshotViaSubprocess: aSpec rect: aRect` — builds argList (with `-ExecutionPolicy Bypass -File <path> -Mode screen|window` + optional `-X -Y -W -H` for window target), creates `OS.ExternalProcess defaultClass new`, calls `lineEndTransparent` + `createInOutErrorPipes` + `startProcess: 'powershell.exe' arguments: argList asArray` + `wait` + drain `outputPipe upToEnd` + drain `errorPipe upToEnd` + read `exitStatus` + `release`. Maps non-zero exit OR empty stdout to `screenshot-capture-failed` failure outcome. On success normalizes to ByteArray + parses PNG IHDR for extent headers + returns `{ok:true, pngBytes, width, height}`.
- `handleScreenshotBody:` restructured to merge override + subprocess paths through ONE outcome handler:
  ```smalltalk
  outcome := screenshotCaptureOverride
      ifNotNil: [screenshotCaptureOverride value: spec value: rect]
      ifNil: [self captureScreenshotViaSubprocess: spec rect: rect].
  (outcome isKindOf: Core.Dictionary) ifFalse: [^... 500 catastrophic-non-dict ...].
  (outcome at: 'ok' ifAbsent: [false]) = true
      ifTrue: [... success path: maxBytes 413, extra headers, httpBinaryResponse: 200 ...]
      ifFalse: [... failure mapping: status/error/message → httpResponse ...]
  ```
- Removed orphaned `"Production capture path - lands in Step 17." ^self httpResponse: 500 ... '...not-yet-implemented...'!` placeholder from end of old `handleScreenshotBody:`.

#### Step 17 file-in DEBUG SAGA (~90 min, 6 narrowing iterations)

Initial file-in: `{"error":"eval_failed","message":"Syntax error: Unmatched comment quote ->"}`.

Hypothesis-driven narrowing:
1. **Non-ASCII chars** — ruled OUT (`[System.IO.File]::ReadAllBytes | Where -gt 127` returned 0).
2. **`handleScreenshotBody:` restructure** — ruled OUT (stubbed `handleScreenshotBody:` to 3-line `^self httpResponse: 500 ... '{"error":"stub"}'!`; error STILL reproduced).
3. **3 new methods as a chunk** — ruled OUT via addon test (wrote `step17-addon-only-new-methods.st` with just the 3 methods in `'screenshot helpers'` category — addon filed in clean: `{"ok":true,"result":"nil"}`). Caveat: addon's leading comment-only chunks initially produced "Nothing more expected ->" (different error confirming the API contract entry about leading comment-only chunks being rejected); stripped leading comments and re-tested.
4. **Method docstrings** — ruled OUT (replaced all 3 new method docstrings with `"X"` — error STILL reproduced).
5. **3 new methods inside the 'screenshot handler' section (vs addon's separate 'screenshot helpers' section)** — TESTED by removing all 3 new methods entirely (left handleScreenshotBody: stubbed) → file-in PASSED. **Bug is in one of the 3 new methods when added to the full-file context.**
6. **Inline body comments** — tried rewriting comments to remove special characters. SUCCESS when removing `!` characters.

**ROOT CAUSE**: My comment at L2496 of captureScreenshotViaSubprocess: body said `"Map outcome - exit != 0 OR empty stdout indicate subprocess failure"`. The `!=` contains a **`!`** which is the **VW chunk separator**. The chunk parser in this image treats `!` as a chunk boundary **EVEN INSIDE multi-line `"..."` comments**. So the chunk got split at `"Map outcome - exit !`, leaving the `"` unclosed at chunk end → "Unmatched comment quote".

**FIX**: Rewrote all comments in captureScreenshotViaSubprocess: body (and the new ones in handleScreenshotBody:) to remove `!` characters AND removed `+` separators in comment captions (rewrote as `and` for safety) AND removed `[SystemInformation]::` brackets in comments (defensive — brackets are fine but I was being paranoid):
- `"exit != 0"` → `"non-zero exit"`
- `"Build + launch subprocess"` → `"Build and launch subprocess"`
- `"Wait for exit + drain pipes ..."` → `"Wait for exit and drain pipes ..."`
- `"Map outcome - exit != 0 OR ..."` → `"Map outcome - non-zero exit OR ..."`
- `"Success - normalize to ByteArray + parse PNG IHDR ..."` → `"Success - normalize to ByteArray and parse PNG IHDR ..."`
- `"[SystemInformation]::VirtualScreen"` → `"SystemInformation VirtualScreen"`
- Also: `caller's maxBytes` → `caller maxBytes` (defensive — apostrophe should be fine inside `"..."` but stripped to match the file-in-clean state after retry)

File-in clean after the rewrite: `{"ok":true,"result":"nil"}`.

#### Step 17 real-usage verification — BLOCKED

- Invoked `bridge handleScreenshotBody: '{"target":{"type":"screen"},"format":"png"}'` with NO override set → fell through to `captureScreenshotViaSubprocess:` → launched PowerShell subprocess.
- Response: `HTTP/1.1 500 Internal Server Error` with body `{"error":"screenshot-capture-failed","message":"powershell exit=259; stderr="}`.
- **259 = Windows `STILL_ACTIVE`** (`GetExitCodeProcess` returns 259 for any process that has not yet exited).
- Empty stderr means the subprocess produced NO diagnostic output — either it never ran OR we read pipes BEFORE the subprocess wrote anything.

#### Step 17 subprocess API investigation — found the blocker

Reduced to simplest possible test: `cmd /c echo hello` via `OS.ExternalProcess`:
```smalltalk
proc := OS.ExternalProcess defaultClass new.
proc lineEndTransparent.
proc createInOutErrorPipes.
proc startProcess: 'cmd.exe' arguments: #('/c' 'echo' 'hello').
proc wait.
proc exitStatus  "→ 259 (STILL_ACTIVE)"
```
**Even trivial `cmd /c echo hello` returns exit=259 after `proc wait`.** So `wait` does NOT actually block until subprocess exit in this image.

Tested predicates:
- `proc isExited` → returns the proc itself (printString `'a WinProcess (Inactive)'`), NOT a Boolean. `[proc isExited] whileFalse:` raises "NonBoolean receiver — proceed for truth".
- `proc isActive` → returns Boolean `true` initially. Polled 200× at 50ms = 10s timeout on `cmd /c echo hello` (a command that completes in <100ms) → still `true`. **`isActive` never flips to false even though the subprocess HAS completed (per the proc's printString showing "Inactive").**

Confirmed selectors on `OS.WinProcess` matching wait/exit/active/state/done/finished/result/running:
- `wait` (returns immediately, doesn't actually wait)
- `exit` (send-exit-signal, not state-check)
- `exitStatus` (returns 259 STILL_ACTIVE for non-exited; presumably returns real code post-exit)

Session-11 probe-f3-winprocess.st listed `wait`/`isActive`/`isExited` as available — those selectors ARE present, but their BEHAVIOR doesn't match the expected synchronous-wait + Boolean-predicate semantics. **Session-11's API contract row for `OS.ExternalProcess` is INCOMPLETE/MISLEADING and needs revision.**

#### Step 17 candidate fixes for session-13

| Option | Description | Likelihood |
|---|---|---|
| (a) `execute:arguments:do:errorStreamDo:` one-shot | Documented as one-shot variant (both class-side AND instance-side per session-11). Probably handles wait + pipe drain internally per Topaz convention. Block signatures unknown — probe needed. | HIGH — try first |
| (b) Poll `exitStatus ~= 259` | Use Windows `STILL_ACTIVE` sentinel as "running" indicator. Hack but functional. Risk: 259 could legitimately be an exit code (very unlikely — reserved by Windows). | MEDIUM |
| (c) Temp-file approach | Subprocess writes PNG to a `[System.IO.Path]::GetTempFileName` path; PowerShell exits; VW reads file from disk. Sidesteps stdout pipe + wait sync entirely. Oracle F3 listed this as documented fallback for "VW subprocess API can't handle concurrent binary drain". | HIGH — guaranteed-works fallback |
| (d) `shOne:` / `cshOne:` convenience | Listed in session-11 probe as Windows-specific selectors. Might handle sync execution. | MEDIUM — Windows-specific, probe needed |
| (e) Oracle consult | Multi-system tradeoff analysis on OS.ExternalProcess semantics in this VW image. | Use if a/b/c/d all fail |

Recommended order: (a) → (c) (try one-shot first; fall to temp-file if one-shot has its own quirks).

---

## Current state (end of session-12)

- **VW image**: still up at `vwnt.exe` PID **5624**, started **6/20/2026 1:07:31 PM** (UNCHANGED across sessions 9/10/11/12 — 4-session continuous run, ~11 hours elapsed in real time).
- **Bridge**: UP at v0.9.0 on `127.0.0.1:9876`. **Token at session-12 EOD**: `3959455773663-433116` (rotated MANY times during session-12 — every Step 10-17 file-in caused `VWBridge start` to rotate). Re-read `.token` before any /eval after session-12 ends.
- **`Dialog useNativeDialogs: false`**: SET (carried from session-7+8+9+10+11). Resets on `vwnt.exe` restart.
- **Bridge code on disk**: Step 17 in-progress (3 new methods + handler restructure + handler subprocess wiring that DOESN'T WORK due to OS.ExternalProcess wait blocker). **UNCOMMITTED.** File-ins clean.
- **Bridge code in image**: matches disk (file-in'd after each successful step). Production subprocess capture path returns `500 screenshot-capture-failed` due to `exit=259` blocker.
- **SUnit on disk**: `VWBridge-ScreenshotTest.st` unchanged from session-11 (10 RED tests + 16 helpers). All 10 tests CONCEPTUALLY GREEN per direct-invocation verification (Steps 11-16).
- **SUnit in image**: matches disk. `VWBridgeScreenshotTest` 26 selectors, `VWBridgeTest` 21 selectors, `VWBridgeWaitTest` 37 selectors.
- **Image globals carried from session-10+11**: unchanged. `TEST_BUG2_YES_RET=true`, `TEST_BUG2_NO_RET=false`, `TEST_PURGE_TARGET_RET=true`.
- **MAS window state at EOD**: unchanged from session-11 EOD (no /click /menu/click /type interactions in session-12).
- **Git**: `main` is **5 commits ahead of `origin/main`** (Steps 12-16 local-only): `3ffae6d`, `055f67b`, `f01e744`, `8acf02a`, `f33d3f7`. Steps 10+11 pushed as `38da008`.
- **Untracked files**: [`scripts/screenshot-helper.ps1`](../scripts/screenshot-helper.ps1) (standalone-verified, byte-faithful via .NET Process API), [`src/vw-bridge/probes/step17-addon-only-new-methods.st`](../src/vw-bridge/probes/step17-addon-only-new-methods.st) (debug artifact from Step 17 saga — narrowed bug to "3 new methods in full-file context" vs addon).
- **Known bugs**: unchanged from session-10/11 (all #1-#6 FIXED). **NEW from session-12: production /screenshot subprocess capture path is non-functional pending Step 17 wait-mechanism fix.**
- **Known limitations**: carry from session-7..11 unchanged. NEW from session-12 (see "NEW carry-forward constraints" section below).

---

## NEW carry-forward constraints from session-12

**5 critical additions to add to [`vw-image-api-contract.md`](./vw-image-api-contract.md) at session-13 start.** All discovered the hard way this session.

### 1. `!` inside `"..."` comments breaks VW chunk parser

The VW chunk-format parser in this image treats `!` as a chunk separator **EVEN INSIDE multi-line `"..."` comments**. A comment like `"Map outcome - exit != 0 OR empty stdout indicate subprocess failure"` will silently produce **"Syntax error: Unmatched comment quote ->"** file-in errors because:
1. Parser reads `"Map outcome - exit ` as start of comment.
2. Hits `!` (from `!=`).
3. Treats `!` as chunk boundary, splits chunk mid-comment.
4. Comment never closes → next chunk starts inside an open comment state → cascading parse failure.

**ALWAYS rewrite comments to avoid `!`:**
- `!=` → `not equal to` / `non-zero` / `differs from`
- `!exists` → `does not exist`
- `foo!` (in comment text) → `foo` or `foo period`

Also affects single-line inline comments. The `'... text ...' printString` examples in comments that show `!` need rewriting.

**Cost in session-12**: ~90 min of hypothesis-driven narrowing. Could have been minutes if known.

### 2. SUnit test assertion failures pop the VW debugger when run via /eval

`self assert: false description: 'msg'` raises a `TestFailure` exception. The `on: Error do:` wrapper in /eval probe code does NOT catch it — instead the assertion routes through the VW debugger UI which **BLOCKS the /eval serve-process indefinitely** (until the debugger is manually dismissed).

**Symptoms**:
- /eval call times out at curl's default (120s) or your `--max-time`.
- Bridge is otherwise responsive (`/health` works fine).
- Bridge log shows no entries for the /eval call.
- A VW debugger window pops up on the host display.

**Workaround**: invoke production methods DIRECTLY via /eval (e.g., `bridge handleScreenshotBody: '{...}'`) and inspect the response. AVOID `(TestCase selector: #testFoo) run` and AVOID manual `setUp + performTest + tearDown` dances from /eval. For full SUnit suite GREEN confirmation, use a VW Workspace.

This is the source-of-truth pattern used in Steps 11-16 verifications.

### 3. `ByteArray indexOfSubCollection: aString startingAt:` returns 0 (type mismatch)

ByteArray elements are Integers (0-255). String elements are Characters. The 2-arg `indexOfSubCollection:startingAt:` fails to find matches when types differ (returns 0 = not found).

For substring checks on binary HTTP responses (where the response from `httpBinaryResponse:` is a ByteArray):
- Convert ByteArray header section to String first via:
  ```smalltalk
  hdrStr := WriteStream on: String new.
  1 to: hdrEnd do: [:idx | hdrStr nextPut: (Core.Character value: (resp at: idx))].
  "Now run substring checks on hdrStr contents (String, not ByteArray)"
  ```
- This is the REVERSE direction of the `appendAsciiString:toByteStream:` helper used in `httpBinaryResponse:` to splice ASCII headers INTO the binary response.

Production response builder (`appendAsciiString:toByteStream:` Character→Integer direction) is unaffected — only probe-side substring inspection has this gotcha.

### 4. `OS.ExternalProcess>>wait` does NOT actually wait synchronously in this image

**CRITICAL**: the session-11 probe-f3-winprocess.st API contract entry listing `wait`/`isActive`/`isExited`/`exitStatus` is MISLEADING. Those selectors EXIST but their BEHAVIOR doesn't match expected synchronous-wait + Boolean-predicate semantics:

| Selector | Documented (session-11) | Actual behavior (session-12) |
|---|---|---|
| `wait` | Block until process exits | **Returns immediately** without waiting |
| `isExited` | Boolean predicate | **Returns proc itself** (printString `'a WinProcess (Inactive)'`) — NOT a Boolean |
| `isActive` | Boolean predicate | Returns Boolean `true` initially. **NEVER flips to false** even after subprocess completes (verified: polled 200× at 50ms = 10s timeout on `cmd /c echo hello`, still `true`) |
| `exitStatus` | Integer exit code | Returns `259` (Windows `STILL_ACTIVE` = `0x103`) when called on a process that hasn't actually exited |

**Verified with trivial test**:
```smalltalk
proc := OS.ExternalProcess defaultClass new.
proc lineEndTransparent.
proc createInOutErrorPipes.
proc startProcess: 'cmd.exe' arguments: #('/c' 'echo' 'hello').
proc wait.
proc exitStatus  "→ 259 (STILL_ACTIVE)"
```

**Candidates for session-13 to find a working synchronous-wait mechanism** (in recommended trial order):
- **(a) `OS.ExternalProcess>>execute:arguments:do:errorStreamDo:`** (one-shot pattern, listed on both class-side AND instance-side in session-11 probe). Likely handles wait + pipe drain internally per Topaz convention. Block signatures need probing.
- **(b) Temp-file approach** — subprocess writes PNG to `[System.IO.Path]::GetTempFileName` path, exits; VW polls file existence then reads from disk. Sidesteps stdout pipe + wait sync entirely. Oracle F3 listed this as the documented fallback for "VW subprocess API can't handle concurrent binary drain".
- **(c) Poll `exitStatus ~= 259`** — use Windows `STILL_ACTIVE` sentinel as "running" indicator. Hack but probably functional.
- **(d) `shOne:`/`cshOne:` convenience selectors** — Windows-specific per session-11. Might handle sync execution.
- **(e) Oracle consult** — multi-system tradeoff analysis on `OS.ExternalProcess` semantics in this image.

### 5. PowerShell `>` redirection mangles binary stdout

PowerShell's `>` redirection operator applies **Out-File semantics with default text encoding (UTF-16 LE with BOM)** EVEN when the inner subprocess uses `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)` for binary-safe stdout. The parent PowerShell process intercepts and re-encodes.

**Symptom**: 594-byte PNG comes out as 1.17 MB file starting with `255,254,112,0,111,0,119,0,...` (UTF-16 LE BOM `0xFF 0xFE` + "powersh..." in UTF-16 LE).

**Byte-faithful redirection requires one of**:
- **(a) .NET Process API** (`ProcessStartInfo` with `RedirectStandardOutput=true` + `BaseStream.CopyTo`) — what `OS.ExternalProcess` uses internally per Win32 conventions.
- **(b) `cmd /c "..." > file`** — cmd redirection is byte-faithful (treats stdout as raw bytes).
- **(c) NOT PowerShell `>`** — always mangles.

**Verified standalone**: PowerShell screenshot-helper.ps1 via .NET Process API path → byte-faithful 594KB 2560×1440 PNG with proper magic + IHDR. Via `> file` → 1.17 MB UTF-16 LE garbage.

This is RELEVANT to Step 17 because if the eventual `OS.ExternalProcess` wait fix uses native pipes (most likely), production will be byte-faithful. If the fix uses temp-file path (option b above), the temp-file must be invoked via `cmd` not PowerShell.

---

## Pending tasks (session-13)

### Immediate on resume

1. **Restart `vwnt.exe`?** Bridge healthy at EOD (responds to /health). Image accumulated ~10 partial Step 17 file-ins + many subprocess test probes. No observed wedges. Restart NOT strictly required. If restarted: re-toggle `Dialog useNativeDialogs: false` via /eval (after first file-in), then file-in via VW Workspace in order: VWBridge.st → VWBridge-Test.st → VWBridge-WaitTest.st → VWBridge-ScreenshotTest.st.
2. **Verify state**: `curl.exe -s /health` → v0.9.0, re-read [`.token`](../src/vw-bridge/.token).
3. **Decide commit + push** for the 5 local-only commits (Steps 12-16): `3ffae6d`, `055f67b`, `f01e744`, `8acf02a`, `f33d3f7`. Plus this handoff.
4. **Decide commit shape** for Step 17 partial work on disk: PowerShell helper script (standalone-verified, clean) + Smalltalk wrapper (files-in clean BUT production capture broken). Either: (a) commit as "Step 17 partial: PowerShell helper + Smalltalk subprocess wrapper landed but production capture BLOCKED on OS.ExternalProcess wait — see session-12 handoff" with clear "DOESN'T WORK YET" markers in commit message; or (b) leave uncommitted until Step 17 fully works.

### Highest-value next directions

5. **Phase F3 Step 17 unblock** (per "NEW carry-forward constraint #4" candidates):
   - First try `execute:arguments:do:errorStreamDo:` one-shot pattern. Probe the block signatures, test with `cmd /c echo hello`, then with PowerShell screenshot helper.
   - If that doesn't work, try temp-file approach: PowerShell writes PNG to `[System.IO.Path]::GetTempFileName` path, exits; VW polls file existence then reads from disk via `Filename binaryReadStream` (need to probe binary-read API).
   - If neither works, Oracle consult on `OS.ExternalProcess` semantics + alternative subprocess invocation patterns in this image.

6. **Phase F3 Steps 18-20** (deferred until Step 17 unblocked):
   - **Step 18**: add `/screenshot` route to `doDispatch:` at L526 area in `VWBridge.st` POST routes section. Verify `serve:` socket-write at L402 accepts ByteArray (the binary response from `httpBinaryResponse:`). If `[stream nextPutAll: aByteArray]` mangles bytes on the socket stream, fix by building full response upstream as ByteArray + ensuring `lineEndTransparent` is set (already is) + possibly setting `encoding: #latin1` for 1:1 byte mapping.
   - **Step 19**: real-usage verify — capture live PartySearch window via `curl.exe -X POST http://127.0.0.1:9876/screenshot -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{"target":{"type":"window","appClass":"PartySearchView"},"format":"png"}' --output capture.png` + verify via PowerShell `[System.Drawing.Image]::FromFile('capture.png')` decode round-trip + visual inspection.
   - **Step 20**: v0.9.0 → v0.9.1 bump at 4 canonical sites in `VWBridge.st` + update `VWBridge-Test.st testHealthReturnsCurrentVersion` assertion. Standard release procedure.

7. **Phase C — API freeze + OpenAPI spec** (per roadmap). Lock down v0.9.1 surface (14 endpoints once /screenshot lands) before SDK work. Hand-write `docs/openapi.yaml` + CI drift check. ~4-6h. Natural follow to v0.9.1 ship.

8. **Phase D — Auto-start architecture** (still unblocked by session-9 parcel evidence + session-11 loadParcelFrom: confirmation). Three viable paths converge on "external trigger." Oracle consult on tradeoffs. ~1 session.

9. **Phase E — Playwright TypeScript SDK + 3 first tests** against v0.9.1 bridge. Depends on Phase C ideally.

### Carry-overs still pending (from session-7+8+9+10+11, none resolved this session)

10. **EXPLORATION-PLAN step 3** — 3-deep menu navigation.
11. **EXPLORATION-PLAN step 4** — leaf dispatch catalog across MAS menu tree.
12. **End-to-end verification of `#id` / `#imcNr` / `#groupScheme`** (no-modal partialFind: paths) — still UNVERIFIED via bridge per session-3 calibration.

### Production-grade packaging (medium-term — unchanged from session-11)

13. Log rotation (still).
14. Class-side log mutex for concurrent fork safety + Windows file-sharing race.
15. Env-var externalization of log path / .token path / port / parcel deployment path / **screenshot helper script path** (added: now there's a 4th hardcoded path).
16. Parcel build script — depends on Phase D decision.

---

## Proposed atomic commits for session-12 deliverables

Per session-3..11 atomic-commit convention.

### Committed THIS session (1 pushed, 5 local-only)

| # | Subject | Files | Status |
|---|---|---|---|
| 0 | `feat(vw-bridge): /screenshot endpoint scaffold steps 10+11 of PLAN-PHASE-F-SCREENSHOT.md - test seams (...) + request validation (...)` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+142/-1) | **PUSHED** as `38da008` |
| 1 | `feat(vw-bridge): /screenshot binary response builder + handler override wiring step 12 of PLAN-PHASE-F-SCREENSHOT.md test #4 GREEN binary safety lock - (...)` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+99/-27) | LOCAL `3ffae6d` |
| 2 | `feat(vw-bridge): /screenshot success headers (5 extras: Cache-Control + Screenshot-Format/Target/Width/Height) step 13 (...) test #5 GREEN` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+9/-1) | LOCAL `055f67b` |
| 3 | `feat(vw-bridge): /screenshot maxBytes 413 check step 14 (...) test #6 GREEN screenshot-too-large - (...)` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+16/-2) | LOCAL `f01e744` |
| 4 | `feat(vw-bridge): /screenshot window targeting 404/409 (resolveWindowRectForScreenshot: + windowMatchesScreenshotFilter:) step 15 (...) tests #7 #8 GREEN` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+79/-4) | LOCAL `8acf02a` |
| 5 | `feat(vw-bridge): /screenshot failure outcome mapping (408/500) step 16 (...) tests #9 #10 GREEN - completes all 10 SUnit tests (...)` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+37/-25) | LOCAL `f33d3f7` |

Net: **5 commits ahead of origin** at session-12 EOD. Push decision deferred to session-13 user authorization.

### Proposed for session-13 (NOT YET committed in session-12)

| # | Proposed subject | Files |
|---|---|---|
| 6 | `feat(screenshot-helper): PowerShell System.Drawing capture script for VWBridge /screenshot Step 17 — standalone-verified byte-faithful 594KB 2560x1440 PNG via .NET Process API; .ps1 uses [SystemInformation]::VirtualScreen + Graphics.CopyFromScreen + [Console]::OpenStandardOutput().Write for binary stdout (NOT Write-Output / Write-Host); ValidateSet param mode screen/window + INT-only X/Y/W/H args per Oracle F3 PS-injection mitigation; exit 0 success + exit 2 capture failure + stderr INFO/ERROR diagnostics` | [`scripts/screenshot-helper.ps1`](../scripts/screenshot-helper.ps1) (NEW) |
| 7 | `feat(vw-bridge): /screenshot Step 17 PARTIAL - PowerShell subprocess wrapper landed (3 new methods + handler restructure) BUT production capture BLOCKED on OS.ExternalProcess wait not actually waiting (cmd /c echo hello returns exit=259 STILL_ACTIVE after proc wait); 90-min DEBUG SAGA found root cause: ! inside "..." comments breaks VW chunk parser - fixed by rewriting comments (NEW CONSTRAINT added to vw-image-api-contract.md); 3 new methods (screenshotHelperScriptPath + pngExtentFromBytes: + captureScreenshotViaSubprocess:rect:) + handleScreenshotBody: restructured to merge override + subprocess paths through single outcome handler + removed orphaned not-yet-implemented placeholder; file-in clean; production capture returns 500 screenshot-capture-failed pending session-13 wait-mechanism fix (candidates: execute:arguments:do:errorStreamDo: one-shot OR temp-file OR poll exitStatus ~= 259)` | [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) (+~80/-~30 vs HEAD) |
| 8 | `probes: src/vw-bridge/probes/step17-addon-only-new-methods.st - debug artifact from Step 17 file-in saga; narrowed bug to "3 new methods in full-file context" vs addon (proved addon parses clean = bug is in full-file interaction); root cause turned out to be ! inside comments in captureScreenshotViaSubprocess: body. Kept for evidence trail.` | [`src/vw-bridge/probes/step17-addon-only-new-methods.st`](../src/vw-bridge/probes/step17-addon-only-new-methods.st) (NEW) |
| 9 | `docs: knowledge/vw-image-api-contract.md - session-12 5 NEW carry-forward constraints (! in "..." comments breaks chunk parser; SUnit assertion failures via /eval pop VW debugger blocking serve-process; ByteArray indexOfSubCollection: aString returns 0 due to element type mismatch; OS.ExternalProcess wait does NOT actually wait in this image - isExited returns proc not Boolean isActive never flips false; PowerShell > redirection mangles binary stdout via UTF-16 LE Out-File semantics)` | [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) (modified, ~+50 lines) |
| 10 | `docs: plan/PLAN-PHASE-F-SCREENSHOT.md - session-12 progress section: Steps 10-16 COMPLETED (all 10 SUnit tests conceptually GREEN via direct invocation); Step 17 PARTIAL with subprocess wait blocker (root cause: OS.ExternalProcess wait doesn't wait + isExited/isActive broken); Steps 18-20 deferred; 20-step checklist updated (16 done, 4 pending+1 partial); session-13 implementation roadmap` | [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) (modified, ~+80 lines) |
| 11 | `docs: HANDOFF-2026-06-20-session12 - Steps 10-16 GREEN (5 commits local-only + 38da008 pushed) + Step 17 PARTIAL (PowerShell helper standalone-verified; Smalltalk wrapper lands but production capture BLOCKED on OS.ExternalProcess wait) + 5 NEW carry-forward constraints (! in comments / SUnit debugger trap / ByteArray indexOfSubCollection type mismatch / OS.ExternalProcess wait broken / PowerShell > mangles binary) + session-13 roadmap (find wait mechanism then complete 18-20)` | [`knowledge/HANDOFF-2026-06-20-session12.md`](./HANDOFF-2026-06-20-session12.md) (THIS FILE) |

Recommended: bundle commits 6-11 into a coherent session-13 atomic-commit pass after the user picks the commit shape. OR split if Step 17 unblocks early and clean Step 17 commit lands separately from the docs.

---

## Important decisions (this session)

- **Phase F3 implementation over alternatives** — F3 had 5 commits-worth of momentum from session-11 (test scaffold + Oracle verdict + subprocess feasibility probes). Each step has a discrete test transition → clean commit breakpoint cadence. Alternative was Phase C/D/E which would interrupt the test-GREEN-streak.
- **Direct-invocation verification pattern for ALL Step 11+ tests** — after Step 10's hung /eval probe revealed SUnit assertion failures pop the VW debugger blocking the serve-process. Direct invocation of `bridge handleScreenshotBody:` + ByteArray/String inspection is the safe pattern. Lesson is now constraint #2.
- **Commit cadence: one commit per test-transition step** — matches user's explicit example ("after tests 1-3 GREEN, after test 4 GREEN, etc."). Steps 10+11 bundled (related: ivars unlock seam-using tests later, both produce "tests 1-3 GREEN"). Steps 12, 13, 14, 15, 16 individual.
- **Push Steps 10+11 immediately, batch Steps 12-16 locally** — user picked "Commit + push" for 10+11 then "Commit only, don't push yet" 5 times in a row. Pattern signals session-EOD push as preferred.
- **PowerShell standalone test via .NET Process API, NOT `>` redirection** — discovered `>` mangling on the first test attempt. Used .NET Process API which mimics OS.ExternalProcess production invocation, byte-faithful.
- **Hypothesis-driven narrowing for Step 17 file-in syntax error** — 6 iterations cost ~90 min. Each iteration ruled out a class of causes (non-ASCII, handler restructure, 3-new-methods-as-chunk, docstrings, 3-new-methods-in-context, inline comments). Final root cause: `!` in `"..."` comments. The "test the methods in isolation via addon" iteration was the KEY insight — when addon worked but full file didn't, the bug was clearly context-dependent.
- **NO commit for Step 17** — production capture path is BROKEN. Committing now would muddy git history. Wait for session-13 fix.
- **NO Oracle consult on Step 17 wait mechanism THIS session** — Oracle is appropriate when 2+ approaches have been tried. Session-12 has only tried `wait + exitStatus` (the documented pattern). Session-13 should try `execute:arguments:do:errorStreamDo:` and temp-file first, then Oracle if both fail.

---

## Key files

| File | Role |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | CANONICAL v0.9.0 — Steps 12-16 committed locally; Step 17 partial UNCOMMITTED on disk (3 new methods + handler restructure + handler subprocess wiring). File-ins clean. Production /screenshot capture broken pending Step 17 wait-mechanism fix. |
| [`scripts/screenshot-helper.ps1`](../scripts/screenshot-helper.ps1) | **NEW session-12 (UNTRACKED)** — PowerShell System.Drawing capture helper. Standalone-verified byte-faithful 594KB 2560×1440 PNG via .NET Process API. ValidateSet param mode + INT-only args per Oracle F3 PS-injection mitigation. Used by `captureScreenshotViaSubprocess:` once wait-mechanism is fixed. |
| [`src/vw-bridge/probes/step17-addon-only-new-methods.st`](../src/vw-bridge/probes/step17-addon-only-new-methods.st) | **NEW session-12 (UNTRACKED)** — Debug artifact from Step 17 file-in saga. Just the 3 new methods in a `'screenshot helpers'` methodsFor: section. Filed in cleanly (proving the 3 methods themselves parse OK). The bug was in the interaction with full-file chunks at the `!`-in-comments root cause. |
| [`src/vw-bridge/VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) | Unchanged from session-11 — 10 tests + 16 helpers. All 10 tests CONCEPTUALLY GREEN per direct-invocation verification (Steps 11-16). Full SUnit suite confirmation via VW Workspace pending. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold v0.9.0. 21 selectors. Unchanged session-12. `testHealthReturnsCurrentVersion` still asserts `"version":"0.9.0"` — update to `"version":"0.9.1"` atomic at Step 20. |
| [`src/vw-bridge/VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) | SUnit /wait tests v0.9.0 — 37 selectors. Unchanged session-12. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token. EOD value: `3959455773663-433116`. Rotated MANY times during session-12 file-ins. Re-read before any /eval at session-13 start. |
| [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log) | NDJSON log. Gitignored. Session-12 added many VWBridge stop/start entries (one per file-in) but no /wait /click etc. — only /eval invocations (which don't log by default). |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **PENDING session-13 update** — 5 NEW carry-forward constraints from session-12 to be added. READ FIRST before any new probe. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#6 — all FIXED. Unchanged session-12. NEW: production /screenshot subprocess capture BLOCKED on OS.ExternalProcess wait mechanism (Step 17). |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. Unchanged session-12. |
| [`knowledge/vw-input-recovery.md`](./vw-input-recovery.md) | Unchanged session-12. |
| [`knowledge/vw-dialogs.md`](./vw-dialogs.md) | Unchanged session-12. |
| [`knowledge/vw-eval-cookbook.md`](./vw-eval-cookbook.md) | **PENDING session-13 update** — should add session-12 lessons: avoid `!` in `"..."` comments, avoid SUnit-via-/eval (use direct invocation), `ByteArray indexOfSubCollection:` type-mismatch workaround. |
| [`knowledge/HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) | Session-8 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session9.md`](./HANDOFF-2026-06-20-session9.md) | Session-9 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session10.md`](./HANDOFF-2026-06-20-session10.md) | Session-10 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session11.md`](./HANDOFF-2026-06-20-session11.md) | Session-11 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session12.md`](./HANDOFF-2026-06-20-session12.md) | **THIS FILE.** Session-12 EOD. |
| [`plan/STRATEGIC-ASSESSMENT-2026-06-20.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-20.md) | Strategic snapshot. |
| [`plan/ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) | Quality-shaped phase roadmap. Phase F partial (F1+F2+F3-scaffold done session-11; F3-impl Steps 10-16 done session-12; F3-impl Steps 17-20 pending session-13). |
| [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) | Phase B plan. All done. |
| [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) | **PENDING session-13 update** — Steps 10-16 completed, Step 17 PARTIAL/BLOCKED, Steps 18-20 deferred. Add session-12 progress section + 20-step checklist update (16 done, 1 partial, 3 pending). |
| [`scripts/run-b4-surname-10x.ps1`](../scripts/run-b4-surname-10x.ps1) | Phase B4 driver from session-10. Unchanged. |

---

## Context for continuation (read this before resuming)

- **5 commits ahead of `origin/main`** (Steps 12-16). Push decision in session-13.
- **Step 17 work UNCOMMITTED on disk**: 3 new methods + handler restructure in `VWBridge.st` + scripts/screenshot-helper.ps1 written. File-in works cleanly AFTER fixing `!` in comments (root cause from 90-min debug saga — NEW CONSTRAINT #1).
- **Standalone PowerShell capture VERIFIED**: 594KB 2560×1440 PNG byte-faithful via .NET Process API. PowerShell `>` redirection MANGLES binary stdout (NEW CONSTRAINT #5).
- **Smalltalk-side `OS.ExternalProcess>>wait` BROKEN in this image** (NEW CONSTRAINT #4): even `cmd /c echo hello` returns exit=259 (STILL_ACTIVE) after `proc wait`. `isExited` returns proc not Boolean. `isActive` never flips false. Session-11 probe API contract is misleading on the BEHAVIOR (selectors are present, semantics don't match).
- **Find correct wait mechanism in session-13**: try `execute:arguments:do:errorStreamDo:` first (likely correct), fall back to temp-file approach (Oracle F3 documented fallback). Once production capture works, complete Steps 18-20.
- **All 10 SUnit tests CONCEPTUALLY GREEN** via direct-invocation verification. Full SUnit suite GREEN confirmation deferred to VW Workspace at some session EOD.
- **For ANY bridge change in v0.9.1+**: same protocol as session-11 (edit, file-in via /eval `asFilename fileIn` wrapper to avoid 'dispatch' substring, re-read .token, version bump 4 sites + test assertion when shipping). **ADDITIONALLY: avoid `!` inside `"..."` comments** (NEW CONSTRAINT #1) — will silently break file-in with "Unmatched comment quote".
- **For ANY new SUnit test class or seam addition**: `'path' asFilename fileIn` wrapper expression pattern. Avoid 'dispatch' substring in any comments. **AVOID SUnit-via-/eval** (NEW CONSTRAINT #2) — assertion failures pop the VW debugger which blocks the serve-process. Use direct-invocation verification of the production method + response inspection.
- **For ANY substring check on a binary HTTP response** (ByteArray): convert to String first via `WriteStream-on-String + nextPut: (Character value: byte)` loop (NEW CONSTRAINT #3). The 2-arg `indexOfSubCollection:startingAt:` mismatches type-wise (ByteArray Integers vs String Characters → returns 0).
- **For ANY subprocess invocation**: do NOT trust `OS.ExternalProcess>>wait` to actually wait (NEW CONSTRAINT #4). Use one of the candidate mechanisms (one-shot OR temp-file OR poll on `exitStatus ~= 259`). Session-13 will determine the canonical pattern.
- **For ANY PowerShell helper script**: emit raw bytes via `[Console]::OpenStandardOutput().Write(...)` AND invoke from cmd or .NET Process API for byte-faithful redirection (NEW CONSTRAINT #5). PowerShell `>` will mangle.
