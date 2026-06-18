# VWBridge — Project Overview

> A briefing document. Pick the level of detail that matches your audience.

---

## The 10-second version

> *"We're putting a small HTTP server inside the WEALTH/MAS Smalltalk app so
> tests and AI agents can drive it the same way they drive a website — clicking
> buttons, typing into fields, reading values back."*

## The 30-second version

> *"WEALTH/MAS is a VisualWorks desktop app. Standard test tools like Playwright
> and Selenium only work on web pages, so right now the only way to test it is a
> human clicking through it manually. We're adding a tiny network listener that
> exposes the app's widget tree (every button, field, list, etc.) over a local
> HTTP API. Any test framework that speaks HTTP — pytest, Karate, an AI agent —
> can then drive the app: open a window, type into a field, click a button,
> assert the result. The app itself isn't being modified — we're just loading a
> small Smalltalk script into the running image."*

---

## How it actually works (for a curious dev)

```
 Python test (or AI agent)
        │  HTTP + Bearer token over 127.0.0.1:9876
        ▼
 ┌──────────────────────────────────┐
 │  VWBridge — Smalltalk class      │
 │  loaded into the running image   │
 │                                  │
 │  • Tiny TCP listener (background │
 │    process, port 9876)           │
 │  • Walks ScheduledControllers →  │
 │    ApplicationModel → UIBuilder  │
 │    → namedComponents             │
 │  • Hops onto the UI thread to    │
 │    fire clicks / set values      │
 │  • Returns JSON                  │
 └──────────────────────────────────┘
        │
        ▼
 The running WEALTH/MAS image
 (no app code changed)
```

**Mental model:** think *Chrome DevTools' "Inspect Element"* — but for Smalltalk
widgets, exposed over HTTP so external scripts can use it.

---

## Progress checkpoint

| Stage | Status | What it proves |
|---|---|---|
| Phase 1 — widget discovery probe | Done | We can walk every open window's widget tree |
| v0.5 — read-only HTTP bridge | Done, curl-tested | `/health`, `/windows`, `/windows/tree` return live JSON. 3 windows, 29 widgets dumped successfully. |
| Phase A v0.7 — interactive | About to land | `/click`, `/type`, `/value` + Bearer-token auth. Code complete, file-in error just fixed, retest pending. |
| First Python E2E test | ~1 session away | Once Phase A is curl-verified — see [`E2E-DISTANCE.md`](./E2E-DISTANCE.md) |
| Phase B — screenshots, menus, keyboard | Deferred | Only matters for nicer failure diagnosis; not blocking |
| CI / persistence story | Not started | Bridge currently dies with the image; needs Store packaging or startup hook for prod use |

---

## FAQ — anticipated questions

### "Is the app being modified?"

No. We load a small Smalltalk class into the running image at runtime. The
image can be saved or not — your call. No source files in the app are touched.

### "What if it crashes the app?"

The bridge runs in a background process with error handlers around every
external call. The worst realistic failure is the listener stops accepting
connections — the UI keeps running.

### "Why not use [tool X]?"

- **Playwright / Selenium** — web only, won't drive a desktop Smalltalk app.
- **AutoIt / WinAppDriver** — work at the pixel / OS-window level, brittle.
- **Our bridge** — talks to the actual widget objects, faster and more reliable.

### "Why custom HTTP instead of a real framework?"

The VW image doesn't have an HTTP server library available. Hand-rolling ~100
lines was cheaper than adding a third-party dependency to a production image.

### "Can it touch GemStone?"

The bridge itself doesn't talk to GemStone. But if a button you click invokes a
GemStone operation, that happens. That's why prod-touching widgets (commit,
login, remove) need explicit sign-off before automation.

### "Can it do code introspection too?"

Yes — same machinery. The same reflection APIs that walk widgets can list every
class and method in the image (essentially a "Jasper for VW"). Not built yet,
but it's a same-week addition once Phase A is solid.

### "When can QA use it?"

After Phase A's acceptance tests pass — probably this session. After that, the
next decisions are *which flow do we automate first* and *where does the test
harness run*.

### "How long has this taken?"

A handful of sessions to discover the image's quirks (it's a GBS image with
shadowed kernel classes, no UUID, no HTTP server, no Semaphore timeout) and to
design the click strategy. The bridge itself is ~400 lines of Smalltalk.

### "What's the risk?"

Low for read-only and dev environments. For production touching: same risk as
any UI automation — a careless test could mutate real data. That's why prod
widgets are gated behind explicit sign-off.

---

## Related documents

- [`HANDOFF.md`](./HANDOFF.md) — full technical handoff, image-specific gotchas, install steps, what's verified vs. what's pending
- [`VWBridge-working.md`](./VWBridge-working.md) — install instructions and endpoint reference (the doc you'd hand a tester)
- [`E2E-DISTANCE.md`](./E2E-DISTANCE.md) — distance from current state to first Python end-to-end test
- [`VWBridge.st`](./VWBridge.st) — v0.5 base bridge source
- [`VWBridge-phaseA.st`](./VWBridge-phaseA.st) — v0.7 interactive extension source
