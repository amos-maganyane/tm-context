# VisualWorks Smalltalk Test Automation Bridge

## Architecture Document

**Problem:** Smalltalk Test Mentor license expiring. VisualWorks renders ALL widgets custom (zero native OS controls). Windows UI Automation, MSAA, Playwright, Selenium, WinAppDriver, Appium all fail -- no accessibility tree exposed.

**Solution:** Internal instrumentation -- a test-only Smalltalk package loaded into the QA image that exposes the widget graph over a RESTful API (OpenAPI 3.x), driven by an external Python test framework.

**Maintenance model:** Built and maintained by AI. Human team provides access and domain knowledge; AI writes Smalltalk agent code, Python SDK, and test suites.

---

## Why Internal Instrumentation (Not Vision)

| Criterion | Internal Instrumentation | Vision/OCR (Eggplant, OculiX) |
|-----------|--------------------------|-------------------------------|
| Reliability | 95%+ (deterministic) | 60-85% (fragile) |
| Speed | <10ms/action | 100-500ms/action |
| Maintenance | Low (selector-stable) | High (reference images rot) |
| State access | Full (enabled, visible, value, selection) | Pixel heuristics only |
| DPI/theme immune | Yes | No -- breaks on change |
| CI/CD ready | Yes (headless, fast) | Requires virtual display, slow |
| Cost | Development effort only | Tool license OR dev effort |
| 50-step workflow success | ~95% (0.999^50) | ~0.5-7% (0.9^50 to 0.95^50) |

Vision-based is fallback only. It cannot serve as primary regression strategy for a financial desktop app.

---

## System Architecture

```
+------------------------------------------------------------------+
|                    TEST RUNNER (CI/CD)                             |
|  pytest + allure + junit-xml                                      |
+------------------------------------------------------------------+
         |
         | Python SDK (high-level API)
         |
+------------------------------------------------------------------+
|                    DRIVER SDK (Python)                             |
|  app.window("Main").table("Accounts").cell(row=3, col="Balance")  |
|  Page Object Model, retry/wait strategies, evidence capture       |
+------------------------------------------------------------------+
         |
         | REST API (HTTP, OpenAPI 3.x, Bearer token auth)
         | localhost:PORT (port-forwarded from VM if remote)
         |
+------------------------------------------------------------------+
|                    REST API (OpenAPI 3.x)                          |
|  /windows, /widgets, /actions, /wait, /screenshot, /test-data     |
|  Synchronous, versioned (/v1/...), JSON bodies                    |
+------------------------------------------------------------------+
         |
         | Command queue (serialized onto UI process)
         |
+------------------------------------------------------------------+
|               IN-IMAGE TEST AGENT (Smalltalk)                     |
|  Loaded in QA image only. Disabled by default.                    |
|  Widget tree enumeration, synthetic events, state queries          |
|  HTTP server (background process), UI executor (UI process)        |
+------------------------------------------------------------------+
         |
         | VisualWorks internals (ApplicationModel, UIBuilder,
         | WidgetWrapper, ComponentSpec, ScheduledWindow)
         |
+------------------------------------------------------------------+
|               VISUALWORKS APPLICATION                              |
|  Custom-rendered widgets, GemStone persistence                    |
+------------------------------------------------------------------+
```

---

## Layer 1: In-Image Test Agent (Smalltalk Package)

### Core Classes

```
TestBridgeAgent
  - A singleton managing the TCP listener and command dispatch
  - Started via: TestBridgeAgent start (or startOn: portNumber)
  - Stopped via: TestBridgeAgent stop

TestBridgeListener
  - Background Smalltalk process (NOT the UI process)
  - HTTP server on 127.0.0.1 only (using VW's built-in HTTP support or minimal custom)
  - Parses HTTP requests, validates Bearer token
  - Routes to appropriate handler, enqueues commands onto TestBridgeExecutor

TestBridgeExecutor
  - Runs ALL widget operations on the UI process
  - Uses VisualWorks' UIProcess mechanism to schedule work
  - Returns results to the listener for TCP response
  - Implements "UI idle" detection before responding

TestBridgeWidgetFinder
  - Traverses the widget tree from ScheduledWindow roots
  - Selector strategies: byLabel, byClass, byName, byPath, byIndex
  - Composite selectors: window > panel > button[label="Save"]
  - Returns widget references (internal handles, not exposed raw)

TestBridgeActions
  - click: aWidgetRef
  - doubleClick: aWidgetRef
  - type: aString into: aWidgetRef
  - select: anItem in: aWidgetRef
  - expand: aTreeNode
  - scroll: direction in: aWidgetRef
  - All actions synthesize proper VisualWorks events

TestBridgeAssertions
  - getText: aWidgetRef
  - getValue: aWidgetRef
  - isEnabled: aWidgetRef
  - isVisible: aWidgetRef
  - getSelection: aWidgetRef
  - getCellData: row col in: aTableRef
  - getWindowTitle: aWindowRef

TestBridgeScreenshot
  - Captures Display form as PNG bytes
  - Can capture specific widget bounds
  - Returns base64-encoded image in response
```

### VisualWorks Widget Tree Access

VisualWorks UI architecture (from research):

```
ScheduledWindow (top-level OS window)
  └── ApplicationModel (controller/glue)
       └── UIBuilder (constructed from windowSpec)
            └── WidgetWrapper hierarchy
                 ├── InputFieldSpec → ValueHolder (aspect)
                 ├── ActionButtonSpec → action selector
                 ├── ListSpec → SelectionInList
                 ├── TableSpec → rows/columns
                 ├── TreeViewSpec → hierarchical
                 └── SubCanvasSpec (nested ApplicationModel)
```

Key access patterns:

```smalltalk
"Enumerate all open windows"
ScheduledControllers scheduledControllers
    collect: [:ctrl | ctrl model]  "→ ApplicationModel instances"

"Get the UIBuilder for an application"
anApp builder  "→ UIBuilder with named components"

"Find a widget by its aspect name"
anApp builder componentAt: #customerName  "→ WidgetWrapper"

"Get the underlying spec"
aWrapper spec  "→ ComponentSpec with label, enabled, visible"

"Read widget value"
aWrapper widget model value  "→ current field value"

"Find by label text"
anApp builder namedComponents
    select: [:assoc | assoc value spec label = 'Save']

"Synthesize a click"
aWrapper widget controller
    dispatchEvent: (ButtonPressEvent new)
```

### Threading Model (Critical)

VisualWorks uses cooperative green threads (Processes). The UI runs in a dedicated UI Process. Rules:

1. **Socket listener**: Runs in its own Process (background priority)
2. **Command execution**: MUST be scheduled onto the UI Process
3. **Mechanism**: Use `UIProcess interruptWith: [...]` or `WorldState addDeferredAction: [...]`
4. **Synchronization**: Semaphore between listener and executor
5. **UI idle detection**: After action, wait for `WorldState stepGlobal` to settle before responding

```smalltalk
"Schedule work on UI process and wait for result"
| result sem |
sem := Semaphore new.
UIProcess interruptWith: [
    result := self executeCommand: aCommand.
    sem signal].
sem wait.
^ result
```

### Security

- Bind to `127.0.0.1` ONLY (never `0.0.0.0`)
- Ephemeral port (OS-assigned, written to a known file path for driver pickup)
- One-time session token generated at startup, required in every request
- Command whitelist -- no arbitrary code evaluation
- Payload size cap (prevent OOM attacks)
- Logging: every command + result + timestamp to transcript/file
- **Disabled by default** -- must be explicitly started
- **Never loaded in production images**

---

## Layer 2: Wire Protocol (RESTful API -- OpenAPI 3.x)

### Design Decision

The wire protocol is a **RESTful HTTP API** conforming to OpenAPI 3.x standards. This replaces raw TCP sockets because:

- Self-documenting (Swagger UI for manual exploration)
- Standard tooling (curl, Postman, any HTTP client in any language)
- Python SDK becomes a thin OpenAPI client (can auto-generate)
- Easier to debug, mock, and test the bridge in isolation
- Versioned via URL path (`/v1/...`)

### Transport

- HTTP/1.1 on `127.0.0.1` only (never `0.0.0.0`)
- Port discovery: agent writes `{port: N, token: "..."}` to a well-known file path on the VM
- Stateless requests with Bearer token authentication
- JSON request/response bodies

### Access Model (Remote VM)

The VisualWorks application runs inside a Windows VM accessed via RDP. The REST agent runs inside that VM on localhost. External access:

```
Your PC (RDP client)
    │
    │  RDP session to VM
    ▼
Windows VM (VW app + REST agent on 127.0.0.1:PORT)
    │
    │  SSH tunnel / port forward (VM:PORT → your PC:PORT)
    ▼
Your PC (Python SDK / pytest connects to localhost:PORT)
    │
    │  (or: AI agent calls via forwarded port)
    ▼
Test results + evidence
```

Options for port exposure:
1. **SSH tunnel** (preferred): `ssh -L 8099:127.0.0.1:8099 vm-host`
2. **netsh port proxy**: If SSH unavailable, Windows native forwarding
3. **Agent binds to VM's LAN IP**: Least secure, only if tunnel impossible (add IP allowlist)

### OpenAPI Specification (Summary)

```yaml
openapi: 3.0.3
info:
  title: VW Test Bridge API
  version: 1.0.0
  description: REST API for VisualWorks widget automation

servers:
  - url: http://127.0.0.1:{port}/v1
    variables:
      port:
        default: "8099"

security:
  - bearerAuth: []

paths:
  /health:
    get:
      summary: Health check (no auth required)
      responses:
        200: {description: Agent running, image loaded}

  /windows:
    get:
      summary: List all open application windows
      responses:
        200:
          content:
            application/json:
              schema:
                type: array
                items: {$ref: '#/components/schemas/WindowInfo'}

  /windows/{windowId}/widgets:
    get:
      summary: List widgets in a window (optionally filtered)
      parameters:
        - name: windowId
          in: path
          required: true
        - name: aspect
          in: query
          description: Filter by aspect name
        - name: label
          in: query
          description: Filter by label text
        - name: class
          in: query
          description: Filter by widget class

  /widgets/{widgetId}:
    get:
      summary: Get widget state (value, enabled, visible, bounds)

  /widgets/{widgetId}/actions:
    post:
      summary: Perform action on widget
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                action: {enum: [click, doubleClick, type, clear, select, expand, collapse, scroll]}
                args: {type: object}

  /widgets/{widgetId}/value:
    get:
      summary: Get current widget value
    put:
      summary: Set widget value directly

  /wait:
    post:
      summary: Wait for a condition
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                condition: {enum: [widgetExists, widgetEnabled, valueEquals, windowOpen, idle]}
                selector: {type: object}
                expected: {}
                timeout_ms: {type: integer, default: 5000}

  /screenshot:
    post:
      summary: Capture screenshot
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                scope: {enum: [screen, window, widget]}
                target: {type: string}
      responses:
        200:
          content:
            image/png: {}

  /test-data:
    post:
      summary: Seed or reset test data (GemStone)
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                action: {enum: [seed, reset, rollback]}
                fixture: {type: string}

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer

  schemas:
    WindowInfo:
      type: object
      properties:
        id: {type: string}
        title: {type: string}
        class: {type: string}
        bounds: {$ref: '#/components/schemas/Bounds'}

    WidgetInfo:
      type: object
      properties:
        id: {type: string}
        aspect: {type: string}
        class: {type: string}
        label: {type: string}
        value: {}
        enabled: {type: boolean}
        visible: {type: boolean}
        bounds: {$ref: '#/components/schemas/Bounds'}

    Bounds:
      type: object
      properties:
        x: {type: integer}
        y: {type: integer}
        width: {type: integer}
        height: {type: integer}
```

### Selector Strategy

Widgets are identified by query parameters on the collection endpoints:

| Parameter | Example | Stability |
|-----------|---------|-----------|
| `aspect` | `?aspect=customerName` | Highest -- internal VW binding name |
| `path` | `?path=detailsPanel.nameField` | High -- hierarchical |
| `label` | `?label=Save` | Medium -- breaks on i18n |
| `class` | `?class=ActionButtonView` | Medium -- many matches |
| `index` | `?class=InputFieldView&index=2` | Low -- breaks on layout change |

### Synchronous Model

All endpoints block until:
1. The action is dispatched on the UI process
2. The UI process returns to idle (no pending events)
3. Any triggered animations/redraws complete

This eliminates race conditions in test code. No polling needed on the client side.

### Error Responses

```json
{
  "error": "widget_not_found",
  "message": "No widget matching aspect='customerName' in window 'Main'",
  "timestamp": "2026-05-31T12:00:00Z",
  "screenshot": "base64..."  
}
```

Standard HTTP status codes:
- `200` success
- `404` widget/window not found
- `408` timeout (wait expired)
- `409` action failed (widget disabled, modal blocking)
- `401` bad/missing token
- `500` internal agent error

---

## Layer 3: Python Driver SDK

### Installation

```bash
pip install vw-test-bridge
```

### High-Level API

```python
from vw_bridge import VWApp, connect

# Connect to running VisualWorks image (reads port/token from discovery file, or env vars)
# Works locally on VM or via port-forwarded tunnel from your PC
app = connect()  # or: connect(host="127.0.0.1", port=8099, token="...")

# Window access
main = app.window("Portfolio Manager")

# Widget interaction
main.field("customerName").type("John Smith")
main.button("Search").click()
main.table("Results").wait_for_rows(min=1, timeout=10)

# Assertions
assert main.table("Results").cell(0, "Balance") == "R 150,000.00"
assert main.button("Delete").is_enabled() is False

# Screenshots on demand
main.screenshot("portfolio_loaded.png")

# Scoped selectors
with main.panel("Details") as details:
    details.field("email").type("john@example.com")
    details.dropdown("accountType").select("Premium")
    details.button("Save").click()

# Wait strategies
main.dialog("Confirmation").wait(timeout=5)
main.dialog("Confirmation").button("Yes").click()

# Table operations
table = main.table("Holdings")
for row in table.rows():
    if row["Fund"] == "Equity Fund A":
        row.click()
        break

# Evidence capture
app.screenshot("evidence/final_state.png")
app.disconnect()
```

### Page Object Model

```python
from vw_bridge import PageObject, widget

class PortfolioPage(PageObject):
    window_title = "Portfolio Manager"

    customer_name = widget(aspect="customerName")
    search_button = widget(label="Search")
    results_table = widget(aspect="searchResults")
    delete_button = widget(label="Delete")

    def search_customer(self, name: str):
        self.customer_name.clear().type(name)
        self.search_button.click()
        self.results_table.wait_for_rows(min=1)

    def get_balance(self, row: int) -> str:
        return self.results_table.cell(row, "Balance")
```

### pytest Integration

```python
import pytest
from vw_bridge import connect

@pytest.fixture(scope="session")
def app():
    """Connect to VisualWorks test image."""
    app = connect()
    yield app
    app.disconnect()

@pytest.fixture(autouse=True)
def reset_state(app):
    """Reset application state between tests."""
    app.command("resetTestData")
    yield

def test_buy_online_disables_electronic_collection(app):
    buy = BuyOnlinePage(app)
    buy.navigate()
    buy.enter_amount(2_500_000)
    buy.continue_to_collection()

    assert buy.electronic_collection.is_enabled() is False
    assert buy.direct_deposit.is_checked() is True
```

### CI/CD Configuration

```yaml
# GitHub Actions / GitLab CI
test-visualworks:
  stage: test
  tags: [windows, interactive-desktop]
  script:
    - powershell Start-Process "C:\VW\visualworks.exe" -ArgumentList "testImage.im"
    - powershell Start-Sleep -Seconds 10  # wait for image boot + agent start
    - pytest tests/regression/ --junitxml=results.xml --alluredir=allure-results
  artifacts:
    when: always
    paths:
      - results.xml
      - allure-results/
      - evidence/
```

---

## Layer 4: GemStone Test Data Management

### Separation of Concerns

| Channel | Purpose | Protocol |
|---------|---------|----------|
| UI Bridge | Black-box UI automation | JSON/TCP to VW image |
| Data Bridge | Test fixture setup/reset | Direct GemStone/S API or dedicated endpoint |

### Approach

```python
# Separate fixture from UI automation
@pytest.fixture
def seeded_portfolio(gemstone_session):
    """Create test data directly in GemStone."""
    gemstone_session.execute("""
        | portfolio |
        portfolio := Portfolio new.
        portfolio clientName: 'Test Client'.
        portfolio addFund: (Fund named: 'Equity A' balance: 150000).
        portfolio commit.
    """)
    yield "Test Client"
    gemstone_session.execute("Portfolio deleteWhere: [:p | p clientName = 'Test Client']")
```

### Why Separate

- UI tests verify behavior through the UI (black-box)
- Data setup through GemStone is fast and deterministic
- Avoids 50-click setup sequences before testing actual feature
- Cleanup is guaranteed (not dependent on test passing)

---

## Layer 5: Vision Fallback (Secondary Strategy)

For widgets that cannot be identified structurally (e.g., third-party embedded controls, canvas-rendered charts):

### Tool: OculiX 3.0+ (MIT license, active development)

```python
from oculix import Screen, Pattern

# Template matching for custom-rendered chart area
chart_region = Screen().find(Pattern("templates/chart_area.png").similar(0.85))
chart_region.click()

# OCR for reading rendered values
value = Screen().find(Pattern("templates/total_label.png")).right(100).text()
assert "R 150,000" in value
```

### When to Use Vision

- Third-party embedded controls with no Smalltalk widget backing
- PDF/document viewers embedded in the app
- Chart/graph areas (canvas-rendered, no widget tree)
- As verification layer (screenshot comparison for visual regression)

### When NOT to Use Vision

- Standard VisualWorks widgets (use internal bridge)
- State assertions (enabled/disabled/visible -- use bridge)
- Data entry (use bridge -- faster, deterministic)
- Anything that has an aspect name or widget class

---

## Implementation Roadmap

### Phase 1: Foundation (2-3 weeks)

- [ ] Smalltalk package: TestBridgeAgent, Listener, Executor
- [ ] Widget discovery: enumerate windows, find by aspect/label/class
- [ ] Basic actions: click, type, select
- [ ] Basic assertions: getText, isEnabled, isVisible
- [ ] TCP protocol: connect, disconnect, ping, single command
- [ ] Python SDK: connect, find widget, click, type, assert
- [ ] One passing end-to-end test

### Phase 2: Completeness (2-3 weeks)

- [ ] Full action set: doubleClick, expand, collapse, scroll, table operations
- [ ] Full assertion set: getCellData, getRowCount, getSelection
- [ ] Wait strategies: waitForWidget, waitForEnabled, waitForValue
- [ ] Multi-window support: listWindows, switchTo, waitForWindow, modal handling
- [ ] Screenshot capture: screen, window, widget
- [ ] Error handling: widget not found, timeout, action failed
- [ ] Composite selectors and path-based navigation

### Phase 3: Enterprise Readiness (2-3 weeks)

- [ ] Page Object Model support in Python SDK
- [ ] pytest fixtures: session, reset, evidence capture
- [ ] Allure reporting integration
- [ ] CI/CD pipeline template (Windows runner with interactive desktop)
- [ ] GemStone data bridge for fixture management
- [ ] Logging and audit trail (every command timestamped)
- [ ] Security hardening: token rotation, command whitelist
- [ ] Documentation and team onboarding guide

### Phase 4: Migration (ongoing)

- [ ] Port existing Test Mentor test cases to new framework
- [ ] Coverage analysis: what Test Mentor tested vs what new framework covers
- [ ] Vision fallback for any widgets that can't be reached structurally
- [ ] Performance benchmarks: target <30s for typical regression suite
- [ ] Production hardening based on real usage feedback

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| VisualWorks internals change between versions | High | Pin to specific VW version; abstract widget access behind adapter |
| UI process deadlock from bad command | High | Watchdog timeout on executor; kill and restart on hang |
| GemStone state contamination between tests | Medium | Isolated test data domains; deterministic reset |
| Port/token discovery race on CI | Low | Retry with backoff; health check before test start |
| Team lacks Smalltalk expertise for agent maintenance | Medium | Keep agent small (<1000 lines); document thoroughly |
| Image corruption from agent bug | High | Test agent in dedicated QA image; never load in production |
| Performance regression (too many widget lookups) | Low | Cache widget references within test; batch discovery |

---

## Decision Log

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| Internal instrumentation over vision | Deterministic, fast, state-aware, CI-ready | Vision: 60-85% reliability unacceptable for financial app |
| Synchronous protocol | Simpler, auditable, no race conditions | Async: adds complexity without clear benefit |
| RESTful HTTP over raw TCP | OpenAPI spec, self-documenting, standard tooling, auto-gen SDK | Raw TCP: lighter but no ecosystem tooling, harder to debug |
| Localhost TCP over named pipes | Cross-platform (VW runs on Linux/Mac too), simpler | Named pipes: Windows-only, VisualWorks support unclear |
| Python driver (not Java/C#) | pytest ecosystem, team familiarity, rapid development | Java: heavier, OculiX integration easier but team doesn't use |
| Aspect-first selectors | Most stable identifier in VisualWorks | Label: breaks on i18n; index: breaks on layout change |
| Separate data bridge from UI bridge | Clean separation; UI tests stay black-box | Combined: muddies failure diagnosis |
| QA image only | Zero production risk | Production toggle: unacceptable security surface |

---

## Appendix: VisualWorks Widget Class Hierarchy

```
Widget (abstract)
├── ComposedTextView (text display/edit)
├── InputFieldView
├── ButtonView (action buttons)
├── CheckButtonView
├── RadioButtonView  
├── ListWidget (single-select list)
├── MultiSelectionListWidget
├── TableWidget (rows + columns)
├── TreeViewWidget (hierarchical)
├── ComboBoxWidget (dropdown)
├── TabControlWidget
├── NotebookWidget
├── SliderWidget
├── MenuBarWidget
├── ToolbarWidget
├── CanvasWidget (SubCanvas for nested apps)
└── CustomWidget (application-specific)
```

Each widget has:
- `model` → ValueHolder or SelectionInList (data binding)
- `controller` → event handling (click, key, mouse)
- `spec` → ComponentSpec (label, enabled, visible, aspect name)
- `bounds` → Rectangle (position and size)

---

## Appendix: Comparison with Test Mentor

| Capability | Test Mentor | Proposed Bridge |
|------------|-------------|-----------------|
| Widget discovery | In-image (proprietary) | In-image (open, our code) |
| Record/playback | Yes (proprietary format) | No -- code-first only |
| Coverage metrics | Built-in | Separate (SUnit coverage tools) |
| External driver | None (all in-image) | Python SDK (pytest-native) |
| CI/CD support | Manual | First-class (headless, reporting) |
| Multi-language tests | Smalltalk only | Python (any language via protocol) |
| Maintenance | Vendor-dependent | Self-maintained (small codebase) |
| License | Commercial (expiring) | Internal (no license) |
| GemStone integration | Unknown | Explicit data bridge |
| Vision fallback | None | OculiX integration for edge cases |
