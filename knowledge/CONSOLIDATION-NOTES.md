# VWBridge Consolidation — v0.8.5 single file

**Written:** end of session that consolidated the 7-file patch chain into one canonical source.
**Status:** [`VWBridge-consolidated.st`](../src/vw-bridge/VWBridge-consolidated.st) is on disk, **NOT yet filed in**, **NOT yet validated** end-to-end. Validation is the next step.

---

## What this is

A single, canonical `.st` file containing the entire VWBridge v0.8.5 implementation — the result of collapsing 7 incremental patch files (`VWBridge.st` + `VWBridge-phaseA.st` + `VWBridge-phaseB.st` + `VWBridge-phaseB1.st` through `VWBridge-phaseB4.st`) into one.

**Replaces** the 7-file patch chain. After cascade-modal flow is validated end-to-end, the 7 originals can be deleted and this file renamed to `VWBridge.st`.

**Same behavior as the patch chain** — no functional changes. Same class shape (`Root.Smalltalk.VWBridge` with instVars `port listener process token` + classInstVar `singleton`), same 78 methods, same endpoints, same token-write side effect, same auto-start on file-in.

---

## What was merged

### Methods kept "as-is" (single definition in originals, unchanged in consolidated)

69 methods inherited verbatim from their original phase file. No conflict resolution needed for these.

### Methods with overrides — latest version wins (9 methods, listed by where the winner lives)

| Method | Defined in (oldest → newest) | Winner | Why latest wins |
|---|---|---|---|
| `listenerLoop` | base v0.5, **phaseB1 v0.8.2** | phaseB1 | Per-connection fork — non-blocking listener |
| `serve:` | base v0.5, **phaseA v0.7** | phaseA | Full HTTP read with headers, body, auth |
| `dispatch:` (1-arg) | base v0.5, **phaseA v0.7** | phaseA | Routes through 3-arg dispatcher (backward-compat shim) |
| `dispatch:headers:body:` | phaseA, phaseB, phaseB2, phaseB3, **phaseB4 v0.8.5** | phaseB4 | All routes registered, version bumped to 0.8.5 |
| `resolveAspect:inWindowMatching:` | phaseA, **phaseB3 v0.8.4** | phaseB3 | Defensive `valuesDo:` fallback (fixes WealthPublishedPundleVersionsTool MNU) |
| `parseAnyValue:cursor:` | phaseA, **phaseB v0.8** | phaseB | Adds `$[` array case |
| `doListDialogs` | phaseB3, **phaseB4 v0.8.5** | phaseB4 | Filters via `scheduledControllers` (not stale `allInstances`) |
| `describeDialog:` | phaseB3, **phaseB4 v0.8.5** | phaseB4 | Extracts message via `spec.label asString` (handles ComposedText) |
| `doRespondDialog:` | phaseB3, **phaseB4 v0.8.5** | phaseB4 | Uses `target closeAndUnschedule` (wakes wedged modal loop) |

### Dead code dropped (NOT included in consolidated)

Removed because superseded by a later version OR by a structural change in the chain:

- **Base `serve:`** — superseded by phaseA's full HTTP serve. Original handled only request line.
- **Base `dispatch:` (1-arg)** — superseded by phaseA's shim that routes through `dispatch:headers:body:`. Original only knew about /health, /windows, /windows/tree at v0.5 version string.
- **Base `listenerLoop`** — superseded by phaseB1's per-connection-fork version. Original ran serve: inline on the single listener process (caused the wedge).
- **phaseA `resolveAspect:inWindowMatching:`** — superseded by phaseB3's defensive iteration.
- **phaseA `parseAnyValue:cursor:`** — superseded by phaseB's array-aware version.
- **phaseB3 `doListDialogs`** — superseded by phaseB4's `scheduledControllers`-filtered version.
- **phaseB3 `describeDialog:`** — superseded by phaseB4's ComposedText-aware version.
- **phaseB3 `doRespondDialog:`** — superseded by phaseB4's `closeAndUnschedule` mechanism.
- **phaseA, phaseB, phaseB2, phaseB3 `dispatch:headers:body:`** — all superseded by phaseB4's v0.8.5 version.
- **6 redundant auto-restart blocks** — each patch file ended with `VWBridge stop. VWBridge start.` + token-write. Consolidated has ONE such block at the end.

### Header / docstring

Header docstring consolidates the design notes from all 7 patches into one comprehensive section:
- Endpoint catalog
- Key design notes (socket layer, fork model, click strategy, valuesDo: gotcha, ComposedText, dialog dismissal, native dialogs toggle)
- Security note
- Namespace gotcha

---

## File-in procedure (one-time, after image restart)

### Step 0 — Restart the VW image

The image at the end of the last session was in a broken input-dispatch state (`activeControllerProcess: nil`, 3 zombie processes). Kill `vwnt.exe` PID 5912 in Task Manager, relaunch normally. See [`vw-input-recovery.md`](./vw-input-recovery.md) Level 4 for the procedure.

### Step 1 — File in the consolidated file

**IMPORTANT:** Use `asFilename fileIn.` from a Workspace, NOT the Launcher → File Browser → File In menu. In VW 9.3.1 (Momentum image) the Launcher menu's File In has chunk-parser quirks that fail on bridge files; the workspace `asFilename fileIn.` mechanism is the proven-working path (this is how all 7 prior phase files were filed in — see [`src/vw-bridge/SESSION-RESUME.md`](../src/vw-bridge/SESSION-RESUME.md) lines 20-23).

Open any Workspace and Do It (Ctrl+D) on this single line:

```smalltalk
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-consolidated.st' asFilename fileIn.
```

**Expected output (Transcript):**
```
VWBridge starting on 127.0.0.1:9876
VWBridge token: <new-token>
Try: curl http://127.0.0.1:9876/health
VWBridge: listening via SocketAccessor
Token written to .token: <new-token>
```

**Verify:**
```powershell
Get-Content -LiteralPath src\vw-bridge\.token
curl http://127.0.0.1:9876/health
# → {"status":"ok","version":"0.8.5"}
```

### Step 2 — Re-toggle native dialogs off

`Dialog useNativeDialogs` resets to `true` on every image restart. Native dialogs are invisible to VW introspection — they must be Smalltalk dialogs for `/dialogs` and `/dialogs/respond` to work.

```powershell
$tok = (Get-Content -LiteralPath src\vw-bridge\.token).Trim()
$h = @{ Authorization = "Bearer $tok" }
Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST `
  -Headers $h -Body 'Dialog useNativeDialogs: false' -ContentType 'text/plain'
# → ok=$true; result='false'
```

### Step 3 — Validate the cascade-modal flow (v0.8.5's reason to exist)

This was the unvalidated piece at session end. Procedure (full agent test):

```powershell
$tok = (Get-Content -LiteralPath src\vw-bridge\.token).Trim()
$h = @{ Authorization = "Bearer $tok" }

# 1) Trigger the Party Search Find action - opens "search may take a while" confirm modal
Invoke-RestMethod -Uri http://127.0.0.1:9876/click -Method POST -Headers $h `
  -Body '{"aspect":"findID"}' -ContentType 'application/json'
# (Background: /click is now wedged behind the modal)

# 2) Verify modal is visible to introspection
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs -Method GET -Headers $h
# → dialogs[0].message contains "search" / "while", buttons=["Yes","No"]

# 3) Respond "No" - dismisses first modal, may pop a "Search cancelled" cascade
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs/respond -Method POST -Headers $h `
  -Body '{"choice":"No"}' -ContentType 'application/json'
# → ok=true, method=closeAndUnschedule, recordedCancel=true

# 4) Check for cascade modal
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs -Method GET -Headers $h
# → if dialogs not empty: message="Search cancelled" or similar, buttons=["OK"]

# 5) Dismiss cascade modal
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs/respond -Method POST -Headers $h `
  -Body '{"choice":"OK"}' -ContentType 'application/json'

# 6) Verify all modals cleared
Invoke-RestMethod -Uri http://127.0.0.1:9876/dialogs -Method GET -Headers $h
# → dialogs=[]
```

**Success criteria:** `/click` background job no longer wedged, `/dialogs` returns empty, VW input still works after the flow (try clicking something in the Party Search window manually to confirm).

---

## After successful validation — cleanup migration (DONE 2026-06-19)

v0.8.5 dialog flow was validated end-to-end against the Party Search modal
(both validation-error path with OK and broad-search-confirm path with No;
`closeAndUnschedule` dismissed both cleanly with no zombie processes
across repeated cycles). Cleanup was then executed:

1. **Created** [`src/vw-bridge/archive/`](../src/vw-bridge/archive/) — preserves
   the historical patch chain for audit / future-port reference.
2. **Moved** the 7 phase files plus the deprecated workspace stub into
   `archive/`:
   - `VWBridge.st` (v0.5 base)
   - `VWBridge-phaseA.st` (v0.7)
   - `VWBridge-phaseB.st` (v0.8 / v0.8.1)
   - `VWBridge-phaseB1.st` (v0.8.2)
   - `VWBridge-phaseB2.st` (v0.8.3)
   - `VWBridge-phaseB3.st` (v0.8.4)
   - `VWBridge-phaseB4.st` (v0.8.5 patch)
   - `VWBridge-phaseA-workspace.st` (deprecated stub)
3. **Renamed** `VWBridge-consolidated.st` → `VWBridge.st` — now the canonical
   single-file v0.8.5 bridge.
4. **Wrote** [`archive/README.md`](../src/vw-bridge/archive/README.md) — version
   chain + warning not to file in (use `../VWBridge.st` instead).
5. **Updated** [`src/vw-bridge/SESSION-RESUME.md`](../src/vw-bridge/SESSION-RESUME.md)
   "FIRST ACTION on resume" — replaces the 3-file file-in instruction with the
   single-file `'path' asFilename fileIn.` form, and notes the new
   `/health` version is `0.8.5`.

After this migration, the install procedure is **one workspace Do It**:

```smalltalk
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn.
```

instead of the prior 7-step file-in rite. The token is auto-written to
`src\vw-bridge\.token` on every bridge start.

**Commit pending** — per AGENTS.md, no commit without explicit user OK. When
ready, suggested commit message:

> Phase C: consolidate 7-file VWBridge patch chain into single canonical v0.8.5
>
> All 7 phase files (VWBridge.st through VWBridge-phaseB4.st) collapsed into
> one src/vw-bridge/VWBridge.st with no functional change. Originals preserved
> under src/vw-bridge/archive/ for audit / reference. v0.8.5 dialog flow
> validated end-to-end (broad-search confirm dismissed via closeAndUnschedule,
> validation-error modal dismissed with OK, no zombie process accumulation).
> SESSION-RESUME.md updated with single-file install instruction.

---

## Verification done before this hand-off

| Check | Result |
|---|---|
| Method count: originals (78 unique selectors) vs consolidated (78) | ✓ Equal |
| Dropped (overridden) methods: 9 originals collapsed correctly | ✓ All resolved to latest version |
| Missing methods | ✓ None |
| Invented methods | ✓ None (the regex-flagged "defineClass:" is a false positive — it's the class definition chunk) |
| Method category structure | ✓ All 20 categories present, logical order |
| Chunk terminators (`!` lines) | ✓ 101 = expected (78 methods + 3 file-level + 20 category closers) |
| Bracket balance (code, strings stripped) | ✓ `[`=`]`, `{`=`}`, `(`=`)` all zero diff |
| Token-write block | ✓ Single block at end of file, writes to `src/vw-bridge/.token` |
| Auto-start on file-in | ✓ `VWBridge stop. VWBridge start.` at end |

---

## What's NOT included (deferred to Phase D)

This consolidation is **structural cleanup only**. It does NOT introduce:

- Namespace migration (still `Root.Smalltalk.VWBridge`, not e.g. `VWBridge.Core.Server`)
- Multi-class split (Core / Handlers / Tests packages)
- Proper Parcel / Bundle packaging
- Env-driven config (port / token / allowed hosts still hard-coded defaults)
- File-based logger (still uses `Transcript`)
- `/version` endpoint separate from `/health`
- Graceful shutdown endpoint

Those are Phase D — production packaging. Doing them now would mean packaging unvalidated code AND would require knowing what packaging mechanism this Momentum GBS image supports (probe needed: does `Parcel` class exist? what VW version? does Store run?).

---

## See also

- [`HANDOFF-2026-06-19.md`](./HANDOFF-2026-06-19.md) — full session handoff with VW image state and remaining EXPLORATION-PLAN steps
- [`vw-input-recovery.md`](./vw-input-recovery.md) — image restart procedure
- [`vw-dialogs.md`](./vw-dialogs.md) — dialog mechanism (why `closeAndUnschedule` is the right dismiss method)
- [`vw-bridge-testing.md`](./vw-bridge-testing.md) — testing discipline (restart bridge between cycles)
- [`smalltalk-gotchas.md`](./smalltalk-gotchas.md) — chunk format, namespace qualifiers, ComposedText, valuesDo: gotcha
