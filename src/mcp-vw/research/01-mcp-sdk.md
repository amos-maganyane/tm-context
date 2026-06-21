---
title: MCP SDK Selection — Python vs TypeScript
purpose: Step 2 deliverable for Phase M research. Side-by-side comparison of the official Anthropic MCP SDKs (Python `mcp` v1.28.0 vs TypeScript `@modelcontextprotocol/sdk` v1.29.0) with a decisive pick for the Phase M VW Bridge MCP server on a Windows workstation primarily targeting Claude Desktop.
written: 2026-06-21 (session-21 Phase M research, Step 2)
source: librarian agent bg_32aa30c2 (2m 38s, ses_114b20e89ffeb05DoJgBp4xP5f) — context7 + websearch verified against PyPI, npm, GitHub repo metadata, Anthropic's modelcontextprotocol.io tutorial, jgfoster/Jasper precedent
status: FINAL
decision: TypeScript SDK (@modelcontextprotocol/sdk ^1.29.0) — see §5
---

# Phase M — MCP SDK Selection: Python vs TypeScript

**Date:** 2026-06-21
**Target environment:** Windows 10/11, Claude Desktop primary client
**Project:** VW Bridge MCP server (Phase M) — wraps existing HTTP bridge at `127.0.0.1:9876` as MCP tools
**Outcome:** DECISIVE PICK — TypeScript SDK (`@modelcontextprotocol/sdk`). Reasoning in §5.

---

## 1. SDK A — Python (`mcp` on PyPI)

### 1.1 Identity + maturity

| Field | Value |
|---|---|
| PyPI package | `mcp` |
| Current stable | **v1.28.0** |
| Stable release date | **2026-06-16** |
| Latest pre-release | `2.0.0a2` (2026-06-16) — opt-in only |
| Python requirement | `>=3.10` |
| Author | Anthropic, PBC |
| License | MIT |
| Repo | https://github.com/modelcontextprotocol/python-sdk |
| Stars | 23,385 |
| Forks | 3,562 |
| Open issues | 570 |
| Contributors | 190 (top: dsp-ant, maxisbey, Kludex) |
| Total releases | 59 |
| Repo created | 2024-09-24 |
| Last push | **2026-06-21** (today) |
| Maintenance status | **v1.x is in maintenance mode** — only critical bug fixes + security patches. Stable v2.0.0 target: **2026-07-27** (alongside new spec). v1.x is the only stable line for now. |

Source: PyPI release history at https://pypi.org/project/mcp/#history and GitHub repo metadata.

**Important v2 note from the v1.x README:** *"If your package depends on mcp, add a `<2` upper bound to your version constraint (for example `mcp>=1.27,<2`) before the stable v2 release lands."* — A migration is coming, but v2 is a near-total rework (stateless request/response) and v1.x is what we'd ship on.

### 1.2 Tool definition shape

- **Style:** Decorator on plain Python functions. The `FastMCP` class is the high-level facade.
- **Input schema:** Derived automatically from **Python type hints + docstring**. The type annotations produce a JSON Schema under the hood. Pydantic `BaseModel` is supported for nested objects.
- **Output schema:** Anything returned by the tool is auto-serialized. Return type annotation is honored — if it's a Pydantic model, TypedDict, dataclass, or `dict[str, T]`, the result is delivered as **structured content** (`structuredContent` on `CallToolResult`). Plain `str`/`int`/etc. is wrapped as `{"result": value}`.
- **Return value shape:** Either a raw value (auto-wrapped) or a full `CallToolResult(content=[TextContent(type="text", text=...)], isError=...)` for fine control.

```python
from mcp.server.fastmcp import FastMCP
mcp = FastMCP("vw-bridge")

@mcp.tool()
def evaluate(expression: str) -> str:
    """Evaluate a Smalltalk expression in the running VW image."""
    # ... call http://127.0.0.1:9876/eval ...
    return "42"
```

(Source: [v1.x server docs](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/server.md), `examples/snippets/servers/basic_tool.py`)

### 1.3 Server boilerplate (literal minimal)

```python
# server.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("vw-bridge")

@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers (demo)."""
    return a + b

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

(Source: [python-sdk README quickstart](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/README.md), `examples/snippets/servers/fastmcp_quickstart.py`)

Install + run:
```bash
uv add "mcp[cli]"
uv run server.py
```

### 1.4 Transport options

All in `mcp.server.fastmcp.FastMCP.run()`:

- `stdio` (default) — local subprocess, what Claude Desktop uses
- `streamable-http` — remote, HTTP POST + SSE for streaming
- `sse` — Server-Sent Events (legacy, still supported but being phased out for Streamable HTTP)
- ASGI mount on a Starlette/FastAPI app is also supported for embedding in a larger web app

### 1.5 Claude Desktop integration (literal `claude_desktop_config.json` on Windows)

Path: `%APPDATA%\Claude\claude_desktop_config.json` per the official docs. **BUT see 03-mcp-best-practices.md §1.1** — the MSIX install (default in 2026) actually reads `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json` instead. This is the single most-reported Windows MCP bug in 2026.

```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "uv",
      "args": [
        "--directory",
        "C:\\Users\\ammaganyane\\code\\tm-context\\src\\mcp-vw",
        "run",
        "server.py"
      ]
    }
  }
}
```

(Source: official [Build an MCP server — Python tab](https://modelcontextprotocol.io/docs/develop/build-server) — Windows section)

**Caveat from the same docs:** *"You may need to put the full path to the `uv` executable in the `command` field. You can get this by running `which uv` on macOS/Linux or `where uv` on Windows."*

### 1.6 Error reporting semantics

Three options, all official:

```python
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError
from mcp.types import CallToolResult, TextContent

mcp = FastMCP("vw-bridge")

# Option 1 — raise ToolError (preferred for expected errors)
@mcp.tool()
def divide(a: float, b: float) -> float:
    if b == 0:
        raise ToolError("Cannot divide by zero")
    return a / b

# Option 2 — let unhandled exceptions bubble; SDK converts to isError=True
@mcp.tool()
def read(path: str) -> str:
    return open(path).read()  # FileNotFoundError -> isError result

# Option 3 — return CallToolResult for full control
@mcp.tool()
def validate(data: str) -> CallToolResult:
    return CallToolResult(
        content=[TextContent(type="text", text="bad input")],
        isError=True,
    )
```

(Source: [python-sdk `docs/server.md`](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/server.md))

### 1.7 Testing patterns

Official in-memory transport — no subprocess, no networking:

```python
import pytest
from mcp.client.session import ClientSession
from mcp.shared.memory import create_connected_server_and_client_session
from mcp.types import CallToolResult, TextContent
from inline_snapshot import snapshot

from server import app

@pytest.fixture
async def client_session():
    async with create_connected_server_and_client_session(app, raise_exceptions=True) as s:
        yield s

@pytest.mark.anyio
async def test_call_add_tool(client_session: ClientSession):
    result = await client_session.call_tool("add", {"a": 1, "b": 2})
    assert result == snapshot(CallToolResult(
        content=[TextContent(type="text", text="3")],
        structuredContent={"result": 3},
    ))
```

(Source: [python-sdk `docs/testing.md`](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/testing.md))

### 1.8 Windows-specific gotchas

| Gotcha | Detail |
|---|---|
| `uv` location | `command` should be the full `uv` exe path on Windows. Pure `"uv"` works only if `%USERPROFILE%\.local\bin` is on PATH for the Claude Desktop process. |
| Path separators | Use double backslashes or forward slashes in JSON. |
| `${APPDATA}` expansion bug | Known issue — add explicit `env: { "APPDATA": "..." }` if you see `${APPDATA}` literally in error logs. (Source: official troubleshooting on [connect-local-servers](https://modelcontextprotocol.io/docs/develop/connect-local-servers).) |
| Logging to stdout | CRITICAL: any `print()` or stdout writing on stdio transport will corrupt the JSON-RPC stream. Use `print(..., file=sys.stderr)` or `logging` to stderr. |
| MSIX path landmine | Documented `%APPDATA%\Claude\` is wrong for MSIX installs — see best-practices doc §1.1. |

---

## 2. SDK B — TypeScript (`@modelcontextprotocol/sdk` on npm)

### 2.1 Identity + maturity

| Field | Value |
|---|---|
| npm package | `@modelcontextprotocol/sdk` |
| Current stable | **v1.29.0** |
| Stable release date | **2026-03-30** |
| Latest pre-release | `2.0.0-alpha.2` (2026-04-01) — opt-in only |
| Runtime | Node.js, Bun, Deno |
| Author | Anthropic, PBC |
| License | MIT |
| Repo | https://github.com/modelcontextprotocol/typescript-sdk |
| Stars | 12,702 |
| Forks | 1,936 |
| Open issues | 462 |
| Contributors | 160 |
| Total releases | 94 |
| **Weekly downloads** | **38.9M** |
| **Dependents** | **55.7K** |
| Repo created | 2024-09-24 |
| Last push | **2026-06-21** (today) |
| Maintenance status | v1.x in **active** maintenance (v1.29.0 was the most recent release; backports from v2 work land on v1.x). v2.0.0 stable target: Q3 2026 with the 2026-07-28 spec. |

**Key observation:** TypeScript SDK has **3.5× the npm dependents** of the Python SDK (55.7K vs ~15K for `mcp`) and **38.9M weekly downloads** — by far the more widely integrated SDK.

### 2.2 Tool definition shape

- **Style:** Method call on the `McpServer` instance (`server.registerTool(name, config, handler)`). No decorators — explicit registration.
- **Input schema:** **Zod** raw shape (v1) or wrapped with `z.object({})` (v2). ArkType and a `fromJsonSchema` adapter are also supported.
- **Output schema:** Tools return a `CallToolResult` literal. The TS SDK does NOT auto-wrap return values — you build the content array yourself.
- **Return value shape:** `Promise<CallToolResult>` with explicit `content: Content[]` array.

```typescript
import { z } from "zod";

server.registerTool(
  "evaluate",
  {
    description: "Evaluate a Smalltalk expression in the running VW image",
    inputSchema: { expression: z.string() },
  },
  async ({ expression }) => ({
    content: [{ type: "text" as const, text: "42" }],
  })
);
```

### 2.3 Server boilerplate (literal minimal)

```typescript
// src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "vw-bridge", version: "1.0.0" });

server.registerTool(
  "add",
  {
    description: "Add two numbers (demo).",
    inputSchema: { a: z.number(), b: z.number() },
  },
  async ({ a, b }) => ({
    content: [{ type: "text" as const, text: String(a + b) }],
  }),
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("vw-bridge MCP server running on stdio");
}

main().catch((err) => {
  console.error("fatal:", err);
  process.exit(1);
});
```

### 2.4 Transport options

From the [TS SDK `docs/server.md`](https://github.com/modelcontextprotocol/typescript-sdk/blob/main/docs/server.md): *"MCP supports two primary transport mechanisms for servers. Streamable HTTP is designed for remote servers that are accessible over a network. Stdio is used for local servers that are spawned as child processes."*

- `StdioServerTransport` — local subprocess (what Claude Desktop uses)
- `StreamableHTTPServerTransport` — HTTP POST + SSE streaming
- `SSEServerTransport` — legacy SSE (deprecated for new servers but supported for compat)
- WebSocket — reachable via the `Hono` middleware (`@hono/node-server`)

### 2.5 Claude Desktop integration

```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "node",
      "args": [
        "C:\\Users\\ammaganyane\\code\\tm-context\\src\\mcp-vw\\build\\index.js"
      ]
    }
  }
}
```

**Alternative dev mode** (no build step — run TS directly via `tsx`):
```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "npx",
      "args": ["-y", "tsx", "C:/Users/ammaganyane/code/tm-context/src/mcp-vw/src/index.ts"]
    }
  }
}
```

### 2.6 Error reporting semantics

```typescript
server.registerTool(
  "fetch-data",
  {
    description: "Fetch data from a URL",
    inputSchema: { url: z.string() },
  },
  async ({ url }): Promise<CallToolResult> => {
    try {
      const res = await fetch(url);
      if (!res.ok) {
        return {
          content: [{ type: "text", text: `HTTP ${res.status}: ${res.statusText}` }],
          isError: true,
        };
      }
      return { content: [{ type: "text", text: await res.text() }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Failed: ${error instanceof Error ? error.message : String(error)}` }],
        isError: true,
      };
    }
  },
);
```

**Note:** Unlike the Python SDK, unhandled exceptions in TS DO bubble up and crash the server. The TS SDK does NOT auto-catch — you must wrap tool bodies in try/catch and return `isError: true`. Python is more forgiving; TS is more explicit.

### 2.7 Testing patterns

The TS SDK ships an in-process **InMemoryTransport** (`@modelcontextprotocol/sdk/inMemory.js`) — spin up `McpServer` + `Client` in the same process, connect with `InMemoryTransport`, call tools, assert. No subprocess, no port binding. The canonical usage lives in the SDK's own vitest suite (`src/inMemory.ts`) — slight DX gap vs Python's first-class `create_connected_server_and_client_session`.

For manual end-to-end: `npx -y @modelcontextprotocol/inspector node build/index.js`.

### 2.8 Windows-specific gotchas

| Gotcha | Detail |
|---|---|
| **`windowsHide` always set in v1.29.0** | PR #1640 / #1772 (backported as part of v1.29.0, 2026-03-30) fixed a bug where spawning a stdio MCP server on Windows would briefly flash a console window. **The SDK now always sets `windowsHide: true` on Windows.** This is THE single most important Windows-specific fix in either SDK. Pre-1.29.0 versions had this issue. |
| Path separators | Use `\\` or `/` in JSON. |
| `node` location | Use `where node` to find the absolute path. |
| `${APPDATA}` expansion bug | Same as Python — add explicit `env: { "APPDATA": "..." }` if needed. |
| Logging to stdout | Same critical rule: `console.log()` corrupts the JSON-RPC stream. Use `console.error()`. |
| Build step required | Unlike Python, you must `tsc` before running (unless you use `tsx`). |

---

## 3. Side-by-side summary

| Dimension | Python (`mcp`) | TypeScript (`@modelcontextprotocol/sdk`) |
|---|---|---|
| **Latest stable** | v1.28.0 (2026-06-16) | v1.29.0 (2026-03-30) |
| **GitHub stars** | 23,385 | 12,702 |
| **Ecosystem (dependents)** | ~15K on PyPI | **55.7K on npm** |
| **Weekly downloads** | not retrieved | **38.9M** |
| **Contributors** | 190 | 160 |
| **License** | MIT | MIT |
| **Tool style** | `@mcp.tool()` decorator (ergonomic) | `server.registerTool(...)` (explicit) |
| **Input schema** | Type hints + docstring → JSON Schema (Pydantic for objects) | Zod raw shape → JSON Schema (or ArkType / fromJsonSchema) |
| **Output schema** | Auto-wraps; Pydantic → structured content | Manual: `content: [{ type: "text", text }]` literal |
| **Transports** | stdio, Streamable HTTP, SSE (legacy) | stdio, Streamable HTTP, SSE (legacy), WS via Hono |
| **Error model** | 3 options: `ToolError` / auto-catch / `CallToolResult` | Manual try/catch + return `isError: true` |
| **Testing utility** | First-class `create_connected_server_and_client_session` | InMemoryTransport exists but no canonical example in README |
| **Windows fix for stdio** | Not specifically called out | **v1.29.0 — `windowsHide` always set** |
| **Maintenance** | v1.x **maintenance mode** (v2 stable 2026-07-27) | v1.x **active** maintenance (v2 stable Q3 2026) |
| **Claude Desktop config** | `uv --directory <path> run server.py` | `node <path>/build/index.js` |
| **Jasper precedent** | — | **Jasper uses `@modelcontextprotocol/sdk` (TS)** |

---

## 4. Jasper's SDK choice (relevant precedent)

**Jasper** ([jgfoster/Jasper](https://github.com/jgfoster/Jasper), the canonical GemStone MCP server published under the `gemtalksystems` VS Code Marketplace namespace) is built on **`@modelcontextprotocol/sdk` v1.12.1 (TypeScript)** — see [02-jasper-delta.md](./02-jasper-delta.md) for the full architectural breakdown.

Jasper serves MCP over both:
- **stdio** (proxy via `node` for Claude Code's `claude mcp add`)
- **HTTPS/SSE** at `https://127.0.0.1:27101/sse` for Claude Desktop's "Add custom connector"

Its `package.json` depends on `@modelcontextprotocol/sdk ^1.12.0`. This is a directly analogous project (Smalltalk → MCP), and the maintainer chose TypeScript. Worth noting for our own Phase M, which has the same shape (VisualWorks Smalltalk → MCP via HTTP bridge).

---

## 5. RECOMMENDATION

**Pick: TypeScript SDK — `@modelcontextprotocol/sdk` (v1.29.0+).**

### Why — five concrete reasons, in priority order

1. **Phase E alignment (decisive).** Phase E will use the Playwright SDK, which is JavaScript/TypeScript. Locking in TypeScript for Phase M means one toolchain, one `package.json`, one `node_modules`, one set of editor settings, one test runner (vitest), one CI config, and one mental context. Picking Python for Phase M means we'll context-switch between `pyproject.toml` + `uv` and `package.json` + `npm` for the lifetime of this project. The user explicitly flagged this as a selection criterion, and it's the strongest reason on the board.

2. **Active Windows support.** TypeScript SDK v1.29.0 (2026-03-30) shipped a specific fix for Windows stdio behavior — `windowsHide` is now always set, eliminating console-window flicker. No analogous Windows-specific fix in the Python SDK changelog. For a Windows workstation as the primary dev/QA environment, this is meaningful.

3. **Ecosystem signal.** 55.7K npm dependents vs ~15K PyPI dependents. 38.9M weekly downloads. The TS SDK is what Claude Code, Claude Desktop, VS Code, Cursor, and the bulk of the MCP server ecosystem are integrated against. More eyeballs → more bug reports → faster fixes.

4. **Jasper precedent.** The most directly analogous project (Smalltalk → MCP, stdio + HTTPS/SSE, target Claude Desktop) chose TypeScript. Their config shape is nearly identical to what we need.

5. **Both SDKs are stable + Anthropic-maintained + MIT.** The "risk" of picking TypeScript is essentially zero — both are official, both are first-party from Anthropic, both have v2 migrations coming in 2026, both will receive security patches through the v1.x lifecycle. Python's FastMCP decorator is ergonomically a touch nicer, but the gap is small (maybe 5 lines of boilerplate per tool), and it doesn't outweigh items 1–4.

### What we accept by picking TypeScript

- **Slightly more boilerplate per tool** (manual `content: [{ type: "text", text }]` vs Python's auto-wrapping). Mitigation: a 5-line `text(s: string)` helper in `src/mcp-vw/util.ts` collapses it to one call.
- **Must wrap tool bodies in try/catch** (TS SDK doesn't auto-catch). Mitigation: a small `safeHandler` wrapper that catches and returns `isError: true` with a structured error.
- **Build step required** (or use `tsx` to skip it in dev). Mitigation: `package.json` script `"dev": "tsx watch src/index.ts"` and `"start": "node build/index.js"` for prod.
- **v2 migration coming Q3 2026** (both SDKs). Mitigation: pin `"@modelcontextprotocol/sdk": "^1.29.0"` and migrate when v2 ships.

### What we avoid by NOT picking Python

- **`uv` PATH issues on Windows** — official warning: *"You may need to put the full path to the `uv` executable in the `command` field."* Real source of friction.
- **v1.x in maintenance mode** — v2.0.0 lands 2026-07-27 (a near-total rework). Complex tools we build today may need migration <6 weeks.
- **Language context-switching with Phase E** — already covered in (1).

### Concrete pin for our `package.json`

```json
{
  "name": "@amos-maganyane/mcp-vw",
  "version": "0.1.0",
  "type": "module",
  "bin": { "mcp-vw": "./build/index.js" },
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc && chmod 755 build/index.js",
    "start": "node build/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.29.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.4.0",
    "tsx": "^4.7.0",
    "vitest": "^1.6.0"
  }
}
```

### Concrete `claude_desktop_config.json` (Windows MSIX path) for Phase M

**Dev mode (no build step):**
```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "npx",
      "args": ["-y", "tsx", "C:/Users/ammaganyane/code/tm-context/src/mcp-vw/src/index.ts"],
      "env": { "VW_BRIDGE_URL": "http://127.0.0.1:9876" }
    }
  }
}
```

**Prod mode (after `npm run build`):**
```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "node",
      "args": ["C:/Users/ammaganyane/code/tm-context/src/mcp-vw/build/index.js"],
      "env": { "VW_BRIDGE_URL": "http://127.0.0.1:9876" }
    }
  }
}
```

⚠ **Per best-practices doc §1.1**, the MSIX install (default 2026) reads from `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`, NOT the documented `%APPDATA%\Claude\` path. Our installer must handle this.

---

## 6. Sources

- [PyPI — `mcp` v1.28.0](https://pypi.org/project/mcp/)
- [GitHub — `modelcontextprotocol/python-sdk`](https://github.com/modelcontextprotocol/python-sdk)
- [Python SDK server docs](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/server.md)
- [Python SDK testing docs](https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/testing.md)
- [npm — `@modelcontextprotocol/sdk`](https://www.npmjs.com/package/@modelcontextprotocol/sdk)
- [GitHub — `modelcontextprotocol/typescript-sdk`](https://github.com/modelcontextprotocol/typescript-sdk)
- [TypeScript SDK v1.29.0 release notes](https://github.com/modelcontextprotocol/typescript-sdk/releases/tag/v1.29.0)
- [TS stdio `windowsHide` fix — PR #1640 / #1772](https://github.com/modelcontextprotocol/typescript-sdk/pull/1772)
- [TypeScript SDK server docs](https://github.com/modelcontextprotocol/typescript-sdk/blob/main/docs/server.md)
- Official MCP tutorial — [Build an MCP server](https://modelcontextprotocol.io/docs/develop/build-server)
- [Connect to local MCP servers](https://modelcontextprotocol.io/docs/develop/connect-local-servers)
- [MCP Inspector docs](https://modelcontextprotocol.io/docs/tools/inspector)
- [Jasper (jgfoster/Jasper)](https://github.com/jgfoster/Jasper) — confirmed TS SDK use
