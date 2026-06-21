---
title: MCP Best Practices for HTTP-Wrapping Servers (2026)
purpose: Step 5-input deliverable for Phase M research. Best-practice reference for building a production-quality MCP server that wraps an HTTP backend in 2026 — Claude Desktop config, auto-registration, single-owner enforcement, error semantics, version pinning, testing, Windows gotchas. Sourced from real-world MCP servers (github-mcp-server, notion-mcp-server, playwright-mcp, mcp-server-fetch, jasper) and the official Anthropic patterns (.mcpb Desktop Extensions, modelcontextprotocol/python-sdk, modelcontextprotocol/typescript-sdk).
written: 2026-06-21 (session-21 Phase M research, Step 5-input)
source: librarian agent bg_df28bd3a (3m 40s, ses_114b1826effeOuanVJ817AV655) verified against real GitHub repos, PyPI/npm, official MCP specification, Anthropic-published patterns
status: FINAL
---

# MCP Best Practices for HTTP-Wrapping Servers (2026)

**Target**: `src/mcp-vw/` — Phase M MCP server for the VW Bridge at `127.0.0.1:9876`
**Reference date**: June 2026
**Evidence base**: 5 reference MCP servers + official MCP spec + Anthropic patterns

---

## 1. Claude Desktop config — the Windows MSIX landmine

### 1.1 Two paths, only one is read

There are **two different paths** and only one of them is the file Claude Desktop actually reads. The official documentation points at the wrong one on the standard Windows build.

| Install flavor | Documented path | Path Claude Desktop actually reads |
|---|---|---|
| Legacy / direct `.exe` (rare in 2026) | `%APPDATA%\Claude\claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` ✅ |
| **MSIX (default — claude.ai/download, WinGet, Microsoft Store)** | `%APPDATA%\Claude\claude_desktop_config.json` ❌ | `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json` ✅ |

**Why this matters for Phase M**: any installer we write must read/write the MSIX path on a default Windows 11 install. Anthropic's MSIX packaging silently redirects Electron's `app.getPath("userData")` into the package's virtualized filesystem. The "Edit Config" button in Developer settings uses Electron's `shell.openPath()` which resolves the **non-virtualized** path — so the file users edit is *not* the file Claude reads. This is the single most-reported Windows MCP bug in 2026.

**PowerShell helper to find the real path**:

```powershell
$pkg = (Get-AppxPackage -Name "*Claude*").PackageFamilyName
Join-Path $env:LOCALAPPDATA "Packages\$pkg\LocalCache\Roaming\Claude\claude_desktop_config.json"
```

**Sources**:
- Bug report: <https://github.com/anthropics/claude-code/issues/25579> (MSIX userData redirection)
- Bug report: <https://github.com/anthropics/claude-code/issues/26073> (Edit Config opens wrong file)
- Recovery: <https://startdebugging.net/2026/06/fix-mcp-servers-stop-working-after-claude-desktop-update-on-windows/>

### 1.2 Literal JSON shape

```json
{
  "mcpServers": {
    "vw-bridge": {
      "command": "C:\\path\\to\\mcp-vw\\dist\\mcp-vw.exe",
      "args": ["--bridge-url", "http://127.0.0.1:9876"],
      "env": {
        "VW_BRIDGE_TOKEN_FILE": "C:\\Users\\<user>\\AppData\\Local\\vw-bridge\\.token"
      }
    }
  }
}
```

**Valid keys** (from the Python SDK README + VS Code usage + FastMCP source):

| Key | Type | Required | Notes |
|---|---|---|---|
| `command` | string | yes (stdio) | Absolute path preferred on Windows |
| `args` | string[] | no | All values literal strings — no shell expansion |
| `env` | object<string,string> | no | Inherited from Claude Desktop's environment plus additions |
| `disabled` | boolean | no | Per-server disable flag |
| `type` | `"stdio"` \| `"http"` \| `"sse"` | no (defaults to stdio) | |

**Common gotchas**:
- **Null fields break entries.** If your installer emits `transport: null`, `keep_alive: null`, Claude Desktop ignores the whole entry. Strip nulls.
- **Backslash escaping**: use `\\` or `/` in JSON.
- **Logging to stdout breaks the JSON-RPC stream.** Any `print()` or `console.log()` on stdio transport corrupts the protocol. Use stderr only.

---

## 2. Auto-registration patterns

Four patterns are in active use in 2026:

### 2.1 `.mcpb` Desktop Extensions (Anthropic official, June 2025)

Anthropic's first-party answer. Bundle server + runtime + manifest into a `.mcpb` zip; user double-clicks, Claude Desktop installs it. **Dominant pattern for any user-facing distribution.**

- Manifest spec: <https://github.com/anthropics/mcpb/blob/main/MANIFEST.md>
- Engineering writeup: <https://www.anthropic.com/engineering/desktop-extensions>

Key features:
- `${__dirname}` expands to the unpacked install dir at runtime
- `${user_config.KEY}` substitutes user-provided values (token paths, URLs)
- Sensitive values stored in OS keychain automatically via `sensitive: true` flag
- Cross-platform single-file distribution

**For Phase M**: this is the **primary distribution path**. Bypasses MSIX path hell entirely because Claude Desktop spawns the server itself — user never edits JSON.

### 2.2 `fastmcp install claude-desktop` (Python ecosystem)

PrefectHQ's FastMCP (25K stars) CLI writes to `claude_desktop_config.json` directly. De facto pattern in the Python MCP world. **Does NOT handle the MSIX path** ([open issue PrefectHQ/fastmcp#3346](https://github.com/PrefectHQ/fastmcp/issues/3346)) — not directly applicable to Phase M (we're TypeScript) but the pattern is instructive.

### 2.3 VS Code one-click deep links

Pattern: `https://insiders.vscode.dev/redirect/mcp/install?name=<n>&config=<base64-json>`. Used by `mcp-server-fetch` and `github-mcp-server`. README badge → click → register. **Secondary path for Phase M.**

### 2.4 Manual JSON snippet in README

Common: `mcp-server-fetch` and `github-mcp-server` both lead with this. **Tertiary fallback for Phase M.**

### 2.5 Jasper's auto-registration pattern (direct file write, both clients)

From [`jgfoster/Jasper`](https://github.com/jgfoster/Jasper) (TS, GemStone MCP):

- On extension activation, writes `mcpServers.gemstone` into both `~/.claude.json` (Claude Code, user-scope) AND `claude_desktop_config.json` (Claude Desktop)
- Always-on for Claude Code; opt-out for Claude Desktop via `gemstone.mcp.registerWithClaudeDesktop: true` (default true)
- Strips legacy per-workspace `gemstone-<hash>` entries on every activation (idempotent + clean)
- First-time Claude Code prompt: "Reload Window" since Claude Code snapshots its MCP list at session start

**Phase M should adopt this pattern verbatim** for the PowerShell installer fallback (when `.mcpb` isn't available).

---

## 3. Single-owner enforcement

### 3.1 The problem

When the user has two Claude Desktop processes (chat panel + Code/Agent panel), Anthropic's MSIX package can launch one stdio MCP server **twice per session** — once per panel — bypassing the global dedup. Both processes try to drive the same VW image through the same bridge: corrupted `.token` reads, duplicate UI events.

This is bug [aaddrick/claude-desktop-debian#526](https://github.com/aaddrick/claude-desktop-debian/issues/526), unresolved as of June 2026.

### 3.2 The canonical pattern: lockfile + PID + stale-PID recovery

From `knowledge-rag` MCP server ([source](https://github.com/lyonzin/knowledge-rag/blob/master/docs/single-instance.md)):

```
On startup:
1. O_CREAT | O_EXCL on <data_dir>/<name>.lock with our PID
2. If exists: read PID, probe process.kill(pid, 0)
   - alive   → exit with code 75 (EX_TEMPFAIL)
   - dead    → remove stale lock, retry
3. Normal exit: remove lock in finally block
4. SIGINT/SIGTERM: handler removes lock and re-raises
5. SIGKILL/crash: stale-PID detection on next startup recovers
```

Exit code 75 (`EX_TEMPFAIL` from `sysexits.h`) is the documented choice — Claude Desktop treats it as transient and doesn't retry-loop.

**Windows-friendly variant**: `fs.openSync(path, 'wx')` (the `x` flag fails if file exists). For Python: `os.open(path, os.O_CREAT | os.O_EXCL | os.O_RDWR)`.

### 3.3 Recommendation for Phase M

Implement lockfile + PID + stale-PID detection, **gated on `MCP_VW_SINGLE_OWNER=1` env var** (default on; user can override for advanced multi-Claude coordination via the bridge). Bridge itself is single-tenant anyway — second Claude would just hit a different port.

---

## 4. Error semantics

### 4.1 Two channels in MCP

| Channel | Mechanism | When | LLM sees it? |
|---|---|---|---|
| **JSON-RPC error** | `error.code` (-32603 etc.), no `result` | Protocol-level: bad params, unknown method, server internal error | **No** — surfaces as "tool call failed" with no context |
| **Tool result error** | Normal `result` with `content[]` + `isError: true` | Application-level: HTTP 5xx, validation, business-logic | **Yes** — message text becomes LLM input for next turn |

**Golden rule** (Python SDK migration guide):

> "isError: true tells the AI the tool ran but the operation failed — the AI can adjust and retry. Throwing an exception creates a protocol-level error that may disconnect the client. **Always prefer isError for tool failures.**"

### 4.2 Standard JSON-RPC error codes

```
PARSE_ERROR      = -32700
INVALID_REQUEST  = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS   = -32602
INTERNAL_ERROR   = -32603

# SDK-defined
CONNECTION_CLOSED        = -32000
REQUEST_TIMEOUT          = -32001
REQUEST_CANCELLED        = -32002
URL_ELICITATION_REQUIRED = -32042
```

### 4.3 Canonical pattern: GitHub MCP server

Source: [`pkg/errors/error.go`](https://github.com/github/github-mcp-server/blob/main/pkg/errors/error.go) (Go, official, ~100 tools).

`NewGitHubAPIErrorResponse` differentiates:
1. `*github.RateLimitError` → "GitHub API rate limit exceeded. Retry after 47s." (Retry-After embedded)
2. `*github.AbuseRateLimitError` → "GitHub secondary rate limit exceeded. Retry after 60s."
3. Generic API errors with status code

**Key principle**: error message embeds the action the LLM should take ("Retry after 47s"). This is the design pattern the LLM's tool-feedback loop needs.

### 4.4 Token rotation pattern (critical for Phase M)

From Linear MCP ([npm @blocksuser/mcp-linear](https://registry.npmjs.org/@blocksuser/mcp-linear)):

> "The server re-reads the file on each API request, so a rotated token is picked up automatically without restarting."

Phase M analog:
1. **Stat the `.token` file on every tool call** (mtime check is cheap)
2. If mtime changed, **re-read** the token
3. If 401 comes back, **re-read and retry once** before returning an error

### 4.5 Decision matrix for Phase M error cases

| Failure mode | Retry? | Encoding | Recommended message shape |
|---|---|---|---|
| **Bridge down / connection refused** | Yes (3x exp backoff) | `isError: true` | `"VW Bridge is not responding at http://127.0.0.1:9876. Check that the VisualWorks image is running and the bridge is started. Retried 3 times over 7s."` |
| **Bridge returns 5xx** | Yes (1-2x) | `isError: true` | `"VW Bridge returned 503: <body>. The bridge is overloaded or restarting. Try again in 5s."` |
| **Bridge 401 / token rotated** | Yes (re-read + retry once) | silent recovery; only `isError` if recovery fails | First call: recover transparently. If recovery fails: `"VW Bridge rejected the token in VW_BRIDGE_TOKEN_FILE. The bridge rotates this on cold start — restart the bridge or wait 5s and retry."` |
| **Bridge slow / timeout** | No (30s default) | `isError: true` | `"VW Bridge did not respond within 30s. Possible cause: the image is paused in the debugger or running a long compile. Try breaking the request into smaller steps."` |
| **Bridge eval `recursive_dispatch_forbidden` (Bug #5)** | No | `isError: true` | `"vw_eval body cannot reference both 'VWBridge' and 'dispatch' — this would re-enter the bridge dispatcher and wedge the listener. Use direct handler call instead (e.g. 'VWBridge singleton handleWindows')."` |
| **Bridge eval compile-on-VWB.VWBridge wedge (#41)** | No (refuse via MCP-layer guard) | JSON-RPC `INVALID_PARAMS` | `"vw_compile_method refuses targets in VWB namespace — this would wedge the bridge listener (carry-forward #41). Pick a MAS class instead."` |

### 4.6 Timeouts

| Operation | Default |
|---|---|
| HTTP connect (bridge alive check) | 2s |
| HTTP read (tool call) | 30s |
| Stdio handshake (`initialize`) | 10s |
| Token re-read | 1s |

### 4.7 What you should never do

- Throw an unclassified `Exception` and rely on SDK's catch-all — the LLM sees a generic "Error executing tool foo: ...".
- Write the token (or URL containing the token in query string) into error messages — tokens are credentials.
- Return a 200 with the error body in `content` and no `isError` flag — model treats it as success.

---

## 5. Version pinning

### 5.1 Two version axes

1. **MCP protocol version** — declared in `initialize` request as `protocolVersion`. Server may negotiate down. Examples: `2024-11-05`, `2025-03-26`, `2025-06-18`, `2025-11-25` (current draft).
2. **Server binary version** — what `npx mcp-server-x@1.2.3` resolves to.

### 5.2 Pinning the server binary

Universal 2026 convention: `npx -y <pkg>@<version>` (exact pin). For Phase M (single-developer dev tool): pin by absolute path to built executable. No registry resolution.

### 5.3 MCP protocol version negotiation

The spec ([Lifecycle 2025-06-18](https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle)):
- Server SHOULD accept client's offered version if supported
- Otherwise server MUST respond with another version it supports
- Server may include `supported: ["2024-11-05", ...]` in error's `data` field

In practice: Claude Desktop in June 2026 sends `protocolVersion: "2025-11-25"`. Modern Python + TypeScript SDKs handle negotiation automatically. **For Phase M**: pin to whatever the TS SDK supports (currently `2025-06-18`+) and declare it in `serverInfo.version`.

### 5.4 Backward-compat across server versions

No formal mechanism. De-facto:
- **Append-only tool additions**: never remove/rename. GitHub MCP example: [Tool Renaming docs](https://github.com/github/github-mcp-server/blob/main/docs/tool-renaming.md)
- **Additive `inputSchema` changes**: optional fields with sensible defaults
- **Deprecation warning** on old tool names for ≥1 minor version

---

## 6. Testing strategy

### 6.1 The four-level pyramid

1. **Unit / static** — tool input validation, schema conformance, error message shape. Fastest, runs in CI.
2. **In-memory MCP client** — full protocol handshake against real `Server` object, same process, no subprocess.
3. **Subprocess / stdio integration** — spawn actual server binary, connect with stdio client, exercise end-to-end.
4. **Live host / Inspector** — MCP Inspector (UI + CLI) or actual Claude Desktop.

### 6.2 In-memory pattern (Python SDK)

```python
@pytest.mark.asyncio
async def test_health_lists_tools(mcp_session):
    async with mcp_session as session:
        tools = await session.list_tools()
        assert {t.name for t in tools.tools} >= {"vw_health", "vw_eval"}
```

The Python SDK exposes `create_connected_server_and_client_session` — wires `ClientSession` to `Server` via in-memory streams. TS SDK has `InMemoryTransport.create_linked_pair()` for the same.

### 6.3 MCP Inspector (level 3-4)

```bash
# UI mode (browser at :6274, proxy at :6277)
npx @modelcontextprotocol/inspector ./dist/mcp-vw.exe

# CLI mode (scriptable, for AI-coding-agent loops)
npx @modelcontextprotocol/inspector --cli ./dist/mcp-vw.exe --method tools/list
```

### 6.4 The "stdout is sacred" test

```python
async def test_no_garbage_on_stdout(mcp_vw_server):
    """Regression: a linked library printed a progress bar to stdout and broke MCP."""
    async with mcp_session(...) as session:
        await session.list_tools()
    assert mcp_vw_server.stdout == b"" or is_valid_jsonrpc_frame(mcp_vw_server.stdout.read())
```

#1 cause of "works for 30 seconds, then hangs" bugs in stdio MCP servers.

---

## 7. Three HTTP-wrapping MCP servers to study

### 7.1 `modelcontextprotocol/servers/src/fetch` — minimal example

- **Repo**: <https://github.com/modelcontextprotocol/servers/tree/main/src/fetch>
- **Language**: Python, **Tools**: 1 (`fetch`)
- **Why study**: simplest possible HTTP-wrapping server. Three install shapes (`uvx`, `docker`, `pip`) in README. Windows config block is the canonical `PYTHONIOENCODING=utf-8` workaround.

### 7.2 `github/github-mcp-server` — canonical HTTP wrapper

- **Repo**: <https://github.com/github/github-mcp-server>
- **Language**: Go, **Tools**: ~100 across 20+ toolsets
- **Why study**: most heavily-trafficked HTTP-wrapping server. Implements layered error categorization (rate-limit / secondary / abuse / status / GraphQL / raw). Middleware-based observability (tracks error types per tool call for telemetry).
- **Pattern to copy**: rate-limit-aware error formatter with `Retry-After` in the message.

### 7.3 `microsoft/playwright-mcp` — dual-mode pattern

- **Repo**: <https://github.com/microsoft/playwright-mcp>
- **Language**: TypeScript, **Tools**: ~21
- **Why study**: same code runs as stdio (Claude Desktop) AND HTTP/SSE (remote). `MODE` env var switches. Window-of-opportunity Windows workarounds documented in [issue #1540](https://github.com/microsoft/playwright-mcp/issues/1540).

### 7.4 Honorable mentions

- **`makenotion/notion-mcp-server`** — official Notion MCP, OpenAPI-driven, structured-error-in-content pattern, both stdio + HTTP modes
- **`sooperset/mcp-atlassian`** — best OAuth refresh-token + rotation handling in the wild ([`utils/oauth.py`](https://github.com/sooperset/mcp-atlassian/blob/main/src/mcp_atlassian/utils/oauth.py))
- **`blocksuser/mcp-linear`** — re-read-token-on-every-request pattern
- **`jgfoster/Jasper`** — GemStone MCP, direct precedent for Phase M (see [02-jasper-delta.md](./02-jasper-delta.md))

### 7.5 Shared patterns across all five

1. **stdio first, HTTP optional**. Stdio is the dominant 2026 pattern.
2. **Token via env var, file, or both**. Phase M uses file (matches bridge's `.token`).
3. **`npx -y <pkg>@<version>`** is the canonical invocation.
4. **Inspector debug section** in every README.

---

## 8. Windows gotchas cheat-sheet

| Gotcha | Symptom | Fix |
|---|---|---|
| **MSIX userData redirection** | Config in `%APPDATA%\Claude\` silently ignored | Write to `%LOCALAPPDATA%\Packages\Claude_<hash>\LocalCache\Roaming\Claude\` |
| **Edit Config opens wrong file** | User edits file A, app reads file B | Restart Claude Desktop after edit; verify in Developer settings |
| **`npx` is `npx.cmd`** | `spawn npx ENOENT` on Windows | Use absolute path to `node.exe + cli.js`, OR ship a `.exe` |
| **`cmd /c npx` breaks stdio pipes** | MCP server "disconnected" in Claude Code | Use `node cli.js` absolute path form, NOT `cmd /c` |
| **Path separator** | `\` in JSON breaks parsing | Use `\\` or forward slashes (`C:/...`) |
| **Env var inheritance** | Server doesn't see `PATH` | Claude Desktop passes parent env, but shell expansion (`$FOO`, `%FOO%`) does not work inside `args` |
| **Python stdout encoding** | `UnicodeDecodeError` on Windows console | Set `PYTHONIOENCODING=utf-8` in `env` |
| **nvm-windows + MCP** | Spawned Node can't resolve modules | Use absolute path to `node.exe`, not version-manager shim |
| **Backslash in JSON** | `Invalid JSON` | Always double-escape: `"C:\\Users\\you"` |
| **TS SDK v1.29.0 `windowsHide`** | Console window flicker on stdio | Use SDK v1.29.0+ (fix in PR #1640/#1772) |

---

## 9. Sources

- [Anthropic MCP docs — Build an MCP server](https://modelcontextprotocol.io/docs/develop/build-server)
- [Anthropic MCP docs — Connect to local MCP servers](https://modelcontextprotocol.io/docs/develop/connect-local-servers)
- [Anthropic Desktop Extensions engineering writeup](https://www.anthropic.com/engineering/desktop-extensions)
- [anthropics/mcpb MANIFEST.md](https://github.com/anthropics/mcpb/blob/main/MANIFEST.md)
- [Official modelcontextprotocol/servers catalog](https://github.com/modelcontextprotocol/servers)
- [MCP server registry](https://registry.modelcontextprotocol.io/)
- [github/github-mcp-server pkg/errors/error.go](https://github.com/github/github-mcp-server/blob/main/pkg/errors/error.go)
- [makenotion/notion-mcp-server](https://github.com/makenotion/notion-mcp-server)
- [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
- [sooperset/mcp-atlassian](https://github.com/sooperset/mcp-atlassian)
- [jgfoster/Jasper](https://github.com/jgfoster/Jasper)
- [PrefectHQ/fastmcp](https://github.com/PrefectHQ/fastmcp)
- [MSIX userData bug — claude-code#25579](https://github.com/anthropics/claude-code/issues/25579)
- [Edit Config bug — claude-code#26073](https://github.com/anthropics/claude-code/issues/26073)
- [.cmd shim bug — playwright-mcp#1540](https://github.com/microsoft/playwright-mcp/issues/1540)
- [Double-spawn bug — claude-desktop-debian#526](https://github.com/aaddrick/claude-desktop-debian/issues/526)
