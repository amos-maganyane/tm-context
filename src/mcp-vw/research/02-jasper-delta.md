---
title: Jasper → VW MCP Tool Delta
purpose: Step 3 deliverable for Phase M research. For each Jasper (GemStone MCP) tool, map to its VW Bridge equivalent + flag image-quirk constraints (esp. carry-forward #41 compile wedge + sources-stripped) + assess implementation difficulty. The output is the canonical "what we're inheriting vs what we have to redesign" map.
written: 2026-06-21 (session-21 Phase M research, Step 3)
inputs: librarian agent bg_0880ab49 (2m 55s, ses_114b1c89dffe57yzHeXfTHdHe4) verified against canonical jgfoster/Jasper repo + client/src/mcpTools.ts + mcp-server/src/tools.ts + docs/mcp-server.md; cross-referenced with knowledge/vw-image-api-contract.md (42 carry-forward constraints) + src/vw-bridge/VWBridge.st dispatch handlers
status: FINAL — Jasper catalog verified against source-of-truth in jgfoster/Jasper v1.6.6 (2026-06-18). 33 tools confirmed.
---

# Jasper → VW MCP Tool Delta

## Methodology

Jasper (the GemStone/S Smalltalk MCP server by James Foster, published under GemTalk Systems' `gemtalksystems` VS Code Marketplace namespace — repo: [`jgfoster/Jasper`](https://github.com/jgfoster/Jasper), v1.6.6 / 2026-06-18, MIT, TypeScript) is the proven reference. The user runs Jasper daily on this same Windows workstation for a separate GemStone project; the `/tm/AGENTS.md` house rules document its surface by name.

The librarian verified the catalog directly from Jasper's source-of-truth files (`client/src/mcpTools.ts` for IDE-hosted sessions + `mcp-server/src/tools.ts` for isolated Inspector sessions — both register the same 33 tools with the same bare names, no `gemstone_` prefix). My initial draft had 14 tools mapped from `/tm AGENTS.md` references; the librarian validation surfaced **19 additional tools** the draft missed, so this doc reflects the full 33.

For each Jasper tool, three questions:

1. **Does VW have a semantic equivalent?** (e.g. `commit` has NO VW analog — VW is single-process not transactional.)
2. **Can we satisfy it through an existing bridge endpoint?** (`compile_method` → `vw_eval` with `Cls compile:classified:`)
3. **What image quirks affect the mapping?** (carry-forward #41 — compile wedges on VWB.VWBridge — kills our ability to ship `vw_compile_method` for the bridge class itself.)

Difficulty score: **E** = trivial wrap, **M** = needs care (parameter validation, error mapping, scoping), **H** = blocked-by-constraint or requires new bridge endpoint, **N/A** = no VW equivalent.

## Delta Table — all 33 Jasper tools

### Category 1: Session control (4 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | `commit` | Persist uncommitted changes to GemStone repository | **N/A** — VW has no transactional persistence boundary. Changes mutate the live image; persistence is via `ObjectMemory snapshotAs:` (we do NOT expose this — image-mutating ops are an anti-pattern per AGENTS.md NO-MAS-modification rule) | — | VW image semantics fundamentally different | — | **N/A** | MCP tool description must surface: "VW MCP does not commit. Changes are live in-image and lost on `vwnt.exe` restart unless saved manually." |
| 2 | `abort` | Discard uncommitted GemStone changes | **N/A** — see above | — | — | — | **N/A** | Same as #1. |
| 3 | `status` | Report session info: user, stone, transaction state, uncommitted changes flag | **`vw_status`** (partial — returns version/buildSha/timestamp/parcelMode + image PID + bridge uptime) | `GET /version` + `GET /health` + maybe new `GET /bridge-status` | None | **Optional** new `/bridge-status` for richer info; MVP can use /version + /health | **E** | Already 80% shipped via Phase P P8. Could add VW-image-specific fields (image path, vwnt.exe PID, listener uptime) via a future `vw_bridge_status` if needed. |
| 4 | `refresh` | Refresh session's view of committed state (abort if no uncommitted changes) | **N/A** — VW has no GCI session view to refresh. Bridge always reads live image state. | — | — | — | **N/A** | Tool description: "VW always reads live image state — no refresh needed." |

### Category 2: Code execution (2 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 5 | `execute_code` | Evaluate Smalltalk expression / multi-statement body; return `printString` | **`vw_eval`** (cat E1 in 03-vw-specific-capabilities.md) | `POST /eval` | Bug #5 Stage 1 substring guard + Stage 2 per-process re-entry counter + carry-forward #41 (no compile-on-VWB.VWBridge) | No | **E** (cheapest tool — direct wrap) | Most-used tool in any Smalltalk MCP workflow. |
| 6 | `eval_python` | Compile + execute Python via Grail (GemStone-Python). Reports "Grail not detected" if not loaded. | **N/A** — VW has no Grail (Python-on-Smalltalk transpiler). MAS uses pure Smalltalk. | — | Domain mismatch | — | **N/A** | Could surface "tool not applicable" if Claude asks. |

### Category 3: Code modification — compile (3 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 7 | `compile_method` | Define/replace a method on a class | **`vw_eval` with `Cls compile: 'source' classified: 'cat'`** (instance-side) or `Cls class compile: ...` (class-side) | `POST /eval` | **CARRY-FORWARD #41 (session-20):** `compile:` on `VWB.VWBridge` class wedges the bridge listener even with Cursor>>showWhile: monkey-patch. UI announcement (`ChangeAdded`/`MethodAdded`) fan-out routes through a non-Cursor wedging path. | No (uses existing /eval) | **H** for bridge-class targets; **M** for MAS classes | **MUST** surface #41 as primary safety caveat. MCP-layer guard: refuse compile when target is `VWB.*` namespace (defense-in-depth). |
| 8 | `compile_class_definition` | Create/re-shape a class | **`vw_eval` with `subclass:instVarNames:classVars:...inDictionary:`** | `POST /eval` | Same #41 concern if target is `VWB.VWBridge` (anti-pattern per AGENTS.md NO-MAS-mod) | No | **M** (assuming target is not VWB.VWBridge) | Same #41 guard as #7. Bonus check: deny any namespace under `VWB.*`. |
| 9 | `compile_python` | Transpile Python to Smalltalk via Grail (returns generated source) | **N/A** — VW has no Grail. | — | Domain mismatch | — | **N/A** | Same as #6. |

### Category 4: Code modification — delete (2 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 10 | `delete_method` | Remove a method from a class | **`vw_eval` with `Cls removeSelector: #foo`** (defensive — naturally safe on absent per carry-forward #31) | `POST /eval` | #41 guard if target is `VWB.*` | No | **M** | Lower wedge risk than `compile:` (removeSelector doesn't fire as many announcements) but still treat with care. |
| 11 | `delete_class` | **DESTRUCTIVE:** remove class from a specific dictionary | **`vw_eval` with `Smalltalk.<NS> removeKey: #ClsName`** OR `<NS> at: #ClsName ifAbsent: [nil] ifPresent: [:c \| c removeFromSystem]` | `POST /eval` | #41 guard; same destructive prefix convention as Jasper | No | **M** | MUST keep Jasper's `DESTRUCTIVE:` prefix in tool description. Defense: refuse delete on `VWB.*` namespace classes. |

### Category 5: Code reading (5 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 12 | `get_method_source` | Return textual source of a method | **`vw_get_method_fingerprint`** (RENAMED — sources STRIPPED in storedev64.im. `CompiledMethod>>getSource` returns `nil`.) | `POST /eval` returning `{numArgs, numTemps, messages, literals, categorySymbol, isClassSide}` | **HARD CONSTRAINT:** `visual.sou` stripped. NO textual source recovery possible. | No (uses existing /eval) | **H** (irrecoverable) | Tool description MUST surface: "this image strips sources; returns behavioral metadata only, not source text." AI agents needing source must reason from `messages`/`literals` patterns. |
| 13 | `get_class_definition` | Get class definition (superclass, instance vars, etc.) | **`vw_get_class_definition`** — `vw_eval` with `Cls definition` (returns source-form class definition expression) | `POST /eval` | None | No | **E** | VW's `Class>>definition` returns the canonical 3.7 syntax `subclass:instVarNames:...inDictionary:` form. |
| 14 | `get_class_hierarchy` | Get superclass chain + direct subclasses | **`vw_get_class_hierarchy`** — `vw_eval` with `Cls allSuperclasses, (Cls subclasses)` | `POST /eval` | None | No | **E** | Returns tab-separated `dictName \t className \t kind` per entry (matching Jasper's shape). |
| 15 | `describe_class` | Combined: definition + comment + own methods grouped by category, both sides | **`vw_describe_class`** — wraps #13 + `Cls comment` + `Cls organization` walk | `POST /eval` | None | No | **M** (composite tool — saves round trips) | High-value tool per Jasper docs: "Prefer this over calling get_class_definition + list_methods separately." Worth shipping early in MVP. |
| 16 | `export_class_source` | Export class as Topaz file-in source (full definition + all methods) | **`vw_export_class`** — `vw_eval` walks all methods + emits as chunk-format file-in | `POST /eval` | Methods sources unavailable per #12 — must export as `messages`/`literals` fingerprint OR refuse | No | **H** (sources stripped limits utility) | Cannot produce true Topaz-equivalent export. MVP: omit OR ship as "fingerprint dump" with explicit warning. |

### Category 6: Code navigation (5 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 17 | `find_implementors` | List `Class>>selector` pairs that implement a given selector (max 500) | **`vw_find_implementors`** — `vw_eval` with `Smalltalk allClasses select: [:c \| c selectors includes: sel]` | `POST /eval` | Image has NO `SystemNavigation` per carry-forward §"APIs ABSENT". Manual walk over ~10k classes — needs SCOPE param for performance. | No (uses existing /eval) | **M** | MCP tool takes `selector: string`, optional `scope: ["Kernel", "Tools", "VWB", "MAS-business-classes"]`. Default scope is "all" with a warning that full walk takes ~30s. Cap results at 500 (matching Jasper). |
| 18 | `find_senders` | List `Class>>selector` pairs that send a given message (max 500) | **`vw_find_senders`** — `vw_eval` with manual `senders` walk per api-contract §"Sender scan" pattern | `POST /eval` | Same SystemNavigation gap as #17 | No | **M** | Same scoping concerns. Returns `[{className, selector, isClassSide}, …]`. Jasper has env-0 → env-1 fallback for GemStone-Python; VW doesn't have multi-env so simpler. |
| 19 | `find_references_to` | List methods that reference a named global (class, pool, shared variable) | **`vw_find_references_to`** — `vw_eval` with `literals includes:` walk + `ResolvedDeferredBinding` introspection | `POST /eval` | Same SystemNavigation gap. Plus: cross-namespace refs in chunk file-in are `ResolvedDeferredBinding` per carry-forward #15 — walk must check both bare-class literals AND deferred-binding literals. | No | **M** | Same scoping concerns. Return shape includes `refKind: "direct" \| "deferredBinding"`. |
| 20 | `search_method_source` | Search method source for a substring (max 500 matches, ignoreCase default true) | **N/A in textual form** — sources stripped per #12. **Closest equivalent: `vw_search_method_messages`** (search for selector substring across `m messages`) | `POST /eval` | Source search impossible; selector search is the best we can do | No | **H** (semantic mismatch) | MVP: ship a "search selectors that match substring" tool, with description acknowledging "the image strips sources; this tool searches method selector names + literal references instead." V2: could index `literals` for symbol search. |
| 21 | `list_methods` | List all methods of a class grouped by category | **`vw_list_methods`** — `vw_eval` with `Cls organization` walk | `POST /eval` | None | No | **E** | Returns tab-separated `side \t category \t selector` per method (matching Jasper). |

### Category 7: Schema / dictionary browsing (4 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 22 | `list_dictionaries` | List all SymbolDictionaries in current user's symbolList | **`vw_list_namespaces`** (RENAMED — VW uses NAMESPACES not SymbolDictionaries; semantic mapping per AGENTS.md §"GemStone Smalltalk specifics") | `POST /eval` with `Smalltalk allNameSpaces collect: [:ns \| ns name asString]` | 312 namespaces in this image (per api-contract). | No | **E** | Tool description must clarify VW semantics. Could ship a future bridge `GET /namespaces` endpoint to avoid /eval round-trip. |
| 23 | `list_classes` | List all classes in a given symbol dictionary | **`vw_list_namespace_classes`** — `vw_eval` with `(Smalltalk at: #Ns) keys select: [:k \| (ns at: k) isKindOf: Class]` | `POST /eval` | Per-namespace size varies wildly (Smalltalk ~hundreds; Kernel 100+; some MAS namespaces dozens). | No | **E** | Returns one class name per line. |
| 24 | `list_dictionary_entries` | List ALL entries in a dictionary (classes + globals like pools, shared variables); tab-separated `kind \t category \t name` | **`vw_list_namespace_entries`** — `vw_eval` with `(Smalltalk at: #Ns) keys asSortedCollection collect: [:k \| {kind, category, k}]` | `POST /eval` | None | No | **E** | Same rename as #22. Richer than `list_namespace_classes` (#23). |
| 25 | `list_all_classes` | Enumerate every class in user's symbolList + its dictionary (bulk schema discovery) | **`vw_list_all_classes`** — `vw_eval` with `Smalltalk allNameSpaces inject: ...` (walk + flatten) | `POST /eval` | "May be large on big schemas" — this image has 312 namespaces; full walk could return 5000+ classes | No | **M** (size cap needed) | MCP tool should accept optional `maxResults: int` (default 500). Tool description warns about size. |

### Category 8: Dictionary management (2 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 26 | `add_dictionary` | Create new SymbolDictionary + append to user's symbolList (NOT committed automatically) | **`vw_add_namespace`** (RENAMED — VW uses namespaces) — `vw_eval` with `Smalltalk addNamespace: #NewName` or equivalent | `POST /eval` | VW namespace creation is more involved than GemStone dict creation (need to declare parent + visibility) | No | **M** | Probe API surface before exposing. Could refuse if not 100% sure. |
| 27 | `remove_dictionary` | **DESTRUCTIVE:** remove dictionary from user's symbolList | **`vw_remove_namespace`** — `vw_eval` with `Smalltalk removeKey: #NameSpace ifAbsent: [nil]` | `POST /eval` | #41 guard if target is `VWB` namespace (would destroy the bridge!). MUST refuse `VWB`. | No | **M** with hard-coded `VWB` refusal | DESTRUCTIVE prefix in description. Hard refuse on `Core`, `Kernel`, `Tools`, `VWB`, MAS root namespaces. |

### Category 9: Class metadata (1 Jasper tool)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 28 | `set_class_comment` | Set class comment (replaces existing) — NOT committed automatically | **`vw_set_class_comment`** — `vw_eval` with `Cls comment: 'text'` (class-side mutator) | `POST /eval` | Same #41 concern if Cls is VWB.VWBridge | No | **M** (with #41 guard) | Same defense pattern as #7-8. |

### Category 10: SUnit testing (5 Jasper tools)

| # | Jasper tool | Jasper purpose | VW equivalent | Bridge route | Constraints | New endpoint? | Difficulty | Notes |
|---|---|---|---|---|---|---|---|---|
| 29 | `list_test_classes` | Discover every TestCase subclass in user's symbolList (tab-separated `dictName \t className`) | **`vw_list_test_classes`** — `vw_eval` with `TestCase allSubclasses` (but BEWARE carry-forward #16 — MAS-customized `TestCase>>testClasses` walks GemStoneClasses) | `POST /eval` | Use `allSubclasses` (safe) NOT `testClasses` (MAS-customized, walks thousands) | No | **M** | Tool must use the safe enumeration path. Returns ns + className. |
| 30 | `list_failing_tests` | Run SUnit + return only failed/errored results (with class+method+exception text) | **`vw_list_failing_tests`** — `vw_eval` direct-invoke gate pattern per carry-forward #20 | `POST /eval` | **CARRY-FORWARD #16/#20:** must NEVER use `cls suite run` (wedge 10-15min). Must use direct-invoke per-selector via `on: Core.Exception do:` wrapper. | No | **M** | The MCP tool encapsulates the canonical direct-invoke gate from AGENTS.md §"Direct-invoke gate pattern". AI never specifies "run X.suite" — tool ALWAYS uses safe pattern internally. Returns same shape as Jasper: `status \t className \t selector \t message`. |
| 31 | `run_test_class` | Run all SUnit test methods in a class — per-method pass/fail/error | **`vw_run_test_class`** — same direct-invoke pattern as #30, scoped to one class | `POST /eval` | Same #16/#20 | No | **M** | Per-method `PASSED/FAILED/ERROR: ClassName >> selector\n  <message>`. |
| 32 | `run_test_method` | Run a single SUnit test method | **`vw_run_test_method`** — direct-invoke for one `tc perform: aSelector` | `POST /eval` | Same #16/#20 | No | **M** | `PASSED/FAILED/ERROR: <msg> (<durationMs>ms)`. |
| 33 | `describe_test_failure` | Re-run a failed test in isolation; return structured details (exception class, errorNumber, messageText, MNU receiver+selector, stack) | **`vw_describe_test_failure`** — same direct-invoke wrapper as #30-32, with structured exception capture via `ex class`, `ex description`, `ex receiver`, `ex selector` | `POST /eval` | Same #16/#20. Stack walk requires careful exception-handler design. | No | **M** | Better as a separate tool (matches Jasper). Useful when AI needs to dig deeper after #30 reports a failure. |

---

## Tool count summary (Jasper-equivalent surface)

| Category | Count | Tools | VW status |
|---|---:|---|---|
| Session control | 4 | `commit`, `abort`, `status`, `refresh` | 2 N/A (no transactions); 1 ships as `vw_status`; 1 N/A (no GCI view) |
| Code execution | 2 | `execute_code`, `eval_python` | 1 ships as `vw_eval`; 1 N/A (no Grail) |
| Code modification (compile) | 3 | `compile_method`, `compile_class_definition`, `compile_python` | 2 ship with #41 guard; 1 N/A (no Grail) |
| Code modification (delete) | 2 | `delete_method`, `delete_class` | both ship with #41 + namespace-refusal guards |
| Code reading | 5 | `get_method_source`, `get_class_definition`, `get_class_hierarchy`, `describe_class`, `export_class_source` | 4 ship; 1 (`get_method_source`) ships as fingerprint (sources stripped); 1 (`export_class_source`) limited utility per #12 |
| Code navigation | 5 | `find_implementors`, `find_senders`, `find_references_to`, `search_method_source`, `list_methods` | 4 ship; 1 (`search_method_source`) ships in degraded form (selector search instead of textual source search) |
| Schema browsing | 4 | `list_dictionaries`, `list_classes`, `list_dictionary_entries`, `list_all_classes` | all 4 ship (renamed: `*_dictionary` → `*_namespace`) |
| Dictionary management | 2 | `add_dictionary`, `remove_dictionary` | both ship (renamed); `remove` has hard refusal on `Core`/`Kernel`/`Tools`/`VWB` |
| Class metadata | 1 | `set_class_comment` | ships with #41 guard |
| SUnit testing | 5 | `list_test_classes`, `list_failing_tests`, `run_test_class`, `run_test_method`, `describe_test_failure` | all 5 ship using direct-invoke gate pattern (#16/#20) |
| **TOTAL Jasper tools** | **33** | | |
| **N/A in VW** | **5** | `commit`, `abort`, `refresh`, `eval_python`, `compile_python` | semantic / domain mismatch |
| **Ships as-is or near-as-is** | **18** | | direct or near-direct mapping |
| **Ships with constraint guards** | **8** | (`compile_method`, `compile_class_definition`, `delete_method`, `delete_class`, `set_class_comment`, `remove_dictionary`, `list_failing_tests`-family) | #41 + namespace-refusal + #16/#20 SUnit guards |
| **Ships in degraded form** | **2** | (`get_method_source` → fingerprint, `search_method_source` → selector search) | sources stripped |
| **All map onto existing `POST /eval`** | **28** | | NO new bridge endpoint needed for any Jasper-equivalent. |

Plus the 12 VW-specific tools from [03-vw-specific-capabilities.md](./03-vw-specific-capabilities.md) (UI inspection + driving + screenshot + wait + version) = **40 distinct MCP tools** for the full Phase M scope.

## Confirms strategic assessment

> "Phase M doesn't need to solve any bridge-side problems" (PHASE-PROGRESS.md s20 EOD per-phase table).

Verified: zero new bridge endpoints required for the Jasper-equivalent surface. All 28 active tools (the non-N/A ones) wrap `POST /eval`. **Phase M is pure MCP-server implementation work.**

## Bonus: Jasper's architectural patterns worth borrowing

From the librarian's deep-dive into Jasper's source + architecture doc ([`docs/mcp-server.md`](https://github.com/jgfoster/Jasper/blob/main/docs/mcp-server.md)):

1. **No `gemstone_` prefix on wire.** Jasper's tools are named `commit`, `compile_method` etc. (bare). The MCP server itself is named `gemstone`, which is how Claude groups them in UI. We should follow this pattern: server name `vw-bridge`, tool names like `eval`, `compile_method`, `list_windows`. User's mental model of "`gemstone_*`" is shorthand only.

2. **`DESTRUCTIVE:` prefix convention** on tool descriptions for `delete_class`, `remove_dictionary`. Adopt this verbatim for `vw_delete_class`, `vw_delete_method`, `vw_remove_namespace`.

3. **`NOT committed automatically` notice** in every write-tool description. Doesn't apply to VW (no commit), but the spirit applies: tool descriptions for mutating tools must surface the persistence semantics ("Changes are live in-image and survive until `vwnt.exe` exits").

4. **Defensive `withMcpErrorMap` Zod wrapper** for actionable error messages. The TS SDK accepts a custom error map per-schema; Jasper uses it to turn validation failures into "you passed X, but field Y expects Z" messages. Adopt for Phase M.

5. **Auto-refresh on read tools** — Jasper calls `refreshIfClean` before `status`, `list_failing_tests`, etc. so the read sees latest committed state from other processes. VW analog: re-check `/health` + token mtime before any tool call to detect bridge restart mid-session.

6. **Dictionary ambiguity is explicit failure**, not silent guess. When a class name exists in 2 dictionaries, Jasper's `run_test_class` etc. refuse with a "which one?" message + candidate list. Adopt: when a VW class name resolves in multiple namespaces, refuse with candidates.

7. **Three-process architecture**: VS Code extension host owns session + tools; thin per-client stdio proxy = byte pipe; MCP client. **Phase M can skip this** because we don't have a VS Code extension — our "extension host" equivalent is just the Node process running the MCP server, talking to the bridge over HTTP. No proxy needed for Phase M MVP.

8. **Auto-registration via direct file writes** to both `~/.claude.json` (Claude Code) AND `claude_desktop_config.json` (Claude Desktop), with idempotency + stale-entry cleanup. Adopt for Phase M installer — see best-practices doc §7 for the MSIX-aware variant.

9. **Always-on Claude Code auto-registration; opt-out Claude Desktop**. Jasper does Claude Code unconditionally + Claude Desktop gated by `gemstone.mcp.registerWithClaudeDesktop: true` (default true). Same pattern fits Phase M.
