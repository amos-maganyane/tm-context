# Handoff — Phase F3 COMPLETE, bridge at v0.9.1 (session 2026-06-21 session-13 EOD)

**Written:** session-13 EOD after closing out the [PLAN-PHASE-F-SCREENSHOT.md](../plan/PLAN-PHASE-F-SCREENSHOT.md) 20-step checklist (Steps 17–20 landed; Steps 10–16 carried over from session-12). Five atomic commits ([`5a84f4a`](#step-17-wait-mechanism-fix), [`ab068c2`](#step-17-wait-mechanism-fix), [`82f0eb6`](#step-18-screenshot-http-route--binary-socket-write), [`38a56c6`](#step-19-windowsummaries-rect-keys-for-window-target-http), [`8f03710`](#step-20-version-bump-v091)) pushed cleanly to `origin/main` (`a12f40b..8f03710`).

**For session-14:** (1) standing decisions Phase C (API freeze + OpenAPI spec for v0.9.1, 14 endpoints), Phase D (auto-start), Phase E (Playwright SDK); (2) doc-debt now CURRENT — `vw-image-api-contract.md` updated with 6 new constraints, `PLAN-PHASE-F-SCREENSHOT.md` marked 20/20; (3) carry-overs from session-7..11 still pending (EXPLORATION-PLAN steps 3–4, #id/#imcNr/#groupScheme verify via bridge).

**Supersedes:** nothing. [`HANDOFF-2026-06-20-session12.md`](./HANDOFF-2026-06-20-session12.md) remains the session-12 EOD; this file is session-13 EOD.

---

## User direction this session (condensed)

- Resume prompt with 3 anchor docs, Phase 0 verification (bridge v0.9.0 + token + 0 commits ahead), surface 4 standing decisions.
- Picked **Option 1: Step 17 wait-mechanism fix**, candidate (a) `execute:arguments:do:errorStreamDo:` one-shot first.
- After each step: picked **commit shape** (split for Step 17, single for Steps 18–20).
- Push deferred until session EOD.
- Feedback mid-session: commit messages were too long — switched to conventional format from Step 20 onward.

---

## Work completed in session-13

### Step 17 — wait-mechanism fix

Three probes ([`_probe-step17-execute-one-shot.st`](../src/vw-bridge/probes/_probe-step17-execute-one-shot.st), [`_probe-step17-execute-pwsh-png.st`](../src/vw-bridge/probes/_probe-step17-execute-pwsh-png.st), [`_probe-step17-execute-binary.st`](../src/vw-bridge/probes/_probe-step17-execute-binary.st)) narrowed the broken `bare proc wait` (session-12) to the working `execute:arguments:do:errorStreamDo:` one-shot pattern + `outStream binary` flip:

| Finding | Detail |
|---|---|
| One-shot wait works | Class-side and instance-side both return `'hello'` from `cmd /c echo hello` in 107ms (vs broken bare `proc wait` returning exit=259 STILL_ACTIVE) |
| Without `outStream binary` | `upToEnd` returns `TwoByteString` with codepage-mangled bytes (PNG magic 137 → 235 via 0x89 → 0xEB) |
| With `outStream binary` | `upToEnd` returns `ByteArray` byte-faithful — first 16 bytes match PNG magic + IHDR start exact |

Production [`captureScreenshotViaSubprocess:rect:`](../src/vw-bridge/VWBridge.st#L2504) swapped from bare-wait to one-shot + binary flip (single method body replacement, +43/-45 lines, no signature/ivar change). Verified via `_probe-step17-verify-direct.st`: direct bridge invocation with no override returns ByteArray 851KB+ with PNG magic + 2560x1440 IHDR.

Commits: **[`5a84f4a`](#)** (production fix) + **[`ab068c2`](#)** (5 probe artifacts).

### Step 18 — /screenshot HTTP route + binary socket-write

Added `/screenshot` POST route at [`doDispatch:` L555](../src/vw-bridge/VWBridge.st#L555). First HTTP test produced curl exit=52 empty reply. [`_probe-step18-socket-write.st`](../src/vw-bridge/probes/_probe-step18-socket-write.st) opened a side TCP server, probed the actual stream class (`ExternalReadAppendStream`), and confirmed:

| Strategy | Result |
|---|---|
| `lineEndTransparent` + `nextPutAll: aByteArray` (production at L430) | **ERR "Strings only store Characters"** (swallowed by `on: err do: [:ex | nil]` → empty reply) |
| `stream binary` + `nextPutAll: aByteArray` | **works** (same pattern as Step 17 outStream binary fix) |
| `nextPut:` byte-by-byte loop | works (slower fallback) |

Fix: 6-line addition in [`serve:` L430](../src/vw-bridge/VWBridge.st#L430) flipping stream to binary ONLY when response `isKindOf: ByteArray`. String responses (13 existing endpoints) unaffected. Real-HTTP verify: `POST /screenshot` returns 200 OK + image/png + 855KB body + Content-Length exact match + PNG magic + System.Drawing decodes as 2560x1440 Format32bppArgb.

Commit: **[`82f0eb6`](#)**.

### Step 19 — windowSummaries rect keys for window-target HTTP

First window-target POST returned 500 "Key not found:". Root cause: production `windowSummaries` produced dicts with `bounds` printString only, but [`captureScreenshotViaSubprocess:rect:`](../src/vw-bridge/VWBridge.st#L2552) reads `originX/originY/cornerX/cornerY` integer fields (which only existed in test scaffolds — VWBridge-ScreenshotTest.st helpers). The mismatch was a session-11/12 design oversight (all 10 SUnit tests still GREEN because they use scripted snapshots with the right shape).

Fix: extended [`windowSummaries`](../src/vw-bridge/VWBridge.st#L614) with 4 new integer fields computed from `view displayBox`. Additive only — `bounds` printString preserved for backward compat with /windows JSON consumers. Defensive: all 5 fields return nil if view/displayBox unavailable.

Verified: `POST /screenshot {target:{type:window,appClass:MasLauncher}}` returns 200 OK + image/png + 27KB body (vs 855KB full-screen — proves window region) + X-VWBridge-Screenshot-Width=831 / Height=322 matching MasLauncher bounds 362,684→1193,1006 + PNG magic + System.Drawing decodes as 831×322 Format32bppArgb.

Commit: **[`38a56c6`](#)**.

### Step 20 — version bump v0.9.1

Standard release procedure:

- VWBridge.st L1 banner: `v0.9.0 -- /wait endpoint` → `v0.9.1 -- /screenshot endpoint`
- VWBridge.st L5-25 history paragraph: appended v0.9.1 (session-13) section
- VWBridge.st L549 /health JSON: `0.9.0` → `0.9.1`
- VWBridge-Test.st testHealthReturnsCurrentVersion assertion + description: `0.9.0` → `0.9.1`

Verified: `curl /health` returns `{"status":"ok","version":"0.9.1"}`.

Commit: **[`8f03710`](#)** (conventional-length message).

---

## Current state (end of session-13)

- **VW image**: still up at `vwnt.exe` PID **5624**, started 6/20/2026 1:07:31 PM (UNCHANGED across sessions 9–13, 5-session continuous run).
- **Bridge**: UP at **v0.9.1** on 127.0.0.1:9876. Token at EOD: `3959486010866-91744` (rotated during session-13 file-ins).
- **`Dialog useNativeDialogs: false`**: SET (carried since session-7).
- **Bridge code on disk**: matches image (all changes filed-in and committed).
- **SUnit on disk**: VWBridge-Test.st `testHealthReturnsCurrentVersion` updated to assert v0.9.1. VWBridge-ScreenshotTest.st unchanged (10 tests still conceptually GREEN via direct-invocation verification — full SUnit suite confirmation via VW Workspace still deferred).
- **Git**: `main` is **even with `origin/main`** (5 session-13 commits pushed).
- **Untracked**: `opencode.json` (not mine — left alone per worktree etiquette).
- **MAS window state**: unchanged from session-12 (no /click etc this session).

---

## NEW carry-forward constraints from session-13

Both added to [`vw-image-api-contract.md`](./vw-image-api-contract.md) under "APIs PRESENT with surprising behavior" + "Carry-forward constraints summary".

### 6. `OS.ExternalProcess` one-shot pattern is the working synchronous-wait mechanism

Resolves session-12 constraint #4 (bare `proc wait` doesn't actually wait). The working pattern:

```smalltalk
OS.ExternalProcess
    execute: 'cmd.exe'
    arguments: #('/c' 'whatever')
    do: [:outStream | outStream binary. outStream upToEnd]
    errorStreamDo: [:errStream | errStream upToEnd asString].
```

- Class-side just calls `new` then dispatches to the instance method.
- The `do:` block drains stdout during subprocess lifetime, which makes `wait` synchronize correctly.
- `outStream` is a `StandardIOStream` — character-mode by default. Without `binary` flip the bytes get codepage-decoded (PNG magic 0x89 becomes 0xEB).
- For binary stdout: `outStream binary. outStream upToEnd` returns a `ByteArray` byte-faithful.

### 7. `ExternalReadAppendStream nextPutAll:` rejects `ByteArray` — flip to `binary` first

Connection streams from `SocketAccessor>>readAppendStream` / `readWriteStream` are character-mode by default. `nextPutAll: aByteArray` raises `Error 'Strings only store Characters'`. Fix:

```smalltalk
(response isKindOf: ByteArray) ifTrue: [stream binary].
stream nextPutAll: response.
```

After `binary`, `nextPutAll: aByteArray` succeeds byte-faithful. `lineEndTransparent` is set already in `serve:` but is moot under binary mode (no translation either way). Byte-by-byte `nextPut:` loop also works as a slower fallback.

---

## Pending tasks (session-14)

### Standing decisions (unchanged from session-12)

1. **Phase C** — API freeze + OpenAPI spec for the v0.9.1 surface (14 endpoints now /screenshot ships). Hand-write `docs/openapi.yaml` + CI drift check. Natural next step. ~4–6h.
2. **Phase D** — auto-start architecture. Three paths converge on external trigger. Oracle consult on tradeoffs. ~1 session.
3. **Phase E** — Playwright TypeScript SDK + first 3 tests against v0.9.1 bridge. Depends on Phase C ideally.

### Carry-overs (from session-7..11, still pending)

4. EXPLORATION-PLAN step 3 — 3-deep menu navigation.
5. EXPLORATION-PLAN step 4 — leaf dispatch catalog across MAS menu tree.
6. End-to-end verify of `#id` / `#imcNr` / `#groupScheme` no-modal partialFind: paths via bridge.

### Production-grade packaging (medium-term)

7. Log rotation. Class-side log mutex for concurrent fork safety. Env-var externalization of log/.token/port/parcel/screenshot-helper paths (5 hardcoded paths now). Parcel build script (depends on Phase D).

---

## Key files modified/created this session

| File | Change |
|---|---|
| [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) | Step 17 captureScreenshotViaSubprocess: rewrite + Step 18 /screenshot route + binary socket-write + Step 19 windowSummaries rect keys + Step 20 v0.9.1 banner/history/health |
| [`src/vw-bridge/VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) | Step 20 testHealthReturnsCurrentVersion asserts v0.9.1 |
| [`src/vw-bridge/probes/_probe-step17-execute-one-shot.st`](../src/vw-bridge/probes/_probe-step17-execute-one-shot.st) | Behavioural fingerprint + cmd echo sync test |
| [`src/vw-bridge/probes/_probe-step17-execute-pwsh-png.st`](../src/vw-bridge/probes/_probe-step17-execute-pwsh-png.st) | PowerShell capture confirmed TwoByteString mangling |
| [`src/vw-bridge/probes/_probe-step17-execute-binary.st`](../src/vw-bridge/probes/_probe-step17-execute-binary.st) | `outStream binary` flip → ByteArray byte-faithful |
| [`src/vw-bridge/probes/_probe-step17-verify-direct.st`](../src/vw-bridge/probes/_probe-step17-verify-direct.st) | End-to-end production capture verification |
| [`src/vw-bridge/probes/_addon-step17-one-shot-fix.st`](../src/vw-bridge/probes/_addon-step17-one-shot-fix.st) | Image-side method replacement addon (pre-disk-persist) |
| [`src/vw-bridge/probes/_probe-step18-socket-write.st`](../src/vw-bridge/probes/_probe-step18-socket-write.st) | Side-TCP-server probe — found ExternalReadAppendStream binary requirement |
| [`knowledge/vw-image-api-contract.md`](./vw-image-api-contract.md) | Added 6 carry-forward constraints (5 from session-12 + 1 new session-13) |
| [`plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) | Marked 20/20 done + added session-13 progress section |
| [`knowledge/HANDOFF-2026-06-21-session13.md`](./HANDOFF-2026-06-21-session13.md) | **THIS FILE** |

---

## Important decisions this session

- **Probe-first for Step 17**: 3 probes (one-shot API + PowerShell capture + binary flip) before touching production code. Each probe answered one question. Total ~10 min vs the 90-min session-12 debug saga that had to retrofit understanding.
- **Direct-invocation verify pattern continued**: per session-12 constraint #2, all SUnit-style assertions checked via direct method invocation + response inspection, not via /eval-run-SUnit (which pops the VW debugger).
- **Commit cadence per-step**: Step 17 split into fix + probes commits (matches session-12 pattern); Steps 18/19 single commits each (smaller diffs); Step 20 conventional release commit.
- **Conventional commit message length from Step 20 onward**: per user feedback that previous long messages were unusual. Earlier session-13 commits (5a84f4a, ab068c2, 82f0eb6, 38a56c6) retain long messages and are now in history — debug context lives in this handoff anyway.
- **Push at EOD only**: matches session-12 cadence. All 5 commits stayed local until session close, then pushed atomically (`a12f40b..8f03710`).
