# Plan — Phase F /screenshot endpoint

**Written:** 2026-06-20 (session-10), after Oracle F1 design consult + F2 graphics-API probe.
**Status:** Foundation complete. **F3 implementation BLOCKED** on resolving the PNG-encoder question (probe finding below). The Oracle-recommended API shape is locked.
**Pre-reqs:** v0.9.0 bridge with /wait endpoint shipped.

---

## Bottom line

Per Oracle F1 synthesis: ship **`POST /screenshot` returning raw `image/png` bytes** on success, JSON error envelope on failure. Full virtual screen by default; optional deterministic window targeting via `appClass` + `titleContains`. PNG only. **16 MiB encoded cap** with `413 screenshot-too-large` on exceed (no automatic downscaling). Sync.

But F2 probe found **no PNG-encoder class exists in this image as-loaded.** The implementation path requires resolving how to get PNG bytes from a captured `Graphics.Image`. F3 needs deeper probe + Oracle consult before any code is written.

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

Three candidate paths, in order of cleanliness:

**Path A: Find a stock VW pundle that adds PNG-write support.** Per session-9 parcel discovery, `Kernel.Parcel` exists with 86 class-side selectors including `findParcelNamed:`, `parcelNames`, `parcels`. There are 103 stock `.pcl` files in `C:\visualworks931\parcels\` — one of them may be the image-IO encoder pundle (candidates: `Image*.pcl`, `Graphics*.pcl`, `BinaryIO.pcl`, `Compression-Zip.pcl`?). Probe `Parcel parcelNames` + `Parcel parcels` for matches. Load with `Kernel.Parcel ensureLoadedParcel:withVersion:`. **Lowest-risk path if available.**

**Path B: Use OS-level capture via subprocess.** Bridge forks a PowerShell or `.NET` process that uses `System.Drawing.Graphics.CopyFromScreen` + `Bitmap.Save(stream, ImageFormat.Png)`. Returns bytes via stdout to bridge serve-process. **High portability**; bypasses VW graphics entirely; sidesteps the missing PNG writer. **Downside:** subprocess overhead per capture, dependency on PowerShell/.NET being on the host (it is).

**Path C: Hand-roll PNG encoder in Smalltalk.** PNG is well-documented: header + IHDR chunk + IDAT (zlib-compressed pixel data) + IEND. Zlib compression available via `Graphics.PNGInflateStream`'s deflate counterpart (probe for `DeflateStream` / `ZipDeflateStream`). **Highest effort**; brittle; deferred unless A and B both fail.

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

## F3 next-session checklist

Recommended sequence:

1. **Probe `Kernel.Parcel parcelNames`** — list all 103+ stock parcels, look for image-write candidates. ~10 min.
2. **Probe `C:\visualworks931\parcels\*.pcl`** filesystem-side for names suggesting image-write codecs. Cross-reference with #1. ~5 min.
3. **If parcel found** → `Kernel.Parcel ensureLoadedParcel: 'CandidateName' withVersion: nil`, re-probe for PNG writer class. **Path A confirmed if it adds `PNGImageWriter` or similar.**
4. **If Path A fails** → Spike Path B: PowerShell `Add-Type -AssemblyName System.Drawing` + `[System.Drawing.Graphics]::FromHwnd(hwnd)` + `CopyFromScreen` + `bitmap.Save` to memory stream. Measure subprocess overhead vs UI-process onUIDo: capture path.
5. **Oracle consult F3** with probe results in hand — design the actual capture + encode pipeline given the path chosen.
6. **TDD scaffold** — write 8 tests RED (using the 2 test seams) before any production code.
7. **Implement handler** in `VWBridge.st` per Oracle's API shape spec.
8. **Implement capture/encode** per chosen path.
9. **Real-usage verification** — capture the live PartySearch window via bridge; verify bytes decode as valid PNG; visual inspection of the rendered image.

Estimated effort given resolved encoder question: ~6-10 hours including TDD + real-usage verification + bridge version bump to v0.9.1 + commit + docs.

---

## Key uncertainties

- **Parcel availability of an image-writer codec** — fundamental to Path A.
- **Whether `dllcc`-based FFI is set up in this image** — affects whether we could call Win32 GDI directly. Probe with `Smalltalk at: #ExternalProcedure` etc.
- **Whether the bridge serve-process can fork subprocesses cleanly on Windows** — should be fine with `OS.Subprocess` or `OS.ChildProcess` (whichever exists), but needs verification.
- **PNG encoding speed on Smalltalk-side vs PowerShell-side** — Path C would be slowest; Path B fastest given mature .NET PNG encoder.

---

## What was NOT done in session-10

- Probe for PNG-writer pundles (Q1 Path A first cut).
- Probe for VW FFI infrastructure (`ExternalProcedure`, `dllcc` namespace status).
- Probe for `OS.Subprocess` / equivalent for Path B feasibility.
- Probe for `Screen allScreens` to map the multi-monitor layout.
- Any code in `VWBridge.st`.

All of these are F3 next-session items.

---

## Resume hooks

- **Next-session anchor:** this file + [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md) + the Oracle synthesis above.
- **First action:** probe `Kernel.Parcel parcelNames` + `C:\visualworks931\parcels\*.pcl` for image-write codec candidates (Q1 Path A first cut).
- **Decision point:** after the parcel probe, pick Path A vs Path B vs both — that determines F3 effort estimate and timeline.
- **Quality bar:** same as Phase B's quality gate per [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) — "screenshot quality matches what a developer would manually capture; no truncation; readable file size; no broken images."
