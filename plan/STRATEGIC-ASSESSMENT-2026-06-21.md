# Strategic Assessment — Distance to Goals (session-13 EOD, revised)

**Written:** 2026-06-21 (session-13 EOD, after Phase F3 ship — v0.9.1 with `/screenshot` endpoint).
**Revised:** 2026-06-21 (same session, after architectural pushback that surfaced Phase P — Packaging — as the actual critical-path bottleneck).
**Supersedes:** [`STRATEGIC-ASSESSMENT-2026-06-20.md`](./STRATEGIC-ASSESSMENT-2026-06-20.md) (session-7 vintage). Historical context only.
**Complements:** [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md). The seven quality disciplines at the top of that doc apply to every phase below. When this doc and the roadmap disagree on execution order, the roadmap wins.
**Re-evaluate:** at the next phase boundary, OR when scope changes materially, OR when a phase's quality gate cannot be met and the design needs rethinking.

---

## The four project goals (unchanged)

1. **Bridge / evaluation server** — HTTP bridge into the running VW image so external tools can drive widgets.
2. **Production-grade packaging** — auto-start, logging, config, persistence, CI integration.
3. **Test automation framework** — replace the expiring SilverMark Test Mentor license with a Playwright + bridge stack.
4. **MCP server** — let developers use AI to code on VW (forge-desktop equivalent of Jasper). Two consumer flavours: MCP-for-VW-dev (developer productivity; unblocks onboarding) and general MCP (AI agents drive MAS for testing/exploration).

---

## Per-goal progress

| Goal | Session-7 baseline | Session-13 EOD | Δ |
|---|---|---|---|
| **1. Bridge / eval server** | ~70% (13 endpoints; /wait + /screenshot + /select + /doubleClick + /cell + /activate all missing) | **~90%** (14 endpoints; /wait + /screenshot shipped; /select /doubleClick /cell /activate still missing) | +20% |
| **2. Production-grade packaging** | ~5% (no logging, no auto-start, no OpenAPI, no SUnit) | **~25%** (file-based NDJSON logging at `vw-bridge.log` + 68 SUnit selectors across 3 test classes + 7 carry-forward image-API constraints documented + Bug-fix arc complete; auto-start + parcel + config-externalization + install doc still ❌ — this is Phase P territory) | +20% |
| **3. Test framework** | ~0% (no SDK) | **~0%** (bridge surface stronger but SDK itself not started; gated on Phase P) | 0% |
| **4. MCP server** | ~0% built, architecturally unblocked | **~0%** (same; gated on Phase P) | 0% |

Goals 1 and 2 absorbed most of sessions 9–13. **Both Goal 3 and Goal 4 are now gated on the same thing: Phase P (Packaging).**

---

## Phase-roadmap progress

| Phase | Status | Shipped in |
|---|---|---|
| A — Stabilize | ✅ DONE | sessions 7–9 |
| B — `/wait` endpoint | ✅ DONE | v0.9.0 (session-9) |
| F — `/screenshot` | ✅ DONE | v0.9.1 (session-13) |
| **P — Packaging (NEW; recognised as critical-path bottleneck)** | ⏳ **NOT STARTED — next phase** | — |
| C — API freeze + OpenAPI | ⚙️ partially subsumed by Phase P (P7 install doc + P8 `/version` cover the core; standalone OpenAPI deferred) | — |
| D — Auto-start | ⚙️ subsumed by Phase P (P5 `Parcel>>postLoad:` + external trigger) | — |
| M — MCP server for VW dev (NEW; was implicit in original "Phase H scale + MCP") | ⏳ NOT STARTED (gated on P; parallel with E) | — |
| E — Playwright SDK + 3 tests | ⏳ NOT STARTED (gated on P) | — |
| G — CI pipeline | ⏳ NOT STARTED (gated on P + E) | — |
| H — Scale (test coverage + general MCP) | ⏳ NOT STARTED | — |
| I — Test Mentor migration | ⏳ NOT STARTED | — |

3 phases shipped (A, B, F). Phase P is the next-up.

---

## Phase P — Packaging the eval server

**Why Phase P is on the critical path.** Both downstream products (test framework, MCP for VW developers) require the eval server **loaded on the consumer's image**. Today the only install path is manual file-in of a 2,656-line `.st` file with paths hardcoded to the author's filesystem. That is not deployable to anyone else's machine. Until Phase P ships, neither downstream product can be used by anyone other than the author. **The eval server already works — the bottleneck is making it installable, not making it functional.**

**Quality gate for the phase as a whole:** a developer with no prior context can install the bridge on a clean VW image via a documented procedure, run `curl /health`, and get a valid response — without editing source.

### Deliverables (quality-ordered dependency chain)

| # | Deliverable | Quality gate | Unblocks |
|---|---|---|---|
| **P1** | Externalize 5 hardcoded paths via env vars (`VW_BRIDGE_HOME` + 4 derived). Probe `OS.OperatingSystem environment` for the env-read API first. | Bridge files in cleanly on a fresh VW image at any directory when `VW_BRIDGE_HOME` is set; `/health` succeeds. | Anyone installing on a different machine, today |
| **P2** | Define `VWBridge` as a proper Namespace (not `Root.Smalltalk` top-level) + minimum-viable 3-package split (Core / Patches / Tests). | Existing functionality survives the namespace migration; all 68 SUnit selectors still pass (full suite via VW Workspace); the `SimpleDialog>>choose:` patch lives in its own loadable/unloadable package. | P6 |
| **P3** | Move PowerShell screenshot helper into the install path; discover via env var (not relative-path-from-repo). | `/screenshot` succeeds on a fresh install where the helper script lives at `$VW_BRIDGE_HOME/scripts/screenshot-helper.ps1`, regardless of working directory. | `/screenshot` on a clean install |
| **P4** | `load.st` + `unload.st` pair. `unload.st` cleanly removes all VWBridge classes + the `SimpleDialog` patch, and cleans up the token file. Idempotent — running `load.st` twice is safe. | After `unload.st`, the image is byte-equivalent to its pre-`load.st` state in terms of class presence; `Kernel.Parcel` introspection shows zero residual VWBridge classes. | P6, clean dev workflow |
| **P5** | Auto-start mechanism — `Parcel>>postLoad:` block calls `VWBridge start` + writes token file. Choose external trigger (Topaz stdin script vs CLI arg vs file watcher) via Oracle consult. | Five cold-start cycles (kill `vwnt.exe`, restart, observe bridge auto-up, `curl /health` succeeds) without manual intervention. CI runner survives `vwnt.exe` restart. | CI runner deployment |
| **P6** | Build `.pcl` parcel artifact. `loadParcelFrom: aFilename` is the verified headless install path (session-11 evidence). | Single-file distribution: copying `VWBridge.pcl` to a target machine + setting `VW_BRIDGE_HOME` + running `Kernel.Parcel loadParcelFrom: 'VWBridge.pcl' asFilename` produces a working bridge. | Single-file distribution |
| **P7** | `INSTALL.md` covering env-var setup + `loadParcelFrom:` invocation + smoke test (`curl /health` → expected response). | A developer with no prior context installs the bridge following only `INSTALL.md` and reaches the smoke-test success state on the first try. | Onboarding developer can self-install |
| **P8** | `GET /version` returns parcel metadata (version string, build timestamp, commit SHA). Augments existing `/health`. | `curl /version` returns valid JSON with all three fields; values match the parcel's `versionString` + build pipeline output; SDK consumers can pin to a known version. | SDK version pinning; foundation for later Phase C OpenAPI |

**Decomposition deferred.** The other AI's 13-class proposal fragments cohesion (separating `VWBridgeWaitClock` from `VWBridgeWaitEvaluator` from `VWBridgeWaitSeams` is Java/.NET cosplay, not Smalltalk-idiomatic). Within-class organization via `methodsFor:` categories suffices until Phase E SDK consumption reveals what abstractions actually want extraction. Phase P does the MINIMUM decomposition required for a parcel (3 packages) and leaves the rest for later when the right cuts are knowable from real consumption.

---

## Critical path

**"Onboarding developer can use AI to write VW code on their own image"** is the first user-visible value milestone. Path:

```
Phase P (Packaging)  →  ┌→ Phase M (MCP for VW dev)
                        │
                        └→ Phase E (Playwright SDK + 3 tests)  →  Phase G (CI)
```

Both M and E gate on P. Both can run in parallel once P ships. Neither requires the other.

**"First green Playwright test in CI"** — the test framework milestone — requires P + E + G.

**"Test Mentor retired"** — the north star — requires P + E + G + Phase H (scale to all critical workflows) + Phase I (`testCases.gs` migration; 18 MB; pace depends on coverage scope accepted).

---

## Distance to "Test Mentor retired" (north star)

Quality-bar discipline (per [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md)): each phase ships when its quality gate is met, not when a calendar says it should. A phase that can't meet its gate gets reshaped, not rushed.

Beyond the critical path, two open-ended phases remain:

- **Phase H — Scale.** All critical-path WEALTH workflows have Playwright equivalents. Quality gate: each test passes 10 consecutive green runs before being declared "done". Pace = throughput once SDK + CI exist; no point estimating before P + E + G land.
- **Phase I — Test Mentor migration.** `testCases.gs` is 18 MB. Quality gate: every ported test produces semantically equivalent assertions to its Test Mentor counterpart, validated against the same MAS workflows. Pace depends on whether full port or critical-path-subset scope is accepted.

H and I are throughput phases; P / M / E / G are the hard machinery work.

---

## Honest gut-check (session-13 EOD, revised)

- **Bridge code is solid.** Phase F3 (/screenshot) shipped; bridge core has all endpoints needed for both downstream products. The structural blockers (Bug #2 modal detection, Bug #5 re-entry guard, `/wait` predicate sync, `/screenshot` binary capture) are all behind us.
- **Packaging is the actual bottleneck.** Both test framework and MCP-for-VW-dev require the bridge installed on the consumer's image. Today that means manual file-in with hardcoded author-machine paths. Phase P is the gate; until it ships, the eval server is a single-author developer toy.
- **The other AI's "refactor into 13 packages" advice conflates packaging with decomposition.** Packaging needs ~3 packages + env-var config + parcel build + install doc. Decomposition (13 packages) is deferable until Phase E SDK consumption reveals the right abstractions. Premature decomposition based on speculative class lists would lock in wrong cuts.
- **MCP for VW dev unblocks the onboarding developer immediately once Phase P ships.** Minimum tool set is 3 tools (`evalExpression`, `getUIState`, `browseClass`) — wraps existing bridge endpoints; no new image-side work required. The hard part (the eval server) is already done.
- **Carry-overs from sessions 7–11** (EXPLORATION-PLAN steps 3–4, `#id`/`#imcNr`/`#groupScheme` verify) remain independent of the critical path — pick up any time without blocking the Test Mentor track.

---

## Recommendation for session-14

**Adopt Phase P as the next phase.** Sequence deliverables in dependency order; ship each when its quality gate is met.

1. **P1 + P3 first** — externalize paths, move helper script. Probe `OS.OperatingSystem environment` for the env-read mechanism in this image before committing to a pattern. **Why first:** these alone unblock anyone installing the bridge on a different machine. Highest leverage per unit of work.
2. **P2 + P4** — namespace migration + 3-package minimum split + load/unload. **Why second:** prerequisite for the parcel build; foundation for clean install/uninstall workflow during dev.
3. **P5 + P6** — Oracle consult on auto-start trigger; build `.pcl` parcel. **Why third:** P5 needs P2+P4 done (namespace + clean unload) before parcel `postLoad:` semantics are meaningful; P6 needs all prior deliverables (config + namespace + helper + load/unload) bundled.
4. **P7 + P8** — install docs + `/version` endpoint. **Why last:** ship-ready polish that depends on having a deployable parcel to document.

After Phase P: **Phase M (MCP for VW dev)** and **Phase E (Playwright SDK + 3 tests)** in parallel. Both are gated on P; neither gates the other. Phase M is smaller and unblocks the onboarding developer; Phase E is bigger and unblocks the test framework track. Run both unless one specifically reveals it's risk-bearing the other.

**Quality discipline (carry through every deliverable):** the seven disciplines at the top of [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) apply. TDD red→green→refactor. Real-usage verification gate. Atomic commits + explicit auth. Docs match reality. Smallest correct change wins. Probe before commit. Oracle consult for architecture-shaped decisions. **No timeline pressure.** A deliverable that can't pass through all seven isn't done.

---

## What stays the same from prior assessment

- The **four project goals** are unchanged.
- The **seven quality disciplines** at the top of [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) are unchanged.
- The **anti-pattern** is unchanged: zero modification to MAS application code. Tests adapt to MAS as-shipped. Bridge adapts to MAS as-shipped.
- The **bug-fix arc of sessions 3–8** was load-bearing; the feature-work arc of sessions 9–13 was the natural continuation. Phase P is the natural continuation of session-13.

---

## Resume hooks

- **Next-session anchor:** this file + [`ROADMAP-QUALITY-FIRST.md`](./ROADMAP-QUALITY-FIRST.md) + most recent [`HANDOFF-*.md`](../knowledge/) ([session-13](../knowledge/HANDOFF-2026-06-21-session13.md) current) + [`vw-image-api-contract.md`](../knowledge/vw-image-api-contract.md) (7 carry-forward constraints documented as of session-13).
- **First action:** Phase P deliverables P1 + P3 (path externalization + helper script relocation). Probe `OS.OperatingSystem environment` for env-read API before designing the config layer.
- **Phase P quality gates** (per deliverable): see "Phase P — Packaging the eval server" section above.
- **Standing decisions still open after Phase P:** Phase M vs Phase E ordering (parallel preferred); carry-overs from sessions 7–11 (EXPLORATION-PLAN steps 3–4, `#id`/`#imcNr`/`#groupScheme` verify); long-tail production items (log rotation, class-side log mutex for concurrent fork safety).

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | **v0.9.1** | **A, B, F** |
| _(future)_ | Phase P ship (deployable parcel + install doc) | _(v0.10.0 likely)_ | A, B, F, P |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
| _(future)_ | Phase G ship (first green CI run) | — | A, B, F, P, M, E, G |
