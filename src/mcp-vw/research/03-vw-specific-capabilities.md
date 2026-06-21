---
title: VW-Specific MCP Capabilities — Tools Jasper Cannot Have
purpose: Step 4 deliverable for Phase M research. Inventory of MCP tools that exploit the VW Bridge's GUI surface — capabilities Jasper (GemStone MCP server) structurally cannot offer because GemStone is a headless REPL with no UI behind it. These are the "force multipliers" of the VW MCP server: AI can SEE the UI, DRIVE workflows interactively, and capture diagnostic SCREENSHOTS, going far beyond Jasper's eval-and-status model.
written: 2026-06-21 (session-21 Phase M research, Step 4)
inputs: src/vw-bridge/VWBridge.st dispatch handlers (15 endpoints across L601-L2462) + knowledge/vw-image-api-contract.md (42 carry-forward constraints, esp. #28 /eval HTTP re-entry limit, #41 compile-on-VWB.VWBridge wedge)
status: DRAFT — ready for synthesis into design/architecture.md once librarian outputs land
---

# VW-Specific MCP Capabilities

## Why this matters

Jasper is an MCP server for **GemStone/S 64 Bit** — a server-side Smalltalk persistence engine with **no UI behind the REPL**. Jasper's tool surface is therefore restricted to: execute Smalltalk expressions, navigate code in the persisted image, run SUnit tests, introspect dictionaries, manage transactions. Powerful, but purely text-mode.

The VW Bridge exposes a running **VisualWorks 9.3.1 client image** with a full Win32 GUI — windows, modal dialogs, menus, buttons, lists, input fields. Every UI element is reachable through the bridge's 15 HTTP endpoints (`/windows`, `/windows/tree`, `/click`, `/type`, `/menu`, `/dialogs`, `/screenshot`, `/wait`, …). An MCP server wrapping this surface gives an AI agent capabilities Jasper structurally **cannot** offer:

- **See** the UI — enumerate windows + widgets, screenshot them, read field values
- **Drive** the UI — click buttons, type into input fields, select menu items, dismiss modals
- **Synchronize** with the UI — wait for windows to appear/close, wait for dialogs
- **Diagnose** the UI — capture failure-state screenshots for AI to analyze

These are the differentiators. Phase M's MVP tool surface must include enough of these to enable real workflows; V2/V3 expand coverage.

## Bridge endpoint inventory (single source of truth)

15 endpoints across HTTP methods (verified via `src/vw-bridge/VWBridge.st` `doDispatch:` L657-L708):

| Method | Path | Handler (L#) | Body shape | Returns |
|---|---|---|---|---|
| GET | `/health` | inline (L675) | — | `{status, version}` (auth-exempt) |
| GET | `/version` | inline (L678) | — | `{version, buildCommitSha, buildTimestamp, parcelMode}` (auth-exempt) |
| GET | `/windows` | `handleWindows` (L733) | — | `[{title, viewClass, appClass, bounds, originX/Y, cornerX/Y}, …]` |
| GET | `/windows/tree` | `handleTree` (L740) | — | `[{title, appClass, widgets:[{aspect, label, specClass, widgetClass, value}]}, …]` |
| GET | `/value?aspect=X[&windowTitle=Y]` | `handleGetValueQuery:` (L979) | — | `{ok, aspect, value}` |
| GET | `/menu?aspect=X` | `handleMenuQuery:` (L1300) | — | menu-tree JSON |
| GET | `/dialogs` | `handleDialogsQuery` (L1497) | — | `{ok, dialogs:[{id, class, message, buttons}]}` |
| POST | `/click` | `handleClickBody:` (L885) | `{aspect, windowTitle?}` | `{ok, aspect, method, oldValue, newValue}` |
| POST | `/type` | `handleTypeBody:` (L945) | `{aspect, value, windowTitle?}` | `{ok, aspect, value}` |
| POST | `/menu/click` | `handleMenuClickBody:` (L1326) | `{path:[…], aspect?, windowTitle?}` | `{ok, …}` |
| POST | `/eval` | `handleEvalBody:` (L1441) | raw Smalltalk source | `{ok, result}` (printString) |
| POST | `/dialogs/respond` | `handleDialogsRespondBody:` (L1655) | `{choice}` (Yes\|No\|OK\|Cancel\|Accept\|Decline) | `{ok, …}` |
| POST | `/wait` | `handleWait:` (L2116) | `{kind, timeoutMs, intervalMs, match?, messageContains?, windowId?, caseSensitive?}` | `{ok, satisfied, …}` or 408 |
| POST | `/screenshot` | `handleScreenshotBody:` (L2389) | `{targetType:screen\|window, format:png, maxBytes, timeoutMs, appClass?, titleContains?}` | binary `image/png` body OR JSON error |
| PUT | `/value?aspect=X[&windowTitle=Y]` | `handlePutValueQuery:body:` (L1005) | `{value}` | `{ok, aspect, value}` |

Auth shape: `Authorization: Bearer <token>` (token rotates on every `VWB.VWBridge start`; read from `src/vw-bridge/.token`). Auth-exempt: `/health`, `/version`, `/favicon.ico`.

## Proposed MCP tool surface (VW-only — 12 tools)

The naming convention is `vw_<action>_<object>` (analogous to Jasper's `gemstone_<action>`).

### Category A — UI Inspection (4 tools)

#### A1. `vw_list_windows`

**Description:** Enumerate every currently-open window in the VW image. Each entry includes title, view class, application class, and bounding rectangle (origin + corner). Use this to discover what's on-screen before driving any workflow.

**Params:** none.

**Returns:** Array of `{title, viewClass, appClass, bounds, originX, originY, cornerX, cornerY}`. Empty array if no windows open.

**Backend:** `GET /windows` → `handleWindows` → `windowsSnapshotForWait` (also feeds `/wait window-appears`).

**Sample workflow:** AI agent asks: "What windows are open?" → `vw_list_windows` → AI sees 3 entries (PartySearchView, MainWindow, …) → AI picks PartySearchView for the next step.

---

#### A2. `vw_describe_window`

**Description:** Get the full widget tree of one window — every named component with its aspect symbol, label, spec class, widget class, and current value (`printString`). Use this to discover what's clickable / typeable / selectable in a target window.

**Params:** `windowTitle: string` (substring match; nil = first scheduled window).

**Returns:** `{title, appClass, widgets:[{aspect, label, specClass, widgetClass, value}, …]}`.

**Backend:** `GET /windows/tree` → `handleTree` → `windowTrees` (filters to one window in the MCP layer).

**Sample workflow:** AI sees PartySearchView is open → `vw_describe_window {windowTitle: "PartySearch"}` → AI gets `[{aspect: searchCriteriaType, specClass: RadioButtonSpec, value: '#contractNumber'}, {aspect: searchString, specClass: InputFieldSpec, value: ''}, …]` → AI now knows what fields to fill.

---

#### A3. `vw_get_value`

**Description:** Read the current value of any named widget (input field text, list selection, radio selection, etc.) without clicking on it.

**Params:** `aspect: string` (widget aspect symbol), `windowTitle?: string` (substring; nil = any window).

**Returns:** `{ok, aspect, value}` (value is the widget model's value, JSON-encoded).

**Backend:** `GET /value?aspect=X&windowTitle=Y` → `handleGetValueQuery:`.

**Sample workflow:** AI fills a form, hits a button, then verifies: `vw_get_value {aspect: "searchString"}` → confirms the field still says what AI typed.

---

#### A4. `vw_list_dialogs`

**Description:** Enumerate every live modal `SimpleDialog` (or subclass) currently posted. Each entry includes the dialog class name, the message text, and the available button labels. Use this BEFORE attempting any UI workflow that might be blocked by a modal.

**Params:** none.

**Returns:** `{ok, dialogs:[{id, class, message, buttons}, …]}`. Empty array if no modal posted OR if `Dialog useNativeDialogs` is still true (native dialogs are invisible to VW introspection — wrapper toggles `useNativeDialogs: false` automatically at cold start, but worth re-toggling via `vw_eval` if AI gets unexpected empty results).

**Backend:** `GET /dialogs` → `handleDialogsQuery` → `dialogsSnapshotForWait` (also feeds `/wait dialog-appears`).

**Sample workflow:** AI tries `vw_click {aspect: "search"}` but gets unexpected behavior → AI calls `vw_list_dialogs` → discovers a confirm modal blocking → AI calls `vw_respond_dialog {choice: "OK"}` → retries the original workflow.

---

### Category B — UI Driving (4 tools)

#### B1. `vw_click`

**Description:** Click a named widget (button, radio, list row, tab, checkbox) in a target window. The MCP server picks the right strategy per widget class (RadioButtonSpec uses `model value: spec select` to fire the correct Symbol; everything else uses `model value: true` to fire the spec action — see `doClick:inWindow:` L901).

**Params:** `aspect: string` (widget aspect symbol — e.g. `searchAction`, `contractNumberRadio`), `windowTitle?: string`.

**Returns:** `{ok, aspect, method, oldValue, newValue}` on success, or `{error, message}` on failure (widget not found, click failed, UI timeout, …).

**Backend:** `POST /click {aspect, windowTitle?}` → `handleClickBody:`.

**Sample workflow:** AI fills 'PartySearch' window with surname → `vw_click {aspect: "search", windowTitle: "PartySearch"}` → search executes, results window appears → AI confirms with `vw_wait {kind: "window-appears", match: {appClass: "PartySearchResultsView"}}`.

---

#### B2. `vw_type`

**Description:** Set the value of an input field, ComboBox, text editor — any widget with a writable model. Equivalent of typing characters in the UI but executed directly through the widget's model.

**Params:** `aspect: string`, `value: string`, `windowTitle?: string`.

**Returns:** `{ok, aspect, value}` or `{error, message}`.

**Backend:** `POST /type {aspect, value, windowTitle?}` → `handleTypeBody:` (also exposed as `PUT /value?aspect=X` body `{value}` — same machinery).

**Sample workflow:** AI: `vw_type {aspect: "searchString", value: "Smith", windowTitle: "PartySearch"}` → field updates → AI confirms with `vw_get_value {aspect: "searchString"}` → matches.

---

#### B3. `vw_click_menu`

**Description:** Navigate and click a menu item by its label path (e.g. `["File", "Open", "Recent..."]`). Wraps the bridge's menu-navigation logic; handles 1-deep + 2-deep paths reliably (deeper menus carry forward from sessions 7-11 — `EXPLORATION-PLAN step 3` 3-deep verification still pending).

**Params:** `path: string[]` (label path from menu root), `aspect?: string` (target widget's aspect if menu is widget-specific), `windowTitle?: string`.

**Returns:** `{ok, …}` on success or error envelope.

**Backend:** `POST /menu/click {path, aspect?, windowTitle?}` → `handleMenuClickBody:`.

**Sample workflow:** AI: `vw_click_menu {path: ["File", "Quit"], windowTitle: "Launcher"}` → menu navigates + selects → app exits cleanly.

---

#### B4. `vw_respond_dialog`

**Description:** Click a button on the currently-posted live modal. Single-shot (cascading modals are AI's responsibility — call `vw_list_dialogs` again after responding to detect cascade).

**Params:** `choice: "Yes" | "No" | "OK" | "Cancel" | "Accept" | "Decline"` (case-sensitive; matches the button label as VW renders it).

**Returns:** `{ok, …}` or error envelope.

**Backend:** `POST /dialogs/respond {choice}` → `handleDialogsRespondBody:`.

**Sample workflow:** AI sees `{class: "SimpleDialog", message: "Save changes?", buttons: ["Yes", "No", "Cancel"]}` → calls `vw_respond_dialog {choice: "No"}` → dialog dismisses → AI calls `vw_list_dialogs` again → empty → workflow proceeds.

---

### Category C — Screenshot (1 tool)

#### C1. `vw_screenshot`

**Description:** Capture a PNG of the entire virtual screen OR one specific window. Returns the PNG bytes as an MCP `image` content type so Claude (or any vision-capable MCP client) can SEE the captured frame and reason about it visually. Backed by an out-of-process PowerShell helper (the bridge does not bundle a PNG encoder in-image — see api-contract §"Subprocess invocation" session-13).

**Params:** `targetType: "screen" | "window"`, `format: "png"` (only format supported), `maxBytes: int` (1..16777216 = 16 MiB hard cap; 413 if exceeded), `timeoutMs: int` (1..30000), `appClass?: string` + `titleContains?: string` (required when `targetType: "window"` — at least one must be provided; first-match-wins is forbidden so AT LEAST ONE filter is mandatory).

**Returns:** MCP `image` content (`type: "image"`, `mimeType: "image/png"`, base64 `data`) on success, or JSON error envelope (`screenshot-too-large` 413, `window-not-found` 404, `multiple-windows-matched` 409, `capture-timeout` 408, `screenshot-capture-failed` 500).

**Backend:** `POST /screenshot {targetType, format, maxBytes, timeoutMs, appClass?, titleContains?}` → `handleScreenshotBody:` → `captureScreenshotViaSubprocess:rect:` (forks `powershell.exe` with screenshot-helper.ps1).

**Sample workflow:** AI executes a workflow → unexpected result → AI calls `vw_screenshot {targetType: "screen", format: "png", maxBytes: 5000000, timeoutMs: 10000}` → AI sees the rendered UI → AI diagnoses (e.g. "the search ran but a 'No results' label is showing; the surname spelling must be wrong") → AI retries with corrected input.

**Force multiplier:** This is the single most powerful VW-only tool. Jasper agents debug by `printString`. VW agents debug by LOOKING at the UI.

---

### Category D — Wait Predicates (1 tool)

#### D1. `vw_wait`

**Description:** Block until a UI predicate is satisfied, or timeout. Four predicate kinds supported (compound `all`/`any` + arbitrary `eval-truthy` NOT supported per MVP — see `parseAndValidateWaitRequest:` L2160):

- `window-appears` — wait for any window matching `{appClass, titleContains, …}` to appear
- `window-closes` — wait for a specific window (by `windowId` from `vw_list_windows` OR by `match` filter) to close
- `dialog-appears` — wait for any modal whose message contains `messageContains` substring
- `dialog-closes` — wait for any modal whose message contains `messageContains` substring to dismiss

**Params:** `kind: enum-of-4-above`, `timeoutMs: int` (1..60000 — hard cap 60s), `intervalMs: int` (50..1000 — poll interval), plus per-kind: `match: object` (for window-* kinds), `messageContains: string` + `caseSensitive?: bool` (for dialog-* kinds), `windowId?: string` (for window-closes).

**Returns:** `{ok, satisfied, …}` on success (200), or `{ok: false, error: "timeout", polls, elapsedMs}` on timeout (408).

**Backend:** `POST /wait {kind, …}` → `handleWait:`.

**Sample workflow:** AI types into a slow-rendering field → `vw_wait {kind: "window-appears", timeoutMs: 5000, intervalMs: 200, match: {appClass: "ResultsView"}}` → waits up to 5s, polls every 200ms, satisfies as soon as the results window renders → no race condition.

---

### Category E — Code Execution (1 tool — Jasper-equivalent for completeness)

#### E1. `vw_eval`

**Description:** Evaluate arbitrary Smalltalk source via VW's `Compiler`. Returns `printString` of the result. NOT a Jasper-exclusive — this is the direct equivalent of Jasper's `execute_code` tool — but listed here for completeness because every VW MCP workflow will eventually need it (e.g. for `Dialog useNativeDialogs: false` re-toggle, or for any expression Phase M's typed tools don't cover).

**Params:** `source: string` (Smalltalk source code).

**Returns:** `{ok, result}` (result is `printString`) or `{error, message}` (compile error, runtime error, or one of the safety guards below).

**Backend:** `POST /eval` (body = source) → `handleEvalBody:`.

**Safety constraints (must surface in MCP tool description AND error semantics):**

- **Bug #5 Stage 1 substring guard (carry-forward in api-contract):** body containing BOTH `'VWBridge'` AND `'dispatch'` substrings is rejected with `recursive_dispatch_forbidden` 400. Workaround documented in error message — direct handler calls like `VWBridge singleton handleWindows` are allowed because they contain no `'dispatch'`.
- **Bug #5 Stage 2 per-process re-entry counter:** if `/eval` body indirectly calls back into the dispatcher (e.g. via socket), the second dispatch fires `recursive_dispatch` 400 immediately rather than wedging the listener. Same defense from a different angle.
- **Carry-forward #41 (compile-on-VWB.VWBridge wedge — session-20):** `Cls compile: 'methodSource' classified: 'cat'` on VWB.VWBridge from `/eval` body WEDGES the bridge even with the Cursor monkey-patch installed. Implication for Phase M tool design: **do NOT expose a `vw_compile_method` MCP tool that targets VWB.VWBridge or any class whose `compile:` would fire UI announcement fan-out**. Either scope `vw_compile_method` to MAS classes only (which don't seem to wedge), or surface this as a constraint to the AI in the tool description.

**Sample workflow:** AI: `vw_eval {source: "Smalltalk.Dialog useNativeDialogs: false. ^'native-off'"}` → re-arms Bug #2 fix without bouncing the bridge → AI proceeds with `vw_list_dialogs` reliably.

---

### Category F — Bridge Liveness (2 tools)

#### F1. `vw_health`

**Description:** Auth-exempt liveness check. Returns the bridge's current version and an "ok" status. Use this to verify the bridge is responsive before any other tool call (or to detect bridge-restart mid-session — token rotation will follow).

**Params:** none.

**Returns:** `{status: "ok", version: "0.10.0"}`.

**Backend:** `GET /health` (no auth).

**Sample workflow:** MCP server starts → calls `vw_health` → bridge UP → registers all VW tools → ready. Mid-session, any tool error → MCP server retries `vw_health` → if 200, transient bridge issue (retry); if connection refused, bridge is down (surface clear error to AI).

---

#### F2. `vw_version`

**Description:** Auth-exempt build-metadata probe. Returns the bridge's version + git commit SHA at launch + UTC build timestamp at launch + parcel mode (FileIn vs Parcel). Use this for SDK version-pinning, CI sanity checks, or telling the AI agent which bridge build it's talking to.

**Params:** none.

**Returns:** `{version, buildCommitSha, buildTimestamp, parcelMode}`.

**Backend:** `GET /version` (no auth, Phase P P8 ship — session-20).

**Sample workflow:** MCP server starts → calls `vw_version` → compares `version` field to its compiled-in `MIN_BRIDGE_VERSION` constant → if mismatch, surface to user with "please rebuild your bridge to v0.10.0+" instead of trying tools that won't work.

---

## Tool count summary

| Category | Tools | Notes |
|---|---:|---|
| A. UI Inspection | 4 | `vw_list_windows`, `vw_describe_window`, `vw_get_value`, `vw_list_dialogs` |
| B. UI Driving | 4 | `vw_click`, `vw_type`, `vw_click_menu`, `vw_respond_dialog` |
| C. Screenshot | 1 | `vw_screenshot` — the differentiator vs Jasper |
| D. Wait Predicates | 1 | `vw_wait` (4 kinds: window-appears, window-closes, dialog-appears, dialog-closes) |
| E. Code Execution | 1 | `vw_eval` (Jasper-equivalent; safety-constrained per Bug #5 + #41) |
| F. Bridge Liveness | 2 | `vw_health`, `vw_version` (both auth-exempt) |
| **Total VW-only or VW-shaped** | **12 tools** | |
| Total Jasper-equivalent (this doc) | 1 (E1) | Other Jasper equivalents — `find_senders`, `find_references_to`, `get_class_definition`, etc. — covered in 02-jasper-delta.md |

## MVP / V2 / V3 tier suggestion

This decision belongs in `design/architecture.md`, but the rough cut from this doc's perspective:

- **MVP (must ship in first cut):** F1, F2, A1, A2, B1, B2, E1. Seven tools cover "AI can see what windows exist, see what widgets a window has, click + type, eval arbitrary Smalltalk, check bridge liveness." Enough for ~80% of dev-loop tasks.
- **V2 (next iteration):** A3 (`vw_get_value`), A4 (`vw_list_dialogs`), B4 (`vw_respond_dialog`), C1 (`vw_screenshot`), D1 (`vw_wait`). Five more tools. Adds value-introspection, dialog-handling, screenshot-debug, race-free synchronization.
- **V3+ (deferred):** B3 (`vw_click_menu`) — depends on EXPLORATION-PLAN steps 3-4 verification of 3-deep menu navigation (carry-over from sessions 7-11). Defer until menu-tree dispatch catalog is solid.

## Constraints that affect every tool

These apply uniformly to the entire VW MCP tool surface — should be documented once in `design/architecture.md` rather than repeated per tool:

1. **Auth token rotation** — every `VWB.VWBridge start` (cold-start or `load.st`-reload) writes a fresh `.token` file. The MCP server must read `.token` per-request, OR watch its file mtime and reload on change. Hardcoding the token is a non-starter.
2. **Bridge cold-start latency** — typical Start-VWBridge.ps1 cycle is ~9 seconds (FileIn) / ~8 seconds (Parcel). MCP server should NOT auto-start the bridge on tool errors (too slow + may conflict with user's manual launch); instead, surface a clear "bridge is down — please run Start-VWBridge.bat" error.
3. **Bug #5 re-entry guards** — `/eval` cannot call back into the bridge dispatcher. This affects any AI workflow that tries clever in-band orchestration. The MCP server can mitigate by ALWAYS calling direct handler methods (e.g. `VWBridge singleton handleWindows`) from `vw_eval` rather than HTTP self-call.
4. **Carry-forward #41 (compile-on-VWB.VWBridge wedge)** — see E1 above. Tool descriptions for any future `vw_compile_method` MUST surface this limitation to the AI.
5. **Carry-forward #28 (HTTP /eval inherent limit)** — Bug #5 cannot be fully closed at the bridge level; the MCP server is the right place to document the workaround pattern in tool descriptions so AI agents don't try the foot-gun.
6. **Carry-forward #19/#20 ( `/eval` pre-flight rule)** — for any AI-generated Smalltalk that the user will then paste in Workspace, the MCP server's `vw_eval` tool should be the first place AI tries the snippet (cheap ~1 sec round trip) before handing to user. This catches Workspace `Core.*`-vs-`/eval` namespace ambiguity AND syntax errors.

## Next step

Synthesize this catalog into `design/architecture.md` MVP/V2/V3 tool surface decision after librarian outputs land (01-mcp-sdk.md + 02-jasper-delta.md). Cross-check: any Jasper tool that maps onto an existing bridge endpoint should land in category E or its own category in 02; any Jasper tool that needs a NEW bridge endpoint goes into a "Phase M future work" list.
