# Handoff — Phase P P1+P3 + P2 Stage 1+2 SHIPPED (session 2026-06-21 session-14 EOD)

**Written:** session-14 EOD after Oracle-guided Phase P execution. Seven atomic commits pushed local (not yet to `origin/main`): [`d4924c5`](#phase-p-p1p3) (P1+P3 feat), [`b2dec57`](#phase-p-p1p3) (P1+P3 docs), [`bbe16c0`](#phase-p-p1p3) (P1+P3 probes), [`3b72287`](#phase-p-p2-stage-1) (P2 Stage 1 feat), [`5c63e0c`](#phase-p-p2-stage-1) (P2 Stage 1 probes), plus two new for Stage 2 (feat + probes).

**For session-15:** (1) **push** the 7+ local commits to `origin/main` if you want them shipped (push deferred this session); (2) **run full SUnit suite via VW Workspace** to close the P2 quality gate (per session-12 constraint #2 — can't run SUnit via /eval safely); (3) **Stage 3 of P2**: `load.st` + `unload.st` per Oracle plan; (4) **Phase P P5/P6/P7/P8** still pending; (5) carry-overs from sessions 7–11 still pending.

**Supersedes:** nothing. [`HANDOFF-2026-06-21-session13.md`](./HANDOFF-2026-06-21-session13.md) remains the session-13 EOD; this file is session-14 EOD.

---

## User direction this session (condensed)

- Resume prompt with 4 anchor docs + Phase 0 verification. Picked **Option 1 (Phase P P1+P3 first per the revised strategic assessment)** as the natural continuation since the eval server is feature-complete at v0.9.1 but only deployable on the author's machine.
- After P1+P3 verified: picked **Option 1 commit shape** (3 atomic commits: feat + docs + probes) + proceed to P2+P4 next.
- After P2 Stage 1 verified: picked **Option 1** (commit Stage 1 feat + probes split + proceed to Stage 2).
- After P2 Stage 2 verified: **commit and update session handover for next session** (this file).
- Push deferred until session EOD (or session-15 start, per author preference).

---

## Work completed in session-14

### Phase P P1+P3 (committed as `d4924c5`, `b2dec57`, `bbe16c0`)

**P1 — env-var externalization via `VW_BRIDGE_HOME`:**

| Item | Detail |
|---|---|
| Probe chain | 4 versions (`_probe-p1-env-api{,-v2,-v3,-v4}.st`) — narrowed from absent `OS.OperatingSystem` to canonical `OS.CEnvironment userEnvironment at:ifAbsent:` |
| Implementation | 6 new class-side methods on `VWBridge`: `vwBridgeHome`, `vwBridgeHomeOverride:`, `clearVwBridgeHomeOverride`, `tokenFilePath`, `logFilePath`, `screenshotHelperScriptPath` |
| Override seam | `vwBridgeHomeOverride` class-side ivar enables hermetic tests without OS env mutation |
| Tests | 5 SUnit selectors added to `VWBridgeTest` covering override priority + clear + 3 derived path methods |
| Verification | All paths derive correctly (class + instance side delegation), `.token` written to derived path, /health 200 OK, /screenshot returned 884KB PNG 2560×1440 via env-rooted helper location (preserved as evidence at `C:\Users\AMMAGA~1\AppData\Local\Temp\2\opencode\p1-screenshot-v2.png`) |
| Path inventory correction | strategic assessment said "5 hardcoded paths"; actual count after grep + heuristic sweep was **3** (log L176, helper L2514, token L2663). Schema is 1 root env var + 3 derived (not + 4). |

**P3 — PowerShell helper script relocation:**

- Moved [`scripts/screenshot-helper.ps1`](../scripts) → [`src/vw-bridge/scripts/screenshot-helper.ps1`](../src/vw-bridge/scripts) (`git mv` detected as 100% rename)
- Content unchanged (3097 bytes); only location changed for self-contained install
- `screenshotHelperScriptPath` derives new path from `vwBridgeHome , '\scripts\screenshot-helper.ps1'`

**P1+P3 quality gate:** ⚠ partially met (bridge files in cleanly at any directory with `VW_BRIDGE_HOME` set + `/health` succeeds — verified via stages 1–3+5–6 of the fresh-temp-dir test; `/screenshot` succeeded at canonical install but the temp-dir retest hit unrelated Windows `CopyFromScreen "handle invalid"` RDP desktop degradation; same error reproduced via standalone PowerShell with no bridge involvement → environmental, NOT a P1+P3 regression).

**Docs:** added "Environment variables (session-14)" section to [`vw-image-api-contract.md`](./vw-image-api-contract.md) covering canonical fail-loud read, `getenv:` empty-string gotcha, test-time mutation, and the misleading-API trap (`OS.ExternalProcess environment` / `ObjectMemory environment` return Smalltalk NameSpace, not env vars).

### Phase P P2 Stage 1 — source split + category rename (committed as `3b72287`, `5c63e0c`)

- SimpleDialog override extracted from `VWBridge.st` (L2624-2698) to new [`VWBridge-Patches.st`](../src/vw-bridge/VWBridge-Patches.st) with `*VWBridge-Patches mas-bug2-fix` category prefix
- `VWBridge.st` class category: `'VW-TestBridge'` → `'VWBridge-Core'`
- 3 test files class category → `'VWBridge-Tests'`
- **Verified `*PackageName` category convention works in this image** (empirical proof: post-file-in `SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:` returned `#'*VWBridge-Patches mas-bug2-fix'`)
- Residual empty `mas-bug2-fix` category remains in SimpleDialog organization (cosmetic, no methods in it; can clean in Stage 3 unload if desired)

### Phase P P2 Stage 2 — namespace migration to `Smalltalk.VWB` (just committed)

- Oracle consult `bg_c8df2570` recommended option **(b)** — top-level NameSpace `VWB` containing `VWB.VWBridge` (avoids Java-style same-name collision with `VWBridge.VWBridge`)
- **Side-trip:** first file-in attempted `Root.VWB defineClass:` which failed with `"Root.VWB has no binding"`. Root cause: `Root.Smalltalk defineNameSpace: #VWB` places VWB **inside Smalltalk dictionary** (`Smalltalk.VWB`), NOT as a direct Root child. Fixed to `Smalltalk.VWB` throughout + made namespace creation chunk idempotent (defensive guard). Retry clean.
- **50 methodsFor: chunk headers retargeted** (27 on `VWBridge` + 8+6+9 across 3 test files)
- Auto-start chunk now defensively stops+removes old top-level `Root.Smalltalk.VWBridge` before starting new `VWB.VWBridge`
- Each test file appends an idempotent cleanup chunk removing its old top-level counterpart
- Post-file-in verification: `VWB` has 4 classes (env=VWB, correct categories), all 4 old top-level `<GONE>` (byte-equivalent gate met), SimpleDialog patch preserved, bridge singleton class environment = VWB, /health 200 OK + v0.9.1, /screenshot 200 OK 151KB PNG

---

## Current state (end of session-14)

- **VW image:** still up at `vwnt.exe` PID **5624**, started 6/20/2026 1:07:31 PM (UNCHANGED across sessions 9–14, **7-session continuous run**).
- **Bridge:** UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: read from [`.token`](../src/vw-bridge/.token).
- **Bridge class identity:** `Smalltalk.VWB.VWBridge` (NOT `Root.Smalltalk.VWBridge` — Stage 2 removed the old top-level class).
- **`Dialog useNativeDialogs: false`:** SET (carried since session-7).
- **Bridge code on disk:** matches image (all changes filed-in and committed in 7 commits).
- **Git:** `main` is **7 commits ahead of `origin/main`** at EOD (P1+P3 = 3 + Stage 1 = 2 + Stage 2 = 2). Push deferred to session-15.
- **Untracked at EOD:** `opencode.json` (not mine — session-13 etiquette), [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) (session-13 deferred, still pending — should commit when next stable).
- **MAS window state:** unchanged from session-13 (no /click etc this session).

---

## NEW carry-forward constraints from session-14

All added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) where applicable.

### 8. `OS env-var access via `OS.CEnvironment userEnvironment at:ifAbsent:`

`OS.OperatingSystem` is ABSENT in this image. `OS.CEnvironment` (Dictionary subclass) is the env-var class. Canonical fail-loud read:

```smalltalk
OS.CEnvironment userEnvironment
    at: 'VW_BRIDGE_HOME'
    ifAbsent: [self error: 'VW_BRIDGE_HOME not set']
```

⚠ `OS.CEnvironment getenv: 'X'` returns `''` (empty string) for missing var — NOT nil, does NOT raise. Bad for `isNil` checks. Use `userEnvironment at:ifAbsent:` for fail-loud.

⚠ `OS.ExternalProcess environment`, `ObjectMemory environment`, `Smalltalk environment` all return a Smalltalk NameSpace (compile-time symbol scope), NOT OS env vars. Misnomer.

For test-time mutation: `OS.CEnvironment userEnvironmentAt: 'X' put: 'value'` / `userEnvironment removeKey: 'X' ifAbsent: [nil]`. For hermetic SUnit tests, prefer a class-side override seam (e.g. `Class>>fooOverride: aValue` / `clearFooOverride`) over OS env mutation.

### 9. Namespace placement: `Root.Smalltalk defineNameSpace: #X` puts X **inside Smalltalk**

`Root.Smalltalk defineNameSpace: #VWB private: false imports: '' category: 'cat'` creates a NameSpace at `Smalltalk.VWB`, NOT at `Root.VWB`. References from outside the file should use `Smalltalk.VWB` (or bare `VWB` via default scope) — NEVER `Root.VWB`.

The canonical creation selector is **4-arg form**: `defineNameSpace:private:imports:category:`. Shorter variants (`defineNameSpace:`, `defineNameSpace:imports:category:`, `addNamespace:`) are ABSENT.

For idempotent file-in (re-running namespace creation on existing namespace), wrap defensively:

```smalltalk
[(Smalltalk at: #VWB ifAbsent: [nil]) isNil ifTrue: [
    Root.Smalltalk defineNameSpace: #VWB private: false imports: '' category: 'cat']]
        on: Core.Error do: [:ex | nil]
```

### 10. `*PackageName` category prefix IS the extension-method package mechanism

Empirically verified in Stage 1: `!SimpleDialog methodsFor: '*VWBridge-Patches mas-bug2-fix'!` causes the compiled method to be reported with category `#'*VWBridge-Patches mas-bug2-fix'` (the asterisk-prefix gets parsed into the method's category by VW). Parcel-load introspection treats this as belonging to package `VWBridge-Patches`.

For OWN-class methods (e.g. methods of VWBridge added in `!VWB.VWBridge methodsFor: 'config'!`), do NOT use `*PackageName` prefix — that's only for extension methods on classes owned by OTHER packages.

### 11. `CompiledMethod` has no `#category` or `#package` accessors in this image

`m respondsTo: #category = false`, `m respondsTo: #package = false`. To get a method's category, use the CLASS's organization:

```smalltalk
SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:
```

Returns the category Symbol (e.g. `#'*VWBridge-Patches mas-bug2-fix'`).

### 12. `class removeFromSystem` cleanly removes a class

Verified via `_probe-p2-namespace-api.st`. After `cls removeFromSystem`:
- Subsequent `Smalltalk at: #cls` returns nil
- Class instance vars are gone
- Direct method lookups raise

Idempotent: re-running `removeFromSystem` on an absent class needs a defensive guard like `(Smalltalk at: #X ifAbsent: [nil]) ifNotNil: [:cls | cls removeFromSystem]`.

### 13. `NameSpace removeFromSystem` cleanly removes an empty namespace

Verified via same probe. After `namespace removeFromSystem`:
- `Smalltalk at: #namespace` returns nil
- Image symbol space restored

Idempotent guard pattern: `(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns | ns keys isEmpty ifTrue: [ns removeFromSystem]]`.

### 14. `class environment` returns the home namespace

Useful for distinguishing migrated vs original classes:

```smalltalk
VWB.VWBridge environment name "→ 'VWB'"
SimpleDialog environment name "→ 'Smalltalk'"
```

In Stage 2 cleanup chunks: `(oldCls environment == Root.Smalltalk) ifTrue: [oldCls removeFromSystem]` — guard prevents accidental removal of the new VWB.VWBridge class.

---

## Pending tasks (session-15)

### Phase P P2 Stage 3 — `load.st` + `unload.st` (per Oracle plan)

**load.st** orchestrates:
```smalltalk
"Stage 3 - external load orchestrator. Replaces auto-start chunk in VWBridge-Core.st."
'<VW_BRIDGE_HOME>/VWBridge-Core.st' asFilename fileIn.
'<VW_BRIDGE_HOME>/VWBridge-Patches.st' asFilename fileIn.
'<VW_BRIDGE_HOME>/VWBridge-Test.st' asFilename fileIn.
'<VW_BRIDGE_HOME>/VWBridge-WaitTest.st' asFilename fileIn.
'<VW_BRIDGE_HOME>/VWBridge-ScreenshotTest.st' asFilename fileIn.
VWB.VWBridge start.
<write .token to VWB.VWBridge tokenFilePath>
```

**unload.st** defensive sequence (per Oracle Q5):
1. Save `tokenPath := [VWB.VWBridge tokenFilePath] on: Error do: [:ex | nil]` (before VWBridge is gone)
2. Stop bridge: `[VWB.VWBridge stop] on: Error do: [:ex | nil]`
3. Delete `.token`: `tokenPath ifNotNil: [tokenPath asFilename delete]`
4. Remove SimpleDialog patch: `[SimpleDialog removeSelector: #choose:labels:values:default:for:] on: Error do: [:ex | nil]`
5. Remove 4 VWB classes in reverse-dependency order: ScreenshotTest, WaitTest, Test, VWBridge — each via `removeFromSystem`
6. Remove empty VWB namespace: `VWB removeFromSystem`
7. All ops defensive — idempotent (load + unload + unload + load = same as load)

**Quality gate:** post-unload, `Kernel.Parcel introspection` shows zero residual VWBridge classes; `Smalltalk at: #VWB` returns nil; image is byte-equivalent to pre-load state in class presence.

**Important:** Stage 3 must REPLACE the auto-start chunk currently at end of VWBridge.st (which calls `VWB.VWBridge start` directly). Move the start logic to `load.st` so VWBridge-Core.st can be filed-in without auto-starting (parcel-readiness for P6).

### Phase P P2 full quality gate — run full SUnit suite via VW Workspace

Per session-12 constraint #2 (SUnit assertion failures via /eval pop VW debugger blocking serve-process), the full 68-selector suite must be run via VW Workspace, NOT via /eval:

```smalltalk
| testClasses results |
testClasses := #(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest).
results := testClasses collect: [:nm | (VWB at: nm) suite run].
results printString
```

Expected: all 3 suites GREEN (0 failures, 0 errors). If any tests fail, diagnose via `describe_test_failure`-equivalent before declaring P2 complete.

### Phase P remaining deliverables (P5, P6, P7, P8)

| # | Deliverable | Status | Notes |
|---|---|---|---|
| P5 | Auto-start trigger (Oracle consult on Topaz stdin vs CLI arg vs file watcher) | ⏳ Oracle consult needed | Three paths converge on external trigger (no SessionManager / no addToStartUpList: hook in this image — verified session-9). |
| P6 | Build `.pcl` parcel via `Kernel.Parcel loadParcelFrom: aFilename` | ⏳ Depends on P5 | Headless parcel-load API verified session-11. |
| P7 | `INSTALL.md` (env-var setup + parcel load + smoke test) | ⏳ Depends on P6 | Zero-context developer reaches /health on first try. |
| P8 | `GET /version` endpoint (parcel version + build timestamp + commit SHA) | ⏳ Depends on P6 | Augments existing /health. |

After Phase P ships: **Phase M (MCP for VW dev)** and **Phase E (Playwright SDK + 3 tests)** in parallel.

### Carry-overs (still pending from sessions 7–11)

- EXPLORATION-PLAN step 3 — 3-deep menu navigation
- EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree
- End-to-end verify of `#id` / `#imcNr` / `#groupScheme` no-modal `partialFind:` paths via bridge

### Housekeeping

- Commit [`plan/STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) (session-13 deferred — still untracked)
- Log rotation in VWBridge.st (production)
- Class-side log mutex for concurrent fork safety

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | P1: 6 new class-side config methods + classInstanceVariableNames update + 2 instance method delegations + auto-start tokenFilePath. Stage 1: class category rename + SimpleDialog patch extraction. Stage 2: namespace creation + Smalltalk.VWB defineClass: + 27 methodsFor: header retargets + auto-start defensive cleanup. |
| [`src/vw-bridge/VWBridge-Patches.st`](../src/vw-bridge/VWBridge-Patches.st) | **NEW** — extracted SimpleDialog override with `*VWBridge-Patches mas-bug2-fix` category. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | P1: 5 new tests. Stage 1: category rename. Stage 2: namespace migration + cleanup chunk. |
| [`src/vw-bridge/VWBridge-WaitTest.st`](../src/vw-bridge/VWBridge-WaitTest.st) | Stage 1: category rename. Stage 2: namespace migration + cleanup chunk. |
| [`src/vw-bridge/VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) | Stage 1: category rename. Stage 2: namespace migration + cleanup chunk. |
| [`src/vw-bridge/scripts/screenshot-helper.ps1`](../src/vw-bridge/scripts/screenshot-helper.ps1) | **RELOCATED** from repo-root `scripts/` (git rename detected at 100%). |
| `src/vw-bridge/probes/_probe-p1-env-api{,-v2,-v3,-v4}.st` | **NEW** P1 design probes (4 iterations narrowing to OS.CEnvironment) |
| `src/vw-bridge/probes/_probe-p1-verify.st` | **NEW** P1 path-derivation verification |
| `src/vw-bridge/probes/_probe-p2-namespaces.st` | **NEW** failed v1 (unwrapped #category MNU) |
| `src/vw-bridge/probes/_probe-p2-simpledialog{,-v2,-v3}.st` | **NEW** 3 versions narrowing to SimpleDialog method ownership |
| `src/vw-bridge/probes/_probe-p2-package-extension.st` / `_probe-p2-extension-package.st` | **NEW** failed v1s (mid-block temp + parens issues) |
| `src/vw-bridge/probes/_probe-p2-namespace-api.st` | **NEW** Stage 2 lifecycle verification (worked) |
| `src/vw-bridge/probes/_probe-p2-stage1-filein.st` / `_probe-p2-stage1-verify.st` | **NEW** Stage 1 file-in + verify |
| `src/vw-bridge/probes/_probe-p2-stage2-filein.st` / `_probe-p2-stage2-verify.st` | **NEW** Stage 2 file-in + verify |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | **+68 lines** — "Environment variables (session-14)" section + quick-lookup row + carry-forward constraint line. |
| [`knowledge/HANDOFF-2026-06-21-session14.md`](./HANDOFF-2026-06-21-session14.md) | **THIS FILE**. |

---

## Important decisions this session

- **Oracle consulted ONCE** for P2+P4 architecture (`bg_c8df2570`, 5m 43s) — chose option (b) `Smalltalk.VWB.VWBridge` + staged migration. Stage 1 first (package split), Stage 2 second (namespace), Stage 3 deferred to session-15.
- **Path inventory correction:** strategic assessment said "5 hardcoded paths" but actual count was 3 (log + helper + token). Documented honestly in P1 implementation comments; schema is 1 env var + 3 derived.
- **`*PackageName` convention probe SKIPPED** in favor of empirical verification through Stage 1 implementation — saved one probe round and produced a stronger proof (actual production code with the convention working).
- **Idempotent namespace creation:** after the `Root.VWB` side-trip in Stage 2, made the namespace creation chunk defensive (only creates if absent) so re-file-in is safe. This pattern carries forward to Stage 3 unload.
- **Test class consolidation into single `VWBridge-Tests` package:** 3 test files now share one package category. Cleaner than the 3-category Stage 0 layout (`VW-TestBridge-Tests` + `-WaitTests` + `-ScreenshotTests`).
- **NO top-level VWBridge compatibility alias** (per Oracle Q1 warning). Would have undermined the namespace migration and left residue at unload.
- **Push deferred to session-15** per session-13 cadence — user explicit choice.
- **Commit cadence per stage** (Stage 1 + Stage 2 each had feat + probes commits, matching P1+P3's 3-commit shape). 7 atomic commits across the full Phase P P1+P3+P2 Stages 1+2 ship.
- **Windows desktop `CopyFromScreen` quirk** documented but not fixed — environmental issue (RDP session state degradation), not a bridge code bug. Reproduced via standalone PowerShell with no bridge involvement.

---

## Resume hooks

- **Next-session anchor:** this file + [`STRATEGIC-ASSESSMENT-2026-06-21.md`](../plan/STRATEGIC-ASSESSMENT-2026-06-21.md) + [`ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) + [`vw-image-api-contract.md`](./vw-image-api-contract.md) (14 carry-forward constraints documented as of session-14).
- **First action options for session-15:**
  1. **Push** the 7 local commits to `origin/main` (deferred this session — get explicit auth then `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git push`)
  2. **Run full SUnit suite via VW Workspace** (close P2 quality gate; evaluate `(#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) collect: [:nm | (VWB at: nm) suite run]) printString` from a Workspace)
  3. **Phase P P2 Stage 3** — write `load.st` + `unload.st` per Oracle plan; move auto-start logic from end of VWBridge-Core.st into `load.st`
  4. **Phase P P5** — Oracle consult on auto-start trigger (Topaz stdin vs CLI arg vs file watcher); design external launcher
  5. Carry-overs from sessions 7–11 if you want a break from Phase P
- **Phase P P2 Stage 2 verified:** bridge is at `VWB.VWBridge`, all paths derive from `VW_BRIDGE_HOME` env var, SimpleDialog patch in `*VWBridge-Patches mas-bug2-fix` package category, /health + /screenshot both 200 OK.
- **Phase 0 verification for session-15 start:**
  - `curl.exe -s http://127.0.0.1:9876/health` expects `{"status":"ok","version":"0.9.1"}`
  - Read [`src/vw-bridge/.token`](../src/vw-bridge/.token) for current token
  - `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — expect 7 unpushed commits if push deferred carries to session-15
  - If vwnt.exe restarted, re-file-in via VW Workspace OR via /eval batch (the order: VWBridge.st → VWBridge-Patches.st → 3 test files)

---

## Status timeline

| Date | Event | Bridge | Phases done |
|---|---|---|---|
| 2026-06-20 (session-7) | Initial assessment; Bug #2 FIXED | v0.8.12 uncommitted | pre-A |
| 2026-06-20 (session-9) | Phase A + Phase B (/wait) shipped | v0.9.0 | A, B |
| 2026-06-21 (session-13) | Phase F (/screenshot) shipped; Phase P framed | v0.9.1 | A, B, F |
| 2026-06-21 (session-14) | **Phase P P1+P3 + P2 Stage 1+2 shipped (7 commits local-only)** | **v0.9.1** | **A, B, F, partial P** |
| _(future)_ | Phase P P2 Stage 3 + P5 + P6 + P7 + P8 ship | _(v0.10.0 likely)_ | A, B, F, P |
| _(future)_ | Phase M ship (MCP for VW dev) | — | A, B, F, P, M |
| _(future)_ | Phase E ship (first green Playwright test) | — | A, B, F, P, M, E |
