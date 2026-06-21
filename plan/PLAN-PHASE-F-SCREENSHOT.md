# Plan — Phase F /screenshot endpoint

**Written:** 2026-06-20 (session-10), after Oracle F1 design consult + F2 graphics-API probe.
**Updated:** 2026-06-20 (session-11), Q1 resolved — Path A REFUTED across 6 probes. Oracle F3 verdict: Path B. TDD scaffold landed (10 RED tests + 16 helpers).
**Updated:** 2026-06-20 (session-12), Steps 10–16 GREEN via direct-invocation verification. Step 17 PARTIAL/BLOCKED on `OS.ExternalProcess>>wait`.
**Updated:** 2026-06-21 (session-13), Steps 17–20 COMPLETE. Bridge SHIPPED at v0.9.1 with `/screenshot` endpoint.
**Status:** **PHASE F3 SHIPPED.** All 20 steps done. v0.9.1 on `origin/main`.
**Pre-reqs:** v0.9.0 bridge with /wait endpoint shipped — DONE before this phase.

---

## Session-13 progress (Phase F3 SHIPPED)

| Step | Status | Commit |
|---|---|---|
| 17 — wait-mechanism fix | DONE — `OS.ExternalProcess execute:arguments:do:errorStreamDo:` one-shot + `outStream binary` flip | [`5a84f4a`](#) (fix) + [`ab068c2`](#) (probes) |
| 18 — `/screenshot` HTTP route + binary socket-write | DONE — route at `doDispatch:` L555 + `stream binary` flip for ByteArray responses at `serve:` L430 | [`82f0eb6`](#) |
| 19 — windowSummaries rect keys for window-target HTTP | DONE — added originX/originY/cornerX/cornerY integer fields (additive, bounds printString preserved) | [`38a56c6`](#) |
| 20 — v0.9.0 → v0.9.1 bump | DONE — banner + history paragraph + /health + testHealthReturnsCurrentVersion | [`8f03710`](#) |

End-to-end verification at session-13 EOD:

- `curl /health` → `{"status":"ok","version":"0.9.1"}`
- `POST /screenshot {target:{type:screen}}` → 200 OK + image/png + 855KB + PNG magic + System.Drawing decodes as 2560×1440 Format32bppArgb
- `POST /screenshot {target:{type:window,appClass:MasLauncher}}` → 200 OK + 27KB + 831×322 matching MasLauncher bounds + System.Drawing decode clean

Two new carry-forward constraints added to [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md):

- (6) `OS.ExternalProcess execute:arguments:do:errorStreamDo:` one-shot pattern + `outStream binary` is the working synchronous-wait + binary stdout mechanism (resolves session-12 constraint #4).
- (7) `ExternalReadAppendStream nextPutAll: aByteArray` raises "Strings only store Characters" — flip stream to `binary` first.

Full session details in [`knowledge/HANDOFF-2026-06-21-session13.md`](../knowledge/HANDOFF-2026-06-21-session13.md).

---

## Session-11 progress

### Q1 RESOLUTION — Path A REFUTED

Resolved via 6 probes in session-11. Summary table:

| Probe | Finding |
|---|---|
| `Kernel.Parcel parcels` and `parcelNames` | Both return identical 112-element List → **`parcelNames` is LOADED-only** (essentially `parcels collect: #name`); does NOT scan filesystem. New API contract row. |
| Filesystem scan `C:\visualworks931\` recursive `*.pcl` | 425+ parcels across canonical `parcels\`, `preview\`, `packaging\`, `contributed\`, `seaside\`, etc. Only **1 name-match candidate**: `preview\64-bit\ImageWriter.pcl` (65 KB) |
| `ensureLoadedParcel: 'ImageWriter' withVersion: nil` | FAILED with `ParcelMissingError` (empty message) — name cache empty for unloaded parcels |
| `findParcelNamed:` / `parcelNamed:` for unloaded names | Both return `nil` — confirms cache is LOADED-only; no on-demand filesystem scan |
| `loadParcelFrom: '...\ImageWriter.pcl' asFilename` | **SUCCEEDED** (+1 parcel, returned `Parcel parcelNamed: 'ImageWriter'`) but **0 new bindings** in any namespace, 0 new selectors on `Graphics.Image` |
| Parcel introspection: `pcl summary` + `pcl comment` | Revealed `ImageWriter.pcl` is the **64-bit VM-snapshot converter** (defined classes `VirtualImage`, `McCartneyImage`, `VirtualImageBytes`, `SixtyFourBitVirtualImage`, `HugeArray`). Comment: *"image conversion framework which can read virtual image files and write them out... convert 32-bit virtual images to 64-bit"*. NOT a pixel encoder. Zero-diff explained: classes already resident in `storedev64.im` (itself a 64-bit-converted image). |

Image-wide hunt across all 312 namespaces / 10,216 bindings:
- `*ImageWriter*` | `*ImageEncoder*` | `*BitmapWriter*` | `*BMPWriter*` | `*TIFF*` | `*WebP*` → **count = 0** (NOTHING)
- `Graphics.ImageReader` subclasses: `JPEGImageReader`, `XBMImageReader`, `PNGImageReader`, `BMPImageReader`, `GIFImageReader` → **5 readers, ZERO writer peer**
- `Graphics.ImageReader` instance methods matching `write|put|encode|store|emit|stream` → **count = 0**
- `Graphics.PNGImageReader` 41 instance + 3 class-side selectors: ALL decode/filter/chunk-process (`copyPixelsRGB:`, `filterPaeth:`, `processIDATChunk`, `readImage`); ZERO write methods
- `LibJPEG-turbo` (LOADED) 5 classes: `JPEGColorComponent`, `JPEGHuffmanTable`, `JPEGImageReader`, `LibJPEGTurboInterface`, `LibJPEGTurboInterfaceDictionary` — **DECODE ONLY** despite libjpeg-turbo upstream supporting encode

Cleanup: `Kernel.Parcel unloadParcelNamed: 'ImageWriter'` → returned `true`, baseline (112 parcels) restored. ✓

**VERDICT: No pixel-image-encoder exists anywhere in this VW 9.3.1 image. Path A is DEAD.**

### Loaded primitives potentially relevant for Path C (hand-rolled PNG)

- `Compression-Zip` (LOADED) — Zip format framework with DEFLATE
- `Compression-ZLib` (LOADED) — raw zlib (PNG IDAT compression layer)
- `HashesBase` (LOADED) — likely contains CRC32 (PNG chunk integrity check)
- `Xtreams-Compression` (LOADED) — alternative streaming compression
- Binary `WriteStream` availability unknown — needs probe (deferred until path decision)

### Capture-side (Q2) status

NOT resolved yet. But if Oracle picks Path B, Q2 collapses entirely (subprocess does capture + encode in one call).

### Oracle F3 verdict — Path B (PowerShell System.Drawing subprocess)

Oracle F3 returned (bg_3e72b537, 2m 16s) with high confidence + 7-section implementation plan. **Path C eliminated** because it still lacks a Smalltalk-side capture primitive — would degrade into "subprocess capture + Smalltalk encode" which is strictly worse than letting .NET do both.

Key Oracle decisions:
- **Window resolution stays in VW**. Resolve `appClass`+`titleContains` in Smalltalk, return 404/409 BEFORE invoking PowerShell.
- **NEVER concatenate strings into PowerShell source**. Pass only validated INT rectangle coords + mode.
- **Capture via `Graphics.FromImage($bitmap).CopyFromScreen(...)`** — NOT `FromHwnd`. Captures the composited desktop rectangle.
- **Bytes channel**: PowerShell `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)`. NOT `Write-Output`/`Write-Host`/pipeline (text-mangling risk).
- **Multi-monitor**: Full virtual screen by default via `[SystemInformation]::VirtualScreen`, including negative `Left`/`Top` coords.
- **Q3 (UI isolation) confirmed**: zero UI work for screen target; window target needs quick `onUIDo:` snapshot for window-resolution; subprocess does capture+encode on serve-process.
- **DPI awareness**: live-probe risk. If `view displayBox` vs PowerShell coords disagree on scaled monitors, add DPI-aware call in PS helper.
- **Effort estimate**: 1-2 focused sessions.

Test seam refinement (revised):
- `screenshotCaptureOverride` returns a **Dictionary** (not just bytes): `{ok:true, pngBytes, width, height}` on success / `{ok:false, status, error, message}` on failure.
- `scriptedWindowsForScreenshot` **separate** from `scriptedWindowSnapshots` so /wait + /screenshot tests don't interfere.
- Fake PNG bytes in tests MUST include null + high-byte values (lock binary safety from test #1).

Sharp edges (with Oracle's mitigations):
| Edge | Mitigation |
|---|---|
| HWND/window race | Resolve rect immediately before capture; v1 accepts "visible pixels at that rectangle" |
| Occlusion/minimized windows | `CopyFromScreen` is composited desktop; document limitation; PrintWindow/DWM as later escalation |
| PowerShell injection | Resolve appClass/titleContains in VW; pass only validated mode/INT coords to subprocess |
| Binary stdout drain | Temp PNG file fallback if VW subprocess API can't handle concurrent binary drain |
| DPI scaling mismatch | Probe live; add DPI-aware call in PS helper if VW displayBox vs PS coords disagree |

### Subprocess API + binary stream probe RESULTS (session-11)

Two probes (`_probe-f3-subprocess.st` + `_probe-f3-winprocess.st`) confirmed Oracle's Path B is fully feasible in this image:

| Probe | Finding |
|---|---|
| Class hunt across all 312 namespaces for subprocess candidates | **`OS.WinProcess`** (Windows-specific, 24 inst + 5 class-side) + **`OS.ExternalProcess`** (cross-platform parent, 43 inst + 20 class-side) BOTH PRESENT |
| `OS` namespace enumeration | 117 classes including `Stdin`/`Stdout`/`Stderr`, `StandardIOStream`, `StandardIOSubsystem`, `ExternalReadStream`/`ExternalWriteStream`/`BufferedExternalStream`, `PCPipeAccessor`, `UnixProcess` (Unix peer), `OSHandle`, full `SocketAccessor` family |
| `OS.ExternalProcess` key API | `execute:arguments:do:errorStreamDo:` (one-shot with stream blocks), `createInOutErrorPipes`, `inputPipe`/`outputPipe`/`errorPipe`, `readStream`/`writeStream`, `fork:arguments:`/`startProcess:arguments:`, `wait`/`isActive`/`isExited`/`exitStatus`, `kill`/`kill:`/`exit`, `defaultClass` factory, **`lineEndTransparent`** (binary-safe stdout knob), `encoding:` |
| `OS.WinProcess` adds | `quoteArgument:` (security knob for safe argument escaping), `useOEMEncoding`/`oemEncoding`, `executeCommand:`/`executeSingleCommand:`, `getCommandLineInterpreter`, Windows-specific reaping |
| ByteArray WriteStream binary sanity | `WriteStream on: (ByteArray new: 16)` → 8 `nextPut:` of PNG magic bytes 0x89/0x50/0x4E/0x47/0x0D/0x0A/0x1A/0x0A → `ws contents class = ByteArray`, contents = `#[137 80 78 71 13 10 26 10]` — **PERFECTLY BINARY-SAFE** |
| WriteStream subclasses | 7 total including **`DeflateStream`** and **`GZipWriteStream`** (Path C fallback if ever needed) |

### Bridge architecture findings (from VWBridge.st reads)

| Aspect | Finding |
|---|---|
| `httpResponse:type:body:` at L1837 | Uses `out := Core.WriteStream on: Core.String new` (STRING not ByteArray) + `out nextPutAll: bodyString`. **Text-only, would mangle binary.** Need sibling `httpBinaryResponse:type:body:` returning ByteArray. |
| Routing layer at L460-543 | `dispatch:headers:body:` wraps `doDispatch:headers:body:` with Bug #5 Stage 2 re-entry guard. Add `/screenshot` route at L526 area (POST section): `path = '/screenshot' ifTrue: [^self handleScreenshotBody: bodyString]` |
| Socket-write at L384/L402 | `[stream nextPutAll: response] on: err do: [:ex | nil]` — assumes String. For binary, need confirmed-binary socket-write path or build full response (header bytes + body bytes) as one ByteArray upstream |
| `serve:` listener loop at L315-353 | `listenerLoop` forks per-connection process from `listener accept`. Each `serve:` runs on its own forked process — blocking is safe |
| Existing OS/Subprocess refs | NONE in current bridge code. Path B will be the first OS-side integration. |

### TDD scaffold LANDED (session-11)

`src/vw-bridge/VWBridge-ScreenshotTest.st` written + filed-in via `'path' asFilename fileIn` wrapper. Verification confirms:
- Class loaded: `VWBridgeScreenshotTest`, superclass `TestCase`, category `'VW-TestBridge-ScreenshotTests'`, **26 total selectors**
- **10 RED test methods** (3 validation + 1 binary response + 1 capture success + 1 size cap + 2 window targeting + 1 timeout + 1 capture failure — covers all 8 Oracle steps + 2 validation sub-cases)
- **16 helpers**: `setUp`, `tearDown` (defensive — checks `respondsTo: #clearScreenshotOverrides`), `ensureScreenshotImplemented` (uniform RED message), `screenshotResponseFor:`, `statusLineOf:`, `bodyOf:`, `bodyContains:in:`, `headerContains:in:`, `fakePngBytesIncludingNullsAndHighBytes` (includes 0x00 + 0xFF + 0x89 for binary safety lock), `fakeOversizedPngBytesOfSize:`, `fakeSuccessResultWithBytes:width:height:`, `fakeFailureResultStatus:error:message:`, `windowRectSnapshotAppClass:titleContains:origin:corner:`, `windowRectSnapshotAppClass:titleContains:id:`, `withScreenshotCaptureOverride:do:`, `withScriptedScreenshotWindows:do:`
- Spot-check: `(VWBridgeScreenshotTest selector: #testScreenshotRejectsBadRequest) run` → **`1 run, 0 passed, 1 failed, 0 errors`** ← clean RED via `ensureScreenshotImplemented` (NOT doesNotUnderstand error)

### Session-12 implementation roadmap (per Oracle's TDD order)

Each step turns the matching test(s) GREEN.

1. **Test seam ivars on VWBridge**: add `screenshotCaptureOverride` + `scriptedWindowsForScreenshot` to instance vars at L21, plus accessors + `clearScreenshotOverrides` clearing both. This alone moves `ensureScreenshotImplemented` past the "Missing" check (still RED until handler exists).
2. **`parseAndValidateScreenshotRequest:`** + 400/415 error envelope helpers → tests #1, #2, #3 GREEN.
3. **`httpBinaryResponse:type:body:`** returning ByteArray (header bytes + body bytes) + ensure `serve:` socket-write accepts ByteArray → test #4 GREEN (binary safety locked).
4. **`handleScreenshotBody:`** core flow: validate → resolve window if window target → invoke override or production capture → emit response → test #5 GREEN.
5. **`maxBytes` check after capture** → test #6 (413) GREEN.
6. **`resolveWindowRectForScreenshot:`** with 404/409 paths → tests #7, #8 GREEN.
7. **Map failure outcomes** (`status` field) to HTTP status codes → tests #9 (408), #10 (500) GREEN.
8. **PowerShell helper script** (`screenshot-helper.ps1` or inline `-Command` string) using `[SystemInformation]::VirtualScreen` + `Graphics.FromImage($bm).CopyFromScreen(...)` + `Bitmap.Save(stream, ImageFormat.Png)` + `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)`. Validated INT-only args, `quoteArgument:` for safety.
9. **`captureScreenshotViaSubprocess:`** using `OS.ExternalProcess defaultClass new` → `lineEndTransparent` → `createInOutErrorPipes` → `startProcess:arguments:` → drain `outputPipe contents` → `wait` → check `exitStatus`. Or use `execute:arguments:do:errorStreamDo:` one-shot if ergonomics suit.
10. **Add `/screenshot` route to dispatch** at L526 area.
11. **Real-usage verification**: capture live PartySearch window via bridge, verify bytes decode as valid PNG (e.g., via PowerShell `[System.Drawing.Image]::FromStream($ms)` round-trip), visual inspection.
12. **Bridge version bump v0.9.0 → v0.9.1** at 4 canonical sites + update `testHealthReturnsCurrentVersion`.

---

## Bottom line

Per Oracle F1 synthesis: ship **`POST /screenshot` returning raw `image/png` bytes** on success, JSON error envelope on failure. Full virtual screen by default; optional deterministic window targeting via `appClass` + `titleContains`. PNG only. **16 MiB encoded cap** with `413 screenshot-too-large` on exceed (no automatic downscaling). Sync.

**Status (session-11 EOD)**: Q1 fully resolved (Path A REFUTED); Oracle F3 picked **Path B** (PowerShell System.Drawing subprocess) with high confidence; subprocess + binary-stream APIs probed and confirmed viable (`OS.WinProcess` + `OS.ExternalProcess` + `lineEndTransparent` + `quoteArgument:` + ByteArray WriteStream binary-safe); bridge architecture mapped (need `httpBinaryResponse:` sibling); **TDD scaffold landed** (10 RED tests in image, all clean-RED via `ensureScreenshotImplemented`). Session-12 implementation roadmap below (Oracle's 12-step TDD order).

---

## Oracle F1 design consult (bg_2975229b, 1m 29s)

### Encoding choice: binary `Content-Type: image/png`

| Option | Verdict | Reason |
|---|---|---|
| (a) Base64 PNG inline in JSON | Reject | ~33% inflation, JSON parser memory pressure on multi-MB strings |
| (b) File-on-disk + path returned | Reject | Path negotiation, file cleanup lifecycle, security concerns |
| (c) Binary `image/png` response | **CHOSEN** | Single roundtrip, smallest size, fits Playwright-SDK byte-stream consumption |
| (d) Two-endpoint job-id + binary follow-up | Reject | Adds state, no real benefit for failure-report use case |

Tradeoff accepted: breaks the existing JSON-success envelope convention. Errors still use JSON envelope with proper HTTP status (415 / 408 / 413 / etc.).

### Size cap

- **Default and hard cap: 16 MiB** encoded PNG (`16777216` bytes).
- Optional request field `maxBytes` (range `1..16777216`).
- Encoded PNG exceeds cap → `HTTP 413 screenshot-too-large` with JSON error.
- **No automatic downscaling** — preserves forensic fidelity, simpler implementation. Pathological case rejected, not silently corrupted.

### Sync vs async: SYNC

Listener already forks per-request, so blocking the serve-process is consistent with the 13 existing endpoints. Async job state / polling / expiry / cleanup is unjustified complexity for failure-report screenshots.

**Implementation discipline:** only the actual screen-capture primitive runs through `onUIDo:`. PNG encoding and HTTP byte-writing happen back on the serve-process to minimize UI-thread blocking.

### Scope flexibility for v1

| Feature | v1 ship | Notes |
|---|---|---|
| Full virtual screen (default) | ✓ | Captures all monitors at native resolution |
| Single MAS window by `appClass` + `titleContains` | ✓ | Filter must resolve to exactly one window |
| Arbitrary `{x,y,w,h}` region | Defer | No measured need for failure reports |
| All MAS windows tiled into composite | Defer | Multi-capture composition complexity |
| Multiple back-to-back captures | Defer | Sync model is one-shot |

### Format

- **PNG only in v1.**
- Request may include `"format":"png"` for forward compatibility.
- Reject any other format value (400). Do not add JPEG/WebP/quality until measured pressure forces it.
- Lossy formats are poor defaults for text-heavy financial UI + visual diagnosis.

### Concrete API shape

```http
POST /screenshot
Authorization: Bearer <token>
Content-Type: application/json
Accept: image/png
```

Full-screen body (all fields optional):
```json
{
  "target": {"type": "screen"},
  "format": "png",
  "maxBytes": 16777216,
  "timeoutMs": 10000
}
```

Window-target body:
```json
{
  "target": {
    "type": "window",
    "appClass": "PortfolioView",
    "titleContains": "Portfolio"
  },
  "format": "png",
  "maxBytes": 16777216,
  "timeoutMs": 10000
}
```

Validation rules:
- `target.type` ∈ `{"screen", "window"}` (default: `"screen"`)
- `window` target must include at least one of `appClass` / `titleContains` (deterministic filter)
- Window filter must resolve **exactly one** current window
- `format` must be `"png"`
- `maxBytes` positive integer, ≤ `16777216`
- `timeoutMs` positive integer, recommended max `30000`

Success response:
```http
HTTP/1.1 200 OK
Content-Type: image/png
Content-Length: <bytes>
Cache-Control: no-store
X-VWBridge-Screenshot-Format: png
X-VWBridge-Screenshot-Target: screen
X-VWBridge-Screenshot-Width: <pixels>
X-VWBridge-Screenshot-Height: <pixels>

<raw PNG bytes>
```

Error responses (JSON body, conventional shape):
- `400 invalid-screenshot-request` — validation failure
- `404 screenshot-window-not-found` — window filter resolved zero matches
- `409 screenshot-window-ambiguous` — filter resolved multiple matches
- `408 screenshot-timeout` — capture exceeded `timeoutMs`
- `413 screenshot-too-large` — encoded PNG exceeds `maxBytes`
- `415 screenshot-unsupported-format` — `format` field not `"png"`
- `500 screenshot-capture-failed` — capture primitive raised error

### Test strategy (per existing seam convention)

Production ivars on `VWBridge` (nil by default, settable from test fixture only):

| Seam | Purpose |
|---|---|
| `screenshotCaptureOverride` | Block returning fake PNG bytes + extent metadata, or simulating capture failure |
| `scriptedWindowsForScreenshot` | Fake `/windows`-shape snapshots for window-resolution tests |

Plus reuse of existing `clockOverride` / `sleepOverride` if timeout logic is outside the capture primitive.

8 core tests (per Oracle):
1. Valid default request → 200 + `Content-Type: image/png` + exact fake bytes
2. Invalid `format` / `target.type` / negative `maxBytes` / huge `timeoutMs` → 400 JSON envelope
3. Fake PNG > `maxBytes` → 413 with `screenshot-too-large`
4. Window target with zero matches → 404
5. Window target with multiple matches → 409
6. Capture override simulating timeout → 408
7. Capture override simulating generic failure → 500
8. Direct-dispatch test: `/screenshot` reaches handler without recursive HTTP

### Sharp edges flagged by Oracle

1. **UI freeze risk** — only the pixel-grab runs on UI process. PNG encoding + HTTP write happen on serve-process.
2. **Bug #5 re-entry** — `/screenshot` must call window-resolution / capture methods directly from dispatch. NEVER recurse through `dispatch:`.
3. **Stripped sources** — keep discovery-driven. Public API should not leak VW-internal capture-class names.
4. **Memory pressure** — avoid base64 + avoid intermediate file paths. Byte stream straight to socket. Release large image objects promptly.
5. **Window-target determinism** — ambiguous match is `409`, NEVER "first match wins" (test-flake generator).

---

## Phase F2 probe findings (read-only /eval)

### Top-level class availability

| Class | Status | Notes |
|---|---|---|
| `Image` (= `Graphics.Image`) | ✓ present | 99 instance selectors |
| `Screen` (= `Graphics.Screen`) | ✓ present | Superclass `HostGraphicsDevice`. 80 instance selectors. |
| `GraphicsContext`, `GraphicsDevice`, `GraphicsHandle` | ✓ present | Drawing API |
| `Pixmap` | ✓ present | In-memory bitmap |
| `ScheduledWindow`, `Window` | ✓ present | (already used by /windows) |
| `Graphics.HeadlessScreen` | ✓ present | Headless rendering possible |
| `ImageReader` (= `Graphics.ImageReader`) | ✓ present | Decoder base class |
| `PNGImageReader` (= `Graphics.PNGImageReader`) | ✓ present | PNG decoder; superclass `ImageReader` |
| `Display`, `BitBlt`, `Form`, `DisplayMedium`, `HostWindow`, `ScreenCapture` | ✗ ABSENT | Standard VW APIs not here |
| `ImageWriter`, `PNGReadWriter`, `JPEGReadWriter`, `BMPReadWriter` | ✗ ABSENT | **No image WRITER classes** |
| `Pen`, `HostPrinter` partial | minimal | Drawing-output minimal |

Full namespace walk found 44 `Image|Screen|Capture|PNG|Graphics*` classes — mostly Depth-N-Image variants and graphics-context implementations.

### PNG encoding path — OPEN QUESTION (the blocker)

**No PNG writer class exists in this image as currently loaded.**

- `Graphics.PNGImageReader` — class-side selectors `#(canRead: defaultPalette initialize)`. Read-only.
- `Graphics.PNGInflateStream` — decode stream. No `nextPut:`-style writer.
- Walked all `*PNG*` symbols across all namespaces — both are readers; neither has `write*` / `put*` / `store*` class-side selectors.
- `Image` instance methods matching `write|encode|png|output|storeOn`: ONLY `storeOn:` (the Smalltalk literal serializer — writes Smalltalk source for `Image extent:depth:palette:bits:`, NOT PNG bytes).

### Capture path — OPEN QUESTION (secondary blocker)

- `Image class fromUser` exists but is **interactive** (user clicks to select region, returns Image). Not headless.
- `Image class openOnImageFromUser`, `openOnRotatedImageFromUser` — also interactive.
- `Screen` instance selectors matching `capture|snap|image|bound|region|pixel|extent`: ONLY `bounds`, `boundsAround:`, `boundsAround:ifNone:` (read screen geometry). NO pixel-data accessor.
- `HostGraphicsDevice` (Screen superclass, 20 instance selectors): NONE match capture/snap/image/bound/region.
- `Window` / `ScheduledWindow` / `ApplicationWindow` capture selectors: ALL EMPTY.

### Class-side method index on `Image`

```
cincomSmalltalkLogo
extent:depth:bitsPerPixel:palette:
extent:depth:bitsPerPixel:palette:usingBits:
extent:depth:palette:
extent:depth:palette:bits:
extent:depth:palette:bits:pad:
extent:depth:palette:usingBits:
fromUser                          ← interactive
implementorForDepth:
leftArrow
openOnFastRotatedImageFromUser    ← interactive viewer
openOnImageFromUser               ← interactive viewer
openOnLogo                        ← demo
openOnRotatedImageFromUser        ← interactive viewer
rightArrow
toolListIcon
```

`Image extent:depth:palette:bits:` is the in-memory constructor — useful for synthesizing an Image FROM raw pixel data IF we can get that data.

---

## F3 implementation roadmap — open questions BLOCKING work

Before any code, F3 must answer:

### Q1 — How to get a PNG-encoded byte stream from a `Graphics.Image`?

**RESOLVED in session-11: Path A REFUTED.** See "Session-11 progress" section at top of doc for full evidence (6 probes). Choice now between Path B and Path C, pending Oracle F3 (`bg_3e72b537`).

**Path A (DEAD): Stock VW pundle adds PNG-write support.** The only candidate filename match was `preview\64-bit\ImageWriter.pcl` — turned out to be the 64-bit VM-snapshot converter (`VirtualImage`/`McCartneyImage`), not pixel encoder. Image-wide hunt confirmed: no `ImageWriter`/`ImageEncoder`/`BitmapWriter`/`BMPWriter`/`TIFF`/`WebP` class exists; `ImageReader` hierarchy has 5 readers and zero writer peer; `Graphics.PNGImageReader` has zero write methods; `LibJPEG-turbo` (loaded) is decode-only.

**Path B (LIVE candidate): OS-level capture via subprocess.** Bridge forks a PowerShell or `.NET` process that uses `System.Drawing.Graphics.CopyFromScreen` + `Bitmap.Save(stream, ImageFormat.Png)`. Returns bytes via stdout to bridge serve-process. **High portability**; bypasses VW graphics entirely; sidesteps the missing PNG writer. Also collapses Q2 (no separate VW-side capture primitive needed). **Downside:** subprocess overhead per capture (~50-200 ms), dependency on PowerShell + .NET on the host (both present).

**Path C (LIVE candidate, expensive): Hand-roll PNG encoder in Smalltalk.** PNG = magic + IHDR chunk + IDAT (zlib-compressed scanlines) + IEND, with CRC32 on each chunk. `Compression-ZLib` is LOADED (raw zlib for IDAT compression layer). `HashesBase` is loaded (likely CRC32). `Xtreams-Compression` also loaded as alternative. Capture-side still needs solving — `Graphics.Image` has no `Screen.capture` primitive in this image, so Path C either needs OS-side capture (becomes "Path B-capture + Path C-encode" hybrid) or has to invent capture in Smalltalk (likely impossible without primitives we don't have). **Highest pure-Smalltalk effort**; brittle; deferred unless Oracle disagrees.

### Q2 — How to capture the screen / a window into a `Graphics.Image`?

Same probe-driven approach as Q1. Candidates:

- VW `Image fromUser` minus the interactive dialog — check for an underlying primitive that takes explicit `extent` + `origin` args.
- `Screen default` instance methods we haven't fully introspected (especially primitive-call wrappers — selectors starting with `prim*`).
- `HostGraphicsDevice` primitive methods (`#prim*` family if exposed).
- Win32 GDI bindings via `ExternalProcedure` / `DLL_DLLCC`-style FFI calls. VW 9.3.1 has `dllcc` parcel support.
- OS subprocess as in Path B above — handles capture AND encoding in one shot.

### Q3 — Where does PNG encoding happen relative to `onUIDo:`?

Per Oracle: only the pixel-grab on UI process. PNG encoding + HTTP byte-write on serve-process. This requires the capture primitive to return raw pixel bytes (or an Image carrying them), and the encoder runs separately. **If we go with Path B (OS subprocess) the entire pipeline is on serve-process** — Oracle's UI-isolation constraint is automatically satisfied.

### Q4 — Cross-monitor behavior (current setup)

Session observation: Portfolio window opened at bounds `805@281 corner: 1758@1121` — suggests >1080 horizontal pixels visible. Multi-monitor likely. Default full-virtual-screen capture must handle this. Probe `Screen allScreens` size + per-screen bounds before deciding.

---

## F3 progress checklist

| Step | Status | Notes |
|---|---|---|
| 1. Probe `Kernel.Parcel parcelNames` + `parcels` | ✓ DONE session-11 | LOADED=KNOWN=112; `parcelNames` is LOADED-only |
| 2. Filesystem scan `C:\visualworks931\` recursive `*.pcl` | ✓ DONE session-11 | 425+ parcels; only candidate: `preview\64-bit\ImageWriter.pcl` (65 KB) |
| 3. Test-load `ImageWriter` → verify Path A | ✓ DONE session-11 | REFUTED — VM converter not pixel encoder; image-wide hunt confirmed zero pixel encoders anywhere |
| 4. Oracle F3 consult with probe results | ✓ DONE session-11 | `bg_3e72b537`, 2m 16s. Returned high-confidence Path B verdict + 7-section plan + sharp-edge analysis |
| 5. Pick Path B vs Path C | ✓ DONE session-11 | **Path B** (Oracle: Path C still needs OS capture → strictly worse) |
| 6. Subprocess API probe (Path B) | ✓ DONE session-11 | `OS.WinProcess` + `OS.ExternalProcess` viable; `lineEndTransparent` + `quoteArgument:` + `createInOutErrorPipes` + `execute:arguments:do:errorStreamDo:` all present |
| 7. Binary WriteStream sanity | ✓ DONE session-11 | `WriteStream on: (ByteArray new)` round-trips PNG-magic byte-for-byte; `DeflateStream`/`GZipWriteStream` loaded as Path C reserve |
| 8. Bridge architecture read | ✓ DONE session-11 | Dispatch at L460-543 (add `/screenshot` at L526), `httpResponse:` at L1837 text-only (need binary sibling), `serve:` socket-write at L384/402 |
| 9. TDD scaffold — 10 RED tests via test seams | ✓ DONE session-11 | `VWBridge-ScreenshotTest.st` (10 tests + 16 helpers) filed-in via `'path' asFilename fileIn` wrapper; class verified, spot-test ran `1 run, 0 passed, 1 failed, 0 errors` (clean RED via `ensureScreenshotImplemented`) |
| 10. Add `screenshotCaptureOverride` + `scriptedWindowsForScreenshot` ivars + `clearScreenshotOverrides` to VWBridge | ✓ DONE session-12 | Commit `38da008` (with Step 11) |
| 11. Implement `parseAndValidateScreenshotRequest:` + 400/415 envelope | ✓ DONE session-12 | Commit `38da008` (tests #1-#3 GREEN) |
| 12. Implement `httpBinaryResponse:type:body:` (returns ByteArray) + binary-safe socket-write | ✓ DONE session-12 | Commit `3ffae6d` (test #4 GREEN; socket-write deferred to Step 18) |
| 13. Implement `handleScreenshotBody:` core flow + override invocation + success headers | ✓ DONE session-12 | Commit `055f67b` (test #5 GREEN, 5 extra headers) |
| 14. Implement maxBytes check (413) | ✓ DONE session-12 | Commit `f01e744` (test #6 GREEN) |
| 15. Implement `resolveWindowRectForScreenshot:` (404/409) | ✓ DONE session-12 | Commit `8acf02a` (tests #7 #8 GREEN) |
| 16. Map failure outcomes (408/500) | ✓ DONE session-12 | Commit `f33d3f7` (tests #9 #10 GREEN — all 10 conceptually GREEN) |
| 17. PowerShell helper script + `captureScreenshotViaSubprocess:` (production capture) | ✓ DONE session-13 | Commits `307fcf8` (helper script) + `9af652b` (session-12 partial) + `5a84f4a` (session-13 wait-mechanism fix via `execute:arguments:do:errorStreamDo:` one-shot + `outStream binary`) |
| 18. Add `/screenshot` route to dispatch | ✓ DONE session-13 | Commit `82f0eb6` — route at `doDispatch:` L555 + `stream binary` flip for ByteArray responses in `serve:` L430 |
| 19. Real-usage verification — capture live window via bridge | ✓ DONE session-13 | Commit `38a56c6` — windowSummaries shape fix (added originX/Y/cornerX/Y) unblocked window-target HTTP; verified MasLauncher capture 27KB 831×322 + System.Drawing decode |
| 20. Bridge version bump v0.9.0 → v0.9.1 at 4 canonical sites + test assertion | ✓ DONE session-13 | Commit `8f03710` (`/health` reports v0.9.1) |

**Phase F3 SHIPPED.** All 20 steps complete; v0.9.1 pushed to `origin/main` (`a12f40b..8f03710`). End-to-end verification at session-13 EOD: `/screenshot` returns valid PNG decodable as 2560×1440 (screen target) and 831×322 (window target) via PowerShell `System.Drawing.Image::FromFile`.

---

## Key uncertainties

- **Parcel availability of an image-writer codec** — fundamental to Path A.
- **Whether `dllcc`-based FFI is set up in this image** — affects whether we could call Win32 GDI directly. Probe with `Smalltalk at: #ExternalProcedure` etc.
- **Whether the bridge serve-process can fork subprocesses cleanly on Windows** — should be fine with `OS.Subprocess` or `OS.ChildProcess` (whichever exists), but needs verification.
- **PNG encoding speed on Smalltalk-side vs PowerShell-side** — Path C would be slowest; Path B fastest given mature .NET PNG encoder.

---

## What was NOT done in session-10 / session-11 status

| Item | Session-10 | Session-11 |
|---|---|---|
| Probe for PNG-writer pundles (Q1 Path A first cut) | NOT DONE | ✓ DONE — REFUTED (no PNG writer anywhere) |
| Filesystem cross-reference of stock VW parcels | NOT DONE | ✓ DONE — 425+ .pcl scanned, 1 candidate found+refuted |
| Probe for VW FFI infrastructure (`ExternalProcedure`, `dllcc`) | NOT DONE | NOT DONE — defer until Oracle picks path (only matters for Path B variant) |
| Probe for `OS.Subprocess` / equivalent for Path B feasibility | NOT DONE | NOT DONE — defer until Oracle picks Path B |
| Probe for `Screen allScreens` to map multi-monitor layout | NOT DONE | NOT DONE — defer until path chosen (relevant to both B and C) |
| Probe `Compression-ZLib` writer API + CRC32 source | NOT DONE | NOT DONE — defer until Oracle picks Path C |
| Any code in `VWBridge.st` | NOT DONE | NOT DONE — implementation BLOCKED per Oracle-dependent task rule |

---

## Resume hooks

- **Next-session anchor:** this file + [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md) + [`knowledge/HANDOFF-2026-06-20-session11.md`](../knowledge/HANDOFF-2026-06-20-session11.md) (to be written at session-11 EOD).
- **First action:** read Oracle F3 response (when notification arrives — `bg_3e72b537`). Surface path recommendation to user. Then either:
  - Path B chosen → probe `OS.Subprocess`-family selectors + PowerShell System.Drawing spike → TDD scaffold → handler
  - Path C chosen → probe `Compression-ZLib` writer API + CRC32 + binary `WriteStream` + capture-side question → TDD scaffold → handler
- **Decision point:** Path B vs Path C — Oracle has the data, you have the call. Don't pick before Oracle returns.
- **Quality bar:** same as Phase B's quality gate per [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) — "screenshot quality matches what a developer would manually capture; no truncation; readable file size; no broken images." Per-screenshot byte-correctness verification: bytes round-trip through PNG decoder cleanly + visual inspection.
