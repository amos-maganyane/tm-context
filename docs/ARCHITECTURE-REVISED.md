# VisualWorks Test Bridge -- Revised Architecture

## What Changed

After exploring jgfoster's GemStone ecosystem repos, we discovered production-ready components that eliminate the need to build several layers from scratch:

| Component | What It Is | Impact on Our Design |
|-----------|-----------|---------------------|
| **WebGS** | HTTP server framework for GemStone/S with OpenAPI 3.0.3, Swagger UI, routing, JSON | Provides the REST + OpenAPI layer for GemStone-side test data management -- no custom HTTP server needed |
| **GciForPython** | Python FFI wrapper for GemStone C Interface | Python test code can talk DIRECTLY to GemStone for data setup/teardown -- faster than HTTP |
| **Jade** | Windows IDE for GemStone (Dolphin Smalltalk) | Reference for GCI patterns; has VisualWorks component package |

## Revised Architecture: Three-Channel Hybrid

```
+------------------------------------------------------------------+
|                    TEST RUNNER (pytest on your PC)                 |
|  pytest + allure + junit-xml                                      |
+------------------------------------------------------------------+
    |                    |                         |
    | Python SDK         | GciForPython (FFI)      | HTTP client
    | (widget ops)       | (direct GemStone)       | (WebGS REST)
    |                    |                         |
    v                    v                         v
+----------------+  +-------------------+  +---------------------+
| VW IN-IMAGE    |  | GemStone DB       |  | WebGS (GemStone)    |
| AGENT          |  | (via GCI library) |  | REST API + OpenAPI  |
| Widget tree    |  |                   |  | /fixtures, /state   |
| UI automation  |  | Fast data ops:    |  | /docs (Swagger UI)  |
| localhost REST |  | seed, rollback,   |  | Documented routes   |
+----------------+  | query, assert     |  +---------------------+
    |                +-------------------+         |
    |                         |                    |
    v                         v                    v
+------------------------------------------------------------------+
|            VISUALWORKS APPLICATION (GemStone-backed)               |
+------------------------------------------------------------------+
```

### Channel 1: VW In-Image Agent (Widget Automation)

**Purpose**: UI interaction only -- click, type, select, read state, screenshot.
**Runs in**: VisualWorks image on the Windows VM.
**Protocol**: REST API on localhost (minimal HTTP server in Smalltalk).
**Scope**: Small -- ONLY widget operations. No data management.

This is the same as the original architecture but with a reduced scope. It only handles what CANNOT be done from outside the VW image: touching the widget object graph.

### Channel 2: GciForPython (Direct GemStone Access)

**Purpose**: Test data management -- seed fixtures, rollback transactions, verify DB state.
**Runs in**: Python test process (on your PC or CI runner).
**Protocol**: GCI C library via ctypes FFI (direct TCP to GemStone NetLDI).
**Why**: Faster than HTTP, no server needed, direct object access.

```python
from GciLibrary import GciLibrary

gci = GciLibrary(version='3.7.4')
session = gci.login(stone='testStone', gs_user='DataCurator', gs_password='swordfish')

# Seed test data directly in GemStone
gci.execute(session, """
    | customer |
    customer := Customer new.
    customer name: 'Test Client'.
    customer accountNumber: 'ACC-TEST-001'.
    customer commit.
""")

# Verify DB state after UI action
result = gci.execute(session, "Customer findByAccount: 'ACC-TEST-001' ifNone: [nil]")
assert result is not None

# Cleanup
gci.execute(session, "Customer deleteWhere: [:c | c name = 'Test Client']")
gci.abort(session)
gci.logout(session)
```

### Channel 3: WebGS (REST API for GemStone Operations)

**Purpose**: Higher-level test operations, fixture management, state inspection via documented REST API.
**Runs in**: GemStone gem process (server-side).
**Protocol**: HTTP REST with OpenAPI 3.0.3 spec + Swagger UI.
**Why**: Self-documenting, explorable, shareable with non-Python tools.

WebGS already provides:
- `DocumentedRouter` with OpenAPI spec generation
- `OpenApiOperation`, `OpenApiSchema` for endpoint documentation
- Swagger UI served at `/docs`
- JSON parsing/generation
- Route parameters (`:id` style)
- Error handling with stack traces
- 2,900+ RPS on simple operations

We build a `TestBridgeApi` class (like `FilmsApi` in the examples) that exposes:

```
GET  /v1/fixtures              -- list available test fixtures
POST /v1/fixtures/:name/load   -- load a named fixture
POST /v1/fixtures/reset        -- rollback to clean state
GET  /v1/state/:class/:id      -- inspect a domain object
POST /v1/execute               -- run arbitrary Smalltalk (locked down in prod)
GET  /v1/health                -- service health check
```

## When to Use Which Channel

| Need | Channel | Why |
|------|---------|-----|
| Click a button | VW Agent (Channel 1) | Only way to reach VW widgets |
| Type in a field | VW Agent (Channel 1) | Only way to reach VW widgets |
| Read widget value | VW Agent (Channel 1) | Only way to reach VW widgets |
| Take screenshot | VW Agent (Channel 1) | Needs Display form access |
| Seed test data before test | GciForPython (Channel 2) | Fastest, no server dependency |
| Rollback after test | GciForPython (Channel 2) | Direct transaction control |
| Assert DB state | GciForPython (Channel 2) | Direct object queries |
| Explore fixtures interactively | WebGS (Channel 3) | Swagger UI in browser |
| CI health checks | WebGS (Channel 3) | Standard HTTP monitoring |
| Share test data API with team | WebGS (Channel 3) | Self-documenting, language-agnostic |

## What We Reuse vs Build

| Component | Source | Effort |
|-----------|--------|--------|
| HTTP server (GemStone side) | WebGS (as-is) | 0 -- just install |
| OpenAPI + Swagger | WebGS DocumentedRouter (as-is) | 0 |
| GemStone Python access | GciForPython (as-is) | 0 -- just configure |
| Test data REST endpoints | Build on WebGS (like FilmsApi example) | 1-2 days |
| VW in-image widget agent | Build (Smalltalk package) | 2-3 weeks |
| Python test SDK (widget ops) | Build (thin HTTP client) | 1 week |
| pytest integration | Build (fixtures, evidence) | 1 week |

## Revised Roadmap

| Phase | What | Effort | Uses |
|-------|------|--------|------|
| **0. Infrastructure** | Install WebGS in test GemStone; configure GciForPython | 1-2 days | WebGS, GciForPython |
| **1. Data Bridge** | Build TestBridgeApi on WebGS; verify GciForPython connectivity | 3-5 days | WebGS, GciForPython |
| **2. VW Agent Prototype** | TCP/HTTP server in VW; widget discovery; basic click/type | 2 weeks | Custom Smalltalk |
| **3. Python SDK** | Widget client + pytest fixtures + evidence capture | 1 week | Custom Python |
| **4. First Tests** | 10 critical-path test cases | 1-2 weeks | All three channels |
| **5. CI Pipeline** | Windows runner, port forwarding, evidence collection | 3-5 days | All |

**Total: 6-8 weeks** (down from 13-17 in original plan) because WebGS and GciForPython eliminate custom HTTP/data bridge work.

## Access Model (Your Setup)

```
Your PC (macOS)
    |
    | RDP to Windows VM
    v
Windows VM
    ├── VisualWorks app (with in-image agent on localhost:9876)
    ├── GemStone/S (NetLDI on port 50377, WebGS on port 8888)
    |
    | Port forwarding (SSH tunnel or netsh)
    |   VM:9876 → your PC:9876  (VW agent)
    |   VM:50377 → your PC:50377 (GCI/NetLDI)
    |   VM:8888 → your PC:8888  (WebGS/Swagger)
    v
Your PC
    ├── Python SDK connects to localhost:9876 (widget ops)
    ├── GciForPython connects to localhost:50377 (data ops)
    ├── Browser → localhost:8888/docs (Swagger UI)
    └── pytest runs all tests
```

## Dual-Purpose: Test Automation AND AI Agent Interface

The VW bridge serves two consumers with the same REST API:

### 1. Test Automation (Playwright/Karate/Cypress)

Structured, repeatable test suites running in CI/CD. Deterministic, assertion-based.

### 2. AI Agent Interface ("forge-desktop")

The existing QA pipeline agent uses `forge-browse` to drive web applications for investigation and verification. The VW bridge provides the **same capability for desktop apps**:

```
forge-browse (web)        →  browser DOM   →  AI investigates web bugs
forge-desktop (VW bridge) →  widget tree   →  AI investigates desktop bugs
```

**Same agent, same skills, different transport.**

The QA agent could:
- Receive a JIRA ticket about a VW desktop bug
- Connect to the VW bridge REST API (like it connects to forge-browse)
- Navigate the application, reproduce the bug, gather evidence
- Attempt a fix, verify through the bridge, deliver an MR

**API design implication**: The REST endpoints must be expressive enough for both:
- **Structured tests**: precise widget selectors, deterministic waits
- **Exploratory AI**: window listing, widget enumeration, state inspection, "what's on screen?" queries

Key endpoints that serve AI exploration (beyond basic test automation):

```
GET  /v1/windows                      -- what's open right now?
GET  /v1/windows/:id/tree             -- full widget hierarchy (AI can reason about layout)
GET  /v1/windows/:id/screenshot       -- visual evidence for reports
GET  /v1/widgets?visible=true         -- all interactive elements currently visible
GET  /v1/widgets/:id/children         -- drill into a container
POST /v1/widgets/:id/actions          -- interact (click, type, select)
GET  /v1/state/snapshot               -- full application state dump for AI reasoning
```

This positions the bridge as infrastructure that outlives any single use case -- it's the **interface layer between AI/automation and the VW desktop application**.

### Open Question: forge-browse for Desktop (General)

Could forge-browse itself be extended to handle desktop apps? Or should "forge-desktop" be a separate tool with a compatible API?

Considerations:
- forge-browse speaks CDP (Chrome DevTools Protocol) -- not applicable to desktop
- But the **consumer API pattern** is the same (navigate, interact, screenshot, wait)
- A `forge-desktop` tool with the same command vocabulary but backed by the VW bridge REST API would let the QA agent use either seamlessly
- The MCP tool interface could be identical: `{ action: "click", selector: {...} }`

**Decision deferred** -- but the VW bridge API is being designed to support this future.

---

## Test Framework Alignment

The team uses **Playwright**, **Karate**, and **Cypress**. The bridge must integrate with these:

| Layer | Framework | Rationale |
|-------|-----------|-----------|
| VW widget automation | **Playwright** (custom fixture/POM) | Playwright's locator pattern maps directly to widget selectors; team already knows the API; TypeScript SDK preferred over Python |
| WebGS REST API validation | **Karate** | Feature files naturally test REST endpoints; OpenAPI spec can drive contract tests |
| Web UI (if any) | **Cypress** or **Playwright** | Standard browser automation |

### Playwright Integration Pattern

The VW bridge exposes a REST API. Playwright tests consume it via a custom fixture:

```typescript
// vw-bridge.fixture.ts
import { test as base } from '@playwright/test';

type VWApp = {
  window(title: string): VWWindow;
  screenshot(path: string): Promise<void>;
};

type VWWindow = {
  widget(selector: { aspect?: string; label?: string; class?: string }): VWWidget;
  table(aspect: string): VWTable;
  button(label: string): VWWidget;
  field(aspect: string): VWWidget;
};

type VWWidget = {
  click(): Promise<void>;
  type(text: string): Promise<void>;
  value(): Promise<string>;
  isEnabled(): Promise<boolean>;
  waitFor(options?: { timeout?: number }): Promise<void>;
};

export const test = base.extend<{ vw: VWApp }>({
  vw: async ({}, use) => {
    const app = new VWBridgeClient(process.env.VW_AGENT_URL || 'http://localhost:9876');
    await app.healthCheck();
    await use(app);
  },
});
```

### Test Example (Playwright + VW Bridge)

```typescript
import { test } from './vw-bridge.fixture';
import { expect } from '@playwright/test';

test.describe('Buy Online', () => {
  test('disables electronic collection above R2m', async ({ vw }) => {
    const buy = vw.window('Buy Online');
    await buy.field('amount').type('2500000');
    await buy.button('Continue').click();

    expect(await buy.widget({ aspect: 'electronicCollection' }).isEnabled()).toBe(false);
    expect(await buy.widget({ aspect: 'directDeposit' }).value()).toBe('true');
  });
});
```

### Karate Integration (WebGS Data Bridge)

```gherkin
Feature: Test Data Fixtures via WebGS

  Background:
    * url 'http://localhost:8888/v1'

  Scenario: Load baseline customer fixture
    Given path 'fixtures/baseline_customers/load'
    When method post
    Then status 200
    And match response.loaded == true

  Scenario: Reset test data after suite
    Given path 'fixtures/reset'
    When method post
    Then status 200

  Scenario: Verify domain object state
    Given path 'state/Customer/ACC-TEST-001'
    When method get
    Then status 200
    And match response.name == 'Test Client'
    And match response.accountNumber == 'ACC-TEST-001'
```

### GciForPython -- Still Useful

Even with Playwright as the primary test driver, GciForPython remains valuable for:
- **pytest-level fixtures** that Playwright hooks call (worker setup/teardown)
- **CI pipeline scripts** that manage GemStone state between suites
- **Rapid data seeding** without HTTP overhead

## Reference Repos (cloned to visual-works/repos/)

| Repo | Path | What It Provides |
|------|------|-----------------|
| **WebGS** | `repos/WebGS/` | HTTP server + OpenAPI 3.0.3 + Swagger UI for GemStone/S. REST layer for test data management. |
| **GciForPython** | `repos/GciForPython/` | Legacy Python FFI to GemStone (ctypes). Superseded by gemstone-py. |
| **Jade** | `repos/Jade/` | Windows IDE for GemStone (Dolphin Smalltalk). GCI reference. Has VisualWorks Component package. |
| **Jasper** | `repos/Jasper/` | VS Code GemStone IDE with **MCP server** -- AI agents can execute Smalltalk, compile methods, run tests, browse classes directly via MCP tools. |
| **gemstone-py** | `repos/gemstone-py/` | Modern Python bridge to GemStone. Session pooling, async, ORM-like queries, Django/Flask/FastAPI integration, OpenTelemetry, pip-installable. Replaces GciForPython. |

## Key Discovery: Jasper MCP Server

The Jasper repo contains an MCP server (`mcp-server/`) that exposes GemStone operations as AI-consumable tools:

```
execute_code        -- run Smalltalk, get result
compile_method      -- add/update methods on classes
compile_class_definition -- create/update classes
describe_class      -- full class introspection (one round-trip)
find_implementors   -- who implements a selector?
find_senders        -- who sends a selector?
search_method_source -- grep all method source
run_test_method     -- execute single SUnit test
run_test_class      -- execute all tests in a class
list_failing_tests  -- run suite, return failures only
describe_test_failure -- structured failure details (exception, stack)
abort / commit      -- transaction control
eval_python         -- transpile and execute Python via Grail
```

**Impact**: The QA pipeline agent can use this MCP server to:
1. Deploy the VW test bridge Smalltalk code (compile classes/methods into GemStone)
2. Run SUnit tests against the bridge agent itself
3. Inspect GemStone application state during investigation
4. Evolve the test bridge code autonomously (AI writes Smalltalk via MCP)
5. TDD the bridge: write test → run → see failure → compile fix → re-run

This collapses the "need Smalltalk developers" risk entirely -- the AI IS the Smalltalk developer.

## Revised Component Selection

| Need | Old Choice | New Choice | Why |
|------|-----------|-----------|-----|
| Python-to-GemStone | GciForPython (raw ctypes) | **gemstone-py** (pip install) | Production-ready, pooled sessions, async, observability |
| REST API on GemStone | Custom HTTP from scratch | **WebGS** (as-is) | Already has HTTP + OpenAPI + routing |
| AI GemStone access | None | **Jasper MCP server** | AI agent can write/test Smalltalk directly |
| VW widget automation | Custom Smalltalk agent | Custom Smalltalk agent (unchanged) | Still needed -- only way to reach VW widget tree |
| Test framework | Python pytest | **Playwright** (widget ops) + **Karate** (REST/data) | Matches team's existing stack |

## Comparison: Original vs Revised

| Aspect | Original (ARCHITECTURE.md) | Revised (this doc) |
|--------|---------------------------|-------------------|
| HTTP server | Custom Smalltalk from scratch | WebGS (production-ready, OpenAPI built-in) |
| Data management | Custom data bridge | GciForPython (direct) + WebGS (REST) |
| OpenAPI spec | Manual YAML definition | Auto-generated by DocumentedRouter |
| Swagger UI | Not included | Built into WebGS |
| Python GemStone access | None (all through REST) | GciForPython FFI (direct, fast) |
| Timeline | 13-17 weeks | 6-8 weeks |
| Custom code to write | HTTP server + wire protocol + data bridge + SDK | VW widget agent + thin Python SDK only |
| Dependencies | Zero external | WebGS + GciForPython (both MIT, maintained by GemTalk director) |
