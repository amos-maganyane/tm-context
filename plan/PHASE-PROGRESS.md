---
title: Phase Progress Tracker
purpose: Live cross-session view of project progress. Updated at each session EOD when a deliverable shifts state. Complements the per-session HANDOFF docs (point-in-time) and STRATEGIC-ASSESSMENT (framing doc, rewritten only at phase boundaries).
last_updated: 2026-06-22 (session-24 EOD)
---

# Phase Progress Tracker

This file is the **canonical cross-session view** of where each phase stands. Open it first when you want "where are we right now?" without reading through 19 HANDOFFs.

- **Per-session detail**: see `knowledge/HANDOFF-2026-06-21-session{N}.md`
- **Strategic framing + Phase P deliverable rationale**: see `plan/STRATEGIC-ASSESSMENT-2026-06-21.md`
- **The seven quality disciplines that gate every ship**: see `plan/ROADMAP-QUALITY-FIRST.md`

---

## Quick status (session-24 EOD)

- **Critical-path bottleneck**: NONE. Phase M PR P0 trio SHIPPED + pushed this session — Bug 1 (vw_create_class canonical `defineClass:` 8-kw form), Bug 6 (DataSet widget as 14th component type), Bug 5 (7 happy-path smoke tests covering all 4 codegen tools). All defects from the s23 first real-world benchmark are now fixed in production-ready form with regression coverage.
- **Most recent ship**: Phase M PR P0 trio in [`src/mcp-vw/`](../src/mcp-vw/) — 3 commits (`67ec8d2` + `3267fcc` + `d83ff09`), 10 files +892/-63 lines. Vitest: 295 → **305 pass** (incl. 11 rewritten + 15 new tests). Live smoke (`scripts/smoke-test.ts`): 16/16 → **23/23 ALL GREEN** against `storedev64.im` (16 original guards + 7 new happy-path codegen tests covering `vw_create_class` create + idempotent re-create + delete, `vw_compile_method` compile + behavior verify + invalid syntax reject, `vw_create_application_model` end-to-end with Label + ActionButton, `vw_create_window_spec` with 2-col DataSet). Bug 1 cascade fixed 5 broken tests across `applicationModel.test.ts` + `dialog.test.ts` + `e2e.test.ts` + 2 user-facing tool description strings. Bug 6 added DataSet to `Component` union + `COMPONENT_SPEC_CLASS` map + Zod schema + `emitDataSetColumnLiteral` helper + handler validation (probe-driven schema decisions: dropped `showHGrid`/`showVGrid` since they don't exist on this image's `DataSetSpec`, added `menu` as bonus on `DataSetColumnSpec`). Each smoke test cleans up via `vw_delete_class { confirm: true }`; image post-run: 0 leftover `SmokeTest*` classes. Server v0.3.0 unchanged.
- **Session-25 first action options**: (1) Restart opencode (REQUIRED — running mcp-vw is pre-Bug-6 build, new DataSet tool descriptor not surfaced); (2) P1 work: Bug 7 paren-balance pre-check in `vw_compile_method` + `vw_create_window_spec` (~1h, hit twice in s24 during Bug 6 probes); (3) P1 work: write `src/mcp-vw/research/widget-cookbook.md` with one worked example per of 14 widget types (incl. s24 lesson #5 about DataSet adapter chain requirement); (4) Re-run s23 benchmark using ONLY typed tools (no `vw_eval` escape hatch) — project 3 tool calls (`vw_create_application_model` → `vw_open_application` → fallback PowerShell screenshot); (5) Phase E SDK kickoff (Playwright SDK + 3 tests; ~1-2 weeks, parallel with P1).
- **Phase P overall**: 100% COMPLETE (unchanged from s20).
- **Phase M overall**: **~98%** (was ~95%; PR P0 trio fixed all critical real-world bugs + added regression coverage; remaining ~2% = P1 quality work + Bug 2 + Bug 4 + cookbook).
- **Bridge version**: v0.10.0 (unchanged from s20). mcp-vw server v0.3.0.
- **Token at EOD**: `3959514441929-808187` (unchanged from s20 — zero `vwnt.exe` restarts s21+s22+s23+s24).
- **vwnt.exe**: PID 7588 continuous from s20 cycle 5 (started 6/21/2026 17:07:17). Zero kill+restart cycles s24 — all work via npm/vitest + dist rebuilds + the running bridge.

---

## Project goals progress (4 from STRATEGIC-ASSESSMENT)

| # | Goal | Baseline (session-7) | session-13 | session-17 EOD | session-18 EOD | session-19 EOD | session-20 EOD | session-21 EOD | session-22 EOD | Δ since s21 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Bridge / eval server | ~70% | ~90% | ~90% | ~90% | ~90% | ~92% | ~92% | **~92%** (unchanged — no bridge changes s22; one new image quirk discovered + documented as carry-forward #43) | 0% |
| 2 | Production-grade packaging (Phase P) | ~5% | ~25% | ~60% | ~80% | ~90% | **100% COMPLETE** | **100% COMPLETE** | **100% COMPLETE** (unchanged) | 0% |
| 3 | Test framework (Playwright) | ~0% | ~0% | ~0% | ~0% | ~0% | ~0% | ~0% | **~0%** (still 0 SDK code; UNBLOCKED) | 0% |
| 4 | MCP server | 0% built | 0% | ~5% | ~5% | ~5% | ~5% | ~25% | **~95%** (Phase M MVP + V2 + V3 SHIPPED end-to-end; 48 tools registered + 290 tests + 16/16 live smoke against actual bridge; mcp-vw server v0.3.0; remaining ~5% = post-ship hardening from real-usage validation) | **+70%** |

Goal 4 (MCP) **dominant s22 work** — Phase M from ~25% → **~95%**. Shipped the full 48-tool architecture.md v2 surface end-to-end:
- **MVP (18 tools)**: liveness (vw_health/version/status), eval with Bug #5 + #41 guards, schema + reading + navigation + parcel + ui_inspect + ui_drive read/write surface, NATIVE-TYPED vw_create_class.
- **V2 (+13 tools)**: vw_create_window_spec (probe-3 canonical literal-array emitter), vw_compile_method + vw_define_action + vw_define_aspect, vw_create_application_model HEAVYWEIGHT scaffolder, vw_create_dialog, vw_describe_class/find_implementors/find_references_to/get_widget_value extensions, SUnit gate trio (run_test_class/method + list_failing_tests) via direct-invoke pattern #20.
- **V3 (+17 tools)**: schema expansion (list_namespace_classes/list_all_classes/list_test_classes), introspection (get_method_fingerprint/class_hierarchy/export_class/search_method_messages), destructive (compile_class_definition/delete_method/delete_class/set_class_comment) all with #41 guard, dialogs (list_dialogs/respond_dialog), wait + screenshot (with proper MCP ImageContent + BridgeClient.getBinary), describe_test_failure, **vw_create_parcel** heavyweight (Cursor monkey-patch + canonical parcelOutOn: + Notification-resume #38).
- **Carry-forward #43 discovered**: bridge JSON-encoder collapses LF/CR/TAB → space in responses. Workaround: `;` + `|` separators centralized in `src/smalltalk.ts`. All list-returning tools use them.
- **Production wiring**: index.ts stdio entry + OwnerLock + graceful shutdown; `.mcpb` manifest; MSIX-aware PowerShell installer; ~290-line README; subprocess smoke test driving real bridge end-to-end (16 steps green).

---

## Per-phase progress

| Phase | % done | Status | Shipped in / current blocker |
|---|---:|---|---|
| **A — Stabilize** | 100% | ✅ DONE | sessions 7-9 (bugs #1, #2, #4, #5, #6 + NDJSON logging) |
| **B — /wait endpoint** | 100% | ✅ DONE | v0.9.0 session-9 + B4 10x-verified session-10 |
| **F — /screenshot** | 100% | ✅ DONE | v0.9.1 session-13 |
| C — API freeze + OpenAPI | ~25% | ⚙️ partially subsumed | P7 (INSTALL.md) + P8 (`/version`) cover the core docs+version-pinning need; standalone OpenAPI deferred to post-P |
| D — Auto-start | 100% | ✅ SUBSUMED by P5 | Designed session-17 via Oracle; SHIPPED session-18 (Start-VWBridge.ps1+bat) |
| **P — Packaging** | **100%** | ✅ **COMPLETE** | P1+P2(S1+S2+S3+QG)+P3+P4+P5+P6+P7+P8 SHIPPED |
| **M — MCP for VW dev** | **~98%** | ✅ **SHIPPED + battle-tested** | Full architecture.md v2 surface implemented in [`src/mcp-vw/`](../src/mcp-vw/): 48 tools (18 MVP + 13 V2 + 17 V3) + **DataSet 14th component type (s24 Bug 6)**; **305 vitest tests** (was 290; +15 net from Bug 1 rewrites + Bug 6 additions); build + tsc green; **23/23 live smoke** against actual VW bridge (was 16/16; +7 happy-path codegen tests from s24 Bug 5 covering vw_create_class, vw_compile_method, vw_create_application_model, vw_create_window_spec with DataSet). Production wiring unchanged: `.mcpb` manifest + PowerShell MSIX-aware installer + ~290-line README + subprocess smoke test. Server v0.3.0. **s24 PR P0 trio shipped + pushed: Bug 1 (vw_create_class defineClass: 8-kw — 67ec8d2), Bug 6 (DataSet widget — 3267fcc), Bug 5 (7 happy-path smoke tests — d83ff09). Remaining ~2% = P1 work (Bug 7 paren-balance pre-check, widget cookbook, re-run s23 benchmark to validate fixes) + Bug 2 + Bug 4** |
| E — Playwright SDK + 3 tests | 0% | ⚙️ unblocked (next priority option, parallel with M) | Bridge fully deployable in 2 modes + /version for version-pinning; can start SDK any time |
| G — CI pipeline | 0% | ⏳ gated on E | — |
| H — Scale (all critical workflows) | 0% | ⏳ gated on G | — |
| I — Test Mentor migration | 0% | ⏳ gated on G | 18 MB `testCases.gs` to port |

---

## Phase P deliverable breakdown (✅ COMPLETE)

| # | Deliverable | Status | Commit / blocker |
|---|---|---|---|
| P1 | env-var externalization (`VW_BRIDGE_HOME` + 3 derived paths) | ✅ SHIPPED session-14 | `d4924c5` |
| P2 Stage 1 | package category split (Core/Patches/Tests) via `*PackageName` prefix | ✅ SHIPPED session-14 | `3b72287` |
| P2 Stage 2 | namespace migration `Smalltalk.VWB.VWBridge` (was top-level Smalltalk.VWBridge) | ✅ SHIPPED session-14 | `d86274b` (with latent binding bug fixed session-15 `cac044f`) |
| P2 Stage 3 | `load.st` + `unload.st` external orchestrators + VWBridge.st auto-start chunk removal | ✅ SHIPPED session-17 | `cdf3876` |
| P2 quality gate | full SUnit suite GREEN + load/unload idempotency proven | ✅ SATISFIED session-16+17 | 48/48 unblocked via /eval direct-invoke; idempotency via 2 in-place /eval cycles |
| P3 | PowerShell helper relocation under `$VW_BRIDGE_HOME/scripts/` | ✅ SHIPPED session-14 | `d4924c5` (same commit as P1) |
| P4 | `load.st` + `unload.st` pair | ✅ MERGED with P2 Stage 3 ship | `cdf3876` (Stage 3 commit) |
| P5 | auto-start trigger mechanism | ✅ SHIPPED session-18 (Start-VWBridge.ps1 + Start-VWBridge.bat via `vwnt.exe -filein`) | 5-cycle quality gate GREEN (mean 9.11s/cycle) |
| P6 | build `.pcl` parcel via `Kernel.Parcel loadParcelFrom: aFilename` | ✅ SHIPPED session-19 (VWBridge.pcl 52KB + VWBridge.pst 128KB + parcel-start.st + Start-VWBridge.ps1 -Mode FileIn\|Parcel) | 5-cycle parcel-mode gate GREEN (mean 8.43s); built via Cursor>>showWhile: monkey-patch + canonical parcelOutOn: |
| **P7** | `INSTALL.md` (env-var setup + both install paths + smoke test + troubleshooting) | ✅ **SHIPPED** session-20 | Repo-root INSTALL.md covers FileIn + Parcel paths for onboarding-developer with zero prior context |
| **P8** | `GET /version` endpoint (parcel version + build timestamp + commit SHA) | ✅ **SHIPPED** session-20 | Endpoint auth-exempt, 4-field JSON (version + buildCommitSha + buildTimestamp + parcelMode); bridge bumped v0.9.1 → v0.10.0; `scripts/Build-Parcel.ps1` reproducible rebuild; new VWBridge.pcl 53KB + VWBridge.pst 131KB; 5-cycle Parcel-mode gate GREEN (mean 9.16s) |

**Design note on P8 build metadata**: attempted to bake commitSha + timestamp as compiled-literal class-side methods on VWB.VWBridge before `addEntiretyOfClass:`, but `compile:` on VWB.VWBridge wedges the bridge listener even with the Cursor>>showWhile: monkey-patch installed (new carry-forward #41). Shipped instead with class-side accessors + setters that `Start-VWBridge.ps1` /eval-injects at every cold-start in both modes — `/version` reflects "what is currently running" rather than "when was the parcel built". For parcel-build provenance, use `git log parcels/VWBridge.pcl`. Memory entities: `Phase-P-P7-P8-shipped`, `compile-on-VWB-VWBridge-wedge`.

---

## Distance to north star ("Test Mentor retired")

Critical path:

```
Phase P (100% COMPLETE)
    │
    ├──► Phase M (MCP for VW dev) ─┐
    │    (~5% done; UNBLOCKED)      │
    │                               ├──► Onboarding developer can use AI on VW
    │                               │    (first user-visible milestone)
    └──► Phase E (Playwright SDK) ──┘
         (0% done; UNBLOCKED)
              │
              ▼
         Phase G (CI pipeline; gated on P + E)
              │
              ▼
         Phase H (Scale — all critical workflows have Playwright equivalents)
              +
         Phase I (Test Mentor migration — port 18 MB testCases.gs)
              │
              ▼
         Test Mentor retired (north star)
```

### Rough effort remaining

| Phase | Remaining effort | Notes |
|---|---|---|
| P | **0** | ✅ COMPLETE |
| M (MCP MVP — 3-tool surface) | ~2-3 days | 3-layer architecture per Jasper reference. UNBLOCKED. |
| E (SDK + 3 Playwright tests) | ~1-2 weeks | UNBLOCKED. Parallel with M. /version endpoint enables SDK version-pinning. |
| G (CI pipeline — first green run) | ~1 week | After E ships. |
| H (Scale all critical workflows) | weeks-to-months | Throughput phase; pace = SDK + CI velocity. |
| I (Test Mentor migration) | open-ended | 18 MB `testCases.gs` to port; depends on accepted scope. |

### Near-term milestones

| Milestone | Earliest possible | Gating |
|---|---|---|
| Onboarding developer can self-install + use AI on VW | **~2-3 days** | Phase M MVP (Phase P done — install + docs + /version all in place) |
| First green Playwright test in CI | **~3-4 weeks** | E + G |
| Test Mentor decommissioned | open-ended | E + G + H + I |

---

## Per-session impact log

| Session | Date | Phase progress shifts | Bridge ver | Commits | Notes |
|---|---|---|---|---|---|
| 7 | 2026-06-20 | Initial assessment; Bug #2 FIXED | v0.8.12 | uncommitted | pre-A |
| 8 | 2026-06-20 | NDJSON logging shipped; Bug #6 FIXED | v0.8.13 | several | Wave 1 closed |
| 9 | 2026-06-20 | Phase A complete; Phase B (/wait) shipped | v0.9.0 | several | A + B done |
| 10 | 2026-06-20 | B4 real-usage 10x verified (PartySearch surname workflow); F1 Oracle design consult | v0.9.0 | — | B quality gate SATISFIED |
| 11 | 2026-06-20 | Q1 RESOLVED (no PNG writer in image); Oracle F3 verdict Path B (PowerShell subprocess); Phase F3 TDD scaffold landed | v0.9.0 | — | F design phase |
| 12 | 2026-06-20 | Phase F3 Steps 10-16 GREEN; Step 17 BLOCKED on OS.ExternalProcess>>wait bug | v0.9.0 | — | F implementation phase |
| 13 | 2026-06-21 | Phase F shipped (/screenshot); Phase P framed in STRATEGIC-ASSESSMENT | **v0.9.1** | several | A + B + F done; P scoped |
| 14 | 2026-06-21 | Phase P P1 + P3 SHIPPED; P2 Stage 1 + Stage 2 SHIPPED | v0.9.1 | 7 local-only | Partial P (path externalization + namespace migration) |
| 15 | 2026-06-21 | Pushed session-14's 7 commits; latent binding bug FIXED; direct-invoke gate pattern PROVEN | v0.9.1 | 8 pushed + 3 local | P2 verification began |
| 16 | 2026-06-21 | Systematic gate sweep COMPLETE (48/48 unblocked GREEN); 2 latent bug fixes; 3 new techniques; 5 new carry-forward (24-28); P2 quality gate SATISFIED | v0.9.1 | 10 pushed | P2 quality gate done |
| **17** | 2026-06-21 | Phase P P2 Stage 3 SHIPPED (load.st + unload.st + auto-start chunk removal); quality gate idempotency PROVEN via 2 in-place /eval cycles; P5 Oracle consult COMPLETE (Path 4 wrapper design); Jasper mining synthesized; 3 new carry-forward (29-31) | v0.9.1 | 4 pushed | P at ~60%, P5 BLOCKED on session-18 -filein probe |
| **18** | 2026-06-21 | Phase P P5 SHIPPED (Start-VWBridge.ps1 + Start-VWBridge.bat via `vwnt.exe -filein` switch); 6 probes verified -filein syntax (AppDevGuide.pdf p36) + ImageConfigurationSystem allow-flag state + top-level `^` chunk semantics; 5-cycle quality gate GREEN (mean 9.11s/cycle); 3 new carry-forward (32-34); AGENTS.md cold-start path replaced | v0.9.1 | 7 pushed | P at ~80%, P6 next on critical path |
| **19** | 2026-06-21 | **Phase P P6 SHIPPED (VWBridge.pcl 52KB binary parcel + VWBridge.pst companion + parcel-start.st + Start-VWBridge.ps1 -Mode FileIn\|Parcel); Cursor>>showWhile: monkey-patch + canonical parcelOutOn: pattern PROVEN; 24 probes + Oracle consult + research (pypdf VW docs + websearch); 5-cycle parcel-mode quality gate GREEN (mean 8.43s/cycle, faster than P5); 6 new carry-forward (35-40); 9 bridge recoveries during empirical investigation; VWBridge-Tests.pcl DEFERRED (wedged on 3-class build, not on critical path)** | **v0.9.1** | **5 pushed** | **P at ~90%, P7 (INSTALL.md) next** |
| **20** | 2026-06-21 | **Phase P P7+P8 SHIPPED — Phase P COMPLETE. P7: INSTALL.md at repo root (~400 lines, both FileIn + Parcel paths + troubleshooting + uninstall). P8: GET /version endpoint (auth-exempt, 4-field JSON returning version + buildCommitSha + buildTimestamp + parcelMode); bridge bumped v0.9.1 → v0.10.0; class-side version + buildCommitSha/buildTimestamp/parcelMode accessors+setters; Start-VWBridge.ps1 /eval-injects all 3 build-info fields at cold-start in both modes (Get-GitHeadSha pure-PS helper reads .git/HEAD directly, no git CLI dependency); scripts/Build-Parcel.ps1 reproducible rebuild via Cursor monkey-patch + verbatim s19 parcel pattern; new VWBridge.pcl 53KB + VWBridge.pst 131KB ship-built; 5-cycle Parcel-mode quality gate GREEN (mean 9.16s); 2 new carry-forward (41-42 — compile-on-VWB.VWBridge wedge + ensure-block no-binding); 5 bridge recoveries investigating bake-metadata approach (abandoned for simpler design)** | **v0.10.0** | **TBD pushed** | **P at 100% COMPLETE; M or E next** |
| **21** | 2026-06-21 | **Phase M v2 research+design LOCKED (implementation deferred to s22 per user direction). Pushed s20's 6 commits to origin/main (b9e5357..ff2ddb1). 5 research docs at src/mcp-vw/research/ (01-mcp-sdk.md SDK pick TypeScript ^1.29.0; 02-jasper-delta.md 33-tool Jasper-to-VW delta; 03-vw-specific-capabilities.md 12 VW-only MCP tools; 04-mcp-best-practices.md Claude Desktop MSIX-aware integration; 05-vw-native-development.md VW idioms) + design/architecture.md v2 (656 lines, 48 tools: MVP 18 / V2 +13 / V3+ +17, with 8 NATIVE UI-construction tools addressing user critique). 5 image probes (probe-1 class inventory, probe-2 namespace+WindowSpec API, probe-3 inheritance chains + canonical literal format DISCOVERY, POC-1+2+3 validating 1296 ApplicationModel-with-windowSpec UI classes reachable via /eval). 6 wave-2 librarians fired (3 wave-1 successful; 3 wave-2 first fire lost to model-availability, re-fired successfully — 2 returned with content, third also returned at 22m). 2 librarian raw outputs preserved as _librarian-*-raw.md (78KB + 67KB) for s22 reference. Design v1 REJECTED at first sign-off (too eval-centric); v2 user-APPROVED after POC empirical proof. Memory MCP: +5 entities (Session-21, Phase-M-v1-shipped, Phase-M-v2-in-progress, VW-spec-literal-format-pattern, wave-2-librarian-model-failure-and-recovery) + 10 relations + ~40 observations. Zero bridge changes; zero new carry-forward constraints. No vwnt.exe restart this session.** | **v0.10.0 (unchanged)** | **4 committed (not pushed)** | **Phase M ~25%; MVP code defer to s22** |
| **22** | 2026-06-21 | **Phase M MVP + V2 + V3+ SHIPPED end-to-end this session. Full 48-tool architecture.md v2 surface implemented in src/mcp-vw/ TypeScript + @modelcontextprotocol/sdk ^1.29.0: MVP 18 tools (liveness + eval with Bug #5 + #41 guards + schema + reading + navigation + parcel + ui_inspect + ui_drive + NATIVE-TYPED vw_create_class) + V2 13 tools (windowSpec emitter from probe-3 design unlock + applicationModel HEAVYWEIGHT scaffolder + dialog + compile_method/define_action/define_aspect + SUnit gate trio + composite read extensions + ui_get_widget_value) + V3 17 tools (introspection fingerprint/hierarchy/export/search + destructive with #41 guard + dialogs + wait + screenshot with ImageContent + describe_test_failure + schema expansion + vw_create_parcel HEAVYWEIGHT with Cursor monkey-patch). 290 vitest tests across 19 test files. npm run build clean; tsc --noEmit clean. Live smoke (subprocess MCP client driving real bridge): 16/16 PASS against storedev64.im — tools/list returns 48; vw_health/version/eval/status/list_namespaces/get_class_definition/describe_class/find_implementors/compile_method-#41-guard/list_loaded_parcels/create_class-#41-guard/get_class_hierarchy/list_test_classes/delete_class-confirm-guard all green end-to-end. Production wiring: index.ts stdio entry + McpServer + StdioServerTransport + OwnerLock single-owner (Windows EPERM-race retry) + graceful shutdown; manifest.json .mcpb Desktop Extension; scripts/install-mcp-vw.ps1 MSIX-aware installer; scripts/Build-Mcpb.ps1 bundler; ~290-line README. BridgeClient.getBinary added for vw_screenshot returning MCP ImageContent. Carry-forward #43 DISCOVERED + documented (bridge JSON whitespace collapse) with MCP-layer workaround (RECORD_SEP ';' + FIELD_SEP '|') centralized in src/smalltalk.ts. Zero bridge restarts; PID 7588 + token unchanged. mcp-vw server v0.3.0.** | **v0.10.0 (unchanged); mcp-vw 0.3.0** | **6 committed (not pushed)** | **Phase M ~95% SHIPPED; manual Claude Desktop validation next** |
| **23** | 2026-06-21 | **Phase M operationalized through opencode + first real-world benchmark.** mcp-vw wired into opencode at workspace-root `tm/opencode.json` (48 vw_* tools surfaced in agent registry). Live benchmark targeting `vw-mcp-benchmark-test/new-screens (2)/Main App Window-1.png`: PARTIAL initial success (9/10 widgets via typed tools; TableView dropped). Stretch goal proved: full DataSet table rendering matching target PNG via `vw_eval` + `vw_compile_method` escape hatch (built `Smalltalk.SubInstructionRow` class with 6 ivars + 12 accessors + `fromArray:` factory + rewired `MCPBenchReviewWindow>>subInstructions` to SelectionInList + hand-crafted windowSpec with `UI.DataSetSpec` + 6 `UI.DataSetColumnSpec` literals). **7 mcp-vw/bridge defects discovered + catalogued** in `src/mcp-vw/research/benchmark-s23.md` (untracked, deferred per user). Image gained 2 benchmark classes (MCPBenchReviewWindow + SubInstructionRow) preserved as regression fixture for Bug 6 fix work. **Total 38 mcp tool calls, 0 AI errors, 0 bridge wedges, 0 vwnt.exe restarts.** | v0.10.0 (unchanged); mcp-vw 0.3.0 | 0 committed (all artifacts untracked) | Phase M ~95% unchanged; 7-bug catalog ready for P0 PR in s24 |
| **24** | 2026-06-22 | **PR P0 trio SHIPPED + pushed: Bug 1 (`67ec8d2` fix vw_create_class defineClass: 8-kw) + Bug 6 (`3267fcc` feat DataSet widget as 14th component type) + Bug 5 (`d83ff09` test 7 happy-path smoke tests).** Total 10 files +892/-63 lines across mcp-vw codegen + tests + tool descriptions. Vitest: 295/295 → **305/305 pass** (incl. 11 rewritten + 15 new tests). Smoke test: 16/16 → **23/23 ALL GREEN** (added [10a/b/c] + [13a/b] + [10d] + [10e] covering all 4 codegen tools). Typecheck clean. Live-verified end-to-end: emitter outputs sent through `vw_eval`/`vw_compile_method` to live image; class created with correct ivars/super/env/category; DataSet windowSpec compiles + opens at expected bounds. Cascade-fixed 5 broken tests across applicationModel.test.ts + dialog.test.ts + e2e.test.ts + 2 user-facing tool description strings (destructive.ts + reading.ts). **2 new carry-forward constraints discovered + documented: #44 (legacy 6-kw `subclass:...:inDictionary:category:` selector ABSENT — Bug 1 root cause), #45 (bridge response timeout = blocking modal dialog, USER-DISCOVERED pattern that saved hours of Bug 6 debugging).** Zero bridge restarts, zero vwnt.exe restarts; PID 7588 + token unchanged. Probe sessions cleaned up: 135-debugger pile-up from a DataSet-alone MNU at paint (s24 lesson #5 cookbook material) all closed via `ScheduledControllers scheduledControllers` walk; image returned to s23 EOD state with regression fixture preserved at originY=229. Final docs commit: s24 HANDOFF + 2 contract constraints + Phase M ~95% → ~98% in PHASE-PROGRESS. | **v0.10.0 (unchanged)**; mcp-vw 0.3.0 | **3 P0 + 1 docs pushed** | **Phase M ~98%; P1 work next (paren-balance pre-check + widget cookbook + re-run benchmark)** |
| _(future)_ | — | _Phase M ship (MCP for VW dev)_ | — | — | _Onboarding developer milestone_ |
| _(future)_ | — | _Phase E ship (first green Playwright test)_ | — | — | _Test framework starts_ |
| _(future)_ | — | _Phase G + H ship_ | — | — | _Test framework at scale_ |
| _(future)_ | — | _Phase I ship (Test Mentor migration)_ | — | — | _North star reached_ |

---

## Key carry-forward constraints count

| As of | Total constraints | Latest additions |
|---|---:|---|
| session-13 | 7 | sessions 12-13 patterns (OS.ExternalProcess wait, PowerShell binary redirect, ExternalReadAppendStream binary) |
| session-14 | 14 | env vars (8-11), namespace placement (9), `*PackageName` convention (10), `removeFromSystem` patterns (12-13), `class environment` (14) |
| session-15 | 23 | chunk file-in compile scope (15), SUnit testClasses (16), `on: Core.Exception do:` TestFailure-catch (17), Workspace `Core.*` qualification (18), /eval pre-flight rule (19-23) |
| session-16 | 28 | EndOfStreamNotification fileIn trap (24), Direct-invoke v2 Notification-resume (25), Namespace at:put: Notification (26), ByteArray-aware test helpers (27), HTTP /eval Bug #5 inherent limit (28) |
| session-17 | 31 | load.st/unload.st external orchestrators (29), in-place unload+load+verify via single /eval call (30), removeSelector: naturally defensive (31) |
| session-18 | 34 | Dialog asymmetric setter/getter (32), `-filein` switch + ImageConfigurationSystem allow-flags verified (33), `-err` Runtime-Packager-only (34) |
| session-19 | 40 | Cursor>>showWhile: wedge + monkey-patch (35), createParcelNamed: returns empty parcel (36), parcelOutOn:withSource: is Filename arg (37), removeParcelNamed: raises Notification (38), CodeWriter is binary write engine (39), parcel write embeds .pst path reference (40) |
| **session-20** | **42** | **compile: on VWB.VWBridge class wedges bridge even with Cursor monkey-patch (41), ensure: block referencing VWB.VWBridge after parcelOutOn: raises "no binding" (42)** |
| **session-21** | **42** | None — Phase M v2 research used existing constraints (#15, #16, #18, #20, #28, #38, #41) without surfacing new ones. Image probes confirmed empirical surface (1908 ApplicationModel subclasses; 1296 with windowSpec; 312 namespaces). |
| **session-22** | **43** | **Bridge /eval response collapses ASCII whitespace control chars (LF/CR/TAB → space) in JSON encoding (43)** — discovered during MCP MVP live smoke when vw_list_namespaces returned 1 entry. Verified byte-by-byte. MCP-layer workaround: `;` record separator + `|` field separator (RECORD_SEP/FIELD_SEP in src/mcp-vw/src/smalltalk.ts). |
| **session-24** | **45** | **Legacy 6-kw `subclass:...:inDictionary:category:` selector ABSENT (44)** — discovered during PR P0 Bug 1 fix (commit 67ec8d2); verified `Object respondsTo: #subclass:...:inDictionary:category:` → false. Use canonical 8-kw `Smalltalk.<NS> defineClass: ... superclass: #{<X>} indexedType: #none private: false instanceVariableNames: '...' classInstanceVariableNames: '' imports: '' category: '...'` form (receiver = bare `Smalltalk` for root, `Smalltalk.<NS>` for child namespaces). **Bridge response timeout = blocking modal dialog (45)** — USER-DISCOVERED during s24 Bug 6 debugging; when an MCP tool call or `vw_eval` times out, the most common cause is a VW SimpleDialog (often empty-title `" "`) blocking the bridge UI-thread response. Diagnostic: don't retry; check `vw_health` (auth-exempt, still responds), `vw_list_windows` for SimpleDialog or empty-title windows, dismiss via `vw_respond_dialog { buttonLabel: 'OK' }` or close via `ScheduledControllers` walk. Compounding risk: paint-time MNU pops a debugger per re-paint (135-debugger pile-up observed in s24). Pre-flight precaution for batch destructive ops: `Smalltalk.Dialog useNativeDialogs: false`. |

Full carry-forward catalog: [`knowledge/vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md).

---

## Memory MCP entity count

| As of | Entities | Relations | Notable additions |
|---|---:|---:|---|
| session-15 | 8 | 13 | Session-15, Latent-test-bug-indexOfSubCollection, Direct-invoke-gate-pattern |
| session-16 | 12 | 24 | Session-16, Latent-screenshot-test-helper-bug, EndOfStreamNotification-fileIn-trap, Namespace-at-put-binding-notification |
| session-17 | 24 | 42 | Session-17, In-place-unload-load-quality-gate-test (technique), load-unload-orchestrators (technique), Phase-P-P5-Oracle-recommendation (decision-record) |
| session-18 | 24 | 42 | No new entities; +~20 observations across Phase-P-P5-Oracle-recommendation (probe results + 5-cycle gate), VW-image-storedev64 (ImageConfigurationSystem + allow-flags + asymmetric Dialog selectors + PID rotation), Phase-P-progress (P5 SHIPPED), ammaganyane (decisions) |
| session-19 | 27 | 47 | +3 entities: Session-19-2026-06-21, parcelOutOn-wedges-bridge-via-showWhile (code-bug), Cursor-showWhile-monkeypatch-technique (technique), Phase-P-P6-shipped (milestone); +5 relations: discovers/delivers/advances/enables/resolves; +~40 observations across new + existing entities (VW-image-storedev64 parcel API, Phase-P-progress P6 SHIPPED, etc.) |
| **session-20** | **30** | **52** | **+3 entities: Session-20-2026-06-21, Phase-P-P7-P8-shipped (milestone — Phase P COMPLETE), compile-on-VWB-VWBridge-wedge (code-bug); +5 relations: Session-20 delivers Phase-P-P7-P8-shipped, Phase-P-P7-P8-shipped completes Phase-P-progress, compile-wedge affects parcel-build, Session-20 discovers compile-wedge, Phase-P-P7-P8-shipped advances tm-context-vw-bridge; +~25 observations across new + existing entities (VW-image-storedev64 compile wedge + ensure-block no-binding, Phase-P-progress P7+P8 SHIPPED, ammaganyane session-20 decisions)** |
| **session-21** | **35** | **62** | **+5 entities: Session-21-2026-06-21, Phase-M-research-v1-shipped (milestone, rejected at sign-off), Phase-M-research-v2-in-progress (milestone, user-approved), VW-spec-literal-format-pattern (technique — canonical windowSpec literal array discovery), wave-2-librarian-model-failure-and-recovery (session-event); +10 relations capturing v1→v2 supersession, design discovery, MAS UI surface validation; +~40 observations across new + existing entities (ammaganyane s21 direction + design critique, tm-context-vw-bridge Phase M v2 design, VW-image-storedev64 spec hierarchy + ApplicationModel hooks + canonical windowSpec literal)** |
| **session-22** | **35** | **62** | **No new entities created this session (focused entirely on MCP server implementation). Notable deferred memory work: Session-22-2026-06-21 entity capturing the full Phase M shipment + Phase-M-MVP-V2-V3-shipped milestone + carry-forward-43 (bridge JSON whitespace collapse) — to be added in s23 cleanup pass.** |
| **session-24** | **35** | **62** | **No new entities created this session (focused entirely on PR P0 trio execution + EOD docs). Notable deferred memory work — to be added in s25 cleanup pass: Session-23-2026-06-21 entity (7-bug s23 benchmark discovery + DataSet escape-hatch proof of concept) + Session-24-2026-06-22 entity (PR P0 trio shipment) + Phase-M-PR-P0-trio-shipped milestone (Bug 1+6+5 fixed end-to-end) + bridge-timeout-equals-blocking-dialog-pattern (USER-DISCOVERED debugging pattern, source of carry-forward #45) + DataSet-adapter-needs-widget-context-MNU (s24 lesson #5 cookbook material) + carry-forward-44+45 entities.** |

---

## How to maintain this doc

Update at each session EOD when a phase shifts state. Specifically:

1. **Bump `last_updated`** in frontmatter.
2. **Update "Quick status"** — most recent ship, next-session first action, current bottleneck.
3. **Update "Project goals progress"** table — add a new column for the current session if goal % shifted.
4. **Update "Per-phase progress"** table — change `% done` and `status` for any phase that progressed; update `current blocker` if the blocker resolved or shifted.
5. **Update "Phase P deliverable breakdown"** — mark deliverables ✅ as they ship, with commit hash.
6. **Add row to "Per-session impact log"** — what THIS session shipped, in 1-2 sentences.
7. **Update "Key carry-forward constraints count"** if `vw-image-api-contract.md` added bullets.
8. **Update "Memory MCP entity count"** if you created new entities.
9. **Update "Distance to north star"** effort estimates ONLY if scope changed or a phase finished and the next-phase estimate is now sharper.

Keep it scannable. If a row gets longer than 2 lines, move detail into a HANDOFF and link.

**This doc is NOT** the place for:
- Per-session narrative (use HANDOFF-{date}-session{N}.md)
- Strategic framing or phase-rationale changes (use STRATEGIC-ASSESSMENT-{date}.md, rewritten only at phase boundaries)
- Carry-forward constraint detail (use vw-image-api-contract.md)
- Decision records (use memory MCP entities)

This doc IS the place for: "how far are we, where's the bottleneck, what's the next shippable thing."
