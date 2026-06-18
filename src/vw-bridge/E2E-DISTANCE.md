# VWBridge — Distance to First End-to-End Test POC

> Snapshot taken while diagnosing the Phase A v0.7 file-in error. Records the
> answer to: *"how far are we from a Python test that can navigate and walk
> flows in the live WEALTH/MAS image?"*

## TL;DR

Technically very close — **one working session** to a green-field smoke E2E
test, assuming Phase A's click/type actually works on a real widget (which we
verify the moment Phase A files in cleanly and we run the acceptance grid in
[`HANDOFF.md`](./HANDOFF.md)). A real WEALTH/MAS regression test is then
dominated by the **sandbox question** (which flow is safe to automate against
which stone), not by bridge work.

---

## Cost-to-first-E2E, by milestone

| Milestone | Blocker | Effort |
|---|---|---|
| **"Hello bridge" smoke test in Python** — open Workspace, `POST /type importSummary = "hello"`, `GET /value` returns it | Phase A must actually click/type a real widget (probe only confirmed the *surface* exists, not behavior) | ~1 hour after Phase A files in clean. ~50 LOC of `requests` + `pytest`. |
| **Single-screen flow** — fill 2 fields, click a button, assert a downstream widget's value | Same as above + button click actually fires the action callback (v0.7's `model value: true` PluggableAdaptor strategy is unproven against a real button) | Same session if hello-bridge works. |
| **Multi-window flow** — click → new window opens → walk the new window's widget tree | Client-side **wait helper** that polls `/windows` until the target window title appears. Server-side fine as-is. | ~30 minutes — pure Python helper. |
| **Real WEALTH/MAS user flow** | **Not a code problem** — a sandbox problem. The HANDOFF explicitly forbids `commitWidget` / `loginRpcWidget` / `removeWidget` without explicit sign-off because they hit prod GemStone at `invgemprd101.metmom.mmih.biz`. | Pick a flow that doesn't mutate prod, OR get sign-off to use the dev stone (`invgemdev101`) end-to-end. |

---

## What the bridge does NOT cover yet

| Capability | Status | Needed for first E2E? |
|---|---|---|
| Click, type, read value | Phase A v0.7 — about to land | Yes |
| Wait-for-widget / wait-for-window | Client-side polling on `/windows` works today | Yes, but trivial |
| Modal dialog handling | Modal is just another `ScheduledWindow` — should appear in `/windows` | Probably works as-is, untested |
| Menu navigation (File → Open, etc.) | **Not yet** — menus aren't in `builder namedComponents`, they're `MenuBuilder` constructs. Needs an endpoint extension. | Only if target flow needs a menu |
| Keyboard input (Tab, Enter, arrows) | **Not yet** — would need `Controller>>handleKeyEvent:` injection | Almost never needed for form-style tests |
| Screenshot for failure forensics | Deferred to Phase B per [`HANDOFF.md`](./HANDOFF.md) — no PNG encoder, no Base64, no `Display boundingBox` in image | Nice-to-have, not blocking |
| Drag-and-drop, right-click menus, double-click | **Not yet** | Almost certainly not for first POC |

---

## What that means in plain terms

- **Pure technical distance to the first green Python E2E test: one working
  session** — assuming Phase A's click/type works on a real button. (Verified
  the moment Phase A files in cleanly and we run the acceptance grid.)

- **Distance to a WEALTH/MAS regression test that's safe to run in CI:
  dominated by the sandbox question, not by bridge work.** The bridge is
  essentially feature-complete for form-style flows once Phase A is verified.
  The interesting decisions become:

  1. Which flow do we automate first?
  2. Does it touch GemStone? If yes, dev stone or no-op flow only.
  3. Where does CI run the VM? Local on the same Windows box is trivial.
     Remote needs the bridge port reachable from CI.

- **Phase B (screenshots, menus, keyboard) is for when you have ≥1 E2E test
  running and want it to fail more usefully.** Don't pre-build it.

---

## Bottom line

Technically very close. After Phase A lands, the next strategic question is
**"which flow"**, not **"can we drive it"**.
