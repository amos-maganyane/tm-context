# Test Mentor Replacement — Phased Plan

## Context

SilverMark Test Mentor license is expiring. The replacement is an in-house
VisualWorks test automation bridge: a small Smalltalk package loaded into the QA
image that exposes the widget tree over HTTP, driven by an external Playwright
(TypeScript) test suite.

**POC is complete.** Widget discovery works end-to-end. This plan covers what
remains to reach full Test Mentor parity and beyond.

---

## What the POC Proved

- `GET /health` → `{"status":"ok","version":"0.5"}`
- `GET /windows` → JSON array of open windows with title, bounds, class
- `GET /windows/tree` → 29 widgets across 3 windows, live values on the wire
- Full chain: `curl` (external) → TCP `127.0.0.1:9876` → VWBridge in `storedev64`
  → `ScheduledControllers` → `builder.namedComponents` → JSON

VWBridge v0.5 source: [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st)

---

## Phase A — Interaction Endpoints (estimated: 1–2 weeks)

**Goal**: Make the bridge write-capable. Currently read-only.

All interaction ops go through `onUIDo:` with the Delay-watchdog pattern
(already proven in v0.5 — no changes to the threading model needed).

### A1 — `/click` endpoint

```
POST /click
Body: {"aspect": "loginRpcWidget"}
      {"label": "Save"}
      {"widgetId": "<id from /windows/tree>"}
```

Implementation:
1. Resolve widget ref via `builder namedComponents` lookup
2. Dispatch `onUIDo:` → synthesize `ButtonPressEvent` + `ButtonReleaseEvent`
   on the widget's controller
3. Wait for UI idle (watchdog semaphore already in place)
4. Return `{"ok": true}` or `{"error": "..."}` with embedded screenshot

### A2 — `/type` endpoint

```
POST /type
Body: {"aspect": "customerName", "text": "John Smith"}
```

Implementation:
1. Resolve widget → must be `InputFieldView`
2. `onUIDo:` → focus widget, inject `KeyPressEvent` per character
3. Alternative (faster): set `wrapper widget model value: aString` directly
   — test both; direct value-set is deterministic and avoids keyboard layout issues

### A3 — `/value` PUT (direct value set)

```
PUT /widgets/{aspect}/value
Body: {"value": "John Smith"}
```

Bypasses keyboard simulation. Sets `ValueHolder` directly. Preferred for data
entry in tests where keystroke-by-keystroke is not the behaviour under test.

### A4 — `/screenshot` endpoint

```
POST /screenshot
Body: {"scope": "screen"}          -- full display
      {"scope": "window", "title": "WEALTH"}
      {"scope": "widget", "aspect": "resultsTable"}
```

Implementation:
1. `onUIDo:` → `Display canvas` → `aForm writePNGfile: aFilename`
   or capture to `ByteArray` via `PNG codec`
2. Base64-encode, return in response body or save to file
3. Attach to error responses automatically (evidence capture)

### A5 — Bearer token enforcement

Currently the token is generated but not checked. Add auth gate:
```smalltalk
requestLine includes 'Authorization: Bearer '
    ifFalse: [^self httpResponse: 401 type: 'application/json' body: '{"error":"unauthorized"}']
```
Full header parsing needed — `serve:` currently reads only the first line.

### A5 — WEALTH/MAS window validation

Open the WEALTH application windows and re-run `GET /windows/tree`. The walker
is window-agnostic. Confirm WEALTH widget `aspect` names appear correctly so
Phase E test cases can reference them.

**Exit criteria for Phase A**: `curl` can click a button and type into a field
in the GemStone Launcher window. Screenshot returns valid PNG.

---

## Phase B — Full Widget Coverage (estimated: 1 week)

**Goal**: Cover all widget types Test Mentor handled.

### B1 — `/wait` endpoint (condition polling)

```
POST /wait
Body: {
  "condition": "widgetEnabled",   -- or: widgetExists, valueEquals, windowOpen, idle
  "aspect": "deleteButton",
  "expected": true,
  "timeout_ms": 5000
}
```

Poll every 100ms on the UI process. Return when condition met or timeout.
This is the primary synchronisation mechanism for tests — eliminates `sleep` calls.

### B2 — Dropdown / list selection

```
POST /select
Body: {"aspect": "accountType", "value": "Premium"}
      {"aspect": "accountType", "index": 2}
```

`SelectionInList` selection by value match or index. Dispatch `onUIDo:`.

### B3 — Double-click

```
POST /doubleClick
Body: {"aspect": "holdingsTable"}
```

Two `ButtonPressEvent` + `ButtonReleaseEvent` in rapid succession with
`doubleClickInterval` between them.

### B4 — Table cell access

```
GET /widgets/{aspect}/cell?row=0&col=Balance
```

`TableWidget` row/column navigation. `model rows` → `at: row` → column lookup
by header name. Returns cell value as string.

### B5 — Multi-window support

```
GET  /windows                          -- list all open windows with IDs
POST /windows/{id}/activate            -- bring window to front
POST /wait  {"condition": "windowOpen", "title": "Confirmation"}
```

Needed for dialogs, modal handling, and multi-window workflows.

### B6 — Structured error responses with screenshots

Every error response includes a base64 screenshot:
```json
{
  "error": "widget_not_found",
  "message": "No widget matching aspect='customerName' in window 'WEALTH'",
  "timestamp": "2026-06-13T...",
  "screenshot": "iVBORw0KGgo..."
}
```

**Exit criteria for Phase B**: All widget interaction types covered. A test can
navigate a WEALTH workflow end-to-end without manually inserting sleeps.

---

## Phase C — Playwright TypeScript SDK (estimated: 1 week)

**Goal**: Test-author-facing API. Playwright already knows HTTP — the SDK is a
thin wrapper around the REST endpoints with a typed, Playwright-idiomatic surface.

### C1 — `VWBridgeClient` HTTP wrapper

```typescript
// packages/vw-bridge-client/src/index.ts
export class VWBridgeClient {
  constructor(private baseUrl = 'http://localhost:9876', private token?: string) {}

  async healthCheck(): Promise<void> { ... }
  async windows(): Promise<WindowInfo[]> { ... }
  async widgetTree(windowId?: string): Promise<WidgetInfo[]> { ... }
  async click(selector: WidgetSelector): Promise<void> { ... }
  async type(selector: WidgetSelector, text: string): Promise<void> { ... }
  async getValue(selector: WidgetSelector): Promise<string> { ... }
  async setValue(selector: WidgetSelector, value: string): Promise<void> { ... }
  async isEnabled(selector: WidgetSelector): Promise<boolean> { ... }
  async wait(condition: WaitCondition): Promise<void> { ... }
  async screenshot(scope?: ScreenshotScope): Promise<Buffer> { ... }
}
```

### C2 — Playwright fixture

```typescript
// playwright.config.ts + fixtures/vw.ts
export const test = base.extend<{ vw: VWApp }>({
  vw: async ({}, use) => {
    const app = new VWApp(process.env.VW_AGENT_URL || 'http://localhost:9876');
    await app.healthCheck();
    await use(app);
    // screenshots on failure handled by Playwright's onTestFailed hook
  },
});
```

### C3 — Page Object base class

```typescript
export abstract class PageObject {
  constructor(protected app: VWApp) {}

  protected window(title: string) { return this.app.window(title); }
  protected field(aspect: string) { ... }
  protected button(label: string) { ... }
  protected table(aspect: string) { ... }
}

// Usage:
class BuyOnlinePage extends PageObject {
  async enterAmount(amount: number) {
    await this.window('Buy Online').field('amount').type(amount.toString());
  }
  async continueToCollection() {
    await this.window('Buy Online').button('Continue').click();
    await this.window('Buy Online').widget({ aspect: 'electronicCollection' }).waitFor();
  }
}
```

### C4 — Evidence capture

- Auto-screenshot on test failure (Playwright `testInfo.attachments`)
- Named screenshots on demand: `vw.screenshot('portfolio_loaded')`
- Allure report integration via `allure-playwright`

**Exit criteria for Phase C**: A developer can write a Playwright test against
WEALTH using `vw.window(...).button(...).click()` without touching raw HTTP.

---

## Phase D — Test Data Bridge (estimated: 3–5 days)

**Goal**: Decouple test data setup from UI. No 50-click setup sequences.

### D1 — Install WebGS in test GemStone stone

WebGS is already cloned to `remote-desktop/.../repos/WebGS/`. Install into the
`storeTst64` (or dedicated test) stone. Verify Swagger UI at `http://localhost:8888/docs`.

### D2 — Build `TestBridgeApi` on WebGS

Following the `FilmsApi` pattern from WebGS examples:

```smalltalk
Object subclass: #TestBridgeApi
    ...

TestBridgeApi class >> registerRoutesOn: aRouter
    aRouter GET: '/v1/fixtures'           do: [self listFixtures].
    aRouter POST: '/v1/fixtures/:name/load' do: [:req | self loadFixture: req].
    aRouter POST: '/v1/fixtures/reset'    do: [self resetAll].
    aRouter GET:  '/v1/state/:class/:id'  do: [:req | self inspectObject: req].
    aRouter GET:  '/v1/health'            do: [self health].
```

### D3 — gemstone-py integration for CI

```python
# conftest.py
import pytest
from gemstone import connect

@pytest.fixture(scope="session")
def gs():
    session = connect(stone="testStone", user="DataCurator", password=...)
    yield session
    session.close()

@pytest.fixture(autouse=True)
def reset_test_data(gs):
    gs.execute("TestDataManager reset")
    yield
    gs.execute("TestDataManager rollback")
```

**Exit criteria for Phase D**: A Playwright test can seed and assert GemStone
state without touching the UI for setup/teardown.

---

## Phase E — First Real Tests (estimated: 1–2 weeks)

**Goal**: 10 critical-path WEALTH tests. Prove coverage parity with Test Mentor.

| # | Test Case | Widgets Exercised |
|---|-----------|-------------------|
| 1 | Login via RPC | `loginRpcWidget` button, session list |
| 2 | Customer search returns results | search field, results table |
| 3 | Portfolio view loads with correct holdings | holdings table, balance cells |
| 4 | Buy online — electronic collection disables above R2m | `electronicCollection`, `directDeposit` |
| 5 | Trade entry — validation rejects invalid ISIN | trade entry fields, error dialog |
| 6 | Report generation completes | report selector, generate button, progress dialog |
| 7 | Modal dialog — confirm/cancel flow | confirmation dialog buttons |
| 8 | Table sort — ascending/descending toggle | column header click, row order |
| 9 | Multi-window — open detail from list row | list row double-click, detail window |
| 10 | Error state — session timeout handled gracefully | timeout dialog, reconnect flow |

**Exit criteria for Phase E**: All 10 pass in a single `npx playwright test` run
against the live `storeTst64` image. Evidence (screenshots) attached to report.

---

## Phase F — CI Pipeline (estimated: 3–5 days)

**Goal**: Headless, repeatable, evidence-collecting. Runs on push.

### F1 — Auto-start bridge on image boot

File-in `VWBridge.st` into `storeTst64.im` and save the image with the bridge
initialized. Or: add a startup action that evaluates `VWBridge start` on load.

```smalltalk
"Add to image startup list:"
ObjectMemory addToStartUpList: VWBridge
"Or simply save image after VWBridge start"
```

### F2 — CI job (GitHub Actions / GitLab CI)

```yaml
test-wealth-ui:
  tags: [windows, interactive-desktop]
  script:
    - Start-Process "C:\visualworks931\bin\win64\visual.exe" -ArgumentList "storeTst64.im"
    - Start-Sleep -Seconds 15          # wait for image boot + bridge start
    - curl http://127.0.0.1:9876/health   # health gate
    - npx playwright test tests/wealth/ --reporter=junit,html
  artifacts:
    when: always
    paths: [playwright-report/, test-results/]
```

### F3 — Port forwarding (if running tests from outside VM)

```powershell
# SSH tunnel from dev machine to VM:
ssh -L 9876:127.0.0.1:9876 vm-host
# Then pytest/playwright connects to localhost:9876 on dev machine
```

**Exit criteria for Phase F**: Green CI run on a push to main. Full HTML report
+ screenshots available as artifacts.

---

## Phase G — Migration (ongoing, after Phase E)

**Goal**: Complete coverage parity. Retire Test Mentor.

1. **Coverage audit**: enumerate all existing Test Mentor test cases
   (from `storeTst64TM.im` or `testCases.gs` — 18 MB fileout)
2. **Port each case** to Playwright + VW bridge
3. **Gap analysis**: identify any widgets that can't be reached structurally
   (canvas-rendered charts, third-party embedded controls)
4. **Vision fallback** for gaps only: OculiX template matching for chart areas
5. **Performance benchmark**: target <30s for full regression suite
6. **Retire Test Mentor**: remove `storeDev64TM.im` / `storeTst64TM.im` from rotation

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| VWBridge dies on image restart | High | Medium | Save image after file-in, or auto-start via startup list (Phase F1) |
| WEALTH widget aspect names differ from dev image | Medium | Medium | Run `/windows/tree` with WEALTH open before writing test cases |
| UI process deadlock from bad command | Low | High | Watchdog timeout already in place; add max 5s hard kill |
| GemStone state contamination between tests | Medium | Medium | `TestDataManager reset` in `autouse` fixture (Phase D) |
| Token auth bypass | Low | Low | Localhost-only bind; token enforced in Phase A5 |
| Team unfamiliar with Smalltalk for bridge changes | Medium | Medium | Bridge is <500 lines; AI (via Jasper MCP) handles Smalltalk edits |

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Playwright over pytest for widget tests | Team already uses Playwright; TypeScript SDK maps cleanly to widget selectors |
| Karate for WebGS contract tests | Feature files naturally test REST; OpenAPI spec drives contract validation |
| gemstone-py over GciForPython | Pooled sessions, async, pip-installable; GciForPython is legacy ctypes |
| aspect-first selectors | Most stable VW identifier; label breaks on i18n, index breaks on layout change |
| Direct `ValueHolder` set over keystroke replay | Deterministic, faster, layout-independent for data entry |
| VW bridge localhost-only | Security: never expose widget control surface on network |
