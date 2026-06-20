# Handoff — Bug #2 PARTIALLY MITIGATED v0.8.11 (session 2026-06-20 session-6 EOD)

**Written:** end of session-6 that (1) attempted Direction A (simulate YesButton click) and discovered the image lacks the standard `#performAction` / `#fireAction` APIs that the librarian's external research identified as the canonical path, (2) pivoted to Direction B (investigate the wrap context) and stack-walked a wedged fork process to discover the wrap lives in the dialog framework itself (`Cursor showWhile:` + nested `ensure:` inside `ScheduledWindow>>openTransientIn:type:postOpen:`) — NOT in `partialFind:` as session-5 hypothesised, (3) found that `WindowManager>>purgeDeadWindows` is the missing wake-up signal that `closeAndUnschedule` doesn't deliver, (4) shipped this as **v0.8.11** via a new `purgeWedgedDialogProcesses` helper in the bridge, (5) verified the fix end-to-end on Bug #2's actual scenario and on a standalone `Dialog confirm:` scenario, (6) committed the v0.8.11 wave as 2 atomic commits (code + docs) matching session-3/4/5 convention. **Bug #2 Symptom A (partialMatchResults never populates) remains NOT FULLY FIXED** — `Dialog confirm:` still returns nil on force-close because the dialog framework hardcodes that exit path, ignoring the accept ValueHolder. The v0.8.11 fix turns silent wedges into recoverable failures (catchable MustBeBoolean), eliminates wedged-proc accumulation across calls, and ships an informative `purgedWedged:N` field in the `/dialogs/respond` JSON response.
**For:** session-7 — push these 3 commits when ready (handoff itself is commit #3), THEN decide whether to pursue full Symptom A fix (OS event injection via `sensor eventButtonPress:` with constructed `MouseButtonEvent`, OR MAS-side `Dialog>>confirm:` override) or move on to other carry-overs (EXPLORATION-PLAN steps 3+4, production packaging).
**Supersedes:** nothing — this is a NEW handoff file for session-6. Session-5 handoff ([`HANDOFF-2026-06-20-session5.md`](./HANDOFF-2026-06-20-session5.md), committed at `b9f5bc9`) is the historical session-5 EOD snapshot.

---

## User direction in this session (session-6, condensed)

- Open with: "lets start with direction A" — explicit implementation intent on Direction A (OS-event YesButton injection from the session-5 handoff's three concrete fix directions).
- Picked **Pivot to Direction B (Recommended)** when Direction A turned out blocked (no `#performAction` in this image; modal loop polls a Semaphore that cross-process state-setting can't wake). Librarian's open-uncertainty #3 flagged this scenario specifically.
- Picked **Commit + push + handoff (Recommended)** for the EOD wrap after v0.8.11 shipped + end-to-end verified.

---

## Work completed in session-6

### Phase 0 — Resume + bridge bring-up

- Verified session-5 EOD state: 4 commits visible at `amos-maganyane/tm-context` ranging `6423b0c..b9f5bc9`, bridge code on disk = v0.8.10, `Dialog useNativeDialogs:` flag had been reset by `vwnt.exe` restart (which happened 1:07:31 PM, ~7 min after session-5 handoff was written).
- User pasted `Dialog useNativeDialogs: false` + `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn` in Workspace; bridge bound 127.0.0.1:9876 with rotated token `3959414975195-617858`.
- `/health` returned `{"status":"ok","version":"0.8.10"}`.
- **Surprise:** probing `Dialog usesNativeDialogs printString` via `/eval` returned `'true'` — the user's Workspace `Dialog useNativeDialogs: false` line had not stuck (probably missed the Do It). Re-set via `/eval`, verified false. Worth noting for future session resumes: always verify the toggle from outside the Workspace.

### Phase 1 — Direction A attempt (blocked)

Tried 8 candidate "simulate click" mechanisms against the live `Dialog confirm:` modal:

| # | Candidate | Outcome |
|---|---|---|
| 1 | `target model closeAccept` via `mgr activeControllerProcess interruptWith:` | `mgr activeControllerProcess` returns nil during modals; interrupt fall-back doesn't fire |
| 2 | `target model closeAccept` direct on serve process | Returned `'direct_ok'`; modal unchanged |
| 3 | `spec model value` (evaluate the action BlockClosure) | Block returned `'a SimpleDialog'`; no observable side effect |
| 4 | `btnCtrl dispatchBlockClosure: spec model` | Returned `'a SimpleDialog'`; no effect |
| 5 | `sdCtrl triggerButtonClickedEvent: yesBtn` | `EXC: MessageNotUnderstood - #isButtonPressedEvent` — needs a real event object, not the button widget |
| 6 | `target model accept value: true` + `sdCtrl checkForAccept` | `accept value` set to true (verified), `checkForAccept` returned controller-self (just a getter); modal unchanged |
| 7 | `sdCtrl closeDrainEventsAndUnschedule` | **Closes window cleanly WITHOUT MustBeBoolean**, but leaves fork wedged silently in EventQueue>>next forever (strictly worse than `closeAndUnschedule` — no visible failure either) |
| 8 | `forkProc interruptWith: [closeAccept]` | Block ran in fork's process context successfully (`INJECT_FORK = 'fork_block_ok'`), but fork resumed prior Semaphore wait afterwards — `interruptWith:` doesn't break the suspend |

**Key architectural findings (no fix yet):**
- `mgr activeControllerProcess` returns nil during modals; bridge's `onUIDo:` falls back to direct serve-process execution
- No `#performAction` / `#fireAction` / `#actionPerformed` on this image's `ActionButtonView` / `SpecWrapper` / controllers (the librarian's "rank #1 candidate" from Dolphin MVP / Squeak MVC is absent)
- `ActionButtonView` DOES have `#guiSimulateMouseClick`, but it calls non-existent `#simulateMousePress` — wrapper exists, primitive doesn't
- Cross-process state setting (accept/cancel/closeChannel) is invisible to the modal loop, which polls `EventQueue>>next` on a Semaphore

### Phase 2 — Direction B pivot (root cause + capability discovery)

**The Process allInstances breakthrough:**
- `Processor allProcesses` does NOT exist (session-3 was right) but **`Process allInstances` returns 247 procs** in this image
- Stack-walk filter (find procs whose top stack contains `ApplicationDialogController` as a receiver) found the wedged fork
- Top stack at wedge point:
  ```
  Semaphore>>waitIfCurtailedSignal
  BlockClosure>>next
  BlockClosure>>whileTrue
  EventQueue>>next
  WindowManager>>processNextEvent
  BlockClosure>>eventLoop
  BlockClosure>>ensure:
  ApplicationDialogController>>eventLoop
  ...
  Cursor>>showWhile:                              ← THE WRAP
  ApplicationDialogController>>openTransientViews
  ScheduledWindow>>openTransientIn:type:postOpen:
  ```

**The wrap is in the dialog framework, not partialFind:.** `Dialog confirm:` itself runs inside `Cursor showWhile:` + nested `ensure:` blocks in `ScheduledWindow>>openTransientIn:type:postOpen:`. Both standalone AND partialFind:'d confirms wedge identically.

**Session-5's "standalone returns true" was misleading.** Captured `B_TEST1_RET = 'nil-returned'` for a standalone `Dialog confirm:` fork dismissed via bridge `/dialogs/respond Yes`. Session-5's `BUG2_RESULT = {class:'True'}` must have been from manual user click — bridge dismissal returns nil for standalone too. The difference between standalone (silent wedge) and partialFind: (MustBeBoolean) outcomes is cosmetic, not structural.

**Recovery mechanism found: `WindowManager>>purgeDeadWindows`.** After `closeAndUnschedule`:
- `wm hasWindows` → `false` (the closeAndUnschedule did unschedule the window)
- `wm hasPendingEvents` → `true` (the queue is non-empty)
- But the modal loop is blocked at `Semaphore>>waitIfCurtailedSignal` and never sees `hasWindows=false`
- **Sending `purgeDeadWindows` makes the loop notice and exit.** Fork resumes; `Dialog confirm:` returns nil (NOT the accept value); fork's stack unwinds normally.

Other capability discoveries:
- **WindowManager** has `#close`, `#purgeDeadWindows`, `#unscheduleModalWindow:`, `#addEvent:`, `#scheduleModalWindow:`, `#processOutstandingEvents`, `#purgeInvalidWindows`
- **EventQueue** has `#nextPut:`, `#nextPutAtFrontOfQueue:`
- **EventSensor** has `#eventButtonPress:`, `#eventButtonRelease:`, `#eventBlueButtonPress:`, `#eventBlueButtonRelease:`, `#eventDamage:`, `#eventDestroy:`, `#eventDoubleClick:`, `#anyButtonPressed`, `#addMetaInput:` — full OS event injection API for future Symptom A fix
- **SimpleDialog**'s `#accept`, `#cancel`, `#close`, `#closeAccept`, `#closeCancel`, `#closeRequest`, `#closeAndUnschedule` are ALL no-ops cross-process (modal loop doesn't poll these ivars)
- **`spec model`** on ActionButtonSpec for YesButton IS a `BlockClosure` defined in `SimpleDialog>>addLabels:values:default:storeInto:takeKeyboard:equalize:columns:`, but evaluating it returns `self` with no side effect — not the actual click action
- **Signaling the wedged Semaphore directly does NOT work** — loop wakes, finds no event, re-sleeps on next semaphore (verified empirically: 1 signal + 5 more signals both ineffective)

### Phase 3 — v0.8.11 partial fix

**New helper `purgeWedgedDialogProcesses` in [`VWBridge.st`](../src/vw-bridge/VWBridge.st#L1392):**
- Walks `Process allInstances` (~200-300 procs, fast filter)
- Selects: top stack contains `ApplicationDialogController` as a receiver
- For each match: walks same stack for a `WindowManager` receiver
- Sends `purgeDeadWindows` to that WindowManager
- Returns count of unwedged procs

**`doRespondDialog:` rewritten ([VWBridge.st L1334-1390](../src/vw-bridge/VWBridge.st#L1334)):**
- Comment block rewritten to match reality (was incorrectly claiming `closeAndUnschedule` wakes the loop — it doesn't)
- After `closeAndUnschedule`, calls `self purgeWedgedDialogProcesses` and captures count
- Response JSON now includes `"method":"closeAndUnschedule+purgeDeadWindows"` and `"purgedWedged":N`
- KNOWN LIMITATION explicitly called out in the comment (Symptom A still occurs, see vw-bridge-known-issues.md)

**Version bumped at 4 canonical sites:** header L1, dispatcher comment L290, doDispatch comment L320, /health body L339. Test assertion in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st#L98) updated to expect `"version":"0.8.11"`.

**Verification (3 probes, all green):**

| Probe | Expected | Result |
|---|---|---|
| `/health` post-reload | `version:0.8.11` | ✓ `{"status":"ok","version":"0.8.11"}` |
| Standalone `Dialog confirm:` fork + bridge respond Yes | Fork unwedges with nil return, no silent wedge | ✓ `B_TEST1_RET='nil-returned'`, `purgedWedged:1` in response, 0 wedged procs after |
| Bug #2 scenario (`fork [model find]` + bridge respond Yes) | Fork unwedges with MustBeBoolean (caught by on:do:), no silent wedge, no debugger window | ✓ `B3_FIND_STATE='exception: MustBeBoolean - NonBoolean receiver--proceed for truth.'`, `purgedWedged:1`, `partialMatchResults=nil` (Symptom A still occurs but visibly) |

### Phase 4 — Commit wave (2 commits for v0.8.11 work)

| Hash | Subject | Files |
|---|---|---|
| `61079c0` | feat: VWBridge v0.8.11 - Bug #2 partial fix via purgeWedgedDialogProcesses | `src/vw-bridge/VWBridge.st`, `src/vw-bridge/VWBridge-Test.st` |
| `b1b943f` | docs: Bug #2 - session-6 findings + v0.8.11 partial fix status | `knowledge/vw-bridge-known-issues.md` |

Style: SEMANTIC prefix matches the repo's existing convention. 2-commit split per session-3/4/5 "3+ files → 2+ commits" rule (3 files modified → code commit + docs commit).

### Phase 5 — This handoff (commit wave 2, 1 commit)

| Hash | Subject | Files |
|---|---|---|
| (this commit) | docs: add HANDOFF-2026-06-20-session6 - session-6 EOD | `knowledge/HANDOFF-2026-06-20-session6.md` |

---

## Current state (end of session-6)

- **VW image:** still up at `vwnt.exe` PID 5624 (started 1:07:31 PM today, before session-6 began). 6 windows currently: GbxVisualLauncher (GemStone Launcher), VisualLauncher (storedev64), WealthPublishedPundleVersionsTool (MAS Loaded Items), Workbook (Workspace), MasLauncher (MOMENTUM WEALTH - DEVELOPER --- Session Number: 4), PartySearchView (Party Search at `8 @ 230 corner: 792 @ 814`). No debugger windows. No stray SimpleDialog. 0 wedged dialog processes.
- **Bridge:** UP at v0.8.11 on `127.0.0.1:9876`. Token at [.token](../src/vw-bridge/.token) (rotated by every `VWBridge start`; current value `3959417880773-582260` after session-6's `/eval` file-in).
- **`Dialog useNativeDialogs: false`:** SET via `/eval` (after detecting the user's Workspace toggle didn't stick). Will reset to `true` on `vwnt.exe` restart — re-toggle on session-7 resume.
- **Bridge code on disk:** v0.8.11 in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) (~73 KB, ~1700 lines), matches what's running in the image. New helper at L1392 (`purgeWedgedDialogProcesses`).
- **SUnit scaffold on disk:** [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) version-locked to v0.8.11 (`testHealthReturnsCurrentVersion` asserts `"version":"0.8.11"`). NOT loaded in image this session — file-in via Workspace when needed.
- **Image globals from session-6 probes** (will get cleared on `vwnt.exe` restart):
  - `BUG2_MODEL` / `BUG2_CTRL` / `BUG2_SD_CTRL` / `BUG2_SD_MODEL` / `BUG2_YES_BTN` / `BUG2_YES_SPEC` / `BUG2_BTN_VIEW` / `BUG2_BTN_CTRL` — captures of the Party Search model + the modal's structure
  - `BUG2_INJECT1..4` / `BUG2_ISO_A..G` — outcome strings from the 8 Direction A candidate attempts
  - `BUG2_FIND_STATE` / `B2_FIND_STATE` / `B3_FIND_STATE` — fork return states from the test cycles (current value: `'exception: MustBeBoolean - NonBoolean receiver--proceed for truth.'` from the v0.8.11 end-to-end test)
  - `B_TEST1_RET` / `B_TEST1_EXC` / `B_FORK_SEMA` / `B_FORK_PROC2` / `B_EVENT_QUEUE` / `B_WIN_MGR` — Direction B isolation test artifacts
- **Git:**
  - `main` at `b1b943f` LOCALLY, **2 commits ahead of `origin/main`** (or 3 after this handoff lands). About to push during this wrap.
  - Working tree CLEAN before this handoff edit; about to become +1 file (this handoff) → 3 commits ahead before push, then 0 after push.
- **Known bugs:**
  - **Bug #1: FIXED in v0.8.7** (committed in session-4)
  - **Bug #2: PARTIALLY MITIGATED in v0.8.11** (committed this session; silent wedges gone, MustBeBoolean now catchable, but Symptom A — `partialMatchResults` populates — STILL FAILS because force-close returns nil regardless of accept ValueHolder). Three concrete paths for full fix logged.
  - **Bug #3: not a bug** (calibration only)
  - **Bug #4: FIXED in v0.8.6** (committed in session-4)
  - **Bug #4b: FIXED in v0.8.10** (committed in session-5)
  - **Bug #5: FIXED in v0.8.8** (committed in session-4)

---

## Pending tasks (session-7)

### Immediate on resume

1. **Push the 3 local commits** (2 already + this handoff). User explicitly authorized for THIS wrap via "Commit + push + handoff (Recommended)" — future sessions need fresh authorization.
2. **(Optional) Restart `vwnt.exe`** if you want a clean image for full Symptom A fix attempts. Not strictly required for session-7 — current image is clean (0 wedged procs) since v0.8.11 prevents wedge accumulation. Restart only if you want a deterministic baseline.
3. **(Required after any vwnt restart) Re-toggle `Dialog useNativeDialogs: false`** — resets to `true` on restart. Set via Workspace if bridge is DOWN, else via `/eval`:
   ```smalltalk
   Dialog useNativeDialogs: false
   ```
4. **(Required after any vwnt restart) File-in v0.8.11 bridge:**
   - If bridge is DOWN: paste in Workspace: `'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn`
   - If bridge is UP at a prior version: use `/eval` with the same command
5. **Verify state:**
   ```powershell
   curl.exe -sS http://127.0.0.1:9876/health
   # expect {"status":"ok","version":"0.8.11"}
   ```
6. **Re-read token** from [.token](../src/vw-bridge/.token) (rotated on every `VWBridge start`).

### Bug #2 Symptom A — three paths for FULL fix (pick ONE per session)

Session-6 v0.8.11 ships the SILENT WEDGE prevention. Symptom A (partialMatchResults never populates because `Dialog confirm:` returns nil) remains. Three concrete paths:

**Path 1: OS event injection (Direction A revival).** Probe `MouseButtonEvent` / `ButtonPressedEvent` / `RedButtonPressedEvent` / `InputEvent` / `UIEvent` constructors — none are in `Root.Smalltalk` globals (session-6 probed all 5 candidates). Look in pundles like `UIPainter`, `EventManager`, `WindowManager`, or the loaded MAS pundles. Once you have a constructor, build a press+release event pair targeted at the YesButton's bounds and feed via `sensor eventButtonPress: <evt>` + `sensor eventButtonRelease: <evt>`. The sensor is the dialog's input source; events through this path should fire the YesButton's REAL click handler, which sets accept value: true AND signals proper modal exit. Most click-faithful path; hardest construction.

**Path 2: MAS-side `Dialog>>confirm:` override.** Define a MAS-namespace subclass or override that reads `dialog accept value` at force-close instead of returning the framework default. Lowest technical risk if MAS team is willing — change is one method addition. Wider organisational risk because it touches MAS code, not the bridge. Requires MAS team buy-in for a commit.

**Path 3: Process surgery.** Walk the wedged fork's stack to its modal loop frame, mutate the return value or unwind with a value-carrying exception (a custom exception class that the modal loop's `on:do:` resumes with `true`). Brittle, image-version-specific. Not recommended unless paths 1 and 2 both fail.

Recommended order: Path 2 (talk to MAS team) → Path 1 (if MAS team says no) → Path 3 (if everything else fails). Path 1 is doable but significantly more work than Direction A's original handoff anticipated.

### Carry-overs from prior sessions (still pending)

7. **EXPLORATION-PLAN step 3** — 3-deep menu navigation. Pick a leaf like `Party & Contract` → `General reports` → `Contract status` (read-only-sounding, no mutation verb). Verify `walkMenuPath:` handles nested submenus.
8. **EXPLORATION-PLAN step 4** — leaf dispatch catalog across MAS menu tree. Confirm/falsify "all MAS leaves use BlockClosure".

### Production-grade packaging (medium-term, coordinated with user)

9. **Self-test coverage expansion.** Add tests for `/click` (mock Party Search if needed), `/menu`, `/dialogs` (post-v0.8.11), `/value`, `/windows/tree`. Bridge towards CI-runnable suite. Now also: a test for `purgeWedgedDialogProcesses` via a forked `Dialog confirm:` scenario.
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
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | **CANONICAL v0.8.11** — all fixes from session-3 (Bug #1, #4), session-4 (Bug #5, partial #4b), session-5 (full #4b + latent indexOf:startingAt: repair), session-6 (Bug #2 partial fix via `purgeWedgedDialogProcesses` at L1392) applied. File via Workspace if bridge is DOWN (after `vwnt.exe` restart), OR via `/eval` `'...VWBridge.st' asFilename fileIn` if bridge is UP. |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | SUnit scaffold (7 tests + 6 helpers). Version-locked to v0.8.11. RUN ONLY from VW Workspace for green results — `/eval`-driven runs all return 400 cleanly in v0.8.8+ but go red on assertions. |
| [`src/vw-bridge/.token`](../src/vw-bridge/.token) | Bridge token (auto-rewritten on every `VWBridge start`). Current value `3959417880773-582260`; will rotate on next file-in. |
| [`src/vw-bridge/archive/`](../src/vw-bridge/archive/) | Historical 7-file phase chain. Reference only — do NOT file in. |
| [`src/vw-bridge/SESSION-RESUME.md`](../src/vw-bridge/SESSION-RESUME.md) | "FIRST ACTION on resume" guide. Single-file install. |
| [`src/vw-bridge/EXPLORATION-PLAN.md`](../src/vw-bridge/EXPLORATION-PLAN.md) | Step-by-step plan — steps 1+2 done, 3+4 pending. |
| [`knowledge/vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) | Bugs #1-#5 with status. **#1/#4/#4b/#5 FIXED, #2 PARTIALLY MITIGATED v0.8.11** (with session-6 deep dive findings appended to Bug #2 entry — wrap discovery, purge mechanism, capability discoveries, three paths for full Symptom A fix). |
| [`knowledge/vw-party-search.md`](./vw-party-search.md) | PartySearchView usage guide. Workaround for Bug #2 Symptom A (bypass partialFind:, call `ContractManager` directly) STILL REQUIRED for `#contractNumber` / `#surname`. |
| [`knowledge/vw-bridge-testing.md`](./vw-bridge-testing.md) | Bridge testing methodology + anti-patterns. |
| [`knowledge/vw-input-recovery.md`](./vw-input-recovery.md) | What to do if VW input wedges. **Note: session-6 found wedge accumulation is now prevented by v0.8.11's purgeWedgedDialogProcesses — update this doc when next touched.** |
| [`knowledge/vw-dialogs.md`](./vw-dialogs.md) | Dialog/SimpleDialog/closeAndUnschedule mechanics. **Note: this doc's "ValueHolder on: false. Modal exits when set to true." is incorrect — session-5 found `close value=true` is already true mid-modal, session-6 confirmed the modal loop polls `EventQueue>>next` on a Semaphore, not the close ValueHolder. Update this doc when next touched.** |
| [`knowledge/vw-eval-cookbook.md`](./vw-eval-cookbook.md) | Useful `/eval` recipes. Could add a session-6 recipe: "find wedged dialog processes via Process allInstances stack walk". |
| [`knowledge/smalltalk-gotchas.md`](./smalltalk-gotchas.md) | Chunk format, namespace qualification, ComposedText, etc. |
| [`knowledge/CONSOLIDATION-NOTES.md`](./CONSOLIDATION-NOTES.md) | Audit trail of the v0.8.5 consolidation. |
| [`knowledge/HANDOFF-2026-06-19.md`](./HANDOFF-2026-06-19.md) | Session-3 EOD handoff. Committed at `a434f69`. |
| [`knowledge/HANDOFF-2026-06-20.md`](./HANDOFF-2026-06-20.md) | Session-4 EOD handoff. Committed at `aedd18b`. |
| [`knowledge/HANDOFF-2026-06-20-session5.md`](./HANDOFF-2026-06-20-session5.md) | Session-5 EOD handoff. Committed at `b9f5bc9`. |
| [`knowledge/HANDOFF-2026-06-20-session6.md`](./HANDOFF-2026-06-20-session6.md) | **THIS FILE.** Session-6 EOD. |

---

## Important decisions (this session)

- **Direction A → Direction B pivot at the right time.** Spent ~8 candidate attempts on Direction A (closeAccept, spec model value, dispatchBlockClosure, triggerButtonClickedEvent, accept+checkForAccept, closeDrainEventsAndUnschedule, forkProc interruptWith). When all failed AND the librarian's open-uncertainty #3 explicitly pointed at the wrap-context hypothesis, asked the user via question tool with 4 options. User picked B. Pivot was clean — no over-investment in a dead path.
- **Library agent fired early.** Background `librarian` agent (`bg_7161b2d1`) launched at the start of Direction A work for VW ActionButton click pipeline research. Found Dolphin MVP `performAction` + Squeak MVC fixture patterns (rank #1 candidate), confirmed `Process>>interruptWith:` mechanics, and crucially flagged open-uncertainty #3 (the wrap-context hypothesis that turned out to be correct). Without that research direction A would have continued chasing dead ends.
- **Stack walk via `Process allInstances` was the breakthrough tool.** Discovered when probing for process enumeration; turned out to be the ONLY way to find wedged forks since `mgr activeControllerProcess` returns nil during modals and `Processor allProcesses` doesn't exist. Captured as a generic capability — useful for future bridge debugging.
- **`closeDrainEventsAndUnschedule` rejected for v0.8.11** even though it closes without MustBeBoolean. Reason: leaves fork wedged silently (worse than current). Documented as a discovered-but-not-shipped candidate.
- **v0.8.11 = STRICTLY BETTER than v0.8.10, not a full fix.** Trade-off accepted: ship the partial fix now (real improvement on three dimensions — silent wedges gone, accumulation prevented, response JSON richer) rather than block on the full Symptom A fix which requires significantly more work (OS event injection or MAS-side change). Communicated to user via the decision-point question; user confirmed.
- **Atomic 2-commit split for v0.8.11** (code + docs). Matches session-3/4/5 "3+ files → 2+ commits" convention. Each commit's scope is clean.
- **Bug #2 doc has THREE separate "investigation findings" subsections now** (session-3 root cause, session-5 NonBoolean evidence, session-6 v0.8.11 partial fix). Considered consolidating but kept the chronological structure for archaeological clarity — future sessions can trace how the diagnosis evolved.
- **Empty "### Proposed fix (Phase B+1 or Phase C)" stub at the bottom of Bug #2 REMOVED** in the session-6 docs edit. The original "Proposed fix" subsection at L179 (pre-session-5) is preserved as historical context. The actual current proposed fixes are documented inline in the session-5 + session-6 sections.
- **No PUSH yet at handoff write time.** User explicitly authorized "Commit + push + handoff (Recommended)" — handoff first (this file), commit, then push all 3.

---

## Explicit constraints (carry forward)

- **NEVER commit, amend, or push** without explicit user request. Session-6 had explicit "Commit + push + handoff (Recommended)" via question-tool choice; future sessions need fresh authorization.
- **NEVER call `VWBridge singleton dispatch:` from inside `/eval`.** v0.8.11 inherits v0.8.8's Stage 1 + Stage 2 contains, returns 400 cleanly, but still don't do it intentionally.
- **OFF-LIMITS widgets** without explicit OK: `commitWidget`, `loginRpcWidget`, `removeWidget`. **MAS menu leaves with mutation verbs** (add/delete/transfer/commit/change/update/process/submit/upload) need OK before any `/menu/click`.
- **`windowTitle` is CASE-SENSITIVE substring match.**
- **For Workspace file-in (bridge DOWN scenario):** `'path' asFilename fileIn.`, NOT Launcher → File Browser → File In.
- **For `/eval` file-in (bridge UP scenario, v0.8.8+):** PowerShell + `curl.exe` with `--data-binary @file` pattern. Token rotates on every reload — re-read `.token` afterward.
- **`$'` character literal is unreliable** in chunk file-ins. Use `(Core.Character value: 39)`.
- **GBS namespace qualification** — `Root.Smalltalk`, `Core.String`, `Core.Character`, `Core.Error`, `Core.Array`, `Core.Integer`, `Core.OrderedCollection`, `Core.Dictionary`.
- **`/eval` runs on bridge serve process**, NOT UI process. UI-touching `/eval` needs `ScheduledControllers activeControllerProcess interruptWith:` wrapping (or fork). AND must not re-invoke `bridge dispatch:` (v0.8.8 Stage 2 catches with 400 but you still don't want to write it).
- **`mgr activeControllerProcess` returns nil DURING a modal.** Confirmed session-6. Bridge's `onUIDo:` falls back to direct serve-process execution in that case. This is why cross-process modal manipulation requires the new purgeWedgedDialogProcesses approach instead of an `interruptWith:` injection on the UI process.
- **Image sources are STRIPPED**: `(cls compiledMethodAt: sel) getSource` returns nil for all methods including base-image SimpleDialog/Dialog methods. Investigation must be runtime probes (`canUnderstand:`, behavior observation via globals, `respondsTo:` filters, Process allInstances stack walk), NOT source inspection.
- **String `indexOf:startingAt:` does NOT exist** in this image. Use `nextIndexOf:from:to:` (available substitute). `indexOf:` (1-arg) and `indexOfSubCollection:startingAt:` (2-arg substring) both work.
- **Standard `instVarNames` is CLASS-SIDE, not instance-side.** `model instVarNames` MNU — use `model class instVarNames`.
- **`isCollection` does NOT exist** as a generic selector here — use `respondsTo: #do:` or `respondsTo: #reverseDo:` instead.
- **`canUnderstand:` is CLASS-SIDE.** Send to `instance class canUnderstand: #sel`, NOT `instance canUnderstand: #sel` (the latter MNUs).
- **`Process allInstances` works (~200-300 procs); `Processor allProcesses` does NOT exist.** Use `Process allInstances asArray select: [:p | ...stack walk filter...]` for process enumeration. Stack walk pattern: `walk := p suspendedContext. [walk ~~ nil and: [...]] whileTrue: [... walk := walk sender]`.
- **`Character>>asString` calls `printString`** (returns e.g. `'Core.Character lf'`) in this image, NOT a 1-char string. To get a 1-char string from a Character, use `String with: aCharacter`.
- **PowerShell `-Body` with literal JSON inline is QUOTE-HELL.** Use `--data-binary "@path/to/file.json"` instead. Bash-tool `-Body '{"choice":"OK"}'` returned `{"error":"invalid_json"}` until switched to file-based POST.
- **PowerShell `Start-Job` jobs vanish across `bash` tool invocations** (each invocation is a fresh PowerShell session). Don't rely on jobs from prior tool calls.
- **PowerShell here-strings `@'...'@` do NOT require doubled single quotes** (unlike `'...'`). Inside a here-string, `'partialMatchResults'` is the literal text including the surrounding quotes; doubling them produces `''partialMatchResults''` which is invalid Smalltalk. Session-6 hit this twice.
- **Git is in WSL (`wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git ...`), not on PowerShell PATH.** Session-6 confirmed git version 2.53.0 in Ubuntu WSL. For commits/push/log from the bash tool, use the WSL form.
- **PowerShell auto-table-formats arrays of PSCustomObject from `Invoke-RestMethod`,** which can hide all values if columns infer wrong. For raw JSON inspection use `Invoke-WebRequest -UseBasicParsing` then `($r.Content | ConvertFrom-Json)` then iterate explicitly.

---

## Context for continuation (read this before resuming)

- **Bridge is UP at session-6 EOD.** v0.8.11, token `3959417880773-582260`. Image has 0 wedged dialog procs (verified). If vwnt.exe restarts before session-7, redo Phase 0 (Workspace file-in + Dialog flag toggle).
- **`Dialog useNativeDialogs: false`** SET via `/eval` (session-6 found Workspace toggle didn't stick on first try). Will DEFINITELY reset to `true` on `vwnt.exe` restart. Verify with `Dialog usesNativeDialogs printString` via `/eval` after any restart, regardless of what Workspace shows.
- **2 LOCAL ONLY commits + this handoff = 3 commits to push.** User authorized push for THIS wrap; future sessions need fresh push authorization.
- **Bug #2 Symptom A is the next big-value bug.** Three concrete paths logged (OS event injection / MAS-side override / process surgery). User can choose to pursue OR move to carry-overs / production packaging.
- **For ANY bridge change in v0.8.12+**: edit [`VWBridge.st`](../src/vw-bridge/VWBridge.st), reload via `/eval` file-in (bridge UP), bump version at 4 sites (header, dispatcher comment, doDispatch comment, /health body) + the matching `testHealthReturnsCurrentVersion` assertion. Don't forget the docstring of any rewritten method — session-6 found the pre-v0.8.11 `doRespondDialog:` comment was OUTDATED (claimed closeAndUnschedule wakes the loop; it doesn't). Update comments when behavior assumptions change.
- **For ANY new SUnit tests**: add to [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st). Prefer calling handler methods directly (e.g. `bridge handleWindows`) over `bridge dispatch: ...`. NEW test idea for v0.8.11: a forked `Dialog confirm:` + verify `purgeWedgedDialogProcesses` returns count=1 and the fork completes.
- **Production-grade packaging is on the roadmap, NOT critical path.** Bug #2 Symptom A full fix + SUnit coverage expansion come FIRST.

---

## To continue in a new session

1. Press `n` in OpenCode TUI to open a new session, or run `opencode` in a new terminal.
2. Paste this entire file as your first message.
3. Add your request — pick one based on focus:
   - "Continue from handoff above. Attempt Bug #2 Symptom A full fix via Path 2 (MAS-side `Dialog>>confirm:` override). Probe what method actually returns the value to the caller, design the override, test in isolation." — lowest technical risk if MAS team supports it.
   - "Continue from handoff above. Attempt Bug #2 Symptom A full fix via Path 1 (OS event injection). Probe MouseButtonEvent/RedButtonPressedEvent/ButtonPressedEvent constructors across loaded pundles (UIPainter, EventManager, WindowManager namespaces). Once found, construct press+release pair on YesButton bounds, feed via sensor eventButtonPress:/eventButtonRelease:." — most click-faithful, hardest construction.
   - "Continue from handoff above. Skip Bug #2 entirely, do EXPLORATION-PLAN step 3 (3-deep menu navigation) and step 4 (leaf dispatch catalog)." — carry-over backlog.
   - "Continue from handoff above. Pivot to production-grade packaging — SUnit coverage expansion (add test for purgeWedgedDialogProcesses), config externalization (env vars), file-based structured logging, /state + /reset endpoints." — medium-term track.
   - "Continue from handoff above. Update the three stale knowledge docs flagged in this handoff: vw-input-recovery.md (wedge accumulation now prevented), vw-dialogs.md (close ValueHolder semantics are wrong), vw-eval-cookbook.md (add Process allInstances stack walk recipe)." — docs hygiene pass.

The new session will have full context to continue seamlessly.
