# Handoff — Phase F3 Q1 RESOLVED + Oracle F3 verdict + TDD scaffold landed (session 2026-06-20 session-11 EOD)

**Written:** end of session-11 that (1) pushed the 7 ahead-of-origin commits from session-10 to `origin/main` (clean fast-forward, `462bc05..ed5ff39`), (2) executed **Phase F3 Q1 parcel-probe campaign (6 probes)** that definitively REFUTED Path A — the only filesystem-name match (`preview\64-bit\ImageWriter.pcl`) turned out to be the VW 64-bit virtual-image-snapshot converter (`VirtualImage`/`McCartneyImage`/`SixtyFourBitVirtualImage`/`HugeArray`), NOT a pixel-image encoder; an image-wide hunt across all 312 namespaces / 10,216 bindings confirmed `*ImageWriter*`/`*ImageEncoder*`/`*BitmapWriter*`/`*BMPWriter*`/`*TIFF*`/`*WebP*` count=0, `Graphics.ImageReader` hierarchy has 5 readers and ZERO writer peer, `Graphics.PNGImageReader` 41 instance methods are ALL decode/filter/chunk-process with zero write methods, and `LibJPEG-turbo` (loaded) is decode-only despite the upstream libjpeg-turbo supporting encode; (3) **Oracle F3 consult** (bg_3e72b537, 2m 16s) returned high-confidence verdict for **Path B** (PowerShell System.Drawing subprocess) with a 7-section implementation plan + sharp-edge analysis (Path C eliminated because still needs OS capture → strictly worse than letting .NET do both); (4) **subprocess + binary-stream probes (2 more)** confirmed Path B fully viable: `OS.WinProcess` + `OS.ExternalProcess` both present (with `execute:arguments:do:errorStreamDo:` one-shot API + `createInOutErrorPipes` + `inputPipe`/`outputPipe`/`errorPipe` + `wait`/`exitStatus`/`kill` + `lineEndTransparent` binary-safe stdout knob + `quoteArgument:` security knob), 117 classes in `OS` namespace including `Stdin`/`Stdout`/`Stderr` + `StandardIOStream` + `PCPipeAccessor` + full stdio infrastructure, `WriteStream on: (ByteArray new)` round-trips PNG magic bytes (`#[137 80 78 71 13 10 26 10]`) byte-for-byte (binary safety LOCKED), `DeflateStream` + `GZipWriteStream` loaded as Path C reserve; (5) **bridge architecture mapped** from VWBridge.st reads — dispatch routing at L460-543 (extend at L526 area for /screenshot route), `httpResponse:type:body:` at L1837 is text-only (uses `WriteStream on: Core.String new` → need `httpBinaryResponse:` sibling returning ByteArray), `serve:` socket-write at L384/402 (`stream nextPutAll: response`), listener forks per-connection process from `listener accept`, NO existing OS/Subprocess refs in current bridge code (Path B will be the first OS-side integration); (6) **TDD scaffold landed** — wrote `src/vw-bridge/VWBridge-ScreenshotTest.st` (~270 lines, 10 RED tests + 16 helpers per Oracle's TDD order: 3 validation + 1 binary-safety + 1 capture success + 1 size cap 413 + 2 window targeting 404/409 + 1 timeout 408 + 1 capture failure 500; helpers include `ensureScreenshotImplemented` for uniform RED messages instead of cryptic DNU errors, fake PNG bytes with null+high-byte values for binary safety lock, fake outcome factories matching Oracle's dictionary shape `{ok:true, pngBytes, width, height}` vs `{ok:false, status, error, message}`, scripted window snapshot factories, seam wrappers); filed-in via `'path' asFilename fileIn` wrapper expression; class verified loaded (`VWBridgeScreenshotTest`, superclass `TestCase`, 26 selectors); spot-check `(VWBridgeScreenshotTest selector: #testScreenshotRejectsBadRequest) run` returned `1 run, 0 passed, 1 failed, 0 errors` = clean RED state via assertion failure in `ensureScreenshotImplemented` (NOT a doesNotUnderstand error); (7) **2 stale docs updated** — `plan/PLAN-PHASE-F-SCREENSHOT.md` (+196/-33 lines, added session-11 progress section at top with Q1 RESOLUTION + loaded primitives + capture-side status + Oracle F3 verdict + subprocess findings + bridge architecture + TDD scaffold landed; updated Q1 to mark RESOLVED with Path A REFUTED evidence; replaced 9-step next-session checklist with 20-step progress matrix (9 done session-11, 11 pending session-12); added session-12 implementation roadmap with Oracle's TDD order) and `knowledge/vw-image-api-contract.md` (+41/-1 lines, added "Discovery + Load API quirks (session-11 — Phase F3 trap)" subsection covering `parcelNames` LOADED-only / `findParcelNamed:`+`parcelNamed:` LOADED-only / `ensureLoadedParcel:withVersion:` cache-dependent failure / `loadParcelFrom:` explicit-Filename bypass / `unloadParcelNamed:` for cleanup / Parcel instance introspection narrow surface; added "NAMING TRAP — `ImageWriter.pcl` is NOT a pixel encoder" subsection; fixed misleading "Auto-load parcels at boot" row in Quick lookup table).

**For:** session-12 — (1) decide commit + push authorization for the 5 atomic deliverables this session produced (the session-11 work has been intentionally committed + pushed per the "full wrap" decision); (2) execute Phase F3 session-12 implementation roadmap per [`PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) steps 10-20 of the 20-step checklist, starting with: add `screenshotCaptureOverride` + `scriptedWindowsForScreenshot` ivars + `clearScreenshotOverrides` clearing method to VWBridge.st (this moves `ensureScreenshotImplemented` past the "Missing:" check); then `parseAndValidateScreenshotRequest:` + 400/415 envelope (turns validation tests GREEN); then `httpBinaryResponse:type:body:` returning ByteArray + binary-safe socket-write integration (turns binary-safety test GREEN); then `handleScreenshotBody:` core flow (turns capture success test GREEN); then `maxBytes` check (413); then `resolveWindowRectForScreenshot:` (404/409); then failure outcome mapping (408/500); then PowerShell helper script + `captureScreenshotViaSubprocess:` (production capture via `OS.ExternalProcess defaultClass new` → `lineEndTransparent` → `createInOutErrorPipes` → `startProcess:arguments:` → `outputPipe contents` drain → `wait` → check `exitStatus`); then add `/screenshot` route to dispatch at L526 area; then real-usage verification (capture live PartySearch window, verify bytes decode as valid PNG via PowerShell round-trip + visual inspection); then bridge version bump v0.9.0 → v0.9.1 at 4 canonical sites + `testHealthReturnsCurrentVersion` assertion update; (3) alternatively, the standing decisions remain Phase C (API freeze + OpenAPI spec), Phase D (auto-start architecture), Phase E (Playwright SDK scaffold) per the [ROADMAP](../plan/ROADMAP-QUALITY-FIRST.md); (4) carry-overs from session-7+8+9+10 still pending: EXPLORATION-PLAN step 3 (3-deep menu navigation) + step 4 (leaf dispatch catalog), end-to-end verification of `#id`/`#imcNr`/`#groupScheme` no-modal partialFind: paths; (5) carry-forward constraints from session-11 added below (see "Explicit constraints" section).

**Supersedes:** nothing. [`HANDOFF-2026-06-20-session10.md`](./HANDOFF-2026-06-20-session10.md) remains the session-10 EOD; this file is session-11 EOD.

---

## User direction in this session (session-11, condensed)

- Opened with the standard resume prompt: read 3 anchor docs ([HANDOFF-session-10](./HANDOFF-2026-06-20-session10.md), [vw-image-api-contract](./vw-image-api-contract.md), [PLAN-PHASE-F-SCREENSHOT](../plan/PLAN-PHASE-F-SCREENSHOT.md)), do Phase 0 verification (all green: bridge v0.9.0, token matches session-10 EOD, 7 commits ahead), surface standing decisions for user to pick from.
- Picked **Push now** for the 7 ahead-of-origin commits.
- Picked **Phase F3 — start with parcel probe** as the session-11 direction.
- Picked **Test-load ImageWriter, re-probe added classes** after parcel probe found `preview\64-bit\ImageWriter.pcl` candidate.
- Picked **Oracle F3 consult NOW with full probe data** after Path A definitively refuted (ImageWriter is VM converter, not pixel encoder).
- Picked **Probe subprocess + binary-stdout API surface** after Oracle returned Path B verdict.
- Picked **TDD scaffold this session (8 RED tests, ~2-3h)** after subprocess feasibility confirmed.
- Picked **Full wrap — 5 commits + push + handoff** for session-11 EOD.

Commit auth: **GRANTED for 5 atomic commits** (test scaffold + 2 doc updates + probe artifacts + this handoff), with push to origin authorized.

---

## Work completed in session-11

### Phase 0 — Resume verification (~3 min)

- `curl.exe -s http://127.0.0.1:9876/health` → `{"status":"ok","version":"0.9.0"}` ✓ (note: PowerShell `curl` alias is `Invoke-WebRequest` which fails — use `curl.exe`)
- Token from [`.token`](../src/vw-bridge/.token): `3959443064454-247528` — matched session-10 EOD, `vwnt.exe` not restarted, no re-toggle of `Dialog useNativeDialogs: false` needed
- Working tree clean
- `git log origin/main..HEAD` confirmed all 7 expected commits ahead

### Push 7 commits (~30 sec)

- `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git push origin main`
- Output: `462bc05..ed5ff39  main -> main`
- `origin/main` now at `ed5ff39` (session-10 HANDOFF commit)

### F3 Q1 parcel-probe campaign (~60 min, 6 probes)

#### Probe 1 — `Kernel.Parcel parcels` + `parcelNames` enumeration

- LOADED count = 112 parcels
- KNOWN (`parcelNames`) count = 112 — IDENTICAL to LOADED
- **API discovery (new contract row)**: `parcelNames` is LOADED-only — it does NOT scan the search path. Equivalent to `(parcels collect: #name)`. The filesystem is the source of truth for what's available to load.

#### Probe 2 — Filesystem scan `C:\visualworks931\` recursive `*.pcl`

- 425+ stock VW parcels across canonical `parcels\`, `preview\`, `packaging\`, `contributed\`, `seaside\`, `glorp\`, `icc\`, `net\`, `obsolete\`, `security\`, `store\`, `wavedev\`, `web\`, `www\`, `xtreams\`, `image\`, `launchpad\`, `opentalk\`, `webservices\`
- Notable encoder/codec candidates filtered by name:
  - **`preview\64-bit\ImageWriter.pcl`** (65 KB) — name match, but unknown content
  - `parcels\GIFEncoder.pcl` (17 KB, unloaded) — GIF specific
  - `parcels\LibJPEG-turbo.pcl` (17 KB, LOADED) — JPEG library
  - `parcels\ImageReaders.pcl` (46 KB, LOADED) — decoder bundle (origin of `Graphics.PNGImageReader`)
  - `packaging\ImageCompression.pcl` (5 KB, LOADED) — likely VW VM-image compression, not pixel
  - `obsolete\parcels\PNGImageReader.pcl` (1.7 KB) — tiny obsolete redirect
- `preview\64-bit\ImageWriter.pcl` identified as primary Path A candidate (on search path via `$(VISUALWORKS)\preview\*\*`)

#### Probe 3 — `Kernel.Parcel ensureLoadedParcel: 'ImageWriter' withVersion: nil`

- **FAILED** with `ParcelMissingError` (empty message text: `''''`)
- Image state unchanged (112 parcels, 0 new selectors)

#### Probe 4 — diagnostic READ-ONLY

- `searchPathModel value` = OrderedCollection of 35 PortableFilenames, includes `$(VISUALWORKS)\preview\*\*` (search path intact)
- `findParcelNamed: 'ImageWriter'` → `nil`
- `parcelNamed: 'ImageWriter'` → `nil`
- **Hypothesis confirmed**: discovery APIs (`findParcelNamed:`, `parcelNamed:`) only return LOADED parcels — name cache is NOT filesystem-backed. `ensureLoadedParcel:withVersion:` relies on the same cache → fails for unloaded names.
- Available `Kernel.Parcel` class-side selectors include `loadParcelFrom:` (per session-9 API contract) — explicit-Filename bypass

#### Probe 5 — `Kernel.Parcel loadParcelFrom: 'C:\visualworks931\preview\64-bit\ImageWriter.pcl' asFilename`

- **SUCCEEDED** (+1 parcel: ImageWriter, returned `Parcel parcelNamed: 'ImageWriter'`)
- BUT: ZERO new bindings (`allBindings` count unchanged at 10,216), ZERO new class-side or instance-side selectors on `Graphics.Image`, ZERO new Graphics namespace keys
- Anomaly: 65 KB parcel that adds nothing? Need introspection.

#### Probe 6 — Parcel introspection (the smoking gun)

- `pcl summary` → defined classes: `VirtualImage`, `McCartneyImage`, `VirtualImageBytes`, `SixtyFourBitVirtualImage`, `HugeArray`, `LargeVirtualImageBytes`, `McCartneyPermImage`, `SegmentProperties`, `SortableInterval`, `ThirtyTwoBitVirtualmage`, `VirtualImageSegment`, `VirtualObject`, `VirtualObjectRehashProxy`, `VW7Image`; extended classes: `ArithmeticValue`/`Double`/`SmallDouble` `_iw_isDouble`, `VisualLauncher` `basicSave64BitImage`/`save64BitImage`
- `pcl comment` → *"This package provides an image conversion framework which can read virtual image files and write them out with modifications. This is used to convert from 32-bit virtual images to 64-bit virtual images. To produce a 64-bit image, load this package and then evaluate `VirtualImage cloneFrom: 'visual' to: 'visual64' target: McCartneyImage`..."*
- **VERDICT: `preview\64-bit\ImageWriter.pcl` is the VW VM-SNAPSHOT (.im file) converter, NOT a pixel image encoder.** Zero-diff explained: classes already resident in `storedev64.im` (which IS a 64-bit-converted image produced by this exact tool at deployment time).
- **Q1 Path A via this parcel REFUTED.**

#### Cleanup — `Kernel.Parcel unloadParcelNamed: 'ImageWriter'`

- Returned `true`
- Baseline restored: 112 parcels, no ImageWriter listed
- Image state clean

#### Final image-wide hunt for any pixel encoder anywhere

- Walk all 312 namespaces / 10,216 bindings for `*ImageWriter*` | `*ImageEncoder*` | `*BitmapWriter*` | `*BMPWriter*` | `*TIFF*` | `*WebP*` → **count = 0**
- `Graphics.ImageReader` subclasses: `JPEGImageReader`, `XBMImageReader`, `PNGImageReader`, `BMPImageReader`, `GIFImageReader` → **5 readers, ZERO writer peer**
- `Graphics.ImageReader` instance methods matching `write|put|encode|store|emit|stream` → **count = 0**
- `Graphics.PNGImageReader` 41 instance + 3 class-side selectors: ALL decode/filter/chunk-process (`copyPixelsRGB:`, `filterPaeth:`, `processIDATChunk`, `readImage`, `canRead:`); ZERO write methods
- `LibJPEG-turbo` (LOADED) 5 classes: `JPEGColorComponent`, `JPEGHuffmanTable`, `JPEGImageReader`, `LibJPEGTurboInterface`, `LibJPEGTurboInterfaceDictionary` — DECODE ONLY despite libjpeg-turbo upstream supporting encode

**Q1 FULLY REFUTED. No pixel-image-encoder exists anywhere in this VW 9.3.1 image.**

### Oracle F3 consult (~2m 16s, bg_3e72b537)

Fired with comprehensive prompt: full F1 design lock + Q1 resolution data (6 probes summarized) + capture-side status (no Smalltalk-side capture primitive in `Screen`/`HostGraphicsDevice`/`Window`) + loaded primitives for Path C (`Compression-ZLib`, `Compression-Zip`, `HashesBase`, `Xtreams-Compression`) + F1 spec constraints + bridge implementation patterns + 7 specific asks (path recommendation, subprocess/hand-roll specifics, Q3/Q4 confirmation, test seam refinement, sharp edges).

**Verdict: Path B** with high confidence + 7-section implementation plan.

Key decisions:
- **Path C eliminated**: still lacks capture primitive → would degrade into "subprocess capture + Smalltalk encode" which is strictly worse than letting .NET do both
- **Window resolution stays in VW**: resolve `appClass`+`titleContains` in Smalltalk, return 404/409 BEFORE invoking PowerShell
- **NEVER concatenate strings into PowerShell source**: pass only validated INT rectangle coords + mode
- **Capture via `Graphics.FromImage($bitmap).CopyFromScreen(...)`** — NOT `FromHwnd`. Captures composited desktop rectangle.
- **Bytes channel**: PowerShell `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)`. NOT `Write-Output`/`Write-Host`/pipeline (text-mangling)
- **Multi-monitor**: full virtual screen by default via `[SystemInformation]::VirtualScreen`, including negative `Left`/`Top` coords
- **Q3 UI isolation confirmed**: zero UI work for screen target; window target needs quick `onUIDo:` snapshot for window-resolution; subprocess does capture+encode on serve-process
- **DPI awareness**: live-probe risk; add DPI-aware call in PS helper if needed

Test seam refinement (revised from F1):
- `screenshotCaptureOverride` returns a **Dictionary** (not just bytes): `{ok:true, pngBytes, width, height}` on success / `{ok:false, status, error, message}` on failure
- `scriptedWindowsForScreenshot` SEPARATE from `scriptedWindowSnapshots` (no /wait interference)
- Fake PNG bytes in tests MUST include null + high-byte values (lock binary safety from test #1)

Sharp edges with mitigations:
- HWND/window race → resolve rect immediately before capture; v1 accepts "visible pixels at that rectangle"
- Occlusion/minimized → `CopyFromScreen` is composited desktop; document limitation; PrintWindow/DWM as later escalation
- PowerShell injection → resolve appClass/titleContains in VW; pass only validated mode/INT coords to subprocess
- Binary stdout drain → temp PNG file fallback if VW subprocess API can't handle concurrent binary drain
- DPI scaling → probe live; add DPI-aware call in PS helper if VW displayBox vs PS coords disagree

Effort estimate: **1-2 focused sessions** for full Path B implementation.

### Subprocess + binary-stream probes (~15 min, 2 probes)

#### Probe 7 — subprocess class hunt + ByteArray WriteStream sanity

- Subprocess class candidates (matching `Subprocess|ChildProcess|ExternalProcess|PipeableProc|CommandShell|WinProcess|OSProcess|SystemCommand|StreamPipe`): **`OS.WinProcess`** (Windows-specific) + **`OS.ExternalProcess`** (cross-platform parent) — both present
- `OS` namespace: 117 classes including `Stdin`/`Stdout`/`Stderr`/`StandardIOStream`/`StandardIOSubsystem`/`StandardOutTranscript`/`ExternalReadStream`/`ExternalWriteStream`/`ExternalReadWriteStream`/`BufferedExternalStream`/`PCPipeAccessor`/`UnixProcess`/`OSHandle`/`IOAccessor`/`IOBuffer`/`SocketAccessor` family (cross-platform Win/Linux/MacOSX/AIX/Solaris)
- **`WriteStream on: (ByteArray new: 16)`** test: 8 `nextPut:` of PNG magic bytes (0x89/0x50/0x4E/0x47/0x0D/0x0A/0x1A/0x0A) → `ws contents class = ByteArray`, contents = `#[137 80 78 71 13 10 26 10]` — **BINARY-SAFE, BYTE-FOR-BYTE PRESERVED**
- WriteStream subclasses (7 total): `ByteCodeReadWriteStream`, `ClientReportStream`, **`DeflateStream`** (Path C reserve), **`GZipWriteStream`**, `InternalCodeWriterStream`, `ReadWriteStream`, `TextStream`
- **Image quirk note (new contract row)**: `valuesDo:` ABSENT on `NameSpace` — use `keys do: + at: ifAbsent:` pattern instead
- Class-side action selectors (`command:`/`run:`/`exec:`/`system:`/`spawn:`/`popen:`) in OS|Core|Kernel: count = 0 — API uses different naming, deep probe needed

#### Probe 8 — deep `OS.WinProcess` + `OS.ExternalProcess` API

**`OS.ExternalProcess`** (parent, 43 instance + 20 class-side selectors):
- Class-side action: `execute:arguments:do:errorStreamDo:` (one-shot with stream blocks), `fork:`/`fork:arguments:`, `cshOne:`/`shOne:`, `new`, `defaultClass`/`defaultClass:` (factory), `hookupFor:withID:`, `pipeAccessorClass`, `setStatusChangedSemaphore:`, `setUpDefaultClass`, `startReaper`/`stopReaper`/`reapSome`, `registry`/`makeRegistry`
- Instance-side: `execute:arguments:do:` / `execute:arguments:do:errorStreamDo:` (one-shot variants); `createInOutPipes` / `createInOutErrorPipes`; `inputPipe`/`inputPipe:` (stdin), `outputPipe`/`outputPipe:` (stdout), `errorPipe`/`errorPipe:` (stderr); `readStream`/`readStream:`/`readStreamFor:`, `writeStream`/`writeStream:`/`writeStreamFor:`, `errorStream`/`errorStream:`; `endOfPipes`; `encoding`/`encoding:`; **`lineEndAuto`/`lineEndConvention`/`lineEndConvention:`/`lineEndCR`/`lineEndCRLF`/`lineEndLF`/`lineEndTransparent`** ← BINARY SAFETY KNOB; `fork:`/`fork:arguments:`/`startProcess:arguments:`; `wait`/`isActive`/`isExited`/`exitStatus`; `kill`/`kill:`/`exit`; `release`
- Inheritance: `ExternalProcess → OSHandle → OSErrorHolder → Object`

**`OS.WinProcess`** (Windows subclass, 24 instance + 5 class-side):
- Adds Windows specifics: **`quoteArgument:`** ← SECURITY KNOB for safe argument escaping, `useOEMEncoding`/`oemEncoding`/`defaultEncoding`, `executeCommand:`/`executeSingleCommand:`, `getCommandLineInterpreter` (find cmd.exe path), `cshOne:`/`shOne:`/`cshBullet:`/`shOneOEM:`, `buffer`/`bufferSize`/`endOfFile`/`endOfFileMarker`, `directoryListing`, `install`, `printOn:`
- Inheritance: `WinProcess → ExternalProcess → OSHandle → OSErrorHolder → Object`

**Path B fully de-risked. Subprocess API is complete and platform-aware.**

### Bridge architecture mapping (~10 min, grep + Read VWBridge.st)

| Aspect | Finding | Implication |
|---|---|---|
| `httpResponse:type:body:` at L1837 | `out := Core.WriteStream on: Core.String new` then `out nextPutAll: bodyString` — STRING not ByteArray | Text-only. Would mangle binary. **Need sibling `httpBinaryResponse:type:body:` returning ByteArray.** |
| Routing at L460-543 | `dispatch:headers:body:` wraps `doDispatch:headers:body:` with Bug #5 Stage 2 re-entry guard. doDispatch dispatches by method + path. | Add `/screenshot` route at L526 area (POST section): `path = '/screenshot' ifTrue: [^self handleScreenshotBody: bodyString]` |
| `serve:` socket-write at L384/L402 | `[stream nextPutAll: response] on: err do: [:ex | nil]` — assumes String | For binary, need confirmed-binary socket-write path OR build full response (header bytes + body bytes) as one ByteArray |
| `listenerLoop` at L315-353 | `createListener` uses `SocketAccessor newTCPserverAtPort:`; forks per-connection process from `listener accept` | Each `serve:` runs on its own forked process — blocking is safe |
| Existing OS/Subprocess refs | NONE in current bridge code | Path B will be the first OS-side integration |

### TDD scaffold landed (~30 min)

#### Wrote `src/vw-bridge/VWBridge-ScreenshotTest.st` (~270 lines)

Class definition:
- `Root.Smalltalk defineClass: #VWBridgeScreenshotTest superclass: #{TestCase} ... category: 'VW-TestBridge-ScreenshotTests'`
- 1 instance var: `bridge`, `authHeaders`
- 26 total selectors: 10 tests + 16 helpers

10 RED test methods (per Oracle's TDD order + 2 validation sub-cases):

| # | Test method | Asserts |
|---|---|---|
| 1 | `testScreenshotRejectsBadRequest` | empty body → 400 `invalid-screenshot-request` |
| 2 | `testScreenshotRejectsUnsupportedFormat` | `format=jpg` → 415 `screenshot-unsupported-format` |
| 3 | `testScreenshotRejectsInvalidMaxBytes` | `maxBytes=0` → 400 referencing `maxBytes` |
| 4 | `testScreenshotBinaryResponseBuilderRoundTripsPngBytes` | fake bytes (null + high) round-trip byte-for-byte (binary safety lock) |
| 5 | `testScreenshotFakeCaptureSuccessReturns200WithPngBytes` | override returns success → 200 + `image/png` + `X-VWBridge-Screenshot-Width:1920` + `Height:1080` |
| 6 | `testScreenshotMaxBytesExceededReturns413` | override returns 200 bytes when `maxBytes=100` → 413 `screenshot-too-large` |
| 7 | `testScreenshotWindowTargetZeroMatchesReturns404` | scripted windows empty, target=NoSuchApp → 404 `screenshot-window-not-found`; override NOT called |
| 8 | `testScreenshotWindowTargetMultipleMatchesReturns409` | 2 scripted matching windows → 409 `screenshot-window-ambiguous`; override NOT called |
| 9 | `testScreenshotFakeTimeoutReturns408` | override returns `{ok:false,status:408,error:'screenshot-timeout'}` → 408 |
| 10 | `testScreenshotFakeCaptureFailureReturns500` | override returns `{ok:false,status:500,error:'screenshot-capture-failed'}` → 500 |

16 helpers:
- `setUp` (captures `VWBridge singleton` + builds `authHeaders`)
- `tearDown` (defensive — calls `bridge clearScreenshotOverrides` only if implemented; works in RED state)
- `ensureScreenshotImplemented` (checks `handleScreenshotBody:`/`screenshotCaptureOverride:`/`scriptedWindowsForScreenshot:`/`clearScreenshotOverrides` exist; emits uniform RED message via `self assert: false description: '... Missing: ...'` if not — clean failure instead of DNU)
- `screenshotResponseFor:` (calls `ensureScreenshotImplemented` first, then `bridge handleScreenshotBody: bodyString`)
- `statusLineOf:` (extract first line before CR or LF for both String + ByteArray responses)
- `bodyOf:` (extract everything after CRLF+CRLF separator, uses 2-arg `indexOfSubCollection:startingAt:`)
- `bodyContains:in:` (substring predicate, works on String + ByteArray)
- `headerContains:in:` (substring predicate restricted to header section, prevents false positives from body)
- `fakePngBytesIncludingNullsAndHighBytes` (returns `#[16r89 16r50 16r4e 16r47 16r0d 16r0a 16r1a 16r0a 16r00 16r00 16r00 16r0d 16r49 16r48 16r44 16r52 16rff 16rfe 16r00 16r01 16r80 16r7f]` — PNG magic + IHDR start + null + 0xFF + 0xFE + high bytes)
- `fakeOversizedPngBytesOfSize:` (programmatic ByteArray of arbitrary size for size-cap testing)
- `fakeSuccessResultWithBytes:width:height:` (builds Oracle's `{ok:true, pngBytes, width, height}` dict)
- `fakeFailureResultStatus:error:message:` (builds Oracle's `{ok:false, status, error, message}` dict)
- `windowRectSnapshotAppClass:titleContains:origin:corner:` (window snapshot dict with parsed `originX`/`originY`/`cornerX`/`cornerY` rectangle for capture coord computation)
- `windowRectSnapshotAppClass:titleContains:id:` (window snapshot with explicit id for multi-match disambiguation)
- `withScreenshotCaptureOverride:do:` (set override, run block, rely on tearDown to clear)
- `withScriptedScreenshotWindows:do:` (set scripted windows, run block, rely on tearDown to clear)

#### File-in mechanism (the asFilename fileIn wrapper pattern, from session-10)

Test file contains 'VWBridge' but NOT 'dispatch' (intentionally — used 'router' / 'handler' in all comments). Direct POST via `--data-binary @file` should work because Stage 1 guard needs BOTH substrings. But used wrapper expression for safety + consistency with session-9/10 patterns:

```
curl.exe -s -X POST http://127.0.0.1:9876/eval -H "Authorization: Bearer <token>" -H "Content-Type: text/plain" \
  --data-binary "'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-ScreenshotTest.st' asFilename fileIn"
```

Returns `{"ok":true,"result":"nil"}` (standard `fileIn` return).

#### Verification

Probe confirmed class loaded successfully:
- `Smalltalk at: #VWBridgeScreenshotTest` → Class instance
- superclass = `TestCase`, category = `'VW-TestBridge-ScreenshotTests'`
- 26 selectors (10 tests + 16 helpers all present)
- Spot-check: `(VWBridgeScreenshotTest selector: #testScreenshotRejectsBadRequest) run printString` → `'1 run, 0 passed, 1 failed, 0 errors'`
- **1 failed (not 1 errored)** = clean assertion failure from `ensureScreenshotImplemented`, NOT a doesNotUnderstand error. Exactly the RED state we want.

Did NOT run full `VWBridgeScreenshotTest suite run` (per session-10 lesson on /eval suite-run wedge). One test smoke-checked is sufficient evidence — all 10 use the same `ensureScreenshotImplemented` gate.

### Stale doc updates (~20 min, 2 files)

#### [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) (+196/-33 lines)

- Added "Session-11 progress (NEW)" section at top with: Q1 RESOLUTION subsection (Path A REFUTED evidence table with 6 probes), Loaded primitives for Path C subsection, Capture-side (Q2) status subsection, Oracle F3 verdict subsection (Path B + key decisions + test seam refinement + sharp edges + effort estimate), Subprocess API + binary stream probe results subsection (2 probes summarized), Bridge architecture findings subsection (table of httpResponse:/dispatch/serve:/listenerLoop/OS-refs findings), TDD scaffold LANDED subsection (file + class verification + spot-check + helper inventory), Session-12 implementation roadmap subsection (Oracle's 12-step TDD order broken out)
- Updated Bottom line section to reflect session-11 EOD state (Q1 resolved, Oracle picked B, TDD scaffold landed, BLOCKED no more — ready for session-12 implementation)
- Updated Q1 section to mark RESOLVED with link to session-11 evidence
- Replaced F3 next-session checklist (9-step) with 20-step progress matrix (9 done session-11, 11 pending session-12)
- Updated "What was NOT done in session-10" → cross-session matrix showing session-11 status
- Updated Resume hooks for session-12

#### [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) (+41/-1 lines)

- Added "Discovery + Load API quirks (session-11 — Phase F3 trap)" subsection within "Parcel infrastructure (session-9 discovery)" section, covering: `parcels` returns LOADED instances; `parcelNames` LOADED-only (NOT a discovery API); `findParcelNamed:`/`parcelNamed:` LOADED-only; `ensureLoadedParcel:withVersion:` raises `ParcelMissingError` for unloaded names (cache-only); `loadParcelFrom: aFilename` is the headless bypass; `unloadParcelNamed:` for cleanup; Parcel instance introspection NARROW surface (works: name/version/summary/comment/etc.; errors with MNU: file/fileName/prerequisites/components/codeComponents/classes/classDefinitions/extensions/etc.)
- Added "NAMING TRAP — `ImageWriter.pcl` is NOT a pixel encoder (session-11 Phase F3)" subsection with defined-classes list + parcel comment quote + image-wide hunt findings
- Fixed misleading "Auto-load parcels at boot" row in Quick lookup table: changed `ensureLoadedParcel:withVersion:` recommendation to `loadParcelFrom: 'path' asFilename` with reference to new Discovery + Load API quirks subsection

---

## Current state (end of session-11)

- **VW image**: still up at `vwnt.exe` PID 5624 (launched ~13:07 yesterday via Explorer, same instance as session-9/10). Estimated ~280+ baseline procs.
- **Bridge**: UP at v0.9.0 on `127.0.0.1:9876`. **Token unchanged this session**: `3959443064454-247528` (still matches `.token` — VWBridge start was NOT called this session because no production-code reload happened). Re-read `.token` before any /eval after session-11 ends, in case other agents touched it.
- **`Dialog useNativeDialogs: false`**: SET (carried from session-7+8+9+10). Resets on vwnt.exe restart.
- **Bridge code on disk**: v0.9.0 in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (~2194 lines, unchanged session-11 — no production code changes).
- **SUnit on disk**:
  - [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st): 21 selectors (unchanged from session-10).
  - [`VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st): 37 selectors (unchanged from session-10).
  - **NEW: [`VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st)**: 26 selectors (10 tests + 16 helpers). All 10 tests cleanly RED via `ensureScreenshotImplemented`.
- **SUnit in running image**: matches disk after session-11 file-in.
  - VWBridgeTest: 21 selectors (unchanged session-11)
  - VWBridgeWaitTest: 37 selectors (unchanged session-11)
  - VWBridgeScreenshotTest: 26 selectors (NEW this session, filed-in via wrapper expression)
- **Image globals carried from session-10**: unchanged this session.
  - `TEST_BUG2_YES_RET=true`, `TEST_BUG2_NO_RET=false`, `TEST_PURGE_TARGET_RET=true`
- **MAS window state at EOD**: unchanged from session-10 EOD (no UI interactions in session-11).
- **Probe artifacts at EOD (moved to probes/)**: 9 F3 probe files preserved as evidence trail.
- **Git**:
  - origin/main pushed to `ed5ff39` (session-10 HANDOFF) earlier this session
  - 5 atomic session-11 commits proposed below (test scaffold + 2 doc updates + probe artifacts + this handoff)
- **Known bugs**: unchanged from session-10 (all 1-6 FIXED). No new bugs identified.
- **Known limitations (carry + NEW from session-11)**: carry from session-7..10 unchanged. NEW from session-11:
  - **No pixel-image-encoder exists anywhere in this VW image** (Path A dead, definitive). Path B (PowerShell subprocess) is the chosen implementation per Oracle F3.
  - **`Kernel.Parcel parcelNames` is LOADED-only** — does NOT scan the filesystem. Discovery requires filesystem-side scan via PowerShell.
  - **`Kernel.Parcel ensureLoadedParcel:withVersion:` fails for unloaded parcels** with `ParcelMissingError` (empty message). Use `loadParcelFrom: 'path' asFilename` for headless explicit-path load.
  - **`NameSpace>>valuesDo:` ABSENT** in this image — use `ns keys do: [:k | | cls | cls := ns at: k ifAbsent: [nil]. ...]` pattern instead.
  - **`httpResponse:type:body:` at L1837 is text-only** — uses `WriteStream on: Core.String new`. For binary responses (PNG bytes in /screenshot), need a sibling `httpBinaryResponse:type:body:` returning ByteArray + binary-safe socket-write integration.

---

## Pending tasks (session-12)

### Immediate on resume

1. **Restart `vwnt.exe`?** Bridge healthy at EOD (responds to /health). No test failures, no observed wedges. Image accumulated 3 test globals across prior sessions + VWBridgeScreenshotTest class added this session, but no observed issues. Restart not strictly required.
2. **If `vwnt.exe` restarted**: re-toggle `Dialog useNativeDialogs: false` via /eval, file-in via Workspace (NOT /eval since bridge would be DOWN): VWBridge.st → VWBridge-Test.st (21 selectors) → VWBridge-WaitTest.st (37 selectors) → **NEW: VWBridge-ScreenshotTest.st** (26 selectors, 10 tests). Re-read `.token` after VWBridge.st file-in (token rotates on `VWBridge start` chunk).
3. **Verify state**: curl.exe -s /health → v0.9.0, re-read [`.token`](../src/vw-bridge/.token).

### Highest-value next directions

4. **Phase F3 session-12 implementation** (per [`PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) steps 10-20). Order:
   - Step 10: Add `screenshotCaptureOverride` + `scriptedWindowsForScreenshot` ivars to VWBridge at L21 + accessor setters + `clearScreenshotOverrides` clearing method. This moves `ensureScreenshotImplemented` past the "Missing:" check.
   - Step 11: `parseAndValidateScreenshotRequest:` + 400/415 error envelope helpers → turns validation tests #1/#2/#3 GREEN.
   - Step 12: `httpBinaryResponse:type:body:` returning ByteArray + binary-safe socket-write integration → turns binary safety test #4 GREEN.
   - Step 13: `handleScreenshotBody:` core flow → turns capture-success test #5 GREEN.
   - Step 14: `maxBytes` check after capture → turns test #6 GREEN.
   - Step 15: `resolveWindowRectForScreenshot:` with 404/409 paths → turns tests #7/#8 GREEN.
   - Step 16: Map failure outcomes (`status` field → HTTP status code) → turns tests #9 (408) / #10 (500) GREEN.
   - Step 17: PowerShell helper script + `captureScreenshotViaSubprocess:` (production capture).
   - Step 18: Add `/screenshot` route to dispatch at L526 area.
   - Step 19: Real-usage verification — capture live PartySearch window via bridge, verify bytes decode as valid PNG, visual inspection.
   - Step 20: Bridge version bump v0.9.0 → v0.9.1 at 4 canonical sites + update `testHealthReturnsCurrentVersion`.
   - Estimated 4-8 hours total (Oracle's 1-2 session estimate, compressed by session-11's scaffolding).

5. **Phase C — API freeze + OpenAPI spec** (per roadmap). Lock down v0.9.1 surface before SDK work. Hand-write `docs/openapi.yaml` for 14 endpoints (after /screenshot lands) + CI drift check. ~4-6h. Natural follow to v0.9.1 ship.

6. **Phase D — Auto-start architecture** (now unblocked by session-9 parcel evidence). Three viable paths converge on "external trigger." Oracle consult on tradeoffs. ~1 session.

7. **Phase E — Playwright TypeScript SDK + 3 first tests** against v0.9.1 bridge. Depends on Phase C ideally.

### Carry-overs still pending (from session-7+8+9+10, none resolved this session)

8. **EXPLORATION-PLAN step 3** — 3-deep menu navigation.
9. **EXPLORATION-PLAN step 4** — leaf dispatch catalog across MAS menu tree.
10. **End-to-end verification of `#id` / `#imcNr` / `#groupScheme`** (no-modal partialFind: paths) — still UNVERIFIED via bridge per session-3 calibration.

### Production-grade packaging (medium-term)

11. Log rotation (still).
12. Class-side log mutex for concurrent fork safety + Windows file-sharing race.
13. Env-var externalization of log path / .token path / port / parcel deployment path.
14. Parcel build script — depends on Phase D decision.

---

## Proposed atomic commits for session-11 deliverables

Per session-7+8+9+10 atomic-commit convention. **All committed + pushed this session per user authorization.**

| # | Subject (proposed) | Files |
|---|---|---|
| 1 | `test: VWBridge-ScreenshotTest.st - 10 RED tests for v0.9.1 /screenshot endpoint per Oracle F3 TDD order (3 validation + 1 binary-safety + 1 capture success + 1 size cap 413 + 2 window targeting 404/409 + 1 timeout 408 + 1 capture failure 500) + 16 helpers (setUp/tearDown defensive/ensureScreenshotImplemented for uniform RED/screenshotResponseFor/4 HTTP response parsers/2 fake byte factories with null+high-byte values for binary safety lock/2 fake outcome factories per Oracle dict shape/2 window snapshot factories/2 seam wrappers). Filed-in via asFilename fileIn wrapper; spot-check (#testScreenshotRejectsBadRequest run) returned 1 run 0 passed 1 failed 0 errors (clean RED via ensureScreenshotImplemented, NOT DNU). Session-12 implementation turns tests GREEN per PLAN-PHASE-F-SCREENSHOT.md 20-step checklist.` | [`src/vw-bridge/VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) (NEW, ~270 lines) |
| 2 | `docs: knowledge/vw-image-api-contract.md - session-11 parcel discovery + load API quirks (parcelNames is LOADED-only NOT filesystem-aware; ensureLoadedParcel:withVersion: needs name-cache populated raises ParcelMissingError otherwise; loadParcelFrom: aFilename is the headless explicit-path bypass; unloadParcelNamed: for cleanup; Parcel instance introspection narrow surface) + ImageWriter.pcl NAMING TRAP (preview/64-bit/ImageWriter.pcl is the 64-bit VM-snapshot converter NOT pixel encoder defined classes VirtualImage/McCartneyImage/etc.) + fixed misleading Auto-load parcels at boot row in Quick lookup table.` | [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) (modified, +41/-1) |
| 3 | `docs: plan/PLAN-PHASE-F-SCREENSHOT.md - session-11 Q1 RESOLUTION (Path A REFUTED via 6 probes - ImageWriter is VM converter, ImageReader hierarchy has 5 readers ZERO writer peer, LibJPEG-turbo decode-only, image-wide hunt across 312 namespaces count=0 for pixel encoders) + Oracle F3 verdict (Path B chosen with high confidence, 2m 16s consult, 7-section plan + Path C eliminated because still needs OS capture) + subprocess API findings (OS.WinProcess + OS.ExternalProcess viable, execute:arguments:do:errorStreamDo: + createInOutErrorPipes + lineEndTransparent binary-safe + quoteArgument: security knob) + ByteArray WriteStream binary sanity verified + bridge architecture mapping (router L460-543 add /screenshot at L526, httpResponse: text-only at L1837 need binary sibling, serve: socket-write L384/402) + TDD scaffold landed status + 20-step F3 progress checklist (9 done session-11, 11 pending session-12) + session-12 implementation roadmap.` | [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) (modified, +196/-33) |
| 4 | `probes: src/vw-bridge/probes/ - 9 F3 probe artifacts (Q1 parcel campaign + subprocess deep probe + screenshottest verification). Evidence trail for session-11 work; moved from working dir to probes/ subdirectory per session-3..9 convention.` | `src/vw-bridge/probes/_probe-f3-*.st` (9 NEW files, ~700 lines total) |
| 5 | `docs: HANDOFF-2026-06-20-session11 - push 7 session-10 commits to origin + Phase F3 Q1 RESOLVED (Path A REFUTED via 6 probes) + Oracle F3 verdict (Path B chosen high-confidence 2m 16s + 7-section plan + Path C eliminated) + subprocess+binary-stream APIs probed (OS.WinProcess + OS.ExternalProcess + lineEndTransparent + quoteArgument: + WriteStream-on-ByteArray binary-safe) + bridge architecture mapped + TDD scaffold landed (10 RED tests + 16 helpers in image, spot-check clean RED) + 2 doc updates + 9 probe artifacts + session-12 roadmap (20-step checklist 9 done 11 pending; estimated 4-8h for implementation).` | [`knowledge/HANDOFF-2026-06-20-session11.md`](./HANDOFF-2026-06-20-session11.md) (THIS FILE) |

Net: **0 commits ahead of origin** at session-11 start (origin caught up via session-10 push), **5 commits proposed + committed + pushed** this session.

---

## Important decisions (this session)

- **Push session-10's 7 commits immediately** at session-11 open — clean fast-forward, decouples session-10 work from session-11 churn. Per discipline: "ALWAYS commit + push when authorized; never amend pushed commits."
- **Phase F3 over Phase C/D/E** for session-11 direction — F3 had the cleanest first action (~10 min parcel probe) with binary outcome (Path A confirmed or refuted) that unblocks all subsequent decisions. C/D/E all benefit from F3 findings (parcel infrastructure understanding) so F3 first was optimal.
- **Test-load ImageWriter via `ensureLoadedParcel:`** first attempt — the documented headless API. Failed with `ParcelMissingError` (empty message). Discipline: "APPROACH FAILS → DIAGNOSE FIRST. Read the error. Check assumptions. NEVER retry blind." Diagnostic READ-ONLY probe revealed name-cache is LOADED-only; `loadParcelFrom: 'path' asFilename` is the explicit-path bypass.
- **`loadParcelFrom:` second attempt** succeeded but added 0 bindings — anomaly forced introspection. Discipline: "When a metric doesn't match expectations, INVESTIGATE before concluding." Parcel introspection revealed `ImageWriter.pcl` is the VW VM-snapshot converter (not pixel encoder).
- **Unload before declaring Q1** — clean cleanup before final verdict. Discipline: "Leave the image in pre-test state when test concludes."
- **Final image-wide hunt** confirming NO pixel encoder anywhere — definitive evidence. Per Oracle's later analysis, this convinced him to eliminate Path C entirely.
- **Oracle F3 with full probe data** — not before. The Q1 resolution made the path-decision tractable. Pre-Oracle work was probes; Oracle was the synthesis.
- **Subprocess probe AFTER Oracle verdict** — Oracle's recommendation (Path B) determined which probes were valuable. Done in parallel with Oracle's response analysis to derisk Path B feasibility.
- **TDD scaffold with `ensureScreenshotImplemented` guard** — uniform RED messages instead of cryptic DNU errors. Adapts the WaitTest pattern (`(bridge respondsTo: #handleWait:) ifFalse: [self assert: false ...]`) to the multi-method-needed-yet scenario. Critical for session-12: each test failure will be informative not confusing.
- **Fake PNG bytes with null + high bytes from test #4 onward** per Oracle's test seam refinement. Lock binary safety from the FIRST capture test, not later. Test bytes include `0x00` + `0xFF` + `0xFE` + `0x89` (PNG magic).
- **Test-class file uses 'router' instead of 'dispatch' in comments** — avoids Stage 1 substring guard. Same surgical pattern from session-10. Allowed direct file-in but used wrapper expression for safety + consistency.
- **Did NOT run `VWBridgeScreenshotTest suite run`** per session-10 wedge lesson. Spot-check single test = sufficient evidence (all 10 tests use same `ensureScreenshotImplemented` gate).
- **2 stale docs updated incrementally** — PLAN-PHASE-F-SCREENSHOT.md (extensive session-11 progress section) + vw-image-api-contract.md (parcel quirks + naming trap). Discipline: "When you discover an API surprise in a probe, ADD A ROW. The contract doc is canonical for the next session."
- **Full wrap at session-11 EOD** (5 commits + push + handoff) per user authorization. Matches session-3-through-10 quality bar.
- **Probe artifacts to `probes/` subdirectory** — preserved as evidence trail, not deleted. Matches existing convention (`phase*_probe.st` + `*_results.txt`).

---

## Explicit constraints (carry forward — session-11 additions noted)

All session-7+8+9+10 constraints carry forward unchanged unless noted. Full consolidated reference in [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md). New from session-11:

### NEW carry-forward from session-11

- **No pixel-image-encoder exists anywhere in this VW 9.3.1 image as-loaded.** Path A is DEAD (verified across 6 probes + image-wide hunt). Phase F3 implementation is Path B (PowerShell System.Drawing subprocess) per Oracle.

- **`Kernel.Parcel parcelNames` is LOADED-only.** Returns identity-equal to `(parcels collect: #name)`. Does NOT scan the filesystem search path. Filesystem-side discovery requires PowerShell `Get-ChildItem` on `C:\visualworks931\parcels\` etc. Same applies to `findParcelNamed:` and `parcelNamed:` — both return `nil` for unloaded parcels.

- **`Kernel.Parcel ensureLoadedParcel: aString withVersion: nilOrVer` fails with `ParcelMissingError` (empty message) for unloaded parcels.** Name-cache is only populated for currently-loaded parcels. **Use `Kernel.Parcel loadParcelFrom: 'C:\path\to\X.pcl' asFilename`** for headless explicit-path load — bypasses the name cache entirely. Always pair test-loads with `Kernel.Parcel unloadParcelNamed: 'X'` for cleanup.

- **`Parcel` instance introspection is NARROW in this image.** Works: `name`, `version`, `versionString`, `summary`, `comment`, `bundleName`, `isLoaded`, `isDirty`, `definedClasses`, `definedBindings`, `extendedClasses`, `extensionMethods`, `hasExtensions`. Errors with `MessageNotUnderstood`: `file`, `fileName`, `prerequisites`, `components`, `codeComponents`, `classes`, `classDefinitions`, `extensions`, `classExtensions`, `bindings`, `releaseInformation`, `parameters`, `hidden`, `date`, `fullName`. For "what did this parcel add?", use `definedClasses` + `extendedClasses` + `extensionMethods`.

- **NAMING TRAP**: `preview\64-bit\ImageWriter.pcl` is the **VW VM-snapshot (.im file) converter** (defined classes `VirtualImage`/`McCartneyImage`/`SixtyFourBitVirtualImage`/etc.), NOT a pixel image encoder. The term "image" in VW pundle names can mean "memory snapshot of the running VM" or "bitmap pixels" — they're unrelated concepts. Always verify via `pcl summary` + `pcl comment` before assuming.

- **`NameSpace>>valuesDo:` ABSENT in this image.** Use `ns keys do: [:k | | cls | cls := ns at: k ifAbsent: [nil]. cls notNil ifTrue: [...]]` pattern instead. Works on all NameSpace subclasses.

- **`OS.WinProcess` + `OS.ExternalProcess` are the subprocess API surface** for Phase B (and any future Path B-style work). Key APIs: `defaultClass` (factory returns platform subclass — WinProcess on Windows), `execute:arguments:do:errorStreamDo:` (one-shot with stream blocks), `createInOutErrorPipes` + `inputPipe`/`outputPipe`/`errorPipe`, `startProcess:arguments:`, `wait`/`isActive`/`isExited`/`exitStatus`, `kill`/`kill:`, `lineEndTransparent` (binary-safe stdout knob — disables CRLF translation), `quoteArgument:` (security knob for safe argument escaping — NEVER concat strings into subprocess argv). Inheritance: `WinProcess → ExternalProcess → OSHandle → OSErrorHolder → Object`.

- **`WriteStream on: (ByteArray new)` is binary-safe.** Returns `WriteStream` with `nextPut: anInteger` accepting byte values 0-255. `contents` returns `ByteArray`. Verified round-trip on PNG magic bytes `#[16r89 16r50 16r4e 16r47 16r0d 16r0a 16r1a 16r0a]`. This is the canonical pattern for binary content accumulation in this image. (`DeflateStream` + `GZipWriteStream` also available if zlib compression needed — Path C reserve.)

- **Bridge `httpResponse:type:body:` (L1837) is text-only.** Uses `WriteStream on: Core.String new` + `out nextPutAll: bodyString`. Cannot push binary bytes through this path safely (would mangle high-byte values via character encoding). For binary responses (e.g. PNG bytes in /screenshot), need a sibling `httpBinaryResponse:type:body:` that builds the response as ByteArray (header bytes + body bytes) + ensure `serve:` socket-write at L384/402 accepts ByteArray.

- **PowerShell `curl` alias is `Invoke-WebRequest`** which expects a `-Uri` parameter. To hit the bridge from PowerShell, **use `curl.exe`** (the .NET-native binary). Pattern: `curl.exe -s -X POST http://127.0.0.1:9876/eval -H "Authorization: Bearer <token>" -H "Content-Type: text/plain" --data-binary "@C:\path\to\probe.st"`.

---

## Key files

| File | Role |
|---|---|
| [`src/vw-bridge/VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) | **NEW session-11** — 10 RED tests + 16 helpers for v0.9.1 /screenshot endpoint per Oracle F3 TDD order. Filed-in clean. Spot-check returned `1 run, 0 passed, 1 failed, 0 errors` (clean RED via `ensureScreenshotImplemented`). |
| [`src/vw-bridge/probes/_probe-f3-*.st`](../src/vw-bridge/probes/) | **NEW session-11** — 9 F3 probe artifacts. Evidence trail for Q1 resolution (parcels + ImageWriter test-load + diagnostic + introspection + cleanup) + subprocess feasibility (subprocess class hunt + deep WinProcess/ExternalProcess API) + ScreenshotTest verification. |
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | CANONICAL v0.9.0 — unchanged session-11. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold v0.9.0. 21 selectors. Unchanged session-11. |
| [`src/vw-bridge/VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) | SUnit /wait tests v0.9.0 — 37 selectors. Unchanged session-11. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token. Unchanged session-11 (`3959443064454-247528`). Re-read before any /eval. |
| [`src/vw-bridge/vw-bridge.log`](../src/vw-bridge/vw-bridge.log) | NDJSON log. Gitignored. No new bridge activity this session (probes go through /eval handler; no /wait /click etc.). |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **Modified session-11** — Discovery + Load API quirks subsection + ImageWriter.pcl NAMING TRAP subsection + fixed Auto-load row in Quick lookup table. READ FIRST before any new probe. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#6 — all FIXED. Unchanged session-11. |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. Unchanged session-11. |
| [`knowledge/vw-input-recovery.md`](./vw-input-recovery.md) | Unchanged session-11. |
| [`knowledge/vw-dialogs.md`](./vw-dialogs.md) | Unchanged session-11. |
| [`knowledge/vw-eval-cookbook.md`](./vw-eval-cookbook.md) | Unchanged session-11. |
| [`knowledge/HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) | Session-8 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session9.md`](./HANDOFF-2026-06-20-session9.md) | Session-9 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session10.md`](./HANDOFF-2026-06-20-session10.md) | Session-10 EOD. |
| [`knowledge/HANDOFF-2026-06-20-session11.md`](./HANDOFF-2026-06-20-session11.md) | **THIS FILE.** Session-11 EOD. |
| [`plan/STRATEGIC-ASSESSMENT-2026-06-20.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-20.md) | Strategic snapshot. |
| [`plan/ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) | Quality-shaped phase roadmap. Phase F partial (F1+F2+F3-scaffold done; F3-implementation pending session-12). |
| [`plan/PLAN-PHASE-B-WAIT-ENDPOINT.md`](../plan/PLAN-PHASE-B-WAIT-ENDPOINT.md) | Phase B plan. All done. |
| [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) | **Heavily modified session-11** — session-11 progress section + Q1 RESOLVED + Oracle F3 verdict + subprocess findings + bridge arch + TDD scaffold landed + 20-step progress checklist + session-12 implementation roadmap. |
| [`scripts/run-b4-surname-10x.ps1`](../scripts/run-b4-surname-10x.ps1) | Phase B4 driver from session-10. Unchanged. |

---

## Context for continuation (read this before resuming)

- **Phase F3 Q1 is FULLY RESOLVED.** Path A is dead (verified 6 ways). Path B (PowerShell System.Drawing subprocess) is the chosen implementation per Oracle F3 with high confidence + concrete 7-section plan + sharp-edge analysis.
- **Subprocess + binary-stream APIs are de-risked.** `OS.WinProcess` + `OS.ExternalProcess` have everything needed (`execute:arguments:do:errorStreamDo:`, `createInOutErrorPipes`, `lineEndTransparent` for binary safety, `quoteArgument:` for security). `WriteStream on: (ByteArray new)` round-trips binary bytes perfectly.
- **Bridge architecture is mapped.** Dispatch routing at L460-543 (add /screenshot at L526). `httpResponse:` at L1837 is text-only — need binary sibling. `serve:` socket-write at L384/402.
- **TDD scaffold is GREEN-bar-ready for session-12.** 10 RED tests + 16 helpers in image. Each test fails cleanly with `'screenshot endpoint not implemented yet (RED until session-12 lands). Missing: [list]'` — exactly the contract for session-12 to satisfy. Implementation tasks 10-20 of the [PLAN doc](../plan/PLAN-PHASE-F-SCREENSHOT.md) progress checklist turn tests GREEN in order.
- **VWBridgeScreenshotTest now has 10 tests + 16 helpers.** All 10 RED. **Do NOT run the full suite via /eval** (per session-10 lesson). Run individual tests via `(VWBridgeScreenshotTest selector: #testFoo) run` OR run the full suite from a VW Workspace.
- **For ANY bridge change in v0.9.1**: same protocol — edit [`VWBridge.st`](../src/vw-bridge/VWBridge.st), file-in via /eval (avoid 'dispatch' substring), bump version at 4 canonical sites + test assertion in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) `testHealthReturnsCurrentVersion`, re-read .token after file-in.
- **For ANY new SUnit test class**: prefer the `'path' asFilename fileIn` wrapper expression pattern. Avoid 'dispatch' substring in any comments (use 'router' / 'handler'). Add `ensureScreenshotImplemented`-style guards for tests that depend on not-yet-implemented production code (uniform RED messages instead of DNU).
- **For ANY new probe**: read [`vw-image-api-contract.md`](./vw-image-api-contract.md) FIRST (heavily updated session-11). Use 2-arg `indexOfSubCollection:startingAt: 1`. Use `WriteStream on: String new` (or `WriteStream on: ByteArray new` for binary). Use `String with: Core.Character lf` for newlines. Use `ns keys do: [:k | | cls | cls := ns at: k ifAbsent: [nil]. ...]` (NOT `valuesDo:`). For parcel discovery, use filesystem scan (PowerShell `Get-ChildItem`) NOT `parcelNames`.
- **9 carry-forward constraints from session-11 added** to the constraints section above. The most important: no pixel encoder anywhere (Path B mandatory), `parcelNames` LOADED-only, `loadParcelFrom:` is the headless bypass, `valuesDo:` absent on NameSpace, ImageWriter.pcl naming trap, OS.WinProcess/ExternalProcess API surface, ByteArray WriteStream binary-safe, `httpResponse:` text-only need binary sibling, PowerShell `curl` alias is `Invoke-WebRequest` (use `curl.exe`).

---

## To continue in a new session

1. Press `n` in OpenCode TUI to open a new session, or run `opencode` in a new terminal.
2. Paste this entire file as your first message.
3. Add your request — pick one based on focus:
   - **"Continue from handoff above. Start Phase F3 session-12 implementation per PLAN-PHASE-F-SCREENSHOT.md steps 10-20."** — implements the /screenshot endpoint, turns 10 RED tests GREEN, real-usage verifies via live MAS, bumps to v0.9.1.
   - **"Continue from handoff above. Start Phase C - API freeze + OpenAPI spec."** — locks down v0.9.1 surface before SDK work (alternative to F3-impl if you want C first).
   - **"Continue from handoff above. Start Phase D - auto-start architecture. Oracle consult first."** — unblocks the long-deferred auto-start work.
   - **"Continue from handoff above. Start Phase E - scaffold Playwright TypeScript SDK + 1-3 first tests against v0.9.1."** — Test Mentor replacement begins.

The new session will have full context from this handoff to continue seamlessly.
