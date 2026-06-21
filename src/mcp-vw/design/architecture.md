---
title: Phase M MCP Server — Architecture & Design Decisions (v2)
purpose: Step 5 deliverable, REVISED after v1 sign-off rejection. Synthesizes v1 + wave-2 research (3 image probes + 2 of 3 wave-2 librarians complete) to lock all Phase M design decisions with native-typed UI/dev tool surface that addresses user critique "expose more tools to allow native development on visualworks, this will make it also easier for AI than it have to guess". AI writes; user reviews + signs off BEFORE any code lands.
supersedes: architecture.md v1 (526 lines, rejected at sign-off for being too eval-centric)
written: 2026-06-21 (session-21 Phase M v2 design)
status: DRAFT — Parcel/Store tool section refines pending wave-2 librarian bg_3fe35753 (still running 17m+); rest is locked
target_audience: ammaganyane (user) for sign-off; future Sisyphus sessions implementing Phase M
---

# Phase M MCP Server — Architecture & Design Decisions (v2)

## What changed from v1

The v1 design (40 tools, 7-day effort, 13-tool MVP) was rejected at sign-off with the critique:

> "Jasper exposes native tools to allow AI to write code on gemstone like a gemstone developer. For us now we have eval, but shouldn't we expose more tools to allow native development on visualworks, this will make it also easier for AI than it have to guess... write and manage the UI code, the same way a developer would, but this tool is more powerful than any dev."

**v1's failure**: too eval-centric. AI was expected to craft raw Smalltalk strings for compile, class definition, windowSpec construction, parcel build — the MCP server was a thin wrapper around `/eval`. The user wants the MCP server to be the abstraction layer that hides VW's 42 carry-forward constraints + the spec literal syntax + the lazy-aspect-accessor pattern.

**v2's response**: 48 tools (was 40), MVP 18 tools (was 13), **8 new native UI-construction tools** that take structured JSON and emit canonical Smalltalk on the AI's behalf. `vw_eval` becomes the **escape hatch**, not the primary interface.

This doc locks the v2 design. Sign-off → implementation begins (this session or next, per user choice).

## TL;DR — all decisions

| Decision | Choice | Source | Change vs v1 |
|---|---|---|---|
| **SDK** | TypeScript `@modelcontextprotocol/sdk ^1.29.0` | [01-mcp-sdk.md §5](../research/01-mcp-sdk.md) | unchanged |
| **Language** | TypeScript on Node.js 20 LTS | same | unchanged |
| **Transport** | stdio only (MVP) | [04-mcp-best-practices.md §1.4](../research/04-mcp-best-practices.md) | unchanged |
| **Server identity** | `name: "vw-bridge"` + tool prefix `vw_*` | new decision §4 | locks prefix (user runs Jasper which uses bare names — disambiguation matters) |
| **MVP tool count** | **18 tools** (was 13) | §5 | +5 (vw_create_class, vw_open_application, vw_load_parcel, vw_list_loaded_parcels, vw_unload_parcel) |
| **V2 tool count** | **+13 tools = 31 total** (was 26) | §5 | adds native UI scaffolders (vw_create_application_model, vw_create_window_spec, vw_create_dialog, vw_create_parcel, vw_define_action, vw_define_aspect, vw_get_widget_value) |
| **V3+ tool count** | **+17 tools = 48 total** (was 40) | §5 | adds long-tail UI / Painter / Store / Topaz tools |
| **Native UI tools** | 8 first-class (vw_create_class, vw_create_application_model, vw_create_window_spec, vw_create_dialog, vw_create_parcel, vw_define_action, vw_define_aspect, vw_get_widget_value) | §6 (NEW section) | **biggest change vs v1** — addresses user critique |
| **Bridge integration** | HTTP + `.token` file re-read on every call | §7 | unchanged |
| **Auto-registration** | `.mcpb` Desktop Extension (primary) + PowerShell MSIX-aware installer (fallback) | §8 | unchanged |
| **Single-owner** | Lockfile + PID + stale-PID recovery; env var opt-out | §9 | unchanged |
| **Error semantics** | `isError: true` for tool failures; JSON-RPC `-32603` for protocol errors | §10 | unchanged |
| **Versioning** | npm exact pin `^1.29.0`; MCP protocol negotiation; bridge min v0.10.0 | §11 | unchanged |
| **Testing** | 4-level pyramid (unit → in-memory → subprocess → MCP Inspector) | §12 | unchanged |
| **Effort estimate** | **~10 days** for full 48 tools (was 7d for 40) | §13 | +3d for native UI scaffolders |
| **Onboarding milestone** | **~4 days** from session-22 start (was 3d) | §13 | +1d, still attainable in week 1 of Phase M |
| **Bridge changes needed** | ZERO — pure MCP server work | §7 + [02-jasper-delta.md](../research/02-jasper-delta.md) | unchanged |

## 1. SDK choice (UNCHANGED from v1)

**Decision: TypeScript `@modelcontextprotocol/sdk` v1.29.0+** (pin to `^1.29.0`).

Five reasons, in priority order (full rationale in [01-mcp-sdk.md §5](../research/01-mcp-sdk.md)):

1. **Phase E alignment**: Playwright SDK is JS/TS → one toolchain for Phase M + Phase E
2. **Windows stdio fix in v1.29.0**: `windowsHide: true` always set (PR #1640/#1772) — no analog in Python SDK
3. **Ecosystem signal**: 55.7K npm dependents (3.5× Python's 15K) + 38.9M weekly downloads
4. **Jasper precedent**: directly analogous Smalltalk → MCP project (jgfoster/Jasper) uses TypeScript
5. **Both SDKs Anthropic-maintained + MIT**: zero risk in either direction

What we accept: slightly more boilerplate per tool (manual `content: [{ type: "text", text }]`), must wrap tool bodies in try/catch (TS SDK doesn't auto-catch), build step required (or `tsx` for dev).

## 2. Language + runtime (UNCHANGED)

- **Language**: TypeScript ^5.4
- **Runtime**: Node.js 20 LTS (matches Jasper's `.nvmrc`)
- **Module type**: ES modules (`"type": "module"` in `package.json`)
- **Build tool**: `tsc` for type-check + emit
- **Test runner**: `vitest`
- **Schema validation**: `zod` ^3.23.0 (TS SDK convention)
- **HTTP client to bridge**: native `fetch` (Node 20+) — no extra dependency

Project layout (single-package monorepo, simpler than Jasper's 3-workspace split):

```
src/mcp-vw/
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── manifest.json                # .mcpb Desktop Extension manifest
├── src/
│   ├── index.ts                 # entry: register tools, start stdio, acquire owner lock
│   ├── bridge.ts                # HTTP client with token re-read + retry on 401
│   ├── lock.ts                  # single-owner lockfile + PID + stale-PID recovery
│   ├── util.ts                  # text(), errorResult(), safeHandler(), formatBridgeError()
│   ├── codegen/                 # NEW in v2: native-typed code generators
│   │   ├── class.ts             # vw_create_class → subclass: literal
│   │   ├── applicationModel.ts  # vw_create_application_model → class + initialize + aspects + windowSpec
│   │   ├── windowSpec.ts        # vw_create_window_spec → FullSpec literal-array
│   │   ├── dialog.ts            # vw_create_dialog → SimpleDialog spec or add*-builder calls
│   │   └── parcel.ts            # vw_create_parcel → Cursor monkey-patch + parcelOutOn:
│   └── tools/
│       ├── liveness.ts          # vw_health, vw_version, vw_status
│       ├── eval.ts              # vw_eval (with Bug #5 + #41 guards)
│       ├── navigation.ts        # vw_find_senders / vw_find_implementors / vw_find_references_to
│       ├── reading.ts           # vw_get_class_definition / vw_list_methods / vw_describe_class
│       ├── schema.ts            # vw_list_namespaces / vw_list_namespace_entries
│       ├── modify.ts            # vw_compile_method / vw_delete_method (V2+, with #41 guard)
│       ├── testing.ts           # vw_run_test_class / vw_list_failing_tests (V2+, direct-invoke gate)
│       ├── ui_inspect.ts        # vw_list_windows / vw_describe_window / vw_get_value / vw_list_dialogs
│       ├── ui_drive.ts          # vw_click / vw_type / vw_respond_dialog / vw_click_menu
│       ├── wait.ts              # vw_wait (V2)
│       ├── screenshot.ts        # vw_screenshot (V2)
│       └── parcel.ts            # vw_load_parcel / vw_unload_parcel / vw_list_loaded_parcels / vw_create_parcel
├── test/
│   ├── bridge.test.ts           # token re-read + retry on 401
│   ├── codegen/                 # NEW in v2: codegen unit tests (golden-file approach)
│   │   └── windowSpec.test.ts   # vw_create_window_spec({...}) → literal output diff
│   ├── tools/*.test.ts          # per-tool in-memory client tests
│   └── e2e.test.ts              # subprocess MCP Inspector smoke test
├── dist/                        # compiled output (gitignored)
└── README.md                    # user-facing install + Claude Desktop config + smoke test
```

## 3. Transport (UNCHANGED)

**Decision: stdio only for MVP. No HTTP/SSE.**

Phase M is single-developer, single-image, single-Claude. HTTP/SSE solves problems we don't have (multi-client, remote access). All 11 reference servers in `modelcontextprotocol/servers` ship stdio. Adding HTTP later is additive.

## 4. Server identity (NEW DECISION)

**Decision: server name `vw-bridge`; tool names prefixed `vw_*`.**

### 4.1 Why prefix the tools

Jasper (the user's daily GemStone MCP) uses **bare names** (`commit`, `compile_method`, `list_methods`). Jasper's server name is `gemstone`, which is how Claude groups tools in the UI; the wire-level tool name is unprefixed.

For Phase M, both Jasper AND mcp-vw will be registered in the same Claude Desktop simultaneously. **Bare-name collisions** would be confusing:
- `commit` — Jasper's transaction commit vs. ??? (we'd skip this; no VW analog)
- `compile_method` — would Jasper's `compile_method` vs Phase M's `compile_method` collide? UI might group them under their respective servers, but AI's tool selection logic might get confused.
- `list_methods` — Jasper's GemStone vs Phase M's VW

The cleanest disambiguation: prefix Phase M's tools `vw_*`. AI sees `gemstone.commit` vs `vw-bridge.vw_compile_method` and there's no ambiguity. Per the librarian-validated 02-jasper-delta.md §"Bonus: Jasper's architectural patterns worth borrowing", we keep the SAME tool names where the operation is equivalent (`compile_method` → `vw_compile_method`).

### 4.2 Server registration in Claude Desktop config

```json
{
  "mcpServers": {
    "gemstone": { "command": "node", "args": ["/path/to/jasper-proxy.js", "--proxy-socket", "..."] },
    "vw-bridge": { "command": "node", "args": ["/path/to/mcp-vw/dist/index.js"], "env": {...} }
  }
}
```

Two MCP servers, clearly named, zero collision risk.

## 5. Tool surface — MVP / V2 / V3+ (REVISED from v1)

Total surface: **48 distinct tools** = 28 Jasper-equivalent (from [02-jasper-delta.md](../research/02-jasper-delta.md), excluding 5 N/A) + 12 VW-only (from [03-vw-specific-capabilities.md](../research/03-vw-specific-capabilities.md)) + 8 native UI/dev (from [05-vw-native-development.md](../research/05-vw-native-development.md)).

### 5.1 MVP — 18 tools (~3 days)

Smallest viable set that exercises the MCP server end-to-end with NATIVE TYPED tool surface. Covers: bridge liveness, eval (escape hatch), code navigation, code reading, code creation, namespace browsing, UI inspection, UI driving, app open, parcel basics.

| # | Tool name | Native or Eval-wrap? | Description | Source |
|---|---|---|---|---|
| 1 | `vw_health` | native | Auth-exempt liveness check — returns `{status, version}` | 03 F1 |
| 2 | `vw_version` | native | Auth-exempt build metadata — returns `{version, buildCommitSha, buildTimestamp, parcelMode}` | 03 F2 |
| 3 | `vw_status` | native | Combined VW image + bridge status (composite of /health + /version + a quick eval probe) | 02 #3 |
| 4 | `vw_eval` | escape hatch | Evaluate arbitrary Smalltalk source. **Escape hatch only**: tool description says "use vw_create_class / vw_compile_method / vw_create_window_spec FIRST; use this only for one-off expressions" | 02 #5 |
| 5 | `vw_list_namespaces` | native | List all VW namespaces (sorted array) | 02 #22 |
| 6 | `vw_list_namespace_entries` | native | List all bindings (classes + globals) in a namespace | 02 #24 |
| 7 | `vw_get_class_definition` | native | Get class definition (`subclass:instVarNames:...inDictionary:` form) | 02 #13 |
| 8 | `vw_list_methods` | native | List all methods of a class grouped by category (tab-separated `side \t category \t selector`) | 02 #21 |
| 9 | `vw_find_senders` | native | Find `Class>>selector` pairs sending a given selector (max 500, scoped) | 02 #18 |
| 10 | **`vw_create_class`** | NATIVE-TYPED | **Create or update a class with structured params** (name, namespace, superclass, instVars, classVars, classInstVars, category) — AI passes JSON; tool emits `subclass:instVarNames:...inDictionary:` Smalltalk | 05 §10 (NEW) |
| 11 | **`vw_open_application`** | NATIVE-TYPED | Open an ApplicationModel subclass: `MyApp open` or `MyApp new openInterface: #specSelector` | 05 §5.2 (NEW) |
| 12 | `vw_list_windows` | native | Enumerate currently-open VW windows | 03 A1 |
| 13 | `vw_describe_window` | native | Get widget tree of one window | 03 A2 |
| 14 | `vw_click` | native | Click a named widget (RadioButtonSpec uses `model value: spec select`; others use `model value: true`) | 03 B1 |
| 15 | `vw_type` | native | Set value of input field / writable widget | 03 B2 |
| 16 | **`vw_load_parcel`** | NATIVE-TYPED | Load a parcel from file path: `Kernel.Parcel loadParcelFrom: aFilename` | 05 §7.2 (NEW) |
| 17 | **`vw_unload_parcel`** | NATIVE-TYPED | Remove a loaded parcel: `[Kernel.Parcel removeParcelNamed:] on: Core.Notification do: [:n \| n resume]` | 05 §7.2 (NEW) |
| 18 | **`vw_list_loaded_parcels`** | NATIVE-TYPED | Enumerate currently-loaded parcels via `Kernel.Parcel allInstances` filter | 05 §7.2 (NEW) |

**5 new MVP tools vs v1** are bolded. They cover the most-asked AI workflows:
- "Create me a class to hold X" → `vw_create_class`
- "Open this app" → `vw_open_application`
- "Load this parcel" / "Unload this parcel" / "What parcels are loaded?" → parcel trio

### 5.2 V2 — +13 tools = 31 total (~3 more days)

Adds the heavyweight NATIVE UI-construction tools — the heart of the user's critique. Plus SUnit testing + UI screenshot/wait/dialogs + the rest of the read tools.

| # | Tool name | Native or Eval-wrap? | Description | Source |
|---|---|---|---|---|
| 19 | **`vw_create_application_model`** | NATIVE-TYPED | **Scaffolding tool**: creates ApplicationModel subclass + `#initialize` + N aspect accessors + N action methods + class-side `windowSpec`. AI passes `{className, namespace, superclass, aspects:[{name, type, default}], actions:[{name, source}]}` | 05 §10 (NEW) |
| 20 | **`vw_create_window_spec`** | NATIVE-TYPED | **Compile a class-side `windowSpec` method** from structured JSON (window props + components tree) — AI passes the JSON tree, tool emits the canonical literal-array `^#(#{UI.FullSpec} ...)` form (the design unlock from probe-3) | 05 §2 (NEW) |
| 21 | **`vw_create_dialog`** | NATIVE-TYPED | Scaffolding tool: SimpleDialog subclass with EITHER spec-based OR programmatic `add*` builder methods (per librarian-validated SimpleDialog has 12+ add-builder methods) | 05 §4.4 (NEW) |
| 22 | **`vw_define_action`** | NATIVE-TYPED | Add instance-side action method to an ApplicationModel class (typed wrapper around `vw_compile_method`) | 05 §10 (NEW) |
| 23 | **`vw_define_aspect`** | NATIVE-TYPED | Add aspect accessor + instance var to an ApplicationModel class (generates lazy-init pattern `^foo isNil ifTrue: [foo := default asValue] ifFalse: [foo]`) | 05 §10 (NEW) |
| 24 | **`vw_get_widget_value`** | NATIVE-TYPED | Read aspect value from live app instance (wraps existing `/value?aspect=X` bridge endpoint) | 03 A3 |
| 25 | `vw_describe_class` | native | Composite: definition + comment + methods grouped by category in one call | 02 #15 |
| 26 | `vw_find_implementors` | native | List classes implementing a selector | 02 #17 |
| 27 | `vw_find_references_to` | native | List methods referencing a named global (class/pool/shared var) | 02 #19 |
| 28 | `vw_compile_method` | NATIVE-TYPED | Add/replace a method (typed: `{className, isMeta, category, source}`) — with #41 guard (refuses `VWB.*` namespace) | 02 #7 |
| 29 | `vw_run_test_class` | native | Run SUnit test class via direct-invoke gate pattern (carry-forward #20) | 02 #31 |
| 30 | `vw_run_test_method` | native | Run single SUnit test | 02 #32 |
| 31 | `vw_list_failing_tests` | native | Run SUnit + return only failures | 02 #30 |

**6 new V2 tools vs v1** are bolded (19-24). These are the heart of the native UI-dev tooling.

### 5.3 V3+ — +17 tools = 48 total (~4 more days)

The long tail — degraded-utility tools (sources stripped impact) + destructive ops + Painter introspection + Topaz/Store distribution tools.

| # | Tool name | Description | Notes |
|---|---|---|---|
| 32 | `vw_describe_test_failure` | Re-run failed test in isolation, structured exception capture | 02 #33 |
| 33 | `vw_list_dialogs` | Enumerate live modal SimpleDialog instances | 03 A4 |
| 34 | `vw_respond_dialog` | Click a button on currently-posted modal | 03 B4 |
| 35 | `vw_wait` | Block until UI predicate satisfied | 03 D1 |
| 36 | `vw_screenshot` | Capture PNG of screen or window | 03 C1 |
| 37 | `vw_get_method_fingerprint` | Behavioral fingerprint (numArgs, messages, literals) — sources stripped | 02 #12 |
| 38 | `vw_get_class_hierarchy` | Superclass chain + direct subclasses | 02 #14 |
| 39 | `vw_export_class` | Export class as fingerprint dump (Topaz file-out limited utility — sources stripped) | 02 #16 |
| 40 | `vw_search_method_messages` | Search selectors matching substring (degraded from Jasper's `search_method_source`) | 02 #20 |
| 41 | `vw_list_namespace_classes` | List classes in a single namespace | 02 #23 |
| 42 | `vw_list_all_classes` | Bulk enumerate every class with namespace label (maxResults cap) | 02 #25 |
| 43 | `vw_list_test_classes` | Discover TestCase subclasses (safe `allSubclasses` enumeration) | 02 #29 |
| 44 | `vw_compile_class_definition` | Create/re-shape a class (with #41 guard) | 02 #8 |
| 45 | `vw_delete_method` | Remove a method | 02 #10 |
| 46 | `vw_delete_class` | **DESTRUCTIVE:** remove a class (with #41 + VWB.* refusal) | 02 #11 |
| 47 | `vw_set_class_comment` | Set class comment | 02 #28 |
| 48 | **`vw_create_parcel`** | **Build a parcel** from class list + extension methods + namespace (wraps Cursor monkey-patch + `parcelOutOn:`) | 05 §10 (NEW); refines on bg_3fe35753 |

**1 new V3+ tool vs v1** is bolded (48). Several V3 tools are deferred from V2 to keep V2 focused on the native UI-construction story.

### 5.4 Deferred / N/A (5 Jasper tools that have no VW equivalent)

- `commit` — VW has no transactional persistence
- `abort` — same
- `refresh` — VW always reads live image
- `eval_python` — VW has no Grail
- `compile_python` — same

The MCP tool descriptions for `vw_create_application_model` and write tools surface the VW persistence semantics ("Changes are live in-image and survive until vwnt.exe exits — no commit needed; use ObjectMemory snapshotAs: to persist if required").

## 6. NATIVE UI DEVELOPMENT TOOLS — the v2 differentiator

This section addresses the user's critique directly. The 8 NATIVE-TYPED tools are concentrated here.

### 6.1 `vw_create_window_spec` — the design unlock

The empirical discovery from probe-3 (Tools.AboutVisualWorksDialog `windowSpec`): the canonical VW UI definition is **a one-liner method returning a nested literal array**. The MCP tool takes structured JSON; emits the literal.

**Input shape (JSON the AI sends):**

```json
{
  "className": "PartySearchView",
  "namespace": "MyAppPackage",
  "window": {
    "label": "Party Search",
    "bounds": [100, 100, 700, 500],
    "min": [400, 300],
    "max": [1200, 800],
    "sizeType": "specifiedSize",
    "positionType": "screenCenter",
    "openType": "advanced",
    "hasMenuBar": false
  },
  "components": [
    {
      "type": "Label",
      "name": "searchLabel",
      "label": "Search for:",
      "layout": {"l": 10, "lf": 0, "t": 10, "tf": 0, "r": 100, "rf": 0, "b": 30, "bf": 0}
    },
    {
      "type": "InputField",
      "name": "searchInput",
      "model": "searchString",
      "layout": {"l": 110, "lf": 0, "t": 10, "tf": 0, "r": -90, "rf": 1, "b": 30, "bf": 0},
      "numChars": 50,
      "type_": "string"
    },
    {
      "type": "ActionButton",
      "name": "searchButton",
      "label": "Search",
      "model": "doSearch",
      "layout": {"l": -80, "lf": 1, "t": 10, "tf": 0, "r": -10, "rf": 1, "b": 30, "bf": 0},
      "isDefault": true,
      "defaultable": true
    },
    {
      "type": "SequenceView",
      "name": "resultsList",
      "model": "results",
      "layout": {"l": 10, "lf": 0, "t": 40, "tf": 0, "r": -10, "rf": 1, "b": -10, "bf": 1}
    }
  ]
}
```

**Output shape (Smalltalk the tool compiles into the class):**

```smalltalk
windowSpec
    "MCP-generated. Edit via vw_create_window_spec or in UIPainter."
    <resource: #canvas>
    ^#(#{UI.FullSpec}
        #window: #(#{UI.WindowSpec}
            #label: 'Party Search'
            #bounds: #(#{Graphics.Rectangle} 100 100 700 500)
            #min: #(#{Core.Point} 400 300)
            #max: #(#{Core.Point} 1200 800)
            #properties: #(#{UI.PropertyListDictionary}
                #sizeType #specifiedSize
                #positionType #screenCenter
                #openType #advanced)
            #hasMenuBar: false)
        #component: #(#{UI.SpecCollection}
            #collection: #(
                #(#{UI.LabelSpec}
                    #name: #searchLabel
                    #label: 'Search for:'
                    #layout: #(#{Graphics.LayoutFrame} 10 0 10 0 100 0 30 0))
                #(#{UI.InputFieldSpec}
                    #name: #searchInput
                    #model: #searchString
                    #layout: #(#{Graphics.LayoutFrame} 110 0 10 0 -90 1 30 0)
                    #numChars: 50
                    #type: #string)
                #(#{UI.ActionButtonSpec}
                    #name: #searchButton
                    #label: 'Search'
                    #model: #doSearch
                    #layout: #(#{Graphics.LayoutFrame} -80 1 10 0 -10 1 30 0)
                    #isDefault: true
                    #defaultable: true)
                #(#{UI.SequenceViewSpec}
                    #name: #resultsList
                    #model: #results
                    #layout: #(#{Graphics.LayoutFrame} 10 0 40 0 -10 1 -10 1)))))
```

The AI **never sees** the spec literal syntax. The AI thinks "a window with a label + input + button + results list"; the tool handles all the namespace-qualifying, layout-encoding, and literal-array generation.

### 6.2 `vw_create_application_model` — the scaffolding tool

The biggest single ergonomic win. AI passes the app's structure; tool generates 5 pieces:

**Input shape:**

```json
{
  "className": "PartySearchView",
  "namespace": "MyAppPackage",
  "superclass": "ApplicationModel",
  "category": "MyApp-UI",
  "aspects": [
    {"name": "searchString", "type": "string", "default": "''"},
    {"name": "results", "type": "list", "default": "OrderedCollection new"}
  ],
  "actions": [
    {"name": "doSearch", "source": "results value: (self databaseSearch: searchString value)"}
  ],
  "windowSpec": { /* same shape as vw_create_window_spec input */ },
  "hooks": {
    "postBuildWith:": "(aBuilder componentAt: #searchInput) widget takeKeyboardFocus",
    "postOpenWith:": null
  }
}
```

**Output — 6 emitted methods + 1 class definition** (all compiled in one tool call, all under #41 guard for `VWB.*` refusal):

1. Class definition: `ApplicationModel subclass: #PartySearchView instanceVariableNames: 'searchString results' ... inDictionary: 'MyAppPackage'`
2. `#initialize` (instance-side): empty (lazy-init pattern is preferred per librarian-validated §5.1 of 05-vw-native-development.md)
3. `#searchString` accessor (lazy): `^searchString isNil ifTrue: [searchString := '' asValue] ifFalse: [searchString]`
4. `#results` accessor (lazy): `^results isNil ifTrue: [results := OrderedCollection new asValue] ifFalse: [results]`
5. `#doSearch` action: `results value: (self databaseSearch: searchString value)`
6. `#postBuildWith:` hook: `(aBuilder componentAt: #searchInput) widget takeKeyboardFocus`
7. `windowSpec` (class-side): the literal-array form (via `vw_create_window_spec` internal call)

Net result: AI writes ~30 lines of JSON; tool emits ~80 lines of correct, idiomatic Smalltalk. AI never has to remember:
- The `^foo isNil ifTrue: [foo := … asValue] ifFalse: [foo]` lazy pattern
- That `#initialize` is conventionally empty (instance vars are lazy-init)
- The class definition syntax for VW 3.7 namespaces
- The spec literal-array format
- The lifecycle hook signatures

This is "more powerful than any dev" — a human VW developer types this manually + makes mistakes; the AI delegates to the tool + gets it right.

### 6.3 `vw_create_class` (MVP — simpler scaffolder)

Stand-alone class creator without ApplicationModel coupling. Used for domain classes, helper classes, test classes, etc.

```json
{
  "className": "Customer",
  "namespace": "MyAppPackage",
  "superclass": "Object",
  "category": "MyApp-Model",
  "instanceVariableNames": ["name", "email", "phone"],
  "classVariableNames": [],
  "classInstanceVariableNames": [],
  "poolDictionaries": []
}
```

Emits the canonical class definition. Hard-guard: refuses any `VWB.*` namespace (carry-forward #41 — the bridge class is OFF-LIMITS).

### 6.4 `vw_create_dialog`

SimpleDialog cousin of `vw_create_application_model`. Two modes (per librarian-validated §4.4):

**Mode A — spec-based dialog** (for complex dialogs):
```json
{"className": "ConfirmDialog", "mode": "spec", "windowSpec": {...}, "aspects": [...]}
```

**Mode B — programmatic add-builder** (for simple Q&A dialogs):
```json
{
  "className": "GetNameDialog",
  "mode": "programmatic",
  "messages": [
    {"add": "addMessage:", "value": "Enter your name:"},
    {"add": "addTextLine:", "name": "name", "default": ""},
    {"add": "addOK:", "block": "[name value notEmpty]"}
  ]
}
```

Mode B emits a class-side `windowSpec` method that uses the SimpleDialog `add*` builder methods (12 of them present per probe-3 D). Lower-friction for simple dialogs.

### 6.5 `vw_define_action` + `vw_define_aspect` — single-shot scaffolders

For incremental development AFTER a class exists. Add ONE action or ONE aspect to an existing ApplicationModel.

```json
// vw_define_aspect
{"className": "PartySearchView", "aspectName": "selectedCustomer", "type": "object", "default": "nil"}

// vw_define_action
{"className": "PartySearchView", "actionName": "deleteSelected",
 "source": "selectedCustomer value ifNotNil: [database remove: selectedCustomer value]"}
```

Both run under #41 guard. Both emit single methods using `vw_compile_method` internally with the correct category (`'aspects'` for aspects, `'actions'` for actions, per Jasper convention extended to VW).

### 6.6 `vw_get_widget_value` — read live widget state

The native form of bridge endpoint `GET /value?aspect=X`. Wraps the HTTP call in typed I/O.

```json
{"aspect": "searchString", "windowTitle": "PartySearch"}
// returns: {"ok": true, "aspect": "searchString", "value": "Smith"}
```

Used by AI to verify "did my type/click actually update the field?" Read-only; safe.

### 6.7 `vw_create_parcel` (V3 — refines pending bg_3fe35753)

Build a binary parcel from a class list. Wraps the Cursor>>showWhile: monkey-patch + `parcelOutOn:withSource:hideOnLoad:republish:backup:` pattern from session-19 Phase P P6.

**Current best understanding** (will refine with bg_3fe35753 librarian output):

```json
{
  "name": "MyApp",
  "outputDir": "/path/to/parcels/",
  "namespaces": ["MyAppPackage"],
  "classes": ["PartySearchView", "Customer"],
  "extensions": [{"class": "SimpleDialog", "selector": "myCustomMethod"}],
  "hideOnLoad": false
}
```

The tool internally:
1. Installs the Cursor monkey-patch (`Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'`)
2. Builds the parcel: `Kernel.Parcel createParcelNamed: → addNameSpace: → addEntiretyOfClass: → addSelector:class: → parcelOutOn:withSource:hideOnLoad:republish:backup:`
3. Cleans up the parcel registry: `[Kernel.Parcel removeParcelNamed:] on: Core.Notification do: [:n | n resume]`
4. Restores the Cursor method via methodDictionary swap

All of this is encapsulated. AI just specifies "I want a parcel named X containing classes Y and Z"; tool handles 6 image-quirks (showWhile wedge, namespace placement, source companion .pst, Notification on remove, Cursor restoration, ensure: block fallback).

## 7. Bridge integration (UNCHANGED from v1)

### 7.1 HTTP client (`src/bridge.ts`)

Single `BridgeClient` class with token re-read + retry-on-401:

```typescript
class BridgeClient {
  constructor(opts: { bridgeUrl: string; tokenFile: string })

  // Token re-read on mtime change OR 401 response
  private async readToken(): Promise<string>
  private tokenCache: { value: string; mtime: number } | null

  // Core HTTP helpers
  async get(path: string): Promise<unknown>
  async post(path: string, body: unknown): Promise<unknown>
  async postEval(source: string): Promise<unknown>   // /eval with Bug #5 + #41 guards

  // Liveness
  async health(): Promise<{ status: string; version: string }>
  async version(): Promise<{ version: string; buildCommitSha: string; buildTimestamp: string; parcelMode: string }>
}
```

### 7.2 Token rotation handling

Pattern from Linear MCP ([04 §4.4](../research/04-mcp-best-practices.md)):

```typescript
private async readToken(): Promise<string> {
  const stats = await fs.stat(this.tokenFile);
  if (this.tokenCache && this.tokenCache.mtime === stats.mtimeMs) {
    return this.tokenCache.value;
  }
  this.tokenCache = { value: (await fs.readFile(this.tokenFile, "utf-8")).trim(), mtime: stats.mtimeMs };
  return this.tokenCache.value;
}

async get(path: string): Promise<unknown> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = await this.readToken();
    const res = await fetch(`${this.bridgeUrl}${path}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(30_000),
    });
    if (res.status === 401 && attempt === 0) {
      this.tokenCache = null;   // force re-read on retry
      continue;
    }
    if (!res.ok) throw new BridgeError(res.status, await res.text());
    return res.json();
  }
  throw new Error("unreachable");
}
```

Cost: one `fs.stat` per call (~0.1ms on Windows). Worth it for transparent token rotation.

### 7.3 Bug #5 + #41 guards in `vw_eval` and `vw_compile_*`

```typescript
async function vwEvalTool({ source }: { source: string }) {
  // Bug #5 Stage 1 mitigation in MCP layer (bridge has it too; fail-fast here saves a round trip):
  if (source.includes("VWBridge") && source.includes("dispatch")) {
    return errorResult(
      "vw_eval body cannot reference both 'VWBridge' and 'dispatch' — this would re-enter the bridge dispatcher (Bug #5). Use direct handler call instead (e.g. 'VWBridge singleton handleWindows')."
    );
  }
  // #41 guard for compile-on-VWB.*:
  if (/(?:^|[^.\w])(VWB\.\w+)\s+(?:class\s+)?compile:/.test(source)) {
    return errorResult(
      "vw_eval refuses compile: on VWB.* namespace classes — would wedge the bridge (carry-forward #41). Use vw_compile_method on a MAS class instead."
    );
  }
  return bridge.postEval(source);
}

// vw_compile_method has the equivalent guard at the typed-param level:
async function vwCompileMethod({ className, isMeta, category, source }) {
  if (className.startsWith("VWB.") || className === "VWBridge") {
    return errorResult(
      "vw_compile_method refuses targets in the VWB namespace (carry-forward #41 — would wedge the bridge). Pick a MAS class instead."
    );
  }
  // ...
}
```

**Defense-in-depth**: bridge has these guards too; MCP-layer fail-fast saves round trips AND gives a more actionable error message.

## 8. Auto-registration (UNCHANGED from v1)

### 8.1 Primary: `.mcpb` Desktop Extension

Manifest (`manifest.json` at repo root):

```json
{
  "manifest_version": "0.3",
  "name": "vw-bridge",
  "version": "0.1.0",
  "description": "Drive a VisualWorks 9.3.1 image through the VW Bridge HTTP API",
  "author": { "name": "Amos Maganyane" },
  "server": {
    "type": "binary",
    "entry_point": "bin/mcp-vw.exe",
    "mcp_config": {
      "command": "${__dirname}/bin/mcp-vw.exe",
      "args": ["--bridge-url", "${user_config.bridge_url}"],
      "env": {
        "VW_BRIDGE_TOKEN_FILE": "${user_config.token_file}",
        "MCP_VW_SINGLE_OWNER": "${user_config.single_owner ? '1' : '0'}"
      }
    }
  },
  "user_config": {
    "bridge_url": {
      "type": "string", "title": "Bridge URL",
      "default": "http://127.0.0.1:9876", "required": true
    },
    "token_file": {
      "type": "string", "title": "Path to bridge .token file",
      "default": "${HOME}/code/tm-context/src/vw-bridge/.token",
      "sensitive": true, "required": true
    },
    "single_owner": {
      "type": "boolean", "title": "Enforce single-owner (recommended)", "default": true
    }
  },
  "compatibility": {
    "claude_desktop": ">=1.0.0",
    "platforms": ["win32", "darwin", "linux"]
  }
}
```

User flow: download `.mcpb` → double-click → "Install" button. Sensitive token file path stored in OS keychain. Claude Desktop spawns the server itself — user never edits JSON. **Bypasses MSIX path bug entirely.**

### 8.2 Fallback: PowerShell MSIX-aware installer

For legacy Claude Desktop installs OR users who prefer manual control:

```powershell
# install-mcp-vw.ps1
$msixPath = (Get-AppxPackage -Name "*Claude*").PackageFamilyName |
    ForEach-Object { Join-Path $env:LOCALAPPDATA "Packages\$_\LocalCache\Roaming\Claude" } |
    Where-Object { Test-Path $_ } | Select-Object -First 1

$configPath = if ($msixPath) { $msixPath } else { Join-Path $env:APPDATA "Claude" }
$configFile = Join-Path $configPath "claude_desktop_config.json"

$config = if (Test-Path $configFile) {
  Get-Content $configFile -Raw | ConvertFrom-Json
} else {
  @{ mcpServers = @{} } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

$config.mcpServers | Add-Member -NotePropertyName 'vw-bridge' -NotePropertyValue @{
  command = "$env:USERPROFILE\code\tm-context\src\mcp-vw\dist\mcp-vw.exe"
  args = @("--bridge-url", "http://127.0.0.1:9876")
  env = @{
    VW_BRIDGE_TOKEN_FILE = "$env:USERPROFILE\code\tm-context\src\vw-bridge\.token"
    MCP_VW_SINGLE_OWNER = "1"
  }
} -Force

$config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8

Write-Host "[install-mcp-vw] Wrote $configFile (MSIX-aware: $($msixPath -ne $null))"
Write-Host "[install-mcp-vw] Restart Claude Desktop to pick up the new server."
```

## 9. Single-owner enforcement (UNCHANGED from v1)

Lockfile + PID + stale-PID recovery (knowledge-rag pattern, [04 §3.2](../research/04-mcp-best-practices.md)). Env var opt-out via `MCP_VW_SINGLE_OWNER=0`. Exit code 75 (`EX_TEMPFAIL`) on conflict.

## 10. Error semantics (UNCHANGED from v1)

| Channel | When | Mechanism |
|---|---|---|
| **JSON-RPC error** (`-32603`) | Server-side bug, validation failure, protocol violation | `throw` inside tool handler |
| **Tool result with `isError: true`** | Bridge unavailable, 5xx, /eval failed, validation rejected | Return `{ content: [...], isError: true }` |

Golden rule from Python SDK migration guide: "isError: true tells the AI the tool ran but the operation failed — the AI can adjust and retry. Throwing an exception creates a protocol-level error that may disconnect the client. **Always prefer isError for tool failures.**"

Error message format embeds RECOVERY ACTION:
- `"VW Bridge is not responding at http://127.0.0.1:9876. Check that the VisualWorks image is running and the bridge is started (Start-VWBridge.bat). Retried 3 times over 7s."`
- `"vw_compile_method refuses targets in the VWB namespace (carry-forward #41 — would wedge the bridge). Pick a MAS class instead."`
- `"VW Bridge rejected the auth token. The bridge rotates this on cold start — re-read $VW_BRIDGE_TOKEN_FILE and retry, or restart the bridge."`

## 11. Versioning (UNCHANGED from v1)

- Pin SDK: `"@modelcontextprotocol/sdk": "^1.29.0"` in package.json
- Bridge compat check at MCP server init: read `/version`, refuse to register if bridge < v0.10.0 (the version `/version` shipped)
- MCP protocol version: declared in `serverInfo.version` `"0.1.0"`; SDK handles negotiation
- Backward-compat across mcp-vw versions: append-only tool additions, additive schema changes, deprecation warnings ≥1 minor version

## 12. Testing strategy (UNCHANGED from v1)

4-level pyramid:
1. **Unit / static** — tool input validation, schema, error message shape
2. **In-memory MCP client** — full protocol against in-process `Server`
3. **Subprocess / stdio integration** — spawn actual built executable, MCP Inspector smoke tests
4. **Live Claude Desktop** — manual smoke test on real Windows 11 MSIX install

Plus: **golden-file tests for codegen** (NEW in v2):
```typescript
// test/codegen/windowSpec.test.ts
test("vw_create_window_spec emits canonical literal form", () => {
  const input = require("./fixtures/party-search.input.json");
  const output = createWindowSpec(input);
  expect(output).toMatchFileSnapshot("./fixtures/party-search.expected.st");
});
```

Snapshot-driven testing catches regressions in the literal-array emission.

## 13. Effort estimate (REVISED)

| Tier | Tool count | Effort | Notes |
|---|---:|---|---|
| Setup | — | 0.5d | `package.json`, `tsconfig.json`, `vitest.config.ts`, skeleton |
| **MVP** (18 tools) | 18 | **3d** (was 2d) | +1d for `vw_create_class` (typed scaffolder is meatier than eval-wrap) and parcel trio |
| Auto-registration | — | 0.5d | `.mcpb` manifest + PowerShell installer |
| **V2** (+13 tools = 31) | 13 | **3d** (was 2d) | +1d for the 6 native UI-construction tools (vw_create_application_model, vw_create_window_spec, vw_create_dialog, vw_define_aspect, vw_define_action, vw_get_widget_value); golden-file test fixtures |
| **V3+** (+17 tools = 48) | 17 | **4d** (was 2d) | +2d for the long-tail (Painter introspection, Topaz export, Store integration via bg_3fe35753 findings) |
| **TOTAL** | **48** | **~10d** (was 7d) | |

**Onboarding-developer milestone** (the key user-facing milestone):
- MVP only = ~3 days from session-22 start (Setup 0.5 + MVP 3 + auto-reg 0.5)
- MVP + V2 = ~6 days — adds the full native UI-construction story
- Full surface = ~10 days

Per [PHASE-PROGRESS.md](../../plan/PHASE-PROGRESS.md), the onboarding-developer milestone moves from ~3 days (v1) to ~4 days (v2 — MVP includes the new parcel + create_class tools). Still attainable in week 1 of Phase M.

## 14. Open questions for sign-off

| # | Question | Recommendation | Rationale |
|---|---|---|---|
| 1 | Tool naming: `vw_*` prefix? | **YES** (Recommended) | Disambiguates from Jasper's bare names which user runs simultaneously |
| 2 | MVP scope: 18 tools? | **YES** (Recommended) | Covers all the AI workflows the user critique demanded |
| 3 | Implementation timing | **Defer to session-22** (Recommended) | Session-21 was scoped for research; jumping into ~3 days of code is scope creep |
| 4 | Auto-registration shape: `.mcpb` primary? | **YES** (Recommended) | Bypasses MSIX path bug; double-click install; sensitive values in OS keychain |
| 5 | Single-owner default: enforce? | **YES** (Recommended) | MSIX double-spawn bug is real; protect by default |
| 6 | VWB namespace refusal scope | **VWB.* only for MVP** (Recommended) | Expand if user accidentally targets stock VW classes |
| 7 | Surface a `vw_commit` stub that returns "VW has no commit"? | **NO** (Recommended) | Adds clutter; document in write-tool descriptions instead |
| 8 | Parcel section: ship V3 surface now, or wait for bg_3fe35753? | **Wait for bg_3fe35753 then refine** (Recommended) | Parcel tools are V3 — not on MVP critical path; 1 more wave-2 librarian validates before locking |

## 15. Acceptance criteria for "Phase M MVP shipped"

- [ ] `npm install && npm run build` succeeds in `src/mcp-vw/`
- [ ] `vitest` passes (per-tool unit tests + golden-file codegen tests + subprocess smoke test)
- [ ] Claude Desktop registration works: `.mcpb` install OR PowerShell installer writes correct `claude_desktop_config.json` (MSIX-aware on Windows 11)
- [ ] Claude Desktop sees `vw-bridge` server with 18 MCP tools listed
- [ ] AI agent in Claude Desktop can:
  - `vw_health` returns `{status: "ok", version: "0.10.0"}`
  - `vw_eval { source: "1 + 2" }` returns `{ok: true, result: "3"}`
  - `vw_list_namespaces` returns 312-element array
  - `vw_create_class { className: "TestFoo", namespace: "TestPackage", ... }` creates the class
  - `vw_list_windows` returns array (possibly empty)
  - `vw_click { aspect: "search", windowTitle: "PartySearch" }` drives a real widget (verified by manual user inspection of the VW window)
  - `vw_load_parcel { path: "..." }` loads a parcel from disk
  - `vw_list_loaded_parcels` enumerates them
- [ ] Bridge restart mid-session is handled transparently — second tool call succeeds after token rotation, no user intervention
- [ ] Two Claude Desktop processes attempted simultaneously: second mcp-vw exits with code 75 + clear stderr message
- [ ] All 18 tool descriptions include relevant safety constraint (Bug #5 substring for vw_eval, #41 refusal for vw_compile_method + vw_create_class, etc.)
- [ ] README documents `.mcpb` install + PowerShell fallback + manual JSON + smoke test
- [ ] **NEW v2**: `vw_create_class` end-to-end works — AI passes JSON, class appears in image, queryable via `vw_get_class_definition`

If MVP passes all of the above, Phase M is shipped. V2 + V3+ are additive — defer to subsequent sessions.

## 16. References

- [`01-mcp-sdk.md`](../research/01-mcp-sdk.md) — SDK selection rationale (TypeScript `^1.29.0`)
- [`02-jasper-delta.md`](../research/02-jasper-delta.md) — 33 Jasper tools mapped to VW; identifies the 28 active tools all wrapping `POST /eval`
- [`03-vw-specific-capabilities.md`](../research/03-vw-specific-capabilities.md) — 12 VW-only MCP tools (UI inspection / driving / screenshot / wait)
- [`04-mcp-best-practices.md`](../research/04-mcp-best-practices.md) — Claude Desktop config + auto-registration + single-owner + error semantics + Windows MSIX path landmine
- [`05-vw-native-development.md`](../research/05-vw-native-development.md) — VW native dev idioms (image-empirical + librarian-validated); canonical spec literal format discovery
- [`_librarian-bg356abb3f-applicationmodel-raw.md`](../research/_librarian-bg356abb3f-applicationmodel-raw.md) — wave-2 librarian raw output (ApplicationModel deep dive, 1,061 lines)
- [`../../knowledge/vw-image-api-contract.md`](../../knowledge/vw-image-api-contract.md) — 42 carry-forward constraints (esp. #15, #16, #18, #20, #28, #38, #41)
- [`../../vw-bridge/probes/_probe-s21-*`](../../vw-bridge/probes/) — 3 image probes (class inventory, namespace contents, inheritance chains + canonical windowSpec)

## 17. Appendix — File list when MVP implementation begins (session-22)

If sign-off + user picks "begin MVP this session" OR "defer to session-22":

| File | Purpose | Approx LoC |
|---|---|---:|
| `src/mcp-vw/package.json` | npm config | ~40 |
| `src/mcp-vw/tsconfig.json` | TS strict mode, ES2022, ESM | ~25 |
| `src/mcp-vw/vitest.config.ts` | Test runner | ~15 |
| `src/mcp-vw/.gitignore` | dist, node_modules, lockfile | ~10 |
| `src/mcp-vw/manifest.json` | `.mcpb` Desktop Extension manifest | ~50 |
| `src/mcp-vw/src/index.ts` | Entry: register tools, start stdio, acquire owner lock | ~100 |
| `src/mcp-vw/src/bridge.ts` | HTTP client + token re-read + retry on 401 | ~150 |
| `src/mcp-vw/src/lock.ts` | Lockfile + PID + stale-PID recovery | ~80 |
| `src/mcp-vw/src/util.ts` | `text()`, `errorResult()`, `safeHandler()`, `formatBridgeError()` | ~80 |
| `src/mcp-vw/src/codegen/class.ts` | `vw_create_class` Smalltalk emitter | ~80 |
| `src/mcp-vw/src/codegen/applicationModel.ts` | `vw_create_application_model` scaffolder (V2) | ~150 |
| `src/mcp-vw/src/codegen/windowSpec.ts` | `vw_create_window_spec` literal-array emitter (V2) | ~200 |
| `src/mcp-vw/src/codegen/dialog.ts` | `vw_create_dialog` (V2) | ~100 |
| `src/mcp-vw/src/codegen/parcel.ts` | `vw_create_parcel` Cursor monkey-patch + emitter (V3) | ~150 |
| `src/mcp-vw/src/tools/liveness.ts` | `vw_health`, `vw_version`, `vw_status` | ~60 |
| `src/mcp-vw/src/tools/eval.ts` | `vw_eval` with #5/#41 guards | ~50 |
| `src/mcp-vw/src/tools/navigation.ts` | `vw_find_senders` (MVP); `vw_find_implementors`/`vw_find_references_to` (V2) | ~120 |
| `src/mcp-vw/src/tools/reading.ts` | `vw_get_class_definition`, `vw_list_methods` (MVP); `vw_describe_class` (V2) | ~100 |
| `src/mcp-vw/src/tools/schema.ts` | `vw_list_namespaces`, `vw_list_namespace_entries` | ~50 |
| `src/mcp-vw/src/tools/ui_inspect.ts` | `vw_list_windows`, `vw_describe_window` (MVP); `vw_get_value`, `vw_list_dialogs` (V2) | ~80 |
| `src/mcp-vw/src/tools/ui_drive.ts` | `vw_click`, `vw_type` (MVP); `vw_respond_dialog` (V2) | ~80 |
| `src/mcp-vw/src/tools/parcel.ts` | `vw_load_parcel`, `vw_unload_parcel`, `vw_list_loaded_parcels` (MVP); `vw_create_parcel` (V3) | ~100 |
| `src/mcp-vw/test/bridge.test.ts` | Token re-read + retry tests | ~80 |
| `src/mcp-vw/test/codegen/windowSpec.test.ts` | Golden-file codegen tests (V2) | ~40 |
| `src/mcp-vw/test/tools/*.test.ts` | Per-tool in-memory client tests | ~30 each |
| `src/mcp-vw/test/e2e.test.ts` | MCP Inspector subprocess smoke test | ~50 |
| `src/mcp-vw/scripts/install-mcp-vw.ps1` | PowerShell MSIX-aware installer (fallback) | ~80 |
| `src/mcp-vw/scripts/Build-Mcpb.ps1` | Bundle dist + manifest into `.mcpb` zip | ~50 |
| `src/mcp-vw/README.md` | Install + Claude Desktop config + smoke test + tool catalog | ~200 |
| **TOTAL** | (production + tests + scripts + docs) | **~2,500** |

Net: ~2,500 lines of code + tests + docs for the full 48-tool surface. MVP alone is ~1,200 lines.
