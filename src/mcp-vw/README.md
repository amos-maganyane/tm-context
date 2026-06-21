# mcp-vw — VisualWorks 9.3.1 MCP Server

[![tests](https://img.shields.io/badge/tests-290_passing-green)](#testing) [![node](https://img.shields.io/badge/node-%3E%3D20-blue)](#prerequisites) [![sdk](https://img.shields.io/badge/%40modelcontextprotocol%2Fsdk-%5E1.29-blue)](#runtime-stack) [![tools](https://img.shields.io/badge/tools-48_(18_MVP_+_13_V2_+_17_V3)-blue)](#tool-catalog-48-tools)

MCP server that bridges **Claude Desktop** into a **live VisualWorks 9.3.1** image through the [VW Bridge](../vw-bridge/) HTTP endpoint. Exposes the **full 48-tool architecture.md v2 surface** (18 MVP + 13 V2 + 17 V3): liveness, code reading/navigation/introspection, NATIVE-TYPED scaffolders (class + windowSpec + ApplicationModel + dialog + parcel), method compile/define/delete, UI inspect/drive/dialogs/wait/screenshot, parcel load/unload/create, class hierarchy + fingerprint + search, and SUnit testing. Built for the MAS / Old Mutual Wealth WEALTH (`storedev64.im`) deployment but works against any VW Bridge instance.

## Quick start

```bash
# 1. Install deps + build
cd src/mcp-vw
npm install
npm run build
npm test               # ~240 tests, all green

# 2. Install into Claude Desktop (Windows MSIX-aware)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install-mcp-vw.ps1

# 3. Restart Claude Desktop. The `vw-bridge` server appears with 18 tools.
```

---

## What it does

Without `mcp-vw`, Claude Desktop can only issue raw HTTP probes against the VW Bridge through `curl`-style tool calls. The AI has to hand-write Smalltalk for everything: navigating namespaces, reading class definitions, building class shapes, walking spec literals — and it loses to all 42 [carry-forward image quirks](../../knowledge/vw-image-api-contract.md).

`mcp-vw` is the abstraction layer. The 18 tools encapsulate:

- The token rotation pattern (re-read on every call, retry on 401).
- The Bug #5 + carry-forward #41 safety guards that fail-fast before round-tripping.
- The Smalltalk emission idioms for class creation (no apostrophe bugs, no namespace traps).
- The Parcel `Notification`-resume dance (carry-forward #38).
- The single-owner lock against duplicate Claude Desktop spawns.

The AI calls `vw_create_class { className, namespace, superclass, instanceVariableNames }` — `mcp-vw` validates each identifier, refuses VWB.* targets, emits canonical `subclass:...inDictionary:...` Smalltalk, posts to /eval, and surfaces a clean result.

## Tool catalog (48 tools)

All tools are prefixed `vw_` to disambiguate from Jasper (the GemStone MCP) which uses bare names.

### MVP (18 tools)

#### Liveness (3)

| Tool | Description |
|---|---|
| `vw_health` | Auth-exempt `/health` probe. Returns `{status, version}`. |
| `vw_version` | Auth-exempt `/version` probe. Returns `{version, buildCommitSha, buildTimestamp, parcelMode}`. |
| `vw_status` | Composite: `/health` + `/version` + cheap eval probe (`42`). |

#### Eval (1)

| Tool | Description |
|---|---|
| `vw_eval` | Evaluate arbitrary Smalltalk. **Escape hatch** — prefer typed tools first. Guards: Bug #5 substring (`VWBridge`+`dispatch`), carry-forward #41 (compile-on-VWB.*). |

#### Schema (2)

| Tool | Description |
|---|---|
| `vw_list_namespaces` | Sorted JSON array of every namespace (~169 child namespaces of Smalltalk). |
| `vw_list_namespace_entries` | Sorted JSON array of bindings in a namespace. |

#### Reading (2)

| Tool | Description |
|---|---|
| `vw_get_class_definition` | Class definition source (`subclass:` form). Single-segment or namespace-qualified. |
| `vw_list_methods` | JSON array of `{side, category, selector}` for instance + class side. |

#### Navigation (1)

| Tool | Description |
|---|---|
| `vw_find_senders` | Find `Class>>selector` pairs sending a given selector. Cap 500. Optional `scope` (namespace) for speed. |

#### NATIVE-TYPED codegen (1)

| Tool | Description |
|---|---|
| `vw_create_class` | Emits canonical `<Super> subclass: #X ...inDictionary: 'NS' category: 'cat'` Smalltalk from typed JSON. Refuses VWB.* (#41). All identifiers validated against safe regex. |

#### Parcel (3)

| Tool | Description |
|---|---|
| `vw_load_parcel` | `Kernel.Parcel loadParcelFrom: '...' asFilename`. |
| `vw_unload_parcel` | `removeParcelNamed:` wrapped with `on: Core.Notification do: [:n \| n resume]` (#38). Refuses `VWBridge`. |
| `vw_list_loaded_parcels` | JSON array of currently-loaded parcel names. |

#### UI inspect (2)

| Tool | Description |
|---|---|
| `vw_list_windows` | Wraps `/windows`. Enumerates live windows. |
| `vw_describe_window` | Wraps `/windows/tree?windowTitle=X`. Full widget tree. |

#### UI drive (3)

| Tool | Description |
|---|---|
| `vw_click` | POST `/click {aspect, windowTitle?}`. Bridge handles RadioButton-vs-others dispatch. |
| `vw_type` | POST `/type {aspect, value, windowTitle?}`. Empty `value` clears the field. |
| `vw_open_application` | `<className> open` or `<className> new openInterface: #spec`. Refuses VWB.*. |

### V2 (+ 13 tools) — the NATIVE UI-construction differentiator

#### NATIVE-TYPED UI scaffolders (5)

| Tool | Description |
|---|---|
| **`vw_create_window_spec`** | Emits the canonical `windowSpec` literal-array form (the probe-3 design unlock) from structured JSON. Supports 13 component types (Label, ActionButton, InputField, CheckBox, RadioButton, ComboBox, SequenceView, TableView, TreeView, TextEditor, GroupBox, Divider, SubCanvas). AI never sees `#{UI.FullSpec}` / `#{Graphics.LayoutFrame}` / `PropertyListDictionary` syntax. Refuses VWB.*. |
| **`vw_create_application_model`** | HEAVYWEIGHT scaffolder — one JSON call produces 5+ compiled methods: class definition (with ivs from aspect names) + N lazy aspect accessors + N action methods + K lifecycle hooks + class-side windowSpec. Per-step error reporting. |
| **`vw_create_dialog`** | SimpleDialog cousin of `vw_create_application_model`. Default superclass `SimpleDialog`. V2 supports Mode A (spec-based); Mode B (programmatic `add*` builder) is V3. |
| **`vw_define_action`** | Single-shot: add an instance-side action method to an existing class. Wraps `vw_compile_method` with `category='actions'`. |
| **`vw_define_aspect`** | Single-shot: add a canonical lazy-init aspect accessor (`^aspect isNil ifTrue: [aspect := <default> asValue] ifFalse: [aspect]`). |

#### Code reading / navigation expansion (4)

| Tool | Description |
|---|---|
| **`vw_compile_method`** | NATIVE-TYPED method compile: `{className, isMeta, category, source}` JSON. Instance or class side. Refuses VWB.* (#41). |
| **`vw_describe_class`** | Composite class description in one call: definition + comment + instance methods (grouped by category) + class methods. |
| **`vw_find_implementors`** | Find `Class>>selector` pairs that IMPLEMENT a given selector. Walks `includesSelector:` per class. Cap 500. |
| **`vw_find_references_to`** | Find `Class>>selector` pairs that reference a given global (class name, namespace, shared var). Walks compiledMethod `#literals`. Cap 500. |

#### UI inspect expansion (1)

| Tool | Description |
|---|---|
| **`vw_get_widget_value`** | Read live aspect value from a running window. Wraps GET `/value?aspect=X[&windowTitle=Y]`. Verifies `vw_type`/`vw_click` took effect. |

#### SUnit testing (3) — uses the SAFE direct-invoke gate pattern (#20)

| Tool | Description |
|---|---|
| **`vw_run_test_class`** | Run every `test*` selector on a TestCase via direct-invoke (NEVER walks MAS-customized `testClasses` which would wedge 10-15min). Returns JSON suite summary `{className, total, passed, failed, errored, tests}`. |
| **`vw_run_test_method`** | Run ONE test method via direct-invoke. Returns `{result: PASS\|FAIL\|ERR, errorMessage}`. |
| **`vw_list_failing_tests`** | Run all + return ONLY failures + errors (no passes). Concise diagnostic alternative to `vw_run_test_class`. |

### V3 (+ 17 tools) — long-tail introspection + destructive ops + parcel build

#### Schema expansion (3)

| Tool | Description |
|---|---|
| **`vw_list_namespace_classes`** | List ONLY class bindings (Behavior instances) in a namespace, filtering out shared vars + pool dicts. |
| **`vw_list_all_classes`** | Bulk enumerate every class as `Namespace.ClassName`. Default cap 5000. |
| **`vw_list_test_classes`** | Discover TestCase subclasses ending in `Test`/`Tests`. Uses `allSubclasses` (safe — does NOT walk MAS-customized testClasses). |

#### Class introspection (4)

| Tool | Description |
|---|---|
| **`vw_get_method_fingerprint`** | Behavioral fingerprint `{numArgs, numTemps, messages, literals}` since sources are stripped. Use to reason about what a method does. |
| **`vw_get_class_hierarchy`** | Walk superclass chain root→cls + collect direct subclasses (NOT recursive). |
| **`vw_export_class`** | Structural dump: definition + comment + every method with `{category, selector, numArgs, numMessages}`. |
| **`vw_search_method_messages`** | Substring search across method `#messages` sets. Closest approximation to text search since sources stripped. Cap 500. |

#### Destructive ops (4) — all refuse VWB.* + extra guards

| Tool | Description |
|---|---|
| **`vw_compile_class_definition`** | Compile a raw class definition Smalltalk string. Refuses VWB.* + Bug #5 substrings. Use `vw_create_class` for typed creation. |
| **`vw_delete_method`** | Remove a method via `removeSelector:`. Refuses VWB.*. Use `vw_find_senders` first. |
| **`vw_delete_class`** | Remove a class entirely via `removeFromSystem`. Requires `confirm: true`. Refuses VWB.*. Use `vw_find_senders` + `vw_find_implementors` first. |
| **`vw_set_class_comment`** | Set the class comment text. Apostrophes auto-escaped. Refuses VWB.*. |

#### Modal dialogs (2)

| Tool | Description |
|---|---|
| **`vw_list_dialogs`** | Enumerate live modal SimpleDialog instances. |
| **`vw_respond_dialog`** | Click a named button on the currently-posted modal (uses Bug #2 fix infrastructure). |

#### UI synchronization (1)

| Tool | Description |
|---|---|
| **`vw_wait`** | Block until UI predicate satisfied. Predicates: `windowExists`, `aspectEquals`, `aspectNotEmpty`, `dialogExists`, `dialogGone`. Default 10s, max 120s. |

#### Visual capture (1)

| Tool | Description |
|---|---|
| **`vw_screenshot`** | Capture PNG of screen or window. Returns MCP ImageContent (base64) for direct rendering in Claude Desktop. |

#### Test failure analysis (1)

| Tool | Description |
|---|---|
| **`vw_describe_test_failure`** | Re-run a single failing test + structured exception capture `{exceptionClass, messageText, stackSnippet}`. Use after `vw_list_failing_tests`. |

#### Parcel build (1) — HEAVYWEIGHT

| Tool | Description |
|---|---|
| **`vw_create_parcel`** | Build a binary `.pcl` parcel from typed JSON spec. Internally wraps the Cursor>>showWhile: monkey-patch (#35) + `createParcelNamed:` + `addEntiretyOfClass:` + `parcelOutOn:withSource:hideOnLoad:republish:backup:` + `removeParcelNamed:` Notification-resume (#38). Refuses VWB.* targets (#41). |

---

## Prerequisites

- **Node.js ≥ 20** (uses native `fetch` + `AbortSignal.timeout`).
- **VW Bridge** running at `http://127.0.0.1:9876` (verify via `curl.exe -s http://127.0.0.1:9876/health`).
- **`VW_BRIDGE_HOME`** env var set at the User scope, pointing at `<repo>/src/vw-bridge/`. Persists across vwnt.exe restarts.

If the bridge isn't running, start it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "$env:VW_BRIDGE_HOME\scripts\Start-VWBridge.ps1" -KillExisting
```

## Install

Three options, in priority order.

### Option A — `.mcpb` Desktop Extension (recommended)

```powershell
cd src/mcp-vw
npm install --omit=dev      # production deps only for the bundle
npm run build
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File scripts/Build-Mcpb.ps1
```

This writes `build/mcp-vw-0.1.0.mcpb`. Double-click it in Claude Desktop → "Install". Sensitive `tokenFile` is stored in the OS keychain. **Bypasses the Windows MSIX path landmine entirely.**

### Option B — PowerShell installer (fallback)

Detects MSIX vs non-MSIX Claude Desktop installs and writes the right `claude_desktop_config.json`:

```powershell
cd src/mcp-vw
npm install
npm run build
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File scripts/install-mcp-vw.ps1
```

Use `-BridgeUrl`, `-TokenFile`, `-SingleOwner $false` to override defaults. Pass `-WhatIf` to preview the config without writing.

### Option C — Manual JSON edit (for advanced setups)

Locate your Claude Desktop config:

- **MSIX install**: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
- **Standard install**: `%APPDATA%\Claude\claude_desktop_config.json`

Add `vw-bridge` to `mcpServers`:

```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "node",
      "args": ["C:\\Users\\YOU\\tm\\tm-context\\src\\mcp-vw\\dist\\src\\index.js"],
      "env": {
        "VW_BRIDGE_URL": "http://127.0.0.1:9876",
        "VW_BRIDGE_TOKEN_FILE": "C:\\Users\\YOU\\tm\\tm-context\\src\\vw-bridge\\.token",
        "MCP_VW_SINGLE_OWNER": "1"
      }
    }
  }
}
```

Restart Claude Desktop after editing.

## Configuration

All config is via env vars (mcp-vw reads them at startup):

| Var | Default | Description |
|---|---|---|
| `VW_BRIDGE_URL` | `http://127.0.0.1:9876` | Bridge HTTP endpoint. Trailing slash is stripped. |
| `VW_BRIDGE_TOKEN_FILE` | `$VW_BRIDGE_HOME/.token` if set, else `~/.vw-bridge.token` | Path to the bridge's `.token` file. mcp-vw re-reads on every call. |
| `MCP_VW_SINGLE_OWNER` | enabled | Single-owner lock. Disable with `0` / `false` / `off` for parallel dev. |
| `MCP_VW_LOCK_FILE` | `<tmpdir>/mcp-vw.lock` | Lockfile path. Use a non-default if multiple bridges share a host. |

## Carry-forward safety guards (built in)

- **Bug #5 substring guard** (`vw_eval`): rejects source with both `VWBridge` AND `dispatch` substrings — would trip the recursive-dispatch limit. Suggests using direct handler calls or rephrasing.
- **Carry-forward #41** (`vw_eval`, `vw_create_class`, `vw_open_application`): refuses any operation targeting the `VWB` namespace — empirically wedges the bridge.
- **Carry-forward #38** (`vw_unload_parcel`): wraps `removeParcelNamed:` with `on: Core.Notification do: [:n | n resume]`.
- **Self-unload guard** (`vw_unload_parcel`): refuses unloading the `VWBridge` parcel itself — would tear down the listener mid-call.
- **Token rotation** (`bridge.ts`): re-reads `.token` on mtime change AND on 401 response. Retries once with the fresh token.
- **Single-owner lock** (`lock.ts`): lockfile + PID + stale-PID recovery + Windows EPERM-race retry. Exits with code 75 on conflict.
- **Smalltalk injection guards** (every typed tool): all identifiers (class names, namespaces, selectors, variable names) validated against strict regex before embedding in Smalltalk source.

## Development

```bash
npm install            # full deps including devDependencies
npm test               # vitest run — ~240 tests
npm run test:watch     # vitest watch mode
npm run typecheck      # tsc --noEmit
npm run build          # tsc emit to dist/src/
npm run dev            # tsx src/index.ts (stdio server, reads env from current shell)
```

### Project layout

```
src/mcp-vw/
├── package.json           # ESM, Node 20+, deps pinned
├── tsconfig.json          # strict mode, NodeNext, includes test/
├── tsconfig.build.json    # extends; src/ only, emit to dist/
├── vitest.config.ts       # test/**/*.test.ts
├── manifest.json          # .mcpb Desktop Extension manifest
├── src/
│   ├── index.ts           # stdio server entry, registers all 18 tools
│   ├── bridge.ts          # HTTP client with token re-read + 401 retry
│   ├── lock.ts            # OwnerLock single-owner pattern
│   ├── util.ts            # text(), errorResult(), safeHandler(), BridgeError
│   ├── smalltalk.ts       # quote/unquote/splitLines + identifier validators
│   ├── codegen/
│   │   └── class.ts       # vw_create_class NATIVE-TYPED emitter
│   └── tools/
│       ├── types.ts       # ToolDef interface
│       ├── liveness.ts    # vw_health, vw_version, vw_status
│       ├── eval.ts        # vw_eval (with #5 + #41 guards)
│       ├── schema.ts      # vw_list_namespaces, vw_list_namespace_entries
│       ├── reading.ts     # vw_get_class_definition, vw_list_methods
│       ├── navigation.ts  # vw_find_senders
│       ├── parcel.ts      # vw_load_parcel, vw_unload_parcel, vw_list_loaded_parcels
│       ├── ui_inspect.ts  # vw_list_windows, vw_describe_window
│       └── ui_drive.ts    # vw_click, vw_type, vw_open_application
├── test/
│   ├── _helpers.ts        # stubBridge + firstText
│   ├── util.test.ts       # 27 tests
│   ├── bridge.test.ts     # 18 tests
│   ├── lock.test.ts       # 20 tests
│   ├── smalltalk.test.ts  # 28 tests
│   ├── e2e.test.ts        # 14 tests (real MCP Client+Server via InMemoryTransport)
│   ├── codegen/
│   │   └── class.test.ts  # 19 tests
│   └── tools/
│       ├── liveness.test.ts     # 10
│       ├── eval.test.ts          # 18
│       ├── schema.test.ts        # 8
│       ├── reading.test.ts       # 9
│       ├── navigation.test.ts    # 10
│       ├── parcel.test.ts        # 13
│       ├── ui_inspect.test.ts    # 6
│       └── ui_drive.test.ts      # 14
└── scripts/
    ├── install-mcp-vw.ps1 # PowerShell MSIX-aware installer
    └── Build-Mcpb.ps1     # .mcpb bundle builder
```

### TDD discipline

Every behavior change ships through red→green→refactor. Tests live in `test/` mirroring `src/` structure. Tool tests use `stubBridge` from `test/_helpers.ts` to inject a vi.fn()-backed `BridgeClientLike`. The e2e test spins up a real `McpServer` + `Client` pair via `InMemoryTransport.createLinkedPair()` so the protocol layer gets exercised too.

## Troubleshooting

### "VW Bridge is not responding (ECONNREFUSED)"

The bridge isn't running. Start it:

```powershell
& "$env:VW_BRIDGE_HOME\scripts\Start-VWBridge.ps1" -KillExisting
```

### "VW Bridge rejected the auth token (HTTP 401)"

The bridge rotated its token since you last cached it. `mcp-vw` re-reads + retries automatically — if you're still hitting 401 after the retry, the `.token` file is stale. Either restart the bridge or wait for the next launch (token rotates on every `VWB.VWBridge start`).

### "vw_eval refused: source contains both 'VWBridge' AND 'dispatch'"

Bug #5 guard. Two workarounds:

1. Call the handler directly: `VWB.VWBridge singleton handleWindows` instead of going through `dispatch:`.
2. Rephrase any in-source comment that uses both words (use "router" instead of "dispatch").

### "vw_create_class refuses targets in the VWB namespace"

Carry-forward #41. The bridge class is OFF-LIMITS for mid-/eval mutation. Pick a MAS application namespace instead.

### "another mcp-vw process (PID N) holds the single-owner lock"

Two Claude Desktop windows attempted to spawn the server. The second exits with code 75. Options:

1. Close the other Claude Desktop instance.
2. Delete the lockfile if the holder is gone but the lockfile lingers.
3. Set `MCP_VW_SINGLE_OWNER=0` to disable the guard (not recommended).

## Runtime stack

| Component | Version | Notes |
|---|---|---|
| Node.js | ≥ 20 LTS | Native `fetch` + `AbortSignal.timeout` |
| TypeScript | ^5.4 | strict mode, NodeNext, ES2022 |
| `@modelcontextprotocol/sdk` | ^1.29.0 | Stdio + InMemory transports, `registerTool()` API |
| `zod` | ^3.23.0 | Input schema validation |
| `vitest` | ^1.6.0 | Test runner |
| `tsx` | ^4.7.0 | Dev-mode TypeScript execution |

## License

MIT. See [`LICENSE`](../LICENSE) at repo root.
