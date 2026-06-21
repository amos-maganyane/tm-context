# Handoff — Phase P P2 Stage 3 SHIPPED + P5 Oracle consult complete (session 2026-06-21 session-17 EOD)

**Written:** session-17 EOD after Phase P P2 Stage 3 ship (`load.st` + `unload.st` + auto-start chunk removal) + P5 Oracle consult (Path 4 PowerShell wrapper + `vwnt.exe -filein` recommendation) + Jasper mining synthesis. Three atomic commits shipped local then about-to-push together with this handoff: [`cdf3876`](#) (feat) → [`f8f247f`](#) (docs) → [`25bc53d`](#) (probes) → handoff commit (session-17).

**For session-18:** (1) **PROBE `vwnt.exe storedev64.im -filein <path>` syntax** — Oracle's Path 4 recommendation is BLOCKED on this empirical verification. (2) If `-filein` works → implement `src/vw-bridge/scripts/Start-VWBridge.ps1` per Oracle sketch + run P5 quality gate (5 cold-start cycles). (3) If `-filein` does NOT work → re-consult Oracle with new constraint. (4) Optionally probe top-level `^` chunk file-in semantics alongside (orthogonal Oracle-didn't-flag concern). (5) Phase P P6/P7/P8 still gated on P5. (6) Standing housekeeping (Options 2/3/5/6 from session-17 menu) still pending.

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session16.md`](./HANDOFF-2026-06-21-session16.md) remains session-16 EOD; this file is session-17 EOD.

---

## User direction this session (condensed)

- Resume prompt with 5 anchor docs + Phase 0 verification + memory_search_nodes for 13 query terms. All Phase 0 GREEN; surfaced 6 standing decisions via question tool.
- Picked **Option 1 (Phase P P2 Stage 3 — load.st + unload.st)** at session-17 start. Natural unblocked next deliverable now that P2 quality gate was SATISFIED session-16.
- After Stage 3 work complete + 3-commit batch proposed: picked **"Approve 3 atomic commits as proposed (Recommended)"** — decisive, kept commit shape matching session-14+16 cadence.
- After 3 commits landed + next-direction surfaced: picked **"Continue: Option 4 Phase P P5 Oracle consult"** — moved to design phase for the next critical-path deliverable while energy remained.
- After Oracle launched + "fill the wait" surfaced: requested **"Meanwhile oracle is busy what can we learn from jasper"** — directed Jasper mining (`C:\Users\ammaganyane\tm\remote-desktop\remote-desktop\visual-works\repos\Jasper`) for transferable design lessons.
- After Oracle returned + wrap-up surfaced: picked **"Write HANDOFF + commit + push 4 commits (Recommended)"** — clean session close, bundle 3 Stage 3 commits + handoff into a single push to origin.
- Throughout: respected AGENTS.md commit cadence (ASK + WAIT for OK before each commit batch). Push deferred per cadence until explicit auth at session-17 wrap-up.

---

## Work completed in session-17

### Phase 0 verification (all 6 steps GREEN — matches session-16 EOD)

- `/health` → `{"status":"ok","version":"0.9.1"}` ✓
- `.token` = `3959495310063-903045` (unchanged session-16 → session-17, no vwnt.exe restart) ✓
- 0 commits ahead of origin/main (clean push base from session-16) ✓
- 3 untracked: `AGENTS.md`, `opencode.json`, `plan/STRATEGIC-ASSESSMENT-2026-06-21.md` ✓
- Bridge class identity: `VWB.VWBridge environment name = '#VWB'`, `Smalltalk at: #VWBridge = nil`, VWB namespace contains 4 classes (VWBridge, VWBridgeScreenshotTest, VWBridgeTest, VWBridgeWaitTest) ✓
- vwnt.exe PID 6236 continuous since 6/21/2026 11:40:56 AM (3-session continuous run: 15→16→17) ✓
- `VW_BRIDGE_HOME` at User OS level confirmed persistent ✓

### Phase P P2 Stage 3 — `load.st` + `unload.st` ship (Option 1, session-16 chosen direction)

**Step a — design + write [`src/vw-bridge/load.st`](../src/vw-bridge/load.st) (78 lines):** external load orchestrator (do-it expression block, NOT chunk-formatted). Resolves `VW_BRIDGE_HOME` via `OS.CEnvironment userEnvironment at: ifAbsent:` (fails loud per constraint #8), defensively stops + removes any leaked top-level `Root.Smalltalk.VWBridge` (Stage 2 migration cleanup), files in 5 source files in dependency order, calls `VWB.VWBridge start` (rotates token), writes `.token` for agent pickup. `fileIn` left UNWRAPPED per constraint #24 so `EndOfStreamNotification` auto-resumes at top-level handler.

**Step b — design + write [`src/vw-bridge/unload.st`](../src/vw-bridge/unload.st) (97 lines):** defensive idempotent inverse cleanup. Captures `tokenPath` BEFORE class is gone, stops bridge via dynamic `Smalltalk at: #VWB` lookup, deletes `.token`, removes SimpleDialog override, removes 4 VWB classes in reverse-dep order (ScreenshotTest, WaitTest, Test, VWBridge), removes empty VWB namespace (only if `keys isEmpty`). All steps wrapped with `on: Core.Error do: [:ex | log]` for belt-and-suspenders.

**Step c — probe defensive primitives via [`_probe-session17-primitives.st`](../src/vw-bridge/probes/_probe-session17-primitives.st):** `SimpleDialog removeSelector: #absent` and `Object removeSelector: #absent` both return without raising → `removeSelector:` is naturally defensive (the `on: Core.Error do:` wrap is belt-and-suspenders but not strictly required). Pre-load state snapshot captured (4 VWB classes, override installed, token file present, 0 VWBridge parcels in `Kernel.Parcel parcelNames`, 0 VWB keys in `classParcelMap`).

**Step d — test load.st via /eval (twice):** first run against IN-IMAGE old VWBridge.st (with auto-start chunk), then second run against NEW VWBridge.st (without auto-start). Both runs SUCCESS — token rotated `3959501518637-726009` then `3959501660889-966286`, `.token` file written, `/health` 200 OK, all 4 VWB classes present, SimpleDialog override installed with `*VWBridge-Patches mas-bug2-fix` category.

**Step e — remove VWBridge.st auto-start chunk (L2671-2691):** file went from 2691 lines to 2674 lines. Class comment updated with `v0.9.2 Phase P P2 Stage 3 (session-17)` note documenting the change. **VWBridge.st is now parcel-ready for P6** (files in without side-effects).

**Step f — quality gate test via [`_probe-session17-quality-gate.st`](../src/vw-bridge/probes/_probe-session17-quality-gate.st) (217 lines):** single /eval call runs the FULL cycle inline (pre-state snapshot → unload body → post-unload snapshot → load body with dynamic lookups → post-load snapshot → 6 gate assertions). PHASE 2 unload kills the listener mid-call; the /eval handler runs on a forked process and SURVIVES the listener termination, then files in 5 sources + starts a NEW listener + writes new `.token` + responds via the still-open client socket. **All 6 quality gate predicates TRUE both times** (idempotency proven via 2 consecutive cycles): post-unload VWB-present=false, SimpleDialog-override-installed=false, token-file-exists=false; post-load VWB-class-count=4, SimpleDialog-override-installed=true, bridge-singleton-present=true. `Kernel.Parcel classParcelMap-VWB-keys = IdentitySet ()` post-unload confirms Oracle's byte-equivalent quality gate.

**Step g — apply fixes + atomic commit batch:** 3 atomic commits shipped (full details in "Shipped commits" section below). All went through ASK + WAIT cadence per AGENTS.md.

### Phase P P5 Oracle consult (bg_3ae6c998, 4m 26s)

**Recommendation: Path 4 — project-scoped PowerShell launcher wrapper.** Concrete sketch: `src/vw-bridge/scripts/Start-VWBridge.ps1` invokes `C:\visualworks931\bin\win64\vwnt.exe C:\visualworks931\image\storedev64.im -filein <generated-load-chunk>` on launch. Generated chunk = `load.st` body + `\r\n!\r\n` appended (preflight asserts `load.st` doesn't contain `!`). Wrapper does preflight (`VW_BRIDGE_HOME` set, `vwnt.exe` + image + `load.st` exist), launches with `-err` redirect, then polls `/health` + verifies `.token` freshness (`LastWriteTimeUtc > captured oldTokenTime`).

**Critical caveat: `-filein` startup switch UNVERIFIED for VW 9.3.1 MAS image.** Oracle explicitly says "session-18 must empirically prove the exact `vwnt.exe storedev64.im -filein <path>` syntax BEFORE building the wrapper." Implementation BLOCKED on probe.

**Secondary concern (Oracle didn't flag):** `load.st` ends with `^'[load.st] OK token=...'` method-return. Top-level `^` inside chunk-evaluator block MAY raise `BlockContext>>cannotReturn:` when filed in via `-filein`. Works fine in `/eval` (verified twice session-17) but chunk file-in semantics may differ. Worth probing alongside `-filein` in session-18.

**Explicit REJECTIONS** (with reasons):
- **Topaz** — is a GemStone command-line tool, NOT for injecting Smalltalk into running `vwnt.exe`. The `.topaz` files near `storedev64.im` (`iferror.topaz`, `version.topaz`) are GemStone deployment scripts, not VW automation hooks. No `topaz*.exe` under `C:\visualworks931` confirmed.
- **D-snapshot (`ObjectMemory snapshotAs:thenQuit:`)** — bridge listener fork does NOT survive snapshot, derivative `.im` artifact increases recovery cost, drifts from `src/vw-bridge/` scoping.
- **Pure D-parcel auto-load (drop into `C:\visualworks931\parcels\`)** — no boot path calls `findAndLoadParcels` in this image (constraint), and `findAndLoadParcels` pops UI dialog (constraint).

**DEFERRED:** D-parcel + external trigger (`-pcl VWBridge.pcl`) — good for P6 once parcel exists; wrapper switches from `-filein` to `-pcl` when ready. Same wrapper, just different switch.

**Effort estimate (per Oracle):** 1-4 hours for P5 script + probes + docs update. **Confidence:** Medium-high (high on design, medium on `-filein` switch verification).

**Full design preserved in memory entity `Phase-P-P5-Oracle-recommendation`** (15 observations capturing tradeoff matrix + impl sketch + migration path + 8-failure mode analysis + 7-step checklist).

### Jasper mining for transferable patterns (Oracle wait, user-directed)

Mined `C:\Users\ammaganyane\tm\remote-desktop\remote-desktop\visual-works\repos\Jasper` — the GemStone analogue of our VW Bridge (VSCode extension + MCP server + GemStone server combo). 5 key transferable patterns documented:

1. **Jasper architecture is FUNDAMENTALLY DIFFERENT** — uses native GCI library (`libgcits` via `koffi`) for direct in-process GemStone session. NOT an HTTP bridge inside the image. GemStone runs as separate OS processes (`stoned`, `gem`, `netldi`) managed by shell commands. **Jasper has NO equivalent of our P5 problem** because there IS no in-image listener to auto-start.

2. **Subprocess + env-var launch pattern** ([`client/src/processManager.ts:191-227`](file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/repos/Jasper/client/src/processManager.ts#L191-L227)) — every stoned/netldi launch injects a full env dict (`GEMSTONE`, `GEMSTONE_SYS_CONF`, `GEMSTONE_GLOBAL_DIR`, `LD_LIBRARY_PATH`, etc.). **Reinforces our `VW_BRIDGE_HOME` pattern** — confirms env-var as install-root anchor is the right shape, all derived paths flow from there.

3. **No D-snapshot equivalent used in Jasper** — quiet evidence that snapshot-based auto-start is generally avoided even when available. **Reinforces deprioritizing our session-9 D-snapshot path** (Oracle also rejected it).

4. **MCP 3-layer architecture** (per [`docs/mcp-server.md`](file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/repos/Jasper/docs/mcp-server.md)) — extension host owning session + stdio proxy (`mcp-server/src/index.ts` per-client Node process forwarding JSON-RPC over Unix socket/named pipe) + HTTPS/SSE at `127.0.0.1:27101/sse` with self-signed TLS cert. Single-owner ownership model (first window to log in claims the socket). Auto-registration in `~/.claude.json` + Claude Desktop config. **For future Phase M: directly applicable reference design.** MVP tool surface would be 3 wrappers (`eval`, `windows`, `dialogs`) growing to Jasper's ~30.

5. **CONFIRMS our existing design via independent convergent evidence**: Jasper's [`describe_test_failure`](file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/repos/Jasper/TODO.md) (TODO.md L23-28) re-runs a single test with own `AbstractException` handler to **bypass `TestCase>>run`** because the standard run loop swallows the exception — **this is exactly our `Direct-invoke-gate-pattern` from sessions 15+16**. Independent convergent design validates our gate technique.

### Shipped 3 atomic commits + 1 handoff commit (session-17)

| Commit | Subject | Files |
|---|---|---|
| [`cdf3876`](#) | feat(stage3): load.st + unload.st orchestrators + parcel-ready core | 3 files: NEW load.st (78L), NEW unload.st (97L), MODIFIED VWBridge.st (auto-start chunk removed + class comment Stage 3 note, +8/-24) |
| [`f8f247f`](#) | docs(api-contract): session-17 Stage 3 + 3 carry-forward constraints | 1 file: knowledge/vw-image-api-contract.md (new Phase P P2 Stage 3 section + 3 carry-forward bullets + frontmatter bump, +68/-2) |
| [`25bc53d`](#) | probes: session-17 Stage 3 evidence (4 files) | 4 NEW files: _probe-session17-{phase0,primitives,post-load-verify,quality-gate}.st (+352) |
| this | docs(handoff): session-17 EOD - Stage 3 ship + P5 Oracle consult | THIS FILE |

### Memory MCP populated with session-17 facts

- **NEW entity** `Session-17-2026-06-21` (17 observations capturing full session arc)
- **NEW entity** `In-place-unload-load-quality-gate-test` (technique — single /eval call pattern that runs unload+load+verify inline; handler survives listener termination)
- **NEW entity** `load-unload-orchestrators` (technique — external orchestrator pattern; VWBridge.st no longer auto-starts; load.st orchestrates start; cold-start exception now via load.st)
- **NEW entity** `Phase-P-P5-Oracle-recommendation` (decision-record — full Oracle output captured: Path 4 PowerShell wrapper + vwnt.exe -filein, tradeoff matrix, 8-failure mode analysis, 7-step checklist)
- **+8 observations** on existing entities (ammaganyane decision preferences, VWB.VWBridge auto-start removed + load.st drives start, Phase-P-progress P5 Oracle DONE + BLOCKED on session-18 probe, tm-context-vw-bridge 3 new commits + working tree state, VW-image-storedev64 cold-start path now requires external orchestrator)
- **+12 new relations** (advances/modifies/delivers/ships/discovers/validates/orchestrates/verifies/satisfies/designs/extends/produces semantics)

Graph now has 24 entities + 42 relations across 17 sessions of work.

---

## Final state evidence (Phase P P2 Stage 3 quality gate)

| Predicate | Cycle 1 | Cycle 2 | Status |
|---|---|---|---|
| post-unload `VWB-present` is false | true | true | ✓ |
| post-unload `SimpleDialog-override-installed` is false | true | true | ✓ |
| post-unload `token-file-exists` is false | true | true | ✓ |
| post-unload `Kernel.Parcel classParcelMap-VWB-keys` empty | IdentitySet () | IdentitySet () | ✓ |
| post-load `VWB-class-count` = 4 | 4 | 4 | ✓ |
| post-load `SimpleDialog-override-installed` is true | true | true | ✓ |
| post-load `bridge-singleton-present` is true | true | true | ✓ |
| **TOTAL** | **6/6 + parcel** | **6/6 + parcel** | **IDEMPOTENCY PROVEN** |

Token rotated 4× during session: `3959495310063-903045` (session-16 EOD) → `3959501518637-726009` (first load.st test) → `3959501660889-966286` (second load.st test post-auto-start-removal) → `3959501833089-730222` (first quality gate cycle) → `3959501869549-282335` (second quality gate cycle / EOD value).

---

## Current state (end of session-17)

- **VW image:** unchanged from session-15. vwnt.exe PID **6236** started 6/21/2026 11:40:56 AM (3-session continuous through 15→16→17, no restart needed).
- **Bridge:** UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: `3959501869549-282335` (rotated 4× this session via load.st + quality gate cycles).
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` (4 classes in VWB namespace).
- **`Dialog useNativeDialogs: false`:** SET (carried from session-15 toggle).
- **`VW_BRIDGE_HOME` env var:** SET at User OS level (`C:\Users\ammaganyane\tm\tm-context\src\vw-bridge`). Persistent.
- **Bridge code on disk:** matches image. **VWBridge.st auto-start chunk REMOVED** (file went from 2691 to 2674 lines; parcel-ready for P6). load.st now drives cold-start. **VWBridge.st now files in WITHOUT side-effects** — proven via in-place unload+load+verify cycle (the file-in step doesn't auto-start; explicit start needed).
- **Git:** `main` is **3 commits ahead of `origin/main`** at EOD pending push: `cdf3876` → `f8f247f` → `25bc53d`. Push deferred to handoff commit + push together (about to do at handoff commit).
- **Untracked at EOD:** `opencode.json` (not author's), `plan/STRATEGIC-ASSESSMENT-2026-06-21.md` (session-13 deferred housekeeping — still untracked through session-17), `AGENTS.md` (session-15 deferred — your Option 2 from session-16+17 resume menus, NOT bundled into session-17 push).
- **MAS window state:** unchanged from session-13 (no /click etc this session — all gate runs via direct-invoke `tc perform:` or in-place unload+load body).

---

## NEW carry-forward constraints from session-17 (29-31)

All 3 added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) carry-forward summary + new section "Phase P P2 Stage 3 — load.st / unload.st orchestrators (session-17)" inserted after Workspace vs /eval section. Frontmatter `last_verified` bumped to session-17. Recap:

### 29. `load.st` / `unload.st` external orchestrators (Stage 3)

`VWBridge.st` no longer auto-starts. [`src/vw-bridge/load.st`](../src/vw-bridge/load.st) orchestrates env-var resolve + 5-file file-in + `VWB.VWBridge start` + `.token` write; [`src/vw-bridge/unload.st`](../src/vw-bridge/unload.st) is the inverse defensive cleanup. Cold-start exception now goes through `load.st` (was `VWBridge.st`). Parcel-readiness prerequisite for P6 satisfied.

### 30. In-place unload+load+verify via single `/eval` call

The `/eval` handler runs on a **forked process** from the listener and SURVIVES listener termination — can re-create the bridge inline within the same `/eval` body. Pattern: pre-snapshot → unload body (kills listener) → post-unload snapshot → load body (use dynamic `Smalltalk at: #VWB` lookups for the start step to avoid stale compile-time bindings) → post-load snapshot → assert 6 gate predicates. Saves the Workspace cold-start round-trip for quality-gate testing. Idempotency proven via 2 consecutive cycles in session-17 (token rotated 4×, bridge survived 3 listener-recycle events without wedge).

### 31. `removeSelector:` is naturally defensive on absent selector

`Object removeSelector: #absent` returns without raising; same for `SimpleDialog removeSelector: #absent`. The defensive `on: Core.Error do: [:ex | nil]` wrap is belt-and-suspenders but not strictly required for `removeSelector:`. Combined with constraints #12 (`class removeFromSystem`) + #13 (`NameSpace removeFromSystem` on empty namespace) and `tokenPath asFilename delete` defensive guard, the `unload.st` sequence is fully idempotent across multiple invocations.

---

## Pending tasks (session-18)

### Phase P P5 — probe `vwnt.exe -filein` syntax then implement Start-VWBridge wrapper

**FIRST ACTION for session-18:** empirically probe whether `vwnt.exe storedev64.im -filein <path>` is a valid invocation in VW 9.3.1 MAS image. Oracle's full design (`Phase-P-P5-Oracle-recommendation` memory entity) HINGES on this. Options for probing:

1. **Web search** "VisualWorks 9.3.1 command line filein" for official Cincom docs (non-destructive, ~5 min)
2. **Local docs check** `C:\visualworks931\doc\` for HT/PDF references to startup switches
3. **Binary string scan** `Select-String -Pattern '-filein|-fileIn|-doit|-pcl' -Path C:\visualworks931\bin\win64\vwnt.exe` (PowerShell binary inspection, non-destructive)
4. **Empirical test** — kill `vwnt.exe`, launch with `-filein` + tiny test chunk (kills bridge — last resort; ALSO need to verify top-level `^` works in chunk file-in)

**ALSO probe in session-18 (orthogonal):** top-level `^` semantics in chunk file-in. `load.st` ends with `^'[load.st] OK token=...'` — works in `/eval` (verified twice session-17) but chunk file-in MAY raise `BlockContext>>cannotReturn:`. If it does, modify `load.st` to not use top-level `^` OR create a separate `bootstrap.st` for the file-in trigger that doesn't have the return.

**If `-filein` works** → implement Oracle's design: [`src/vw-bridge/scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/) + [`.bat`](../src/vw-bridge/scripts/) wrapper with preflight (env var + file existence) + generated chunk from load.st + launch with `-err` redirect + poll `/health` + verify `.token` freshness. Add `.generated/` + `vwbridge-autostart.err` to gitignore. Run P5 quality gate (5 cold-start cycles). Update AGENTS.md cold-start section to use `Start-VWBridge.ps1` instead of Workspace paste. Update vw-image-api-contract.md with verified `-filein` behavior.

**If `-filein` does NOT work** → re-consult Oracle with the new constraint. Possible fallback paths: PowerShell + Windows UI automation (fragile); Topaz inspection deeper (Oracle said no but worth re-verifying); custom launcher that uses GCI-like mechanism (probably doesn't exist for VW).

### Phase P remaining deliverables (P6, P7, P8)

Unchanged from session-15+16+17 handoffs. ALL gated on P5 ship:

| # | Deliverable | Status | Notes |
|---|---|---|---|
| P6 | Build `.pcl` parcel via `Kernel.Parcel loadParcelFrom: aFilename` | ⏳ Depends on P5 | Wrapper switches from `-filein` to `-pcl` once parcel ships. Headless parcel-load API verified session-11. |
| P7 | `INSTALL.md` (env-var setup + parcel load + smoke test) | ⏳ Depends on P6 | Zero-context developer reaches /health on first try |
| P8 | `GET /version` endpoint (parcel version + build timestamp + commit SHA) | ⏳ Depends on P6 | Augments existing /health |

### Phase M (MCP server for VW dev) — design inputs from Jasper

Once P5 ships, Phase M unblocks. **Jasper's MCP 3-layer architecture is the reference design**: extension host (the bridge HTTP server) + stdio proxy (Node script forwarding JSON-RPC via Unix socket/named pipe) + HTTPS/SSE for URL-based clients. MVP tool surface: 3 wrappers around existing endpoints (`eval`, `windows`, `dialogs`). Auto-registration in `~/.claude.json`. Single-owner via socket binding. See Jasper's [`docs/mcp-server.md`](file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/repos/Jasper/docs/mcp-server.md) for full reference.

### Carry-overs (still pending from sessions 7–11)

- EXPLORATION-PLAN step 3 — 3-deep menu navigation
- EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree
- End-to-end verify of `#id` / `#imcNr` / `#groupScheme` no-modal `partialFind:` paths via bridge

### Housekeeping (deferred since session-13/15/17)

- Commit [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) (session-13 deferred — still untracked through session-17)
- Commit `tm-context/AGENTS.md` (session-15 deferred — your Option 2 from session-16+17 resume menus, project-scoped AI operating rules)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety
- Switch `OS.CEnvironment userEnvironment` reads to `OSSystemSupport getVariable:` (silence the deprecation warning that fires 4× per startup; probe semantics first — missing-key behavior may differ)
- **NEW**: AGENTS.md cold-start section update once P5 ships (replace Workspace paste with `Start-VWBridge.ps1`)

### Stale doc cleanup (assessed session-16 — 11 files flagged, deferred since)

- Archive obsolete pre-session-3 docs: `src/vw-bridge/{HANDOFF.md, VWBridge-working.md, SESSION-RESUME.md, E2E-DISTANCE.md}` (DELETE, history in git); `knowledge/CONSOLIDATION-NOTES.md`, `docs/HANDOFF.md`, `docs/poc-phase-1.md`, `plan/STRATEGIC-ASSESSMENT-2026-06-20.md` (move to archive/ subfolders)
- Update stale status frontmatters: PLAN-PHASE-B + PLAN-PHASE-F mark SHIPPED with retrospective; vw-bridge-known-issues.md title v0.8.5 → v0.9.1
- Optionally refresh docs/ARCHITECTURE-REVISED.md for session-16/17 reality (14 endpoints, Phase P framework, Stage 3 ship)

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/load.st`](../src/vw-bridge/load.st) | **NEW** (78 lines) — external load orchestrator. Resolves VW_BRIDGE_HOME → files in 5 sources → starts bridge → writes .token. |
| [`src/vw-bridge/unload.st`](../src/vw-bridge/unload.st) | **NEW** (97 lines) — defensive idempotent cleanup. Captures tokenPath → stops bridge → deletes .token → removes SimpleDialog override → removes 4 VWB classes reverse-dep → removes empty VWB namespace. |
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | Auto-start chunk REMOVED (L2671-2691 of pre-session-17 version) + class comment updated with v0.9.2 Stage 3 note. File went 2691 → 2674 lines. PARCEL-READY for P6. |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | +68 lines — new "Phase P P2 Stage 3 — load.st / unload.st orchestrators (session-17)" section + 3 carry-forward bullets (29-31) + frontmatter `last_verified` + `source_sessions` bump. |
| `src/vw-bridge/probes/_probe-session17-phase0.st` | **NEW** — bridge identity check (Phase 0 step 5) |
| `src/vw-bridge/probes/_probe-session17-primitives.st` | **NEW** — defensive removeSelector + pre-load state snapshot + Kernel.Parcel introspection |
| `src/vw-bridge/probes/_probe-session17-post-load-verify.st` | **NEW** — post-load.st state verification (used twice) |
| `src/vw-bridge/probes/_probe-session17-quality-gate.st` | **NEW** (217 lines) — in-place unload+load+verify cycle in single /eval body. Run twice consecutively for idempotency proof. |
| [`knowledge/HANDOFF-2026-06-21-session17.md`](./HANDOFF-2026-06-21-session17.md) | **THIS FILE** |

---

## Important decisions this session

- **Picked Option 1 (Phase P P2 Stage 3 — load.st + unload.st)** at session-17 start per session-16 chosen direction. Natural unblocked next deliverable now that P2 quality gate was SATISFIED.
- **In-place unload+load+verify in single /eval call** — bet that the /eval handler survives listener termination (different process from listener). Empirically validated. Eliminated the Workspace cold-start round-trip that would otherwise be needed for quality-gate testing. SAVES TIME and is now a reusable technique (memory entity `In-place-unload-load-quality-gate-test`).
- **Dynamic class lookup in load section** (`Smalltalk at: #VWB ifAbsent: [nil] ifNotNil: [:ns | ns at: #VWBridge ifAbsent: [nil]]`) for the `start` step inside the quality-gate body — defensive against stale compile-time bindings to the OLD class object that unload removed. Direct `VWB.VWBridge` refs also worked empirically (VW's `ResolvedDeferredBinding` re-resolves on each use through namespace lookup chain), but dynamic lookup is belt-and-suspenders for self-modifying code paths.
- **Removed auto-start chunk from VWBridge.st in same commit as load.st/unload.st creation** — they're one logical change (ship Stage 3 deliverables + parcel-readiness). Atomic commit appropriately.
- **Fired Oracle for P5 in background** while doing Jasper mining as non-overlapping prep work per user direction. Oracle 4m 26s, returned with Path 4 (PowerShell wrapper + vwnt.exe -filein) recommendation. Critical caveat: -filein syntax UNVERIFIED, session-18 probe required.
- **Mined Jasper systematically while Oracle ran** — read README + mcp-server.md + topazFileIn.ts + processManager.ts + fileInManager.ts. Synthesized 5 transferable patterns. Identified that Jasper's MCP 3-layer architecture is the reference design for our future Phase M.
- **Accepted Oracle's blocker** — P5 implementation BLOCKED on session-18 -filein probe. Did NOT try to implement the wrapper this session (per Oracle policy: don't ship implementation decisions Oracle was asked to decide; here, Oracle explicitly said "session-18 must prove" before building).
- **Pushed 4 commits at session EOD with explicit auth** (Option 1 in wrap-up question). Clean cadence: ask + wait + push.

---

## Lessons learned

### What went well

- **Quality gate test in single /eval call** — the boldest design bet of the session paid off. The /eval handler survives listener termination because it's on a different forked process. This is now a reusable technique that future Stage-equivalent migrations can leverage for cheap idempotency testing.
- **Probing primitives BEFORE writing load.st/unload.st** — the `_probe-session17-primitives.st` step revealed that `removeSelector:` is naturally defensive (no `on: Error do:` wrap strictly needed). Saved a fix-iterate cycle. Documented as constraint #31.
- **Jasper mining as non-overlapping Oracle wait work** — the user's direction to mine Jasper was high-value. We got: (a) confirmation our Direct-invoke-gate-pattern matches Jasper's independent design, (b) reference design for future Phase M, (c) reinforcement that env-var + subprocess is the right launch shape, (d) explicit evidence snapshot-based startup is generally avoided.
- **Memory MCP captured the design** — Oracle's 15-observation recommendation is preserved as `Phase-P-P5-Oracle-recommendation` entity. Session-18 starts with full Oracle context available, not just transcript scrollback. Cheap to consult.

### What I'd do differently

- **`load.st` ending in `^` was a mistake (in hindsight)** — works perfectly for /eval (which evaluates the body as an implicit method) but I didn't think about chunk file-in semantics. Oracle's design uses `-filein` which evaluates chunks, where top-level `^` MAY raise `BlockContext>>cannotReturn:`. New rule: scripts intended to be both /eval-able AND file-in-able should NOT use top-level `^` — use a final non-returning expression (`Transcript show: '...DONE'`) instead. Will flag to fix in session-18 alongside the -filein probe.
- **Should have asked Oracle to specifically validate the `^` concern** — my prompt was exhaustive but missed this corner case. When asking Oracle for a recommendation involving running OUR code via a new mechanism, list explicit corner cases that need verification.

### Discoveries documented

- **3 new carry-forward constraints** (29-31) in `vw-image-api-contract.md`. The doc has grown to 31 constraints across 14 sessions of work.
- **3 new memory entities** (`Session-17-2026-06-21`, `In-place-unload-load-quality-gate-test`, `load-unload-orchestrators`) + 1 decision-record (`Phase-P-P5-Oracle-recommendation`) + extensions to existing entities. Knowledge graph now has 24 entities + 42 relations.

---

## Resume hooks

- **Next-session anchor:** this file + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (31 carry-forward constraints documented as of session-17).
- **Memory MCP context:** run `memory_search_nodes` for "session" / "VWBridge" / "Phase-P" / "ammaganyane" / "Direct-invoke-gate-pattern" / "Latent-test-bug-indexOfSubCollection" / "Latent-screenshot-test-helper-bug" / "EndOfStreamNotification-fileIn-trap" / "Namespace-at-put-binding-notification" / "In-place-unload-load-quality-gate-test" / "load-unload-orchestrators" / "Phase-P-P5-Oracle-recommendation" at start of session-18 to absorb stored facts.
- **First action options for session-18:**
  1. **Probe `vwnt.exe -filein` syntax** (3 non-destructive paths: web search, local docs, binary string scan; OR 4th destructive: kill vwnt.exe + empirical test) — UNBLOCKS Oracle's Path 4 design
  2. **Also probe top-level `^` in chunk file-in** — orthogonal Oracle-didn't-flag concern with `load.st`
  3. If -filein works → **implement Start-VWBridge.ps1+.bat per Oracle sketch** + run P5 quality gate (5 cold-start cycles)
  4. If -filein doesn't work → **re-consult Oracle** with new constraint
  5. **Commit tm-context/AGENTS.md + plan/STRATEGIC-ASSESSMENT-2026-06-21.md** housekeeping (deferred since session-13/15)
  6. **Phase P P6/P7/P8** still gated on P5
  7. **Phase M planning** can start in parallel (Jasper's MCP design is the reference; not gated on P5 directly, but P5 makes Phase M deployable to others)
  8. **Carry-overs from sessions 7-11** (EXPLORATION-PLAN steps 3-4, #id/#imcNr/#groupScheme verify) — independent of Phase P critical path
- **Phase 0 verification for session-18 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.9.1"}`
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token (was `3959501869549-282335` at session-17 EOD; will rotate ONLY if vwnt.exe restarted)
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect **0 commits ahead** (session-17 pushed all 4)
  - `git status --short` — expect 2-3 pre-existing untracked (AGENTS.md if still untracked, opencode.json, plan/STRATEGIC-ASSESSMENT-2026-06-21.md)
  - If vwnt.exe restarted since session-17: **NEW PROCEDURE — use load.st instead of VWBridge.st directly** (VWBridge.st no longer auto-starts post-Stage 3). Cold-start via VW Workspace paste of `src/vw-bridge/load.st` body. Re-read `.token` after load.st. `Dialog useNativeDialogs: false` re-toggle. `VW_BRIDGE_HOME` env var will auto-inherit (set at User OS level session-15). **If session-18 first action ships Start-VWBridge.ps1, that becomes the canonical cold-start path going forward.**
- **Bridge state at session-17 EOD:** UP at `VWB.VWBridge` v0.9.1, all session-17 work in effect, in-place unload+load+verify cycle proven idempotent (2 consecutive cycles), 3 commits about to push including this handoff.

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits local-only) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-15) | Pushed session-14 commits; fixed latent binding bug; direct-invoke gate pattern proven; partial gate (10/20 VWBridgeTest) | v0.9.1 | A, B, F, partial P (more verified) |
| 2026-06-21 (session-16) | Systematic gate sweep COMPLETE: 48/48 unblocked GREEN + 7 known-blocked Bug#5; 2 latent bug fixes + 3 new techniques; 5 new carry-forward constraints (24-28); 5 commits pushed including handoff; P2 quality gate SATISFIED | v0.9.1 | A, B, F, P2 quality gate SATISFIED |
| 2026-06-21 (session-17) | **Phase P P2 Stage 3 SHIPPED (load.st + unload.st + auto-start chunk removal + parcel-readiness for P6); quality gate idempotency proven via 2 in-place unload+load+verify cycles in single /eval call; P5 Oracle consult complete (Path 4 wrapper + vwnt.exe -filein); Jasper mining synthesized; 3 new carry-forward (29-31); 4 commits pushed including handoff** | **v0.9.1** | **A, B, F, P2 Stage 3 SHIPPED + P5 designed** |
| _(session-18)_ | Probe -filein + implement Start-VWBridge.ps1 (P5 ship) + maybe P6 parcel | _(v0.9.x or v0.10.0)_ | A, B, F, P partial++ |
| _(future)_ | Phase P P6 + P7 + P8 ship | _(v0.10.0 likely)_ | A, B, F, P |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
