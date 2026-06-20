# Roadmap — Quality-First Execution

**Written:** 2026-06-20 (session-8 wrap, after Wave 1 + v0.8.13 logging + MAS-coordination phantom correction).
**Purpose:** structure remaining work as **phases with quality gates**, not weeks on a calendar. User signal at end of session-8: *"do not stress too much about timelines, focus on high quality."*
**Complements:** [`STRATEGIC-ASSESSMENT-2026-06-20.md`](./STRATEGIC-ASSESSMENT-2026-06-20.md) (timeline-shaped progress snapshot against the four project goals) and [`REPLACEMENT-PLAN.md`](./REPLACEMENT-PLAN.md) (phased endpoint roadmap). When these conflict on execution order, this doc wins.
**Re-evaluate:** at each phase boundary, OR when a phase's quality gate cannot be met and the design needs rethinking.

---

## What "high quality" means for this project

Lifted from what sessions 3-8 actually did well, distilled into seven non-negotiable disciplines:

| Discipline | What it forces |
|---|---|
| **TDD red→green→refactor** | Every behavior change has a failing test first. No "should work, will verify later". |
| **Real-usage verification gate** | Before declaring done, drive the actual workflow end-to-end. Bug #2 wasn't "done" until `partialFind:` populated 19 PP0 contracts via the real bridge call. |
| **Atomic commits + explicit auth** | One commit = one logical change. No commit/push without explicit user authorization. |
| **Docs match reality** | Two phantom corrections in 24h (the L12 quote site that wasn't there, and the MAS-coordination dependency that wasn't real). Docs that drift are docs that lie. |
| **Smallest correct change wins** | Bug #2 fix is 12 lines of override on a thin-delegator. Auto-start should be one mechanism, not a framework. |
| **Probe before commit** | Cheap read-only `/eval` probe before any expensive implementation path. Session-8 saved a week by probing SessionManager (didn't exist) before designing around it. |
| **Oracle consult for architecture-shaped decisions** | Used twice (Bug #2 Option A′ pivot, would use for /screenshot + /wait predicate design). Cheap insurance against design errors that compound. |

If something can't pass through all seven, it isn't done.

---

## The roadmap (quality-ordered)

Phases are sequenced by **dependency**, not by calendar. Each phase ships when its quality gate is met. A phase may take one session or several; that's fine.

### Phase A — Stabilize what we have

**Goal:** lock down the foundation before building higher. Cheap, fast, high-value warm-up.

| Step | What | Effort |
|---|---|---|
| **A1** | Fix `bodyOf:` pre-existing test bug — swap 1-arg `indexOfSubCollection:` for 2-arg form at [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) L72-80. Makes existing tests fail cleanly (not error) when accidentally run via `/eval`. | ~5 min |
| **A2** | Probe parcel availability in this image via read-only `/eval`. Three probes: does `Parcel` class exist? Does this image respond to `Parcel storeOnFile:` or equivalent? Does `parcelInitialize` mechanism work? **Decides the entire auto-start architecture (Phase D).** | ~30 min |
| **A3** | Consolidate the 5+ "this image lacks X" constraints from session-8 handoff into a single `knowledge/vw-image-api-contract.md`. Currently scattered across handoff "Explicit constraints" sections. Future probes won't re-discover known limitations. | ~1 h |
| **A4** | Add `/capabilities` bridge endpoint that probes available APIs at boot and reports them as JSON. Cheap insurance against future "wait, does THIS image have X?" surprises. | ~2-4 h |

**Done when:** A1 committed, A2 verdict written down with concrete probe evidence, A3 doc consolidated, A4 endpoint returns ground truth.

**Quality gate:** parcel verdict has actual `/eval` evidence — not "I think it should work".

---

### Phase B — `/wait` endpoint

**Goal:** kill `Start-Sleep` from test code forever. Every test waits on **state**, not **time**.

The single highest-leverage missing piece. Tests without `/wait` are fundamentally flaky — they sleep arbitrary durations and hope. With `/wait`, tests sync on what they actually care about.

| Step | What |
|---|---|
| **B1** | Oracle consult on the predicate language. The hard question is what predicates to support and how to express them. Candidates: window-appears (by appClass + label), dialog-appears (by message substring), value-equals (by widget aspect + comparator), window-closes, generic eval-truthy (needs safety review). |
| **B2** | TDD: 3-5 SUnit tests covering happy path + each predicate kind + timeout behavior. Red first. |
| **B3** | Implement on the bridge serve process with polling. Simpler than event-driven; cleaner failure semantics; matches existing endpoint patterns. |
| **B4** | Real-usage verification: write a real `/click findID` → `/wait dialog-appears Continue?` → `/dialogs/respond Yes` → `/wait window-appears Portfolio` flow. This becomes the test pattern session-9+ tests use. |

**Done when:** 5 SUnit tests green; the partialFind → modal → dismiss → portfolio flow runs end-to-end without any `Start-Sleep`.

**Quality gate:** zero flakes across 10 consecutive sequential runs of the real-usage flow.

---

### Phase C — API freeze + OpenAPI spec

**Goal:** stop the bridge API from being a moving target before tests depend on it.

The bridge has shipped 13 versions across 8 sessions. Before we build an SDK on top, freeze the contract. Otherwise the SDK lags every bridge change and tests break.

| Step | What |
|---|---|
| **C1** | Audit every endpoint that currently exists: method, path, query/body schema, response shape, error codes. About 12 endpoints today. |
| **C2** | Write OpenAPI 3.0 spec at `docs/openapi.yaml`. Hand-written initially; validate against actual bridge responses. |
| **C3** | Versioning policy: this is **v1.0** of the bridge HTTP API. Future breaking changes bump to v2.0 with deprecation period. Patches/features bump 1.x. |
| **C4** | Pre-commit or CI check that the OpenAPI spec matches actual bridge responses. Test runner probes each endpoint and verifies the shape. |

**Done when:** OpenAPI spec exists, every endpoint documented, drift is detectable.

**Quality gate:** spec validates against the live bridge with zero discrepancies; CI check rejects PRs that break this.

---

### Phase D — Auto-start architecture

**Goal:** bridge UP automatically whenever `vwnt.exe` is, without manual file-in.

By this point Phase A2 has told us which mechanism works. Three possible answers, all developer-side, **zero MAS team involvement**:

| Outcome | When | Description |
|---|---|---|
| **D-parcel** (probable best case) | A2 confirms parcel mechanism works | Build `VWBridge.pcl`; `parcelInitialize` calls `VWBridge start`; put parcel where VW finds it on boot. **Cleanest answer** — self-contained, follows VW conventions. |
| **D-snapshot** (workable fallback) | parcels unavailable but image snapshot works | File-in bridge + `ObjectMemory snapshotAs:thenQuit:` with bridge code present + small mechanism (TBD by probe) to restart the listener on image-load. **Functional but less clean** — snapshot bundle is bigger than a parcel. |
| **D-external** (last resort) | Neither works | External PowerShell/batch script launches `vwnt.exe`, polls for ready, injects file-in via Topaz or stdin. **Brittle but ships fastest**. |

| Step | What |
|---|---|
| **D1** | Oracle consult on the chosen architecture. Design decisions vary a lot by outcome. |
| **D2** | Implement. |
| **D3** | Real-usage verification: actually restart `vwnt.exe`, watch the bridge come up automatically, verify `/health` responds within N seconds. Repeat 5 times. |

**Done when:** kill vwnt.exe, restart, bridge auto-starts. End-to-end, observed personally, repeatedly.

**Quality gate:** 5 successful auto-starts in a row from a cold image.

---

### Phase E — Playwright SDK scaffold + 3 first tests

**Goal:** encode the API contract as code; write the first real test cases.

By this point we have stable foundation: frozen API + OpenAPI spec + `/wait` + auto-start. SDK on top can be solid.

| Step | What |
|---|---|
| **E1** | TypeScript SDK package: `VWBridgeClient` class with one method per endpoint, types generated from OpenAPI spec. |
| **E2** | Page Object patterns for MAS workflows: `PartySearchPage`, `PortfolioPage`, etc. Initially just the workflows the first 3 tests need. |
| **E3** | Fixtures: token management, auth headers, image snapshot setup/teardown. |
| **E4** | **Three first test cases**, picked from highest-value WEALTH workflows. Each test: clear single-purpose assertion; runs in <60s; captures evidence on failure (gated on Phase F); proven to run reliably. |

**Done when:** 3 tests green locally, deterministically.

**Quality gate:** **10 consecutive green runs per test.** One flake = back to debugging, no progress until resolved.

---

### Phase F — `/screenshot` endpoint (parallel with E, or after)

**Goal:** when a test fails, we see WHAT failed visually.

Unblocks failure investigation. Tests can run without it, but debugging failures sucks without it.

| Step | What |
|---|---|
| **F1** | Oracle consult on encoding (base64 PNG inline vs file-on-disk + path), size limits, sync vs async. |
| **F2** | Probe VW graphics APIs (likely `Image fromUser:` or `Screen default` — but the image is stripped, so probe first). |
| **F3** | Implement with UI-process dispatch (same pattern as `/dialogs`). |
| **F4** | SDK integration: every test failure auto-captures a screenshot, bundled with the failure report. |

**Done when:** failing tests produce a screenshot bundled with the failure report.

**Quality gate:** screenshot quality matches what a developer would manually capture; no truncation; readable file size; no broken images.

---

### Phase G — CI pipeline

**Goal:** tests run automatically on every code change, headlessly.

| Step | What |
|---|---|
| **G1** | Windows runner setup: `vwnt.exe` installed, bridge auto-start working (from Phase D), test runner image ready. |
| **G2** | Test execution: Playwright CI invocation. Parallel runs if safe; sequential fallback. |
| **G3** | Artifact collection: screenshots, `vw-bridge.log`, VW Transcript dump on failure. |
| **G4** | Reporting: pass/fail summary, failure breakdown by category. |

**Done when:** a code commit triggers CI which boots `vwnt.exe`, starts the bridge, runs all tests, collects artifacts, posts a result.

**Quality gate:** CI has been green for 10 commits in a row before declaring it stable.

---

### Phase H — Scale + MCP server (parallel tracks)

**H-tests**: Expand from 3 → 10 → 30 → eventually all critical-path WEALTH workflows. Each test goes through the same quality gate: 10 green runs before "done". No rushed additions.

**H-mcp**: Wrap stable bridge API in MCP server (forge-desktop equivalent of Jasper). AI agents drive VW. Parallel to test expansion because both depend on the stable API but not on each other.

**Done when:** Test Mentor's critical workflows have Playwright equivalents AND AI agents can drive MAS via the MCP server.

---

### Phase I — Test Mentor migration

Ongoing. Audit existing test cases (`testCases.gs` is 18MB), port critical-path first, retire Test Mentor in pieces. Final goal but not a single push — paced and chunked.

---

## Parcel migration: focused take

The auto-start question keeps pointing at parcel migration. Worth a deeper look since it's the most likely Phase D outcome.

### Why parcel migration is probably the right answer

1. **VW-native mechanism.** Parcels are how production VW code ships. Not a workaround.
2. **Independent of the missing SessionManager hooks.** `parcelInitialize` is built into the parcel format — VW invokes it on parcel load, regardless of SessionManager state. Session-8 was blocked thinking of auto-start as a SessionManager problem; it's actually a parcel-load problem.
3. **Self-contained artifact.** One `.pcl` file = the whole bridge. Trivial to deploy: copy to CI runner, point image at it.
4. **Versionable.** Parcels carry version metadata. `VWBridge-0.8.13.pcl` is unambiguous.
5. **Selective load.** Different images can load different parcels. Dev image = bridge always loaded. Prod image (if we ever care) = no bridge.
6. **Compatible with current source-file approach.** The `.st` file we file-in today IS the parcel's content. Building a parcel is mostly tooling around what we already have.

### What we don't know yet (Phase A2 settles)

- Does this stripped image have the `Parcel` class loaded at all?
- Can we *build* parcels from this image, or only *load* them? If only load, we need to build elsewhere — that's a tooling question.
- Does `parcelInitialize` fire reliably on every image boot, or only on explicit parcel-load operations?
- Are there parcel-load-path conventions we have to honor for VW to find the parcel automatically?

### Failure mode

If parcels aren't available or `parcelInitialize` doesn't behave the way I assume, we fall back to D-snapshot or D-external. Both work; both are uglier.

### Recommendation

Phase A2 probe is ~30 min of `/eval` calls. Do it BEFORE committing to a path. Three plausible outcomes, all have a clean answer in this roadmap.

---

## What stays the same from the prior assessment

The four project goals (per [`STRATEGIC-ASSESSMENT-2026-06-20.md`](./STRATEGIC-ASSESSMENT-2026-06-20.md)) are unchanged:

1. Bridge / evaluation server
2. Production-grade packaging
3. Test automation framework (replace Test Mentor)
4. MCP server for AI dev on VW

The seven disciplines listed at the top of this doc are unchanged. Every phase ships through them.

The **anti-pattern** is unchanged: we don't modify MAS application code, full stop. Tests adapt to MAS as-shipped. The bridge adapts to MAS as-shipped. If something can't be tested, the bridge gets extended (e.g., v0.8.12 SimpleDialog override on a VW base class — never on an MAS class).

---

## What changes from the prior assessment

| Was (timeline-shaped) | Becomes (quality-shaped) |
|---|---|
| "~6-8 weeks to Test Mentor replaced" | "Test Mentor replaced when all critical workflows have green Playwright equivalents AND each has passed the 10-consecutive-green-runs gate" |
| "Wave 2 ~1-2 weeks" | "Phase B (`/wait`), Phase C (API freeze), Phase D (auto-start) ship when their quality gates are met" |
| "MAS team coordination needed for parcel" | (Phantom — corrected in session-8 retrospective. Zero MAS team involvement for the test framework goal.) |
| "Parallel Wave 3 + Wave 4 to compress" | "Phase H runs tracks in parallel only if neither is rushed. Quality bar on each track independently." |

The timeline framing was a lie of false precision. Replaced with phase-shaped gates that we either pass or don't.

---

## How to use this document

- **Before starting a phase:** read the goal + steps + quality gate. Cancel or reshape if the gate isn't achievable with what we know.
- **During a phase:** check work against the seven disciplines at the top. Anything failing them = not done.
- **At phase exit:** confirm the quality gate. Update this document if reality diverged from plan (and explain why).
- **At project end (Test Mentor retired):** archive this doc with a coda explaining how each phase actually unfolded.

This is a living document. Edit it as understanding improves. Bump the `Re-evaluated` line in the header when material changes land.

---

## Resume hooks

- **Next-session immediate action:** Phase A1 (`bodyOf:` 5-min fix) as a low-risk warm-up. Then Phase A2 (parcel probe) to settle auto-start architecture.
- **Anchoring docs to read first:** this file, [`STRATEGIC-ASSESSMENT-2026-06-20.md`](./STRATEGIC-ASSESSMENT-2026-06-20.md), [`REPLACEMENT-PLAN.md`](./REPLACEMENT-PLAN.md), most recent `knowledge/HANDOFF-*.md`.
- **Status updates land in:** this file's phase tables + the next session handoff.
