# Handoff — Bug #4b FIXED + Bug #2 deep diagnosis (session 2026-06-20 session-5 EOD)

**Written:** end of session-5 that (1) shipped the **full Bug #4b fix in v0.8.10** with a new view-tree-walk Tier 2 fallback in `describeDialog:`, plus a latent `indexOf:startingAt:` MNU repair in `extractLabelText:`, (2) committed the v0.8.10 wave as 2 atomic commits (code + docs) matching session-3/4 convention, (3) ran a deep Bug #2 investigation that **reproduced Symptom A** end-to-end on v0.8.10 and uncovered concrete runtime evidence the session-3 writeup missed (the `MustBeBoolean: NonBoolean receiver--proceed for truth.` exception + invisible `GbxDebuggerClient` window), and (4) committed the Bug #2 findings as a 3rd commit. **Bug #2 itself remains NOT FIXED** — the fix requires a fresh VW image because wedge state accumulates across confirm dismissals and contaminates further probes.
**For:** session-6 — push these 4 commits when ready (handoff itself is commit #4), THEN restart `vwnt.exe` to get a clean image, THEN attempt one of the three concrete Bug #2 fix directions logged in this handoff and in `vw-bridge-known-issues.md`.
**Supersedes:** nothing — this is a NEW handoff file for session-5. The session-4 handoff ([`HANDOFF-2026-06-20.md`](./HANDOFF-2026-06-20.md), committed at `aedd18b`) is the historical session-4 EOD snapshot.

---

## User direction in this session (session-5, condensed)

- Open with: "read context from session 4 and check the handoff" — read session-4 + verify its claims (git state, bridge state, Dialog flag).
- "lets investigate and solve the bugs" — clear implementation intent on both open bugs (#4b + #2).
- Picked **Bug #4b first, then #2 if time (Recommended)** when offered the priority question — explicit "ship v0.8.10 then start #2 instrumentation" intent.
- Picked **Commit #4b now, then start #2 (Recommended)** for the checkpoint between bugs — wanted clean atomic commits before tackling #2's multi-hour scope.
- Picked **Wrap: handoff + push (Recommended)** for the EOD checkpoint after Bug #4b shipped + Bug #2 diagnosis deepened but unfixed.

---

## Work completed in session-5

### Phase 1 — Bug #4b full fix (v0.8.10) — view-tree archaeology

**Overturned session-4's "no selector matched" claim.** Session-4 said `subViews`/`components`/`subComponents`/`subwidgets`/`children`/`submorphs`/`childrenComponents` were all tried and none matched. Session-5 found that **`#children` IS universal across `View` / `Wrapper` / `CompositeView` / `VisualPart`** (probe-confirmed via `canUnderstand:`). The session-4 probes must have sent `#children` to the wrong receiver (likely the `SimpleDialog` instance or the `UIBuilder`, neither of which understands it). The correct walk path is `aDialog mainWindow component children`, recursive.

**Live tree shape** for `Dialog warn:` (depth 7, root `CompositePart`, message at `PassiveLabel`, button at `ActionButtonView` wrapped in 6 layers of `SpecWrapper` / `LayoutWrapper` / `BoundedWrapper` / `WidgetStateWrapper` / `CompositePart`). All probe-confirmed.

**Three-tier extraction in [`describeDialog:`](../src/vw-bridge/VWBridge.st):**
- **Tier 1 (existing)**: `namedComponents` lookup via `extractDialogMessageFrom:` + `extractDialogButtonsFrom:` — SimpleDialog happy path.
- **Tier 2 (NEW)**: view-tree DFS walk via the new `extractDialogFromView:` method — fires when Tier 1 returns `msg nil AND btnLabels empty`. Identifies leaves by class-name substring (`*Button*` → ActionButtonView etc., `*Label*` AND NOT `*Button*` → PassiveLabel etc.). First non-empty label in DFS order becomes the message; all buttons collected in DFS order. Stack-based iteration with `reverseDo:` push so children pop in original order (true DFS). Depth-capped at 12 (observed max is 7).
- Reuses `extractLabelText:` for text unwrapping — works for ComposedText (via `#string` fallback) AND LabelWithAccessor (via printString quoted-segment parsing).

**Latent `indexOf:startingAt:` MNU repaired in `extractLabelText:`.** This VW image does NOT implement that selector on String (probe-confirmed via `respondsTo:`; the substitute is `nextIndexOf:from:to:`). The latent bug never surfaced in production because menu items in this image have plain String labels handled by the `isString` early return; the printString-parse path was never triggered for menu walks. The new view-tree walk DOES exercise that path for `ActionButtonView`'s `LabelWithAccessor` labels, so the MNU had to be fixed before Tier 2 could function. Repair: `txt nextIndexOf: qch from: p1 + 1 to: txt size` with defensive `on: Core.Error` wrap. Also reordered fallback chain to put `#string` before `#displayString` — ComposedText answers raw text to `#string` but the class-name placeholder (`'a ComposedText'`) to `#displayString`.

**Verification (4 probes, all green):**

| Probe | Expected | Result |
|---|---|---|
| `/health` post-reload | `version:0.8.10` | ✓ `{"status":"ok","version":"0.8.10"}` |
| Regression: fork `Dialog warn:`, `/dialogs` | `SimpleDialog` Tier 1 unchanged | ✓ `{class:SimpleDialog, message:"BUG4B PROBE - leave me up briefly", buttons:["OK"]}` |
| **NEW**: fork PartySearchView, fork `helpID` click, `/dialogs` | `ExtendedSimpleDialog` Tier 2 populated | ✓ `{class:ExtendedSimpleDialog, message:"1. Select the search type eg: Name.", buttons:["Close"]}` |
| Tier 2 simulation on warn dialog (algorithm validation BEFORE editing deployed bridge) | Same output as Tier 1 | ✓ `#('BUG4B PROBE - leave me up briefly' #('OK'))` |

### Phase 2 — Commit wave 1 (2 commits for v0.8.10 work)

| Hash | Subject | Files |
|---|---|---|
| `6423b0c` | feat: VWBridge v0.8.10 - full Bug #4b fix via view-tree walk | `src/vw-bridge/VWBridge.st`, `src/vw-bridge/VWBridge-Test.st` |
| `607c91f` | docs: Bug #4b - FIXED in v0.8.10, view-tree walk implementation | `knowledge/vw-bridge-known-issues.md` |

Style: SEMANTIC prefix (matches repo's 16/18 = 89% convention). 2-commit split per session-3/4 "3+ files → 2+ commits" rule (3 files modified → code commit + docs commit).

### Phase 3 — Bug #2 deep investigation

Picked Bug #2 per user's "then #2 if time" preference. Reproduced Symptom A end-to-end on v0.8.10 to confirm the bug isn't already fixed as a side-effect of Bug #5's v0.8.8 synchronization. **Symptom A FULLY reproduces**: `partialMatchResults` stays nil 23 s after `/dialogs/respond Yes`, no cascade modals visible to `/dialogs`.

**Smoking gun (session-3 missed it):** after dismiss, `/windows` showed a new `GbxDebuggerClient` window titled `"Unhandled exception: NonBoolean receiver--proceed for truth."`. Session-3 said "No `UnhandledException` raised" — but the exception IS raised, just into a `GbxDebuggerClient` window that the bridge's `/dialogs` enumeration doesn't catch (it filters for `SimpleDialog`-class only). From outside, the action handler appears to silently exit; in reality it's wedged inside the debugger.

**EXACT exception class captured** via instrumented fork that catches `Core.Error`:
```
BUG2_PF_EXCEPTION = 'MustBeBoolean: NonBoolean receiver--proceed for truth.'
BUG2_PF_RESULT = 'returned nil (or exception above)'
```

So the partialFind:'s `(Dialog confirm: ...) ifTrue: [...]` raises a `MustBeBoolean` exception because `Dialog confirm:` returned a non-boolean (almost certainly `nil`). This **confirms session-3's structural hypothesis** — only the "no exception" detail was wrong.

**Key discoveries that surprised the session-3 model:**

1. **Standalone `Dialog confirm:` works correctly** (returns `true`) on first call in a fresh image. Captured into `BUG2_RESULT = {class:'True', isTrue:true, printString:'true'}`. The session-3 doc framed Dialog confirm:'s nil return as universal — it's actually partialFind:-context-specific.
2. **ActionButton dispatch is NOT the difference.** Directly forking `model partialFind: 'PP0'` (bypassing the PluggableAdaptor pipeline entirely) STILL produces the non-boolean return + MustBeBoolean exception. Something in partialFind:'s own setup (some wrap context — possibly `Cursor wait showWhile:`, `self abort`, an `ensure:`, or a transaction) changes the modal's exit semantics.
3. **`widget model value: true` on YesButton does NOT fire the action.** The Bug #1 mechanism that works for PartySearchView ActionButtons doesn't apply to SimpleDialog YesButton — different action wiring. The modal stays up after `value: true`. This rules out the simplest "simulate click via PluggableAdaptor" fix.
4. **`dialog close value=true` ALREADY when the modal is live.** Probed mid-modal; contradicts `vw-dialogs.md`'s "ValueHolder on: false. Modal exits when set to true." The actual exit semantic uses some other mechanism (perhaps an OS event queue check, perhaps another ValueHolder, perhaps `dialog cancel value` flipping).
5. **Wedge accumulation: subsequent standalone confirms hang too.** After the partialFind: confirm wedged its fork in the debugger, even fresh standalone Dialog confirm: forks (`BUG2_STANDALONE2`) stayed in 'pending' state. This means **the image needs to be restarted (vwnt.exe kill + relaunch) between fix attempts** to get clean diagnostic baselines.

**Probe data captured while modal was live** (useful for the next session's fix work):
- `namedComponents` aspects on a Dialog confirm:: `#(#displayMessageString #NoButton #YesButton)` (three widgets, no others)
- YesButton: `spec class=ActionButtonSpec`, `spec isDefault=true`, `widget class=ActionButtonView`, `widget.model class=PluggableAdaptor`
- NoButton: same structure, `isDefault=false`
- `dialog accept class=ValueHolder` (not a special model)

### Phase 4 — Commit wave 2 (1 commit for Bug #2 findings)

| Hash | Subject | Files |
|---|---|---|
| `70920b1` | docs: Bug #2 session-5 investigation findings - NonBoolean debugger evidence | `knowledge/vw-bridge-known-issues.md` |

Docs-only commit — no code changes (Bug #2 not fixed). Adds a "Session-5 investigation findings (2026-06-20)" section with the exception class, the standalone vs partialFind: divergence finding, the wedge-accumulation discovery, and three probable fix directions for the next session.

### Phase 5 — This handoff (commit wave 3, 1 commit)

| Hash | Subject | Files |
|---|---|---|
| (this commit) | docs: add HANDOFF-2026-06-20-session5 - session-5 EOD | `knowledge/HANDOFF-2026-06-20-session5.md` |

---

## Current state (end of session-5)

- **VW image:** still up, **NEEDS RESTART** before any Bug #2 fix attempt (wedge state accumulated from session-5 probes). Currently 5 windows: GbxVisualLauncher (GemStone Launcher), VisualLauncher (storedev64), WealthPublishedPundleVersionsTool (MAS Loaded Items), Workbook (Workspace), MasLauncher (MOMENTUM WEALTH - DEVELOPER --- Session Number: 4). Party Search opened + closed cleanly during the Bug #4b + Bug #2 verification. Help modal opened + dismissed cleanly. Confirm modals opened + dismissed but left wedged fork processes. Debugger window appeared once (from Bug #2 NonBoolean) and was closed via cascade.
- **Bridge:** UP at v0.8.10 on `127.0.0.1:9876`. Token at [.token](../src/vw-bridge/.token) (rotated by every `VWBridge start`; current value `3959411815879-922562`).
- **`Dialog useNativeDialogs: false`:** persists since session-4 (set via `/eval` then, NOT toggled in session-5). Will reset to `true` on `vwnt.exe` restart — re-toggle on resume.
- **Bridge code on disk:** v0.8.10 in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (~64 KB, ~1620 lines), matches what's running in the image.
- **SUnit scaffold on disk:** [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) version-locked to v0.8.10 (`testHealthReturnsCurrentVersion` asserts `"version":"0.8.10"`). NOT loaded in image yet this session — file-in via Workspace when needed.
- **BUG2_* globals in image** (will get cleared on `vwnt.exe` restart):
  - `BUG2_RESULT` = Dictionary `{class:'True', isTrue:true, ...}` from the first successful standalone confirm
  - `BUG2_STANDALONE2` = `'pending'` (fork still wedged in Dialog confirm: nested loop)
  - `BUG2_PF_RESULT` = `'returned nil (or exception above)'`
  - `BUG2_PF_EXCEPTION` = `'MustBeBoolean: NonBoolean receiver--proceed for truth.'` ← **the smoking gun**
- **Git:**
  - `main` at `70920b1` LOCALLY, **3 commits ahead of `origin/main`** (or 4 after this handoff lands). About to push during this wrap.
  - Working tree CLEAN before this handoff edit; about to become +1 file (this handoff) → 4 commits ahead before push, then 0 after push.
- **Known bugs:**
  - **Bug #1: FIXED in v0.8.7** (committed in session-4)
  - **Bug #2: NOT FIXED.** Session-5 deepened the diagnosis with concrete runtime evidence (`MustBeBoolean` exception class, debugger window discovery, standalone vs partialFind: divergence). Three concrete fix directions logged in [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) Bug #2 "Session-5 investigation findings" section. Fix requires fresh image.
  - **Bug #3: not a bug** (calibration only)
  - **Bug #4: FIXED in v0.8.6** (committed in session-4)
  - **Bug #4b: FIXED in v0.8.10** (designed + verified + committed this session, 4 probes green; was PARTIALLY FIXED in v0.8.9 from session-4)
  - **Bug #5: FIXED in v0.8.8** (committed in session-4)

---

## Pending tasks (session-6)

### Immediate on resume

1. **Push the 4 local commits** (3 already + this handoff). User explicitly authorized for THIS wrap via "Wrap: handoff + push (Recommended)" — future sessions need fresh authorization for push.
2. **Restart `vwnt.exe`** to clear wedge state from session-5 probes. This is REQUIRED before any Bug #2 fix attempt — accumulated wedged fork processes + lingering Dialog confirm: loops will contaminate further probes (this session-5 proved it empirically).
3. **Re-toggle `Dialog useNativeDialogs: false`** (resets to `true` on `vwnt.exe` restart). Set via Workspace at first because bridge will be DOWN until file-in:
   ```smalltalk
   Dialog useNativeDialogs: false
   ```
4. **File-in v0.8.10 bridge** via Workspace (bridge DOWN after restart):
   ```smalltalk
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn
   ```
5. **Verify state:**
   ```powershell
   curl.exe -sS http://127.0.0.1:9876/health
   # expect {"status":"ok","version":"0.8.10"}
   ```
6. **Re-read token** from [.token](../src/vw-bridge/.token) (rotated on every `VWBridge start`).

### Bug #2 fix (pick ONE direction per fresh-image attempt)

The session-5 doc update enumerates three concrete fix directions:

**Direction A: Simulate the YesButton click via OS event injection** (NOT via `model value:` which was confirmed dead-end). Need to find the actual click pipeline. Candidates to probe:
- `widget controller pressedButton` / `releasedButton`
- `widget controller buttonAction` / `doClick`
- `widget controller fireAction`
- `ScheduledControllers activeControllerProcess interruptWith: [...]` to inject the action on the right process
- Look at `ButtonController` / `ActionButtonViewController` source via `getSource` (might be available for these vs the stripped SimpleDialog sources)

**Direction B: Investigate what `partialFind:` wraps `Dialog confirm:` in.** Bug #2 ONLY affects partialFind: + Dialog confirm: combination — standalone confirm works. Something in partialFind: changes the modal's return semantics. Could be:
- `Cursor wait showWhile: [...]`
- `withWaitCursor: ...`
- An `on:do:` that catches a specific exception and resumes with `nil`
- A transaction or undo-stack context
- A `[...] ensure: [...]` that interferes with stack unwinding

Without source access (image stripped), bisect empirically: instrument fresh forks that progressively wrap `Dialog confirm:` in suspected contexts until you reproduce the non-boolean return.

**Direction C: Stage 3 — guard `/eval` against Dialog confirm: bodies.** Bridge's serve process hangs when `/eval` body contains `Dialog confirm:` / `Dialog request:` / `Dialog warn:`. Pre-compile substring filter (same pattern as Bug #5 Stage 1 in `looksLikeRecursiveDispatch:`) returning `400 modal_dialog_in_eval` with hint. Cheap, contained, eliminates one foot-gun. Doesn't fix the Symptom A core issue but prevents the related Symptom B hang.

Recommended order: A (most likely to fix) → B (if A fails, explains why) → C (always safe to ship regardless).

### Carry-overs from prior sessions (still pending)

7. **EXPLORATION-PLAN step 3** — 3-deep menu navigation. Pick a leaf like `Party & Contract` → `General reports` → `Contract status` (read-only-sounding, no mutation verb). Verify `walkMenuPath:` handles nested submenus.
8. **EXPLORATION-PLAN step 4** — leaf dispatch catalog across MAS menu tree. Confirm/falsify "all MAS leaves use BlockClosure".

### Production-grade packaging (medium-term, coordinated with user)

9. **Self-test coverage expansion.** Add tests for `/click` (mock Party Search if needed), `/menu`, `/dialogs` (post-Bug-#4b-full-fix), `/value`, `/windows/tree`. Bridge towards CI-runnable suite.
10. **Config externalization.** Env vars for port, token, allowed-hosts. Default file: `.env`.
11. **File-based structured logging** (replace Transcript).
12. **New endpoints:** unified `/state` snapshot, `/reset` (test isolation), `/admin/shutdown`, distinct `/version`.
13. **OpenAPI spec** for the bridge.
14. **Parcel migration + namespace isolation** — gated on tests being in place.
15. **External clients** — `vw-client`, `vw-test-framework`, `vw-mcp-server` npm packages.

---

## Key files

| File | Role |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | **CANONICAL v0.8.10** — all fixes from session-3 (Bug #1, #4), session-4 (Bug #5, partial #4b), session-5 (full #4b + latent indexOf:startingAt: repair) applied. File via Workspace if bridge is DOWN (after `vwnt.exe` restart), OR via `/eval` `'...VWBridge.st' asFilename fileIn` if bridge is UP. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold (7 tests + 6 helpers). Version-locked to v0.8.10. RUN ONLY from VW Workspace for green results — `/eval`-driven runs all return 400 cleanly in v0.8.8+ but go red on assertions. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token (auto-rewritten on every `VWBridge start`). Current value `3959411815879-922562`; will rotate on next file-in. |
| [`src/vw-bridge/archive/`](../src/vw-bridge/archive/) | Historical 7-file phase chain. Reference only — do NOT file in. |
| [`src/vw-bridge/SESSION-RESUME.md`](../src/vw-bridge/SESSION-RESUME.md) | "FIRST ACTION on resume" guide. Single-file install. |
| [`src/vw-bridge/EXPLORATION-PLAN.md`](../src/vw-bridge/EXPLORATION-PLAN.md) | Step-by-step plan — steps 1+2 done, 3+4 pending. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#5 with status. **#1/#4/#4b/#5 FIXED, #2 NOT FIXED** (with session-5 deep dive findings appended to Bug #2 entry). |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. |
| [`knowledge/vw-bridge-testing.md`](./vw-bridge-testing.md) | Bridge testing methodology + anti-patterns. |
| [`knowledge/vw-input-recovery.md`](./vw-input-recovery.md) | What to do if VW input wedges. |
| [`knowledge/vw-dialogs.md`](./vw-dialogs.md) | Dialog/SimpleDialog/closeAndUnschedule mechanics. **Note: session-5 found `dialog close value=true` ALREADY when modal is live — contradicts this doc's "Modal exits when set to true." Doc should be updated when Bug #2 fix lands.** |
| [`knowledge/vw-eval-cookbook.md`](./vw-eval-cookbook.md) | Useful `/eval` recipes. |
| [`knowledge/smalltalk-gotchas.md`](./smalltalk-gotchas.md) | Chunk format, namespace qualification, ComposedText, etc. |
| [`knowledge/CONSOLIDATION-NOTES.md`](./CONSOLIDATION-NOTES.md) | Audit trail of the v0.8.5 consolidation. |
| [`knowledge/HANDOFF-2026-06-19.md`](./HANDOFF-2026-06-19.md) | Session-3 EOD handoff. Committed at `a434f69`. |
| [`knowledge/HANDOFF-2026-06-20.md`](./HANDOFF-2026-06-20.md) | Session-4 EOD handoff. Committed at `aedd18b`. |
| [`knowledge/HANDOFF-2026-06-20-session5.md`](./HANDOFF-2026-06-20-session5.md) | **THIS FILE.** Session-5 EOD. |

---

## Important decisions (this session)

- **Bug #4b first, Bug #2 second.** User explicitly chose this order via the "Bug #4b first, then #2 if time (Recommended)" question. Honored throughout — committed Bug #4b cleanly before starting #2.
- **Atomic 2-commit split for v0.8.10** (code + docs). Matches session-3/4 "3+ files → 2+ commits" convention. Each commit's scope is clean.
- **Latent `indexOf:startingAt:` MNU fixed IN-PLACE in `extractLabelText:`**, not duplicated into a new helper. Justification: the smallest correct change wins (one line), and the latent bug was a blocker for Bug #4b Tier 2 anyway (the view-tree walk hits LabelWithAccessor labels which trigger the printString-parse path). Documented explicitly in the v0.8.10 commit message and the Bug #4b doc.
- **Tier 2 conservative trigger condition** (`msg nil AND btnLabels empty`). Won't overwrite partial Tier 1 results. If a future subclass returns partial Tier 1 (msg-only or buttons-only) in the wild, refine to per-field merge.
- **Bug #2 investigation continued in same session** despite session-3/4 handoffs both saying #2 needs its own dedicated session. Justification: user explicitly said "then #2 if time" — making the choice for them by NOT starting #2 would have been over-cautious. Honored by deeply diagnosing rather than rushing a fix.
- **Bug #2 fix DEFERRED to next session.** Three concrete fix directions logged; image needs `vwnt.exe` restart to clear wedge state; honest stop rather than ship a fix without proper verification.
- **Bug #2 doc updated even though Bug #2 not fixed.** The diagnostic progress is REAL VALUE for the next session. Better to commit findings cleanly than let them rot in conversation.
- **Use Smalltalk forks instead of PowerShell Start-Job for triggering wedging operations** (helpID click in Bug #4b verification, findID click in Bug #2 reproduction). Cleaner: single-session, no cross-PowerShell-session state issues, no orphan jobs. The bridge's serve process is freed immediately; the fork becomes the wedge owner.
- **Used `Root.Smalltalk at: #BUG2_* put: ...` globals for instrumentation.** Image-sources-stripped means I can't `getSource` on partialFind: or Dialog confirm:. Globals are the cheapest cross-process diagnostic channel; the values persist until `vwnt.exe` restart so I could observe them after the fact (this is how I caught the `MustBeBoolean` exception class when the debugger cleared and the fork finally unwedged).
- **No PUSH yet at handoff write time.** User explicitly authorized "wrap session: handoff + push" — handoff first (this file), commit, then push.

---

## Explicit constraints (carry forward)

- **NEVER commit, amend, or push** without explicit user request. Session-5 had multiple explicit "commit"/"push" verbs (via question-tool choices); future sessions need fresh authorization.
- **NEVER call `VWBridge singleton dispatch:` from inside `/eval`.** v0.8.10 inherits v0.8.8's Stage 1 + Stage 2 contains, returns 400 cleanly, but still don't do it intentionally.
- **OFF-LIMITS widgets** without explicit OK: `commitWidget`, `loginRpcWidget`, `removeWidget`. **MAS menu leaves with mutation verbs** (add/delete/transfer/commit/change/update/process/submit/upload) need OK before any `/menu/click`.
- **`windowTitle` is CASE-SENSITIVE substring match.**
- **For Workspace file-in (bridge DOWN scenario):** `'path' asFilename fileIn.`, NOT Launcher → File Browser → File In.
- **For `/eval` file-in (bridge UP scenario, v0.8.8+):** PowerShell + `curl.exe` with `--data-binary @file` pattern. Token rotates on every reload — re-read `.token` afterward.
- **`$'` character literal is unreliable** in chunk file-ins. Use `(Core.Character value: 39)`.
- **GBS namespace qualification** — `Root.Smalltalk`, `Core.String`, `Core.Character`, `Core.Error`, `Core.Array`, `Core.Integer`, `Core.OrderedCollection`, `Core.Dictionary`.
- **`/eval` runs on bridge serve process**, NOT UI process. UI-touching `/eval` needs `ScheduledControllers activeControllerProcess interruptWith:` wrapping (or fork). AND must not re-invoke `bridge dispatch:` (v0.8.8 Stage 2 catches with 400 but you still don't want to write it).
- **Image sources are STRIPPED**: `(cls compiledMethodAt: sel) getSource` returns nil for all methods. Investigation must be runtime probes (`canUnderstand:`, behavior observation via globals, `respondsTo:` filters), NOT source inspection.
- **String `indexOf:startingAt:` does NOT exist** in this image. Use `nextIndexOf:from:to:` (available substitute). `indexOf:` (1-arg) and `indexOfSubCollection:startingAt:` (2-arg substring) both work.
- **Standard `instVarNames` is CLASS-SIDE, not instance-side.** `model instVarNames` MNU — use `model class instVarNames`.
- **`isCollection` does NOT exist** as a generic selector here — use `respondsTo: #do:` or `respondsTo: #reverseDo:` instead.
- **`Processor allProcesses` / `allKnownProcesses` do NOT exist.** Only `Processor activeProcess` confirmed.
- **PowerShell `-Body` with literal JSON inline is QUOTE-HELL.** Use `--data-binary "@path/to/file.json"` instead. Bash-tool `-Body '{"choice":"OK"}'` returned `{"error":"invalid_json"}` until switched to file-based POST.
- **PowerShell `Start-Job` jobs vanish across `bash` tool invocations** (each invocation is a fresh PowerShell session). Don't rely on jobs from prior tool calls.

---

## Context for continuation (read this before resuming)

- **Bridge is UP at session-5 EOD.** v0.8.10, token `3959411815879-922562`. WILL BE DOWN after `vwnt.exe` restart (recommended for Bug #2 fix attempts).
- **`Dialog useNativeDialogs: false`** persists across bridge file-in (set in session-4), DOES NOT persist across `vwnt.exe` restart. Re-toggle on every image restart.
- **3 LOCAL ONLY commits + this handoff = 4 commits to push.** User authorized push for THIS wrap; future sessions need fresh push authorization.
- **Bug #2 fix is the next big-value bug.** Three concrete directions logged; pick ONE per fresh-image session-6 attempt. Don't bundle.
- **For ANY bridge change in v0.8.11+**: edit [`VWBridge.st`](../src/vw-bridge/VWBridge.st), reload via `/eval` file-in (no need for Workspace anymore), bump version at 4 sites (header, dispatcher comment, doDispatch comment, /health body) + the matching `testHealthReturnsCurrentVersion` assertion.
- **For ANY new SUnit tests**: add to [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st). Prefer calling handler methods directly (e.g. `bridge handleWindows`) over `bridge dispatch: ...`.
- **Production-grade packaging is on the roadmap, NOT critical path.** Bug #2 fix + SUnit coverage come FIRST.

---

## To continue in a new session

1. Press `n` in OpenCode TUI to open a new session, or run `opencode` in a new terminal.
2. Paste this entire file as your first message.
3. Add your request — pick one based on focus:
   - "Continue from handoff above. Restart `vwnt.exe`, re-toggle Dialog useNativeDialogs:false, file-in v0.8.10 bridge, then attempt Bug #2 fix Direction A (OS-event YesButton injection)." — the most-likely-to-fix path
   - "Continue from handoff above. Same restart + setup, then attempt Bug #2 fix Direction B (instrument partialFind:'s wrapping context)." — diagnostic deepening if Direction A doesn't pan out
   - "Continue from handoff above. Ship Stage 3 guard (Bug #2 Direction C) — `/eval` substring filter for Dialog confirm:/request:/warn:. Cheap defense-in-depth regardless of Symptom A fix progress." — pure prevention
   - "Continue from handoff above. Skip Bug #2 entirely, do EXPLORATION-PLAN step 3 (3-deep menu navigation) and step 4 (leaf dispatch catalog)." — carry-over backlog
   - "Continue from handoff above. Pivot to production-grade packaging — config externalization (env vars), file-based structured logging, /state + /reset endpoints." — medium-term track

The new session will have full context to continue seamlessly.
