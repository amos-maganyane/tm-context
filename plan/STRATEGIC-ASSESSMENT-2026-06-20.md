# Strategic Assessment — Progress Against the Four Goals

**Written:** 2026-06-20 (session-7 EOD, immediately after Bug #2 Symptom A was FIXED in v0.8.12).
**Purpose:** anchor a multi-session push toward production readiness across all four project goals. Complements [`REPLACEMENT-PLAN.md`](./REPLACEMENT-PLAN.md) (the phased roadmap) and [`../docs/ARCHITECTURE-REVISED.md`](../docs/ARCHITECTURE-REVISED.md) (the three-channel architecture).
**Re-evaluate:** at the end of each Wave below, OR when scope changes materially, OR when estimates drift more than ±50%.

---

## The four goals

From the project charter (per [`../README.md`](../README.md), [`../docs/ARCHITECTURE-REVISED.md`](../docs/ARCHITECTURE-REVISED.md), [`../src/vw-bridge/OVERVIEW.md`](../src/vw-bridge/OVERVIEW.md), and project conversation 2026-06-20):

1. **Evaluation server / bridge** — HTTP bridge into the running VW image so external tools can drive widgets.
2. **Production-grade packaging** — make the bridge survive in production: auto-start, logging, config, persistence, CI integration.
3. **Test automation framework** — replace the expiring SilverMark Test Mentor license with a Playwright + bridge stack.
4. **MCP server** — let developers use AI to code on VisualWorks (forge-desktop-equivalent, parallel to Jasper for GemStone).

---

## Where we actually are (snapshot 2026-06-20)

### Goal 1 — Bridge / Evaluation Server: ~70% done

Mapped against REPLACEMENT-PLAN Phase A + B endpoint coverage:

| Endpoint | Plan phase | Built |
|---|---|---|
| `GET /health`, `/windows`, `/windows/tree`, `/value`, `/menu`, `/dialogs` | Phase 1 | ✅ |
| `POST /click`, `/type`, `/value` | Phase A | ✅ |
| `POST /eval` | bonus | ✅ |
| `POST /menu/click` | Phase A+ | ✅ |
| `POST /dialogs/respond` | Phase B | ✅ v0.8.12 (session-7) |
| Bearer auth | Phase A5 | ✅ |
| `POST /screenshot` | Phase A4 | ❌ |
| `POST /wait` (condition polling) | Phase B1 | ❌ |
| `POST /select` (dropdowns) | Phase B2 | ❌ (radio set/click works via /click since v0.8.7) |
| `POST /doubleClick` | Phase B3 | ❌ |
| `GET /widgets/.../cell` (table cells) | Phase B4 | ❌ |
| `POST /windows/{id}/activate` | Phase B5 | ❌ |
| Structured errors with screenshots | Phase B6 | ❌ |

**Gap to Phase B exit criteria:** ~1-2 weeks of focused endpoint additions. None research-grade — all extend patterns already proven by sessions 3-7.

### Goal 2 — Production-grade packaging: ~5% done

Session-6 handoff items 9-15 — almost untouched:

| Item | Status |
|---|---|
| Auto-start on image boot | ❌ manual file-in required each restart |
| Config externalization (env vars, `.env` file) | ❌ port + paths hardcoded |
| File-based structured logging | ❌ Transcript only |
| New endpoints: `/state`, `/reset`, `/version`, `/admin/shutdown` | ❌ |
| OpenAPI spec | ❌ |
| Parcel migration + namespace isolation | ❌ currently top-level on `Root.Smalltalk` |
| SUnit coverage that actually runs | ❌ blocked by Bug #6 (latent comment-escape bug — see [`../knowledge/vw-bridge-known-issues.md`](../knowledge/vw-bridge-known-issues.md) Bug #6) |

**Gap:** ~2-3 weeks. Auto-start + logging are the highest-leverage — they kill the "bridge is a developer toy" risk and make it usable in CI.

### Goal 3 — Test Automation Framework (TestMentor replacement): ~0% done

REPLACEMENT-PLAN Phases C-G — none started:

| Phase | What | Effort |
|---|---|---|
| C — Playwright TypeScript SDK | `VWBridgeClient` + fixtures + Page Objects | ~1 week |
| D — Test Data Bridge | WebGS install + `TestBridgeApi` + gemstone-py wiring | ~3-5 days |
| E — First 10 WEALTH tests | Login, search, portfolio, buy-online, etc. | ~1-2 weeks |
| F — CI Pipeline | Windows runner, headless image boot, artifact collection | ~3-5 days |
| G — Test Mentor case audit + port | 18MB `testCases.gs` migration | ongoing |

The bridge can be driven by raw `curl` today (session-7 did 30+ probes against it). But there is no SDK, no test-runner integration, no test data layer, no CI.

**Gap:** ~3-4 weeks to Phase E exit (10 tests green in CI). Phase G migration is open-ended depending on coverage scope.

### Goal 4 — MCP Server for AI dev on VW: ~0% built, but architecturally unblocked

Per ARCHITECTURE-REVISED's "Dual-Purpose: Test Automation AND AI Agent Interface" section, the bridge's HTTP API IS the foundation for BOTH test automation AND AI agent access. The forge-desktop MCP for VW would be the symmetric piece to Jasper MCP (GemStone-side, already in use this project).

| Item | Status |
|---|---|
| Bridge HTTP API exposes everything an MCP server would need (`/windows`, `/eval`, `/click`, etc.) | ✅ |
| API designed for AI consumption (windows enumeration, widget tree, state queries) | ✅ |
| MCP wrapper (`vw-mcp-server` package) | ❌ |
| Tool definitions + AI-friendly descriptions | ❌ |
| Auth pass-through pattern for MCP | ❌ |

**Gap:** ~1-2 weeks for wrapper + tool descriptions + testing. Cheap because the HTTP layer is stable post-v0.8.12.

---

## Why the 7-session bug detour was necessary, not wasted

Looking at sessions 3-7, each bug was a **load-bearing fix** that would have broken the test framework if shipped as-is:

| Bug | Why it would have broken the test framework |
|---|---|
| #1 RadioButton corruption | Every test with radio selection would corrupt the shared ValueHolder |
| #2 Symptom A | Every test driving `partialFind:` would silently fail with no signal |
| #4 / #4b ExtendedSimpleDialog enumeration | Any test triggering help/error dialogs would wedge invisibly |
| #5 Recursive dispatch | SUnit running via `/eval` would brick the listener and require image restart in CI |

If we had skipped to "build the Playwright SDK" two weeks ago, we'd be hitting these in production CI now instead of in dev probes. The bug-hunting era discovered the **structural quirks of MAS + VW** that had to be known before any production framework could be reliable on top.

Bridge core is now battle-tested against real MAS workflows. **That foundation is the moat.**

---

## Critical-path recommendation: 5 waves

Each wave is independently shippable and each one removes a class of "this would block the next wave" risk.

| Wave | Items | Effort | Unblocks |
|---|---|---|---|
| **Wave 1** (this week) | Commit v0.8.12 → fix Bug #6 → SUnit coverage for v0.8.11 + v0.8.12 fixes | ~1-2 days | Confidence + auto-regression detection |
| **Wave 2** (1-2 weeks) | `/screenshot` + `/wait` + auto-start on image boot + file-based logging | ~1-2 weeks | Tests can capture evidence, sync without sleeps, survive CI |
| **Wave 3** (2-3 weeks) | Playwright TypeScript SDK + 10 first tests + basic CI pipeline | ~3 weeks | **First green test in CI** — actual TestMentor replacement begins |
| **Wave 4** (parallel with W3) | MCP server wrapper + WebGS test data integration | ~2 weeks | AI agents can drive VW + tests get clean data setup |
| **Wave 5** (ongoing) | Test Mentor case audit + migration | weeks-months | License retirement |

**Total to "Test Mentor replaced":** ~6-8 weeks of focused work from current state. Matches the original [`../docs/ARCHITECTURE-REVISED.md`](../docs/ARCHITECTURE-REVISED.md) estimate of 6-8 weeks. The 7 prior sessions burned no slack against that estimate because they fixed blockers that would have surfaced later anyway.

---

## Honest gut-check (2026-06-20)

- **Bridge core**: solid. Ready to build on. Today's v0.8.12 + the 7 bug fixes cleared the structural blockers.
- **Production packaging**: thin. Bridge is currently a "loaded-into-memory developer tool". To call it production-grade, the auto-start + logging + config-externalization wave is non-negotiable.
- **Test framework**: zero. The Playwright SDK is the highest-leverage missing piece for the original "replace TestMentor" goal.
- **MCP for AI dev**: zero built, but architecturally unblocked. HTTP API surface is right.

If only one wave is prioritized first after committing v0.8.12, the highest-leverage is **Wave 2 auto-start + Wave 3 Playwright SDK with 3 tests** — that is the first wave where user-visible value crosses from "demo" to "real testing infrastructure". Bug #2 being fixed means the existing PartySearchView broad-search workflows are first-class test targets.

---

## Quality bar (carry through every wave)

Each wave must satisfy ALL of:

1. **Atomic commits** — code + docs in matching pairs, no monoliths. Match the session-3/4/5/6/7 commit cadence.
2. **No commit/push without explicit user authorization** — the standing rule that has protected this project end-to-end.
3. **Failing test FIRST** — every code change has a red SUnit / Playwright / curl probe that goes green via the change. Red→green→refactor.
4. **End-to-end verification via real usage** — not just unit tests; drive the actual workflow (the Bug #2 fix in session-7 ran an actual `partialFind:` for `'PP0'` and verified 19 contracts populated).
5. **Knowledge-doc updates** — [`../knowledge/vw-bridge-known-issues.md`](../knowledge/vw-bridge-known-issues.md), session handoffs, this assessment when material progress lands.
6. **No regressions on prior fixes** — Phase 2.6-style regression sweep at the end of each wave (sanity-test all v0.8.x earlier fixes before declaring a wave done).

The 7-session bug arc earned us this discipline. Do not drop it under schedule pressure.

---

## Open questions for the user (resolve BEFORE Wave 3 starts)

These shape the Playwright SDK + CI design:

1. **Test data setup mechanism**: gemstone-py direct? WebGS REST? Both? See [`../docs/ARCHITECTURE-REVISED.md`](../docs/ARCHITECTURE-REVISED.md) "When to Use Which Channel".
2. **CI runner location**: Windows VM with VW already installed? Separate test image (`storeTst64`) or shared dev image (`storedev64`)?
3. **First 10 test scope**: which 10 critical-path WEALTH workflows? ([`./REPLACEMENT-PLAN.md`](./REPLACEMENT-PLAN.md) Phase E gives a starting list — needs validation against actual MAS coverage priorities.)
4. **Test Mentor migration scope**: full port of all existing test cases (`testCases.gs` is ~18MB) or only critical-path subset?
5. **MCP server timing**: build in parallel with Wave 3 (faster overall throughput) or sequential after Wave 3 (less context-switch per session)?

---

## Resume hooks

- **Next session immediate action**: commit v0.8.12 (or explicitly defer the commit). Use the 2-commit + handoff split per session convention.
- **Anchoring docs to read first**: this file, [`./REPLACEMENT-PLAN.md`](./REPLACEMENT-PLAN.md), [`../knowledge/HANDOFF-2026-06-20-session7.md`](../knowledge/HANDOFF-2026-06-20-session7.md), [`../docs/ARCHITECTURE-REVISED.md`](../docs/ARCHITECTURE-REVISED.md).
- **Update this file when**: a wave completes, scope changes materially, or estimates drift more than ±50%. Bump the date in the filename if you're rewriting end-to-end; otherwise edit in place and bump the "Re-evaluated" line in the header.

---

## Status timeline (append as waves complete)

| Date | Event | Bridge version | Wave status |
|---|---|---|---|
| 2026-06-20 | Initial assessment; Bug #2 FIXED | v0.8.12 (uncommitted) | Pre-Wave-1 |
| _(next milestone)_ | _(commit v0.8.12 + Wave 1 complete)_ | _(v0.8.13?)_ | _(Wave 1 done)_ |
