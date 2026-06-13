# Test Mentor Replacement — tm-context

Central repository for replacing the expiring SilverMark Test Mentor license with an
in-house VisualWorks test automation bridge.

## Status: POC Complete — Phase A (Interactions) Next

| Milestone | Status |
|-----------|--------|
| Widget discovery over HTTP (`GET /health`, `/windows`, `/windows/tree`) | ✅ Done |
| 29 widgets enumerated across 3 windows, live values on wire | ✅ Done |
| Full chain proven: `curl` → TCP `127.0.0.1:9876` → VW image → JSON | ✅ Done |
| Click / type / screenshot endpoints | 🔲 Next |
| Bearer token enforcement | 🔲 Next |
| WEALTH/MAS windows wired up | 🔲 Next |

---

## Repository Layout

```
tm-context/
├── README.md                          ← you are here
├── plan/
│   └── REPLACEMENT-PLAN.md            ← phased roadmap to full Test Mentor replacement
├── docs/
│   ├── ARCHITECTURE.md                ← original 13-17 week plan
│   ├── ARCHITECTURE-REVISED.md        ← revised 6-8 week plan (WebGS + gemstone-py)
│   ├── HANDOFF.md                     ← session-by-session handoff notes
│   ├── poc-phase-1.md                 ← POC proof (curl output, confirmed endpoints)
│   └── vm-access/
│       ├── ENVIRONMENT.md             ← VM layout, images, ports, GemStone addresses
│       ├── SAFETY-RULES.md            ← what NOT to touch on the VM
│       └── SMALLTALK-EVAL.md          ← headless eval pattern (vwntconsole)
└── src/
    └── vw-bridge/
        ├── VWBridge.st                ← working VWBridge v0.5 (file-in to install)
        └── probes/
            ├── phase1_probe_v4.st     ← final API surface probe
            └── phase1_results.txt     ← confirmed globals + selectors in VW 9.3.1
```

---

## Quick Start: Install the Bridge into the Running VW Image

The bridge lives only in image memory — it must be filed in each time the image restarts
(or the image must be saved after filing in).

1. Open the running `storedev64` image in VisualWorks
2. Menu: **Launcher → File Browser** → navigate to `src/vw-bridge/VWBridge.st`
3. Click **File In**
4. The bridge auto-starts on port 9876. Verify:

```powershell
curl http://127.0.0.1:9876/health
# → {"status":"ok","version":"0.5"}

curl http://127.0.0.1:9876/windows
# → JSON array of open windows

curl http://127.0.0.1:9876/windows/tree
# → Full widget tree with live values
```

5. To stop: evaluate `VWBridge stop` in any workspace.
6. To restart: evaluate `VWBridge start`.

---

## Key Technical Facts (Baked In From POC)

| Fact | Detail |
|------|--------|
| VW version | VisualWorks 9.3.1 (August 16, 2023) |
| Image | `storedev64.im` at `C:\visualworks931\image\` |
| Bridge port | `127.0.0.1:9876` |
| Namespace | This is a GBS image — ALL names must be qualified: `Root.Smalltalk`, `Core.*` |
| No Semaphore timeout | No `waitTimeoutMSecs:` — use Delay-watchdog pattern (already in bridge) |
| UI process dispatch | `uiProc interruptWith: [...]` + watchdog semaphore |
| Socket recipe | `SocketAccessor newTCPserverAtPort:` + `readAppendStream` + `lineEndTransparent` |
| Token generation | `Time millisecondClockValue` + `identityHash` (no UUID API) |

---

## Three-Channel Architecture (Revised Plan)

```
pytest / Playwright (TypeScript)
    │                  │                    │
    ▼                  ▼                    ▼
Channel 1          Channel 2            Channel 3
VW In-Image        gemstone-py          WebGS
Agent (REST        (direct GCI)         (GemStone REST
localhost:9876)    data ops             + Swagger UI)
    │                  │                    │
    ▼                  ▼                    ▼
VisualWorks        GemStone/S           GemStone/S
widget tree        fixture mgmt         REST data API
```

- **Channel 1** (VW In-Image Agent): widget click/type/assert — the only way to reach VW widgets
- **Channel 2** (gemstone-py): seed fixtures, rollback transactions, verify DB state — fast, no server
- **Channel 3** (WebGS): self-documenting REST API on GemStone, Swagger UI for team exploration

See [`docs/ARCHITECTURE-REVISED.md`](docs/ARCHITECTURE-REVISED.md) for full detail.

---

## Comparison: Test Mentor vs This Bridge

| Capability | Test Mentor | This Bridge |
|------------|-------------|-------------|
| Widget discovery | In-image (proprietary) | In-image (our code) |
| External driver | None (all in-image) | Playwright/TypeScript via REST |
| CI/CD | Manual | First-class (headless, reporting) |
| Multi-language tests | Smalltalk only | Any language via HTTP |
| License | Commercial (expiring) | Internal — no license |
| Record/playback | Yes | No — code-first only |

---

## Reference Repos (not committed here — local to VM)

| Repo | Location | Purpose |
|------|----------|---------|
| WebGS | `remote-desktop/.../repos/WebGS/` | HTTP + OpenAPI for GemStone (Channel 3) |
| gemstone-py | `remote-desktop/.../repos/gemstone-py/` | Modern Python → GemStone (Channel 2) |
| Jasper | `remote-desktop/.../repos/Jasper/` | MCP server for AI-driven Smalltalk dev |
| GciForPython | `remote-desktop/.../repos/GciForPython/` | Legacy Python GCI FFI |
| Jade | `remote-desktop/.../repos/Jade/` | GCI reference + VW component package |
