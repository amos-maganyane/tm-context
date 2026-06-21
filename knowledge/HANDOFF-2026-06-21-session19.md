# Handoff — Phase P P6 SHIPPED via Cursor>>showWhile: monkey-patch + canonical parcelOutOn: (session 2026-06-21 session-19 EOD)

**Written:** session-19 EOD after Phase P P6 ship (`VWBridge.pcl` + `VWBridge.pst` binary parcel artifacts at `src/vw-bridge/parcels/`; `parcel-start.st` post-load script; `Start-VWBridge.ps1 -Mode FileIn|Parcel` wrapper update) + verification through 5-cycle quality gate (mean 8.43s/cycle, faster than P5) + 6 new carry-forward constraints (35-40) + doc updates (api-contract Phase P P6 section, PHASE-PROGRESS P6 SHIPPED). Five atomic commits about to push together with this handoff: `feat(p6)` parcel artifacts + wrapper + parcel-start.st; `docs(api-contract)` Phase P P6 section + constraints 35-40; `docs(plan)` PHASE-PROGRESS.md P6 SHIPPED; `probes` session-19 evidence (24 files); this handoff.

**For session-20:** (1) **Phase P P7** — write `INSTALL.md` documenting both FileIn and Parcel install paths (env-var setup + Start-VWBridge.ps1 invocation + smoke test + troubleshooting). Estimated 1 day. (2) **Phase P P8** — `GET /version` endpoint returning parcel version + build timestamp + commit SHA. Estimated 0.5 day. (3) Optionally start **Phase M** (MCP for VW dev) MVP in parallel — Jasper 3-layer reference design captured session-17; bridge now fully deployable via binary parcel makes onboarding-developer milestone closer. (4) Optionally revisit VWBridge-Tests.pcl build (wedged on 3-class addEntiretyOfClasses: this session; not on production critical path).

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session18.md`](./HANDOFF-2026-06-21-session18.md) remains session-18 EOD; this file is session-19 EOD.

---

## User direction this session (condensed)

- Resume prompt with 6 anchor docs + memory MCP context (15 search terms, 25 entities + 48 relations populated through session-18) + Phase 0 verification + 6 standing-decisions menu.
- Picked **Option 1 (Phase P P6 .pcl parcel build)** at session-19 start per resume prompt recommendation — next critical-path bottleneck for Phase P.
- After parcel granularity question: picked **Option A (2 parcels: VWBridge.pcl Core+Patches + VWBridge-Tests.pcl)** — matches session-14 Stage 1 split + production-vs-dev hygiene.
- After 5 bridge wedges investigating CodeWriter direct call path: when I surfaced the cost reframing, replied **"pivoting defeats our packaging effort"** — clear strategic direction to keep binary .pcl deliverable, NOT pivot to chunk-format fallback. Decisive.
- After surfacing "what are we struggling with?" with research suggestion (docs / context7 / VW): responded **"what are we struggling with? docs don't help? context7mcp? visualworks?"** — directly prompted me to research VW docs + context7 MCP + websearch before more blind probing. Course-correction that saved hours.
- After 4 wedges → research pivot → Cursor monkey-patch + parcelOutOn: WORKING + first parcel built + in-place verify GREEN + Tests parcel wedged: picked **"Keep investigating CodeWriter direct call (Oracle primary)"** initially but then accepted natural pivot to Cursor monkey-patch (Oracle Backup 1) after the empirical evidence convergence.
- After parcel-mode cycle 1 GREEN: implicit auth via "continue" to run 4 more cycles back-to-back (matches session-18 pattern).
- Mid-cycle-1 dialog popup ("Failed to find source file VWBridge.pst. Ok to load without target source?"): surfaced the dialog — user provided real-world feedback that the headless image was hung on a UI dialog. Recovery + .pst copy alongside .pcl fixed it.
- After P6 quality gate GREEN + session-19 wrap-up question: picked default **"Full P6 ship + docs + handoff + push (5 commits, EOD-style) (Recommended)"** — matches session-17 + session-18 EOD pattern (clean close with handoff + push as one batch).
- Throughout: respected AGENTS.md commit cadence (ASK + WAIT for OK before commit batch).

---

## Work completed in session-19

### Phase 0 verification (all 8 steps GREEN — matches session-18 EOD exactly)

- `/health` → `{"status":"ok","version":"0.9.1"}` ✓
- `.token` = `3959506095072-199161` (unchanged session-18 EOD, no vwnt.exe restart at session start) ✓
- 0 commits ahead of origin/main (clean push base from session-18) ✓
- 1 pre-existing untracked: `opencode.json` only (working tree clean of all author's items as of s18 EOD) ✓
- HEAD = `04b33cd51dce24b27000b63faaba9bcfe47f73e7` ✓
- Bridge class identity: env=`#VWB`, top-level VWBridge=`nil`, 4 classes (VWBridge + 3 Test*), port 9876, token-matches-handoff=true, uses-native-dialogs=false ✓
- vwnt.exe PID 8584 continuous since 6/21/2026 2:48:10 PM (single-session run from s18 cycle 5 EOD) ✓
- VW_BRIDGE_HOME set at User OS level ✓

### Probe series (24 probes, all session-19)

Per AGENTS.md "Probe before commit (cheap /eval probe before any structural change)" — extensive empirical investigation before any destructive parcel write:

**Probes 1-7 (introspection, non-destructive):**
- 1: Kernel.Parcel build/save API surface (`createParcelNamed:` class-side; `parcelOutOn:withSource:hideOnLoad:republish:backup:` inst-side; `fileOutOn:`/`writeDefinition:on:`/`writeMethods:on:` chunk variants)
- 2: Package class location (none top-level; `DolphinCompatibility.Package` shim only; Store namespace has 238 keys including AbstractPundleLoader)
- 3: VWB package state (`VWB.VWBridge` class>>category='VWBridge-Core', Test classes 'VWBridge-Tests', SimpleDialog>>choose:* method category='*VWBridge-Patches mas-bug2-fix')
- 4: Stock .pcl format inspection (binary "Smalltalk Binary Storage File" magic; UIPainter.pcl 670KB; Refactory-Namespace.pcl 946B smallest)
- 5: Kernel.Parcel removal API (`removeParcelNamed:` exists) + Bundle-like class search (no top-level Bundle/Pundle classes)
- 6: SANDBOXED `createParcelNamed: 'VWBridge-Core'` → discovered parcel is EMPTY (definedThings=IdentitySet(), summary='Text for an Empty Parcel'); cleanup attempt failed because `removeParcelNamed:` raises Notification
- 7: Cleanup leaked parcel via Notification-resume + enumerate Parcel content-add API (`addEntiretyOfClass:`, `addEntiretyOfClasses:`, `addSelector:class:`, `addNameSpace:`, 60+ setters total)

**Probes 8-15 (CodeWriter direct path investigation — eventually deferred):**
- 8: First build attempt — `parcelOutOn:` + writeStream binary → MNU asLogicalFileSpecification + **bridge wedge #1**
- 9: Diagnostic — `savedParcel:to:` is UI-interactive, `fileOutOn:` is chunk-format, `fileOutAsFor:` is UI-interactive; writeStream is `ExternalWriteStream` (no asLogicalFileSpecification), Filename DOES respond to asLogicalFileSpecification
- 10: Second build attempt — `parcelOutOn:` + Filename (not Stream) → same MNU + **bridge wedge #2**
- 11: writeToParcelFileNamed:... fingerprint + parcel codeComponent absence
- 12: Inventory after recovery #2 (Empty parcel responds to almost nothing; codeComponent setter doesn't exist on Parcel — must be on CodeWriter)
- 13: CodeWriter discovery — `Smalltalk.CodeWriter` (env=#Kernel, super=ObjectTracer, 123 inst-side selectors), `writeToParcelFileNamed:...` is on CodeWriter inst-side
- 14: codeComponent setup test (try `parcel codeComponent: parcel` self-ref) → MNU (no setter exists at all on Parcel) → confirmed setter must be on CodeWriter
- 15: CodeWriter direct sandbox build (writer codeComponent: parcel; writer writeToParcelFileNamed: ...) → MNU `removeKey:ifAbsent:` on `nil` receiver. ChangeSet/SourceFileManager setup that parcelOutOn: would do is missing. **CodeWriter direct path requires reverse-engineering that we can't easily do without sources.**

**Bridge wedges #3-5** during this investigation (delayed-wedge pattern: successful operation, then asynchronous wedge from background broadcast/dependent firing).

**Research detour** (user-prompted "what are we struggling with? docs don't help? context7mcp? visualworks?"):
- pypdf extraction from AppDevGuide.pdf, SourceCodeMgmtGuide.pdf, ToolGuide.pdf → AppDevGuide documents parcel build ONLY through UI (Runtime Packager / System Browser at p478-480; "Parcel > Build > Add Changes" UI menu at p57)
- Context7 — no VW-specific library (only generic Smalltalk/Pharo/GNU Smalltalk)
- Websearch → **StoreCI-Building** (https://github.com/randycoulman/StoreCI) — community CI tool that implements its own `ParcelWriter` class to fill the headless-build gap. Used via `-pcl /path/to/StoreCI-Building` + CLI args.
- Image probe for ParcelWriter/ParcelBuilder/PundleWriter classes → **ALL ABSENT** in our image. Store namespace has only "ForParcel" adapter classes (PackageForParcel, PundleForParcel, etc. — internal wrappers, not headless build APIs).

**Strategic conclusion**: VW 9.3.1 ships parcel build only through UI. StoreCI-Building is the workaround but absent. Three remaining paths: (a) reverse-engineer CodeWriter setup (already failed), (b) Cursor>>showWhile: monkey-patch (Oracle Backup 1), (c) chunk-format pivot (Oracle Backup 2). User direction "pivoting defeats our packaging effort" → take Path (b).

**Probes 16-24 (Cursor monkey-patch path + verification):**
- 16: CodeWriter method fingerprints (all selectors `showWhile?=false` — the wedge IS in parcelOutOn: itself via `Cursor wait showWhile:`, not in any CodeWriter delegate)
- 17: First Cursor monkey-patch attempt (passed `withSource: false` boolean) → MNU asLogicalFileSpecification on `False` receiver (boolean). Oracle's hint validated: withSource: is a Filename arg.
- 18: **WORKING BUILD** — Cursor monkey-patch + Filename withSource: pstPath → VWBridge.pcl (52,478 bytes) + VWBridge.pst (128,285 bytes) successfully written. Bridge alive, registry restored to 112, ensure: ran the methodDictionary swap restore cleanly.
- 19: VWBridge-Tests.pcl build attempt (3 test classes) → **bridge wedge #6** during parcelOutOn: with the same Cursor monkey-patch. Some OTHER UI/dependency path tripped. Tests parcel deferred.
- 20: **In-place unload + loadParcelFrom: + verify** — PHASE 4 loadParcelFrom: returned cleanly: `Parcel parcelNamed: 'VWBridge'`. PHASE 5 post-load: VWB ns + VWBridge class + SimpleDialog override with EXACT correct category `'*VWBridge-Patches mas-bug2-fix'`. PHASE 6 bridge start: `start-ok, token=3959510605650-211227`. PHASE 7 .token written for /eval auth. **Parcel verifiably WORKS.**
- 21-24: P6 quality gate (5 parcel-mode cold-start cycles, all GREEN, mean 8.43s) + post-gate state probe + post-recovery probes.

### Cursor>>showWhile: monkey-patch technique (REUSABLE)

The key insight: VW APIs that wrap their work in `Cursor wait showWhile: [block]` (a UI progress notifier on the Cursor INSTANCE method, not Dialog) wedge headless bridge listeners. `Smalltalk.Dialog useNativeDialogs: false` (Bug #2 fix gate) does NOT prevent this — the path doesn't go through SimpleDialog.

Pattern:

```smalltalk
| oldMethod patchInstalled |
oldMethod := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true]
        on: Core.Notification do: [:n | n resume].
    patchInstalled ifTrue: [
        "... call canonical UI-wrapped API which now skips the UI ..."
    ]
] ensure: [
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: oldMethod]].
```

`methodDictionary at:put:` restoration works even with stripped sources because the saved `oldMethod` is the original `CompiledMethod` object — direct dictionary swap bypasses recompilation. Reusable for any headless invocation of canonical VW APIs that wrap work in `Cursor wait showWhile:` (parcelOutOn:, RuntimePackager save, Store publish, etc.).

Memory entity: `Cursor-showWhile-monkeypatch-technique` (7 observations).

### Parcel build flow (session-19 ship)

```smalltalk
parcel := Kernel.Parcel createParcelNamed: 'VWBridge'.
parcel addNameSpace: VWB.
parcel addEntiretyOfClass: VWB.VWBridge.
parcel addSelector: #choose:labels:values:default:for: class: SimpleDialog.
parcel
    parcelOutOn: 'C:\...\parcels\VWBridge.pcl' asFilename
    withSource: 'C:\...\parcels\VWBridge.pst' asFilename
    hideOnLoad: false
    republish: false
    backup: false.
[Kernel.Parcel removeParcelNamed: 'VWBridge'] on: Core.Notification do: [:n | n resume].
```

Wrapped in the Cursor monkey-patch above. `withSource:` MUST be a Filename (not boolean — Oracle's hint validated empirically).

### Wrapper Parcel mode

[`Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) gained a `-Mode FileIn|Parcel` switch. Parcel mode invocation:

```
vwnt.exe storedev64.im -pcl <VWBridge.pcl> -filein <chunk-wrapped parcel-start.st> -err <err>
```

AppDevGuide.pdf p470 documents left-to-right command-line processing — `-pcl` BEFORE `-filein` ensures parcel loads first, then post-load start script runs. The script (parcel-start.st chunk-wrapped) calls `VWB.VWBridge start` + writes `.token`.

### .pst companion gotcha

Mid-gate cycle-1 (parcel mode initial test): VW popped `'Failed to find source file VWBridge.pst. Ok to load without target source?'` dialog — the .pcl embeds a reference to its .pst source companion. Without .pst alongside, headless image startup wedges on the dialog (90s /health timeout, 36 polls).

Fix: copied `VWBridge.pst` from `.generated/parcels/` to `src/vw-bridge/parcels/` (committed binary distribution, matches stock VW convention — UIPainter.pst lives alongside UIPainter.pcl). Cycle 1 retry GREEN. Alternative clean fix (deferred): rebuild parcel with `hideOnLoad: true` to suppress source dependency.

### Phase P P6 quality gate (Oracle 5-cycle spec, all parcel mode)

5 sequential cycles via `Start-VWBridge.ps1 -Mode Parcel -KillExisting`:

| Cycle | Elapsed | PID transition | Token transition | All verifications |
|---|---|---|---|---|
| 1 (dry-run, manual) | ~5s | 2232 → 3632 | `…-564079` → `…-65801` | ✓ |
| 2 | **9.01s** | 3632 → 8872 | `…-65801` → `…-65801` (suffix repeated) | ✓ |
| 3 | **8.25s** | 8872 → 7960 | `…-65801` → `…-65801` | ✓ |
| 4 | **8.16s** | 7960 → 5864 | `…-65801` → `…-65801` | ✓ |
| 5 | **8.32s** | 5864 → 7532 | `…-65801` → `…-65801` | ✓ |

**Mean cycle time 8.43s** for cycles 2-5 (slightly faster than P5's 9.11s — parcel-start.st is shorter than load.st 5-file file-in). **/health 200 in 1500ms** (3 polls) every cycle. **`useNativeDialogs: false`** re-armed every cycle. **All 5 PIDs distinct**. **Token-suffix repeat** (`-65801` across cycles 2-5) — same pattern flagged session-18; token-entropy probe a future housekeeping idea.

**Post-cycle-5 deep state probe** confirmed **lean production install**:
- env=#VWB, top-level=nil (Stage 2 invariant)
- **VWB has 1 class** (`#VWBridge` only — no Test classes loaded)
- port 9876
- SimpleDialog override category EXACT match `'*VWBridge-Patches mas-bug2-fix'`
- usesNativeDialogs=false

**Production parcel mode delivers a strictly leaner image than FileIn mode** (which loads all 4 classes via file-in of 5 source files). Trade-off: tests not loaded means /eval gate runs require switching to FileIn mode or loading the deferred Tests parcel separately.

### 9 bridge recoveries (session-19 wedge log)

| # | Trigger | Token transition | Time |
|---|---|---|---|
| 1 | parcelOutOn: + Stream MNU | `…-199161` (s18 EOD) → `…-163522` | ~9s |
| 2 | parcelOutOn: + Filename MNU | `…-163522` → `…-811541` | ~9s |
| 3 | Delayed wedge after probe 12 | `…-811541` → `…-163522` | ~9s |
| 4 | Delayed wedge after probe 14 | `…-163522` → `…-104794` | ~9s |
| 5 | Delayed wedge after probe 18 (successful build, then wedge) | `…-104794` → `…-811541` | ~9s |
| 6 | Recovery for pypdf research / fresh state | (FileIn) `…-811541` → `…-564079` | ~9s |
| 7 | Dialog popup (Failed to find source file .pst) | `…-564079` → unchanged (FileIn recovery) | ~9s |
| 8 | Mode-switch recovery before retry | (FileIn) `…-564079` → cycle-1 dry-run | ~9s |
| _gate_ | 5 parcel-mode cycles (NOT recovery — quality-gate cycling) | through `…-65801` final | 35s |

**Wrapper validated under 9 unplanned/cycling launches this session.** Empirical confidence in P5 wrapper is HIGH after this stress test.

### Shipped 5 atomic commits (session-19, EOD)

| # | Commit subject | Files |
|---|---|---|
| 1 | `feat(p6): VWBridge.pcl + parcel-start.st + Start-VWBridge.ps1 -Mode Parcel` | NEW: `src/vw-bridge/parcels/VWBridge.pcl` (52KB binary), `src/vw-bridge/parcels/VWBridge.pst` (128KB binary), `src/vw-bridge/parcel-start.st`; MODIFIED: `src/vw-bridge/scripts/Start-VWBridge.ps1` (Mode FileIn\|Parcel + -pcl arg) |
| 2 | `docs(api-contract): Phase P P6 section + carry-forwards 35-40` | MODIFIED: `knowledge/vw-image-api-contract.md` (Phase P P6 section ~140 lines + 6 new carry-forward bullets + frontmatter + cold-start path table updated) |
| 3 | `docs(plan): PHASE-PROGRESS.md P6 SHIPPED + Phase P at ~90%` | MODIFIED: `plan/PHASE-PROGRESS.md` (10 section updates: quick status, project goals s19 column, per-phase table, Phase P deliverable breakdown, critical path graphic, effort remaining, near-term milestones, per-session impact log, carry-forward count s19, memory MCP entity count s19) |
| 4 | `probes: session-19 P6 evidence (24 files)` | NEW: 24 `_probe-session19-*.st` files (full audit trail: API discovery + CodeWriter investigation + Cursor monkey-patch resolution + verification) |
| 5 | `docs(handoff): session-19 EOD - Phase P P6 SHIPPED` | THIS FILE |

### Memory MCP populated with session-19 facts

- **+3 new entities**:
  - `Session-19-2026-06-21` (session, ~10 observations capturing full session arc + 9 recoveries + breakthrough)
  - `parcelOutOn-wedges-bridge-via-showWhile` (code-bug, 8 observations on the root cause + workaround)
  - `Cursor-showWhile-monkeypatch-technique` (technique, 7 observations on the reusable pattern)
  - `Phase-P-P6-shipped` (milestone, 9 observations capturing artifacts + quality gate + lessons)
- **+5 new relations**: Session-19 discovers Cursor-monkeypatch-technique; Session-19 delivers Phase-P-P6-shipped; Phase-P-P6-shipped advances Phase-P-progress; Cursor-monkeypatch enables Phase-P-P6-shipped; Phase-P-P6-shipped resolves parcelOutOn-wedges-bridge-via-showWhile.
- **+~40 observations** across new + existing entities (VW-image-storedev64 parcel API, Phase-P-progress P6 SHIPPED, ammaganyane session-19 decisions, etc.)

Graph at 27 entities + 47 relations as of session-19 EOD.

---

## Final state evidence (Phase P P6 quality gate satisfied)

| Predicate | All 5 cycles | Source |
|---|---|---|
| Wrapper exit 0 in Parcel mode | ✓ | Start-VWBridge.ps1 output |
| Elapsed under 90s health-poll budget | ✓ (mean 8.43s) | Wrapper timing |
| `vwnt.exe` PID rotated (kill + new launch) | ✓ (5 distinct PIDs) | `Get-Process -Name vwnt` |
| `.token` rotated | ✓ (5 distinct tokens-as-wholes) | `.token` file content + mtime |
| `/health` 200 OK with version 0.9.1 | ✓ (3 polls / 1500ms per cycle) | curl.exe `/health` |
| `VWB.VWBridge environment name` = `#VWB` | ✓ (post-cycle-5 probe) | _probe-session19-post-gate-state.st |
| `Smalltalk at: #VWBridge` = `nil` (Stage 2 invariant) | ✓ | same probe |
| `VWB` keys size = 1 (production parcel = VWBridge ONLY) | ✓ | same probe |
| `singleton-port` = 9876 | ✓ | same probe |
| SimpleDialog override category = `'*VWBridge-Patches mas-bug2-fix'` | ✓ (Bug #2 fix preserved through parcel build + load) | same probe |
| `Dialog usesNativeDialogs` returns false | ✓ (wrapper toggle worked) | same probe |
| `VWBridge.pcl` (52,478 bytes) at `src/vw-bridge/parcels/` | ✓ | filesystem |
| `VWBridge.pst` (128,285 bytes) at `src/vw-bridge/parcels/` | ✓ | filesystem |
| Binary header magic match stock VW | ✓ (00 11 00 00 00 D0... + "Smalltalk Binary Storage File") | hex dump |

Token chain (session-19): `3959506095072-199161` (session-18 EOD) → 9 recovery rotations + 5-cycle gate → `3959511089808-65801` (session-19 EOD).

PID chain: PID 8584 (s18 EOD) → 9096, 1748, 2348, 8960, 3884, 5124, 8256, 7680, 2232, 3632, 8872, 7960, 5864, **7532** (current at session-19 EOD).

---

## Current state (end of session-19)

- **VW image:** unchanged `storedev64.im`. **vwnt.exe PID 7532** (parcel-mode gate cycle 5), started 6/21/2026 16:11:25. Single-session run via Parcel mode.
- **Bridge:** UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: `3959511089808-65801`.
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` only (production parcel install). VWB namespace has 1 class. Test classes NOT loaded (deferred Tests.pcl).
- **`Dialog useNativeDialogs: false`:** SET (wrapper toggle).
- **`VW_BRIDGE_HOME` env var:** SET at User OS level (unchanged from session-15).
- **Bridge code on disk:** `parcels/VWBridge.pcl` + `parcels/VWBridge.pst` committed; `parcel-start.st` and Start-VWBridge.ps1 -Mode update committed. **Parcel-mode is the new canonical production install path; FileIn mode (load.st + 5-file file-in) remains as alternative (e.g., when needing all 4 classes + tests).**
- **Git:** `main` will be **5 commits ahead of `origin/main`** at handoff-write time; about to push as one batch with explicit auth.
- **Untracked at EOD (post-push):** `opencode.json` only (not author's). Plus build artifacts in gitignored `.generated/parcels/` (build cache).
- **MAS window state:** unchanged from session-13 (no /click etc this session — all work via /eval probes + wrapper).

---

## NEW carry-forward constraints from session-19 (35-40)

All 6 added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) carry-forward summary + new section "Phase P P6 — VWBridge.pcl binary parcel + Start-VWBridge.ps1 -Mode Parcel (session-19)" inserted after Phase P P5. Frontmatter `last_verified` bumped to session-19. Recap:

### 35. `Cursor>>showWhile:` is the headless wedge culprit for `parcelOutOn:`

`Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:` wraps its real binary write in `Cursor wait showWhile: [block]` (instance method on Cursor, NOT Smalltalk.Dialog). In headless mode the cursor change blocks indefinitely. `useNativeDialogs:false` does NOT prevent it. Workaround: methodDictionary swap of Cursor>>showWhile: to pass-through, restore in ensure: block. Reusable for any UI-wrapped canonical VW API.

### 36. `createParcelNamed:` returns EMPTY parcel; content added explicitly

`Kernel.Parcel class>>createParcelNamed: 'Name'` registers an empty Parcel (no auto-walk for class>>category matches). Content MUST be added via instance-side `addNameSpace:`, `addEntiretyOfClass:`, `addEntiretyOfClasses:`, `addSelector:class:`, `addBinding:in:`, `addName:in:` (60+ setters). After write, cleanup via `[Kernel.Parcel removeParcelNamed: name] on: Core.Notification do: [:n | n resume]`.

### 37. `parcelOutOn:withSource:` second arg is a Filename, NOT a boolean

The keyword name `withSource:` suggests a boolean but actually means `withSource: <pstFilename>` (Filename for the .pst source companion). Passing nil/false/Stream raises MNU on `#asLogicalFileSpecification`. The 3rd positional `hideOnLoad:` IS the boolean (post-load UI visibility, not source-hiding). The `hideSource:` boolean lives in the lower-level 6-arg `CodeWriter>>writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:` that parcelOutOn: delegates to.

### 38. `removeParcelNamed:` raises Notification (must resume)

A benign `'Notification - '` fires during the removal. Naive `on: Core.Exception do:` catches and ABORTS — parcel stays in registry. Use `on: Core.Notification do: [:n | n resume]` (constraint #25 pattern).

### 39. `CodeWriter` is the binary parcel write engine

Top-level `Smalltalk.CodeWriter` (env=#Kernel, super=ObjectTracer, 123 inst-side selectors). Inst-side `writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:` is the actual binary-write entry point that `parcelOutOn:` delegates to via `prepareCodeWriter:`. None of CodeWriter's methods call `#showWhile:` directly — the UI wrapper is at the parcelOutOn: layer. Direct CodeWriter invocation is theoretically possible but requires reverse-engineering ChangeSet + codeComponent setup (session-19 attempted, failed on MNU `#removeKey:ifAbsent:` on nil receiver).

### 40. Parcel write embeds .pst path reference; ship .pst alongside .pcl

`Kernel.Parcel loadParcelFrom: pclFilename` looks for `pcl.pst` source companion alongside. If absent, VW pops `'Failed to find source file <Name>.pst. Ok to load without target source?'` dialog that wedges headless image startup. Two fixes: (a) commit .pst alongside .pcl (current P6 approach — stock VW does this), (b) rebuild parcel with `hideOnLoad: true` to suppress source dependency. VW binary parcel format: magic header `00 11 00 00 00 D0 00 00 00 01 1D` + ASCII `Smalltalk Binary Storage File` + length-prefixed parcel-name + length-prefixed version-string.

---

## Pending tasks (session-20)

### Phase P P7 — `INSTALL.md` (next on critical path)

Document both install paths in a single INSTALL.md for the onboarding developer:

1. **FileIn install** (full dev/test setup): clone repo → set `VW_BRIDGE_HOME` → run `Start-VWBridge.bat` (defaults to `-Mode FileIn`) → verify `curl /health`
2. **Parcel install** (lean production): clone repo → set `VW_BRIDGE_HOME` → run `Start-VWBridge.ps1 -Mode Parcel` → verify `curl /health`. Smaller image footprint; no test classes.

Quality gate: zero-context developer reaches `/health` 200 on first try via either path.

Effort: ~1 day.

### Phase P P8 — `GET /version` endpoint

Returns parcel version + build timestamp + commit SHA. Augments existing `/health`. Now achievable because P6 provides binary parcel with version metadata (the `'no version'` string can be set via `parcel versionString:` during build).

Effort: ~0.5 day.

### Phase M — MCP for VW dev (PARALLEL with P7+P8 or after Phase P COMPLETE)

Jasper 3-layer reference design captured session-17 (extension host + stdio proxy + HTTPS/SSE). MVP tool surface: 3 wrappers around existing endpoints (`eval`, `windows`, `dialogs`). Auto-registration in `~/.claude.json`. Single-owner via socket binding. P6 binary parcel makes the bridge install path uniform across developer machines, simplifying Phase M deployment.

### VWBridge-Tests.pcl rebuild (DEFERRED — not on critical path)

Build wedged session-19 with `addEntiretyOfClasses:` of 3 test classes. Different code path than single-class build (which worked). Future investigation:
- Try `addEntiretyOfClass:` per class individually (one at a time)
- Try with `addClassAndAllSelectors:` instead of `addEntiretyOfClass:`
- Rebuild with `hideOnLoad: true` (might bypass whatever UI dependency tripped)

If/when needed for dev/QA distribution. Production install (VWBridge.pcl) doesn't need it.

### Stale doc cleanup (still deferred — 11 files flagged session-16)

- Archive obsolete pre-session-3 docs: `src/vw-bridge/{HANDOFF.md, VWBridge-working.md, SESSION-RESUME.md, E2E-DISTANCE.md}` (DELETE, history in git); `knowledge/CONSOLIDATION-NOTES.md`, `docs/HANDOFF.md`, `docs/poc-phase-1.md`, `plan/STRATEGIC-ASSESSMENT-2026-06-20.md` (move to archive/)
- Update stale frontmatters: `PLAN-PHASE-B.md` + `PLAN-PHASE-F.md` mark SHIPPED with retrospective; `vw-bridge-known-issues.md` title v0.8.5 → v0.9.1
- Refresh `docs/ARCHITECTURE-REVISED.md` for session-16-19 reality (14 endpoints + Phase P framework + Stage 3 ship + P5 ship + P6 ship)

### Long-tail production housekeeping

- Switch `OS.CEnvironment userEnvironment` reads to `OSSystemSupport getVariable:` (silence 4× deprecation per startup; probe semantics first)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety
- **Token entropy probe** — session-18 + session-19 both observed token-random-suffix repeating across cycles (-199161 and -65801 respectively). Investigate `generateToken` random source.
- **Rebuild VWBridge.pcl with `hideOnLoad: true`** — clean alternative to shipping .pst alongside (saves 128KB binary in distribution).

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/parcels/VWBridge.pcl`](../src/vw-bridge/parcels/VWBridge.pcl) | **NEW** binary (52,478 bytes) — VW Smalltalk Binary Storage File. Contains VWB namespace + VWB.VWBridge class + SimpleDialog>>choose:labels:values:default:for: extension method (category `*VWBridge-Patches mas-bug2-fix`, Bug #2 fix). |
| [`src/vw-bridge/parcels/VWBridge.pst`](../src/vw-bridge/parcels/VWBridge.pst) | **NEW** binary (128,285 bytes) — source companion file. Required alongside .pcl for `loadParcelFrom:` to not pop confirmation dialog. |
| [`src/vw-bridge/parcel-start.st`](../src/vw-bridge/parcel-start.st) | **NEW** (~50 lines) — post-parcel-load script: resolves VW_BRIDGE_HOME, calls VWB.VWBridge start, writes .token. Do-it expression block; chunk-wrapped by Start-VWBridge.ps1 in Parcel mode. |
| [`src/vw-bridge/scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) | **MODIFIED** — added `-Mode FileIn\|Parcel` parameter, optional `-Parcel <path>` for custom .pcl, branched source-script selection (load.st vs parcel-start.st), branched required-files check, conditional `-pcl <parcelPath>` arg added LEFT of `-filein` per AppDevGuide p470 left-to-right semantics. |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | New "Phase P P6 — VWBridge.pcl binary parcel + Start-VWBridge.ps1 -Mode Parcel (session-19)" section (~140 lines: Cursor monkey-patch + parcelOutOn: quirks + content-add API + VWBridge.pcl content + .pst gotcha + wrapper -Mode update + quality gate). Phase P P5 cold-start path table updated for Parcel-mode + headless-build row. 6 new carry-forward bullets (35-40). Frontmatter `last_verified` bumped to session-19. |
| [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) | 10 section updates: frontmatter, quick status (P6 SHIPPED, Phase P ~90%, P7 next), project goals s19 column, per-phase table (Phase P 90%), Phase P deliverable breakdown (P6 ✅ SHIPPED), critical path graphic (Phase P 90%), effort remaining (P7+P8 ~1.5d), near-term milestones (onboarding ~3-5 days), per-session impact log (s19 row), carry-forward count (40), memory MCP entity count (27, 47). |
| `src/vw-bridge/probes/_probe-session19-*.st` (24 files) | **NEW** — full audit trail of session-19 investigation: API discovery (parcel-api, package-class, vwb-package-state, parcel-remove-bundle, createParcel-sandbox, cleanup-and-content-api), CodeWriter investigation (writeToParcelFileNamed, codeComponent-and-existing, codeComponent-setup, codewriter-api, codewriter-discovery, codewriter-fingerprints, codewriter-sandbox-build, codewriter-mnu-detail), Cursor monkey-patch resolution (cursor-monkeypatch-build), verification (verify-parcel-load, post-gate-state), housekeeping (phase0, registry-inventory, parcel-writer-locate, build-tests-pcl-deferred, build-parcels-failed-attempt, build-diagnostic). |
| [`knowledge/HANDOFF-2026-06-21-session19.md`](./HANDOFF-2026-06-21-session19.md) | **THIS FILE** |

---

## Important decisions this session

- **Picked Option 1 (Phase P P6 .pcl parcel build)** at session-19 start per resume prompt recommendation. Next critical-path bottleneck for Phase P.
- **Picked Option A (2 parcels: VWBridge.pcl Core+Patches + VWBridge-Tests.pcl)** for granularity. Matched session-14 Stage 1 split + production-vs-dev hygiene. Tests parcel ultimately deferred but the split design remains valid.
- **Resisted pivot to chunk-format bundle** when bridge wedges escalated mid-investigation. User direction "pivoting defeats our packaging effort" was decisive — kept binary .pcl as the deliverable shape, even at cost of 5+ bridge wedges of investigation.
- **Heeded user research prompt** when they responded "what are we struggling with? docs don't help? context7mcp? visualworks?" — pivoted to pypdf research + websearch + context7 in parallel. AppDevGuide.pdf confirmed VW ships parcel build only through UI; StoreCI-Building exists as community workaround but ParcelWriter class is ABSENT in our image. This narrowed the path to Cursor monkey-patch (Oracle Backup 1) as the right choice.
- **Cursor monkey-patch + canonical parcelOutOn: worked first try** once we passed Filename (not boolean) for withSource:. Build produced 52KB binary parcel matching stock VW binary format. Cursor>>showWhile: methodDictionary swap restore in `ensure:` block was guaranteed safe.
- **Copied .pst alongside .pcl** as quick fix for source-companion dialog popup (user surfaced the dialog mid-cycle-1). Clean alternative (rebuild with hideOnLoad:true) deferred — current approach matches stock VW convention (UIPainter.pst alongside UIPainter.pcl).
- **Deferred VWBridge-Tests.pcl** when build wedged on `addEntiretyOfClasses:` of 3 test classes. Different code path than working 1-class build. Production install only needs VWBridge.pcl; Tests parcel is for dev/QA which isn't on critical path.
- **Ran full 5-cycle quality gate via Parcel mode** after dry-run cycle 1 green. Same Oracle 5-cycle spec as P5 gate. All cycles GREEN, mean 8.43s (faster than P5's 9.11s).
- **Bundled session-19 work into EOD-style 5-commit batch** per user choice "Full P6 ship + docs + handoff + push". Matches session-17 + session-18 close cadence.

---

## Lessons learned

### What went well

- **User-prompted research pivot** at the 4-wedge mark was the inflection point. Without it I'd have kept blind-probing CodeWriter direct for hours more. Lesson: when probe iteration cost is high and unknowns persist, STOP and research the broader landscape (docs, OSS workarounds, official APIs).
- **Cursor monkey-patch technique discovery** validates Oracle's Backup Path 1 design — and is REUSABLE for any future headless invocation of UI-wrapped canonical VW APIs. Captured in memory entity `Cursor-showWhile-monkeypatch-technique`.
- **`ensure:` block for methodDictionary restore** prevented permanent system change on every failure path. Defensive pattern worth replicating wherever system-method patching is needed.
- **In-place unload + loadParcelFrom: + verify** (session-17 technique extended for parcel verification) was the cheap, high-signal validation that the .pcl actually WORKS for the install workflow. No cold-start round-trip needed.
- **5-cycle parcel-mode quality gate** matched session-18 P5 gate template — proved the wrapper handles both modes cleanly under destructive cycling.
- **AGENTS.md commit cadence respected** — 5 commits, all atomic, all with explicit auth.

### What I'd do differently

- **Should have researched FIRST** before deep-probing CodeWriter direct. AppDevGuide.pdf documents parcel build only through UI; this alone narrows the path significantly. Time cost of 5 wedges + recoveries: ~3 minutes total wall-clock but high cognitive overhead. Lesson for next time: pypdf research on local VW docs is cheap (~30s) and high-signal; should be a first step when probing an unfamiliar API surface.
- **Should have tested parcelOutOn: with a real existing loaded parcel BEFORE the createParcelNamed: + addEntirety + build flow.** Stock parcels are known-working; loading one and re-serializing it would have been a non-destructive test of the API. Could have surfaced the Cursor>>showWhile: wedge without the create+add+content path adding more variables.
- **The .pst companion dialog was not anticipated.** Probe 4 (stock .pcl inspection) showed UIPainter has both .pcl and .pst. Should have inferred that our builds would also produce .pst AND that loadParcelFrom: would expect it alongside. Lesson: when reading source-control conventions for binary artifacts, include companion files in the distribution plan.
- **VWBridge-Tests.pcl deferred** is a soft loss. Three test classes triggered a wedge that single-class build didn't. Future investigation should isolate (one class at a time + try addEntiretyOfClasses: vs addClass: + try hideOnLoad:true to bypass any UI dependency).

### Discoveries documented

- **6 new carry-forward constraints** (35-40) in `vw-image-api-contract.md`. Doc has grown to 40 constraints across 16 sessions of work.
- **3 new memory MCP entities**: `Session-19-2026-06-21`, `parcelOutOn-wedges-bridge-via-showWhile` (code-bug), `Cursor-showWhile-monkeypatch-technique` (technique), `Phase-P-P6-shipped` (milestone). +5 new relations. Knowledge graph now has 27 entities + 47 relations.

---

## Resume hooks

- **Next-session anchor:** this file + [`plan/PHASE-PROGRESS.md`](../plan/PHASE-PROGRESS.md) (now updated with P6 SHIPPED + Phase P ~90%) + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (40 carry-forward constraints documented as of session-19).
- **Memory MCP context:** run `memory_search_nodes` for `session` / `VWBridge` / `Phase-P` / `ammaganyane` / `Phase-P-P6-shipped` / `Cursor-showWhile-monkeypatch-technique` / `parcelOutOn-wedges-bridge-via-showWhile` / `Session-19-2026-06-21` / `Direct-invoke-gate-pattern` / `In-place-unload-load-quality-gate-test` / `load-unload-orchestrators` at start of session-20.
- **First action options for session-20:**
  1. **Phase P P7 (INSTALL.md)** — write the install doc covering FileIn + Parcel paths. Effort: ~1 day. UNBLOCKS user-facing onboarding milestone.
  2. **Phase P P8 (GET /version)** — endpoint returning parcel metadata. Effort: ~0.5 day. Augments /health.
  3. **Both P7 + P8** (Phase P COMPLETE) — ~1.5 days total. Brings Phase P to 100%.
  4. **Phase M MVP** in parallel — Jasper 3-layer reference. Effort: 2-3 days. Unblocks onboarding-developer milestone earlier.
  5. **VWBridge-Tests.pcl rebuild** — investigate why 3-class build wedged. Effort: 0.5-1 day. Not on critical path.
  6. **Stale doc cleanup** (11 files flagged session-16, still deferred).
  7. **Long-tail production housekeeping** (deprecation switch + log rotation + log mutex + token entropy probe + rebuild .pcl with hideOnLoad:true).
- **Phase 0 verification for session-20 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.9.1"}`
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token (was `3959511089808-65801` at session-19 EOD; will rotate ONLY if vwnt.exe restarted)
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect **0 commits ahead** (session-19 pushed all 5)
  - `git status --short` — expect 1 pre-existing untracked: `opencode.json` only
  - vwnt.exe PID 7532, started 6/21/2026 16:11:25 (parcel-mode launch)
  - If vwnt.exe restarted since session-19: **Start-VWBridge.ps1 -Mode Parcel** (NEW canonical for production install) OR **Start-VWBridge.ps1 -Mode FileIn** (alternative with full test classes). Both ship as of session-19.
- **Bridge state at session-19 EOD:** UP via Parcel mode at `VWB.VWBridge` v0.9.1, token `3959511089808-65801`, VWB has 1 class (VWBridge only — lean production install). All session-19 work in effect. 5-cycle parcel quality gate proven. 5 commits about to push including this handoff.

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits local-only) | v0.9.1 | A, B, F, partial P |
| 2026-06-21 (session-15) | Pushed session-14 commits; fixed latent binding bug; direct-invoke gate pattern proven; partial gate (10/20 VWBridgeTest) | v0.9.1 | A, B, F, partial P (more verified) |
| 2026-06-21 (session-16) | Systematic gate sweep COMPLETE: 48/48 unblocked GREEN + 7 known-blocked Bug#5; 2 latent bug fixes + 3 new techniques; 5 new carry-forward (24-28); P2 quality gate SATISFIED | v0.9.1 | A, B, F, P2 quality gate |
| 2026-06-21 (session-17) | Phase P P2 Stage 3 SHIPPED (load.st + unload.st + auto-start chunk removal); quality gate idempotency PROVEN via 2 in-place /eval cycles; P5 Oracle consult COMPLETE (Path 4 wrapper design); Jasper mining synthesized; 3 new carry-forward (29-31); 4 commits pushed | v0.9.1 | A, B, F, P2 Stage 3 SHIPPED + P5 designed |
| 2026-06-21 (session-18) | Phase P P5 SHIPPED (Start-VWBridge.ps1 + Start-VWBridge.bat via vwnt.exe -filein switch); 6 probes verified -filein syntax (AppDevGuide.pdf p36) + ImageConfigurationSystem allow-flag state + top-level `^` chunk semantics; 5-cycle quality gate GREEN (mean 9.11s/cycle); 3 new carry-forward (32-34); 7 commits pushed including handoff + 3 session-13/15/17 housekeeping | v0.9.1 | A, B, F, P at ~80% (P5 SHIPPED) |
| **2026-06-21 (session-19)** | **Phase P P6 SHIPPED (VWBridge.pcl 52KB binary parcel + VWBridge.pst companion + parcel-start.st + Start-VWBridge.ps1 -Mode FileIn\|Parcel); Cursor>>showWhile: monkey-patch + canonical parcelOutOn: pattern PROVEN reusable; 24 probes + Oracle consult + research (pypdf VW docs + websearch + context7); 5-cycle parcel-mode quality gate GREEN (mean 8.43s/cycle, faster than P5); 9 bridge recoveries during empirical investigation; 6 new carry-forward (35-40); VWBridge-Tests.pcl DEFERRED (wedged on 3-class build)** | **v0.9.1** | **A, B, F, P at ~90% (P5+P6 SHIPPED)** |
| _(session-20)_ | Phase P P7 (INSTALL.md) + maybe P8 (/version endpoint) — Phase P COMPLETE target | _(v0.10.0 likely)_ | A, B, F, P (target) |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
