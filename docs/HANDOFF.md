# Session Handoff: VW Widget Bridge Investigation

## Goal
Expose VisualWorks desktop widgets over a network connection (TCP/HTTP) so external test automation and AI agents can drive the VW application (WEALTH/MAS by Momentum Metropolitan).

## Architecture (Three Channels)

```
Python test runner (pytest/Playwright/Karate)
    │                │                    │
    ▼                ▼                    ▼
Channel 1          Channel 2            Channel 3
VW In-Image       GciForPython/        WebGS (GemStone
Agent (REST       gemstone-py          REST API +
on localhost)     (direct GCI)         OpenAPI/Swagger)
    │                │                    │
    ▼                ▼                    ▼
VisualWorks       GemStone/S           GemStone/S
Image             3.7.4.3              3.7.4.3
(widget tree)     (data ops)           (REST data)
```

Three documents define the architecture:
- `remote-desktop/remote-desktop/visual-works/ARCHITECTURE.md` — original 13-17 week plan
- `remote-desktop/remote-desktop/visual-works/ARCHITECTURE-REVISED.md` — revised 6-8 week plan incorporating WebGS + Jasper MCP
- `remote-desktop/remote-desktop/visual-works/vm-access/` — VM environment details, safety rules

## Key Tech Context

### VisualWorks Widget Access (VW-specific, NOT GemStone)

Widget tree traversal path:
```
ScheduledWindow → ApplicationModel → UIBuilder → WidgetWrapper → widget/model/spec
```

Key accessors (VW Smalltalk only):
- `ScheduledControllers scheduledControllers` → all open windows
- `ctrl model` → ApplicationModel instance
- `model builder` → UIBuilder
- `builder namedComponents` → Dictionary of aspect→WidgetWrapper
- `wrapper spec label/enabled/visible` → widget metadata
- `wrapper widget model value` → current value

Threading: VW uses cooperative green threads. Widget ops MUST run on UI Process via `UIProcess interruptWith: [...]` with Semaphore synchronization.

### Jasper MCP Server (GemStone only)

Located in `repos/Jasper/`. Exposes 29 tools (compile_method, execute_code, run_test_class, etc.) that connect to GemStone/S via GCI. **Cannot compile into VisualWorks** — confirmed: VW widget classes (`ScheduledControllers`, `ApplicationModel`, `UIBuilder`, `SpOpStream`, `UIProcess`, `UUID`) are all absent from GemStone's symbol table.

MCP CAN be used for:
- Building GemStone-side WebGS REST API endpoints (fixtures, state)
- GemStone data operations (seed, rollback, query)
- SUnit TDD for GemStone code
- Search/navigate the existing GemStone codebase

### VM Environment

- **Windows VM** accessed via RDP
- **VisualWorks 9.3.1** at `C:\visualworks931\bin\win64\`
- **Dev image**: `storedev64.im` (46.8 MB) — has the WEALTH/MAS app code + dev tools
- **Headless eval**: `vwntconsole.exe test.im -filein script.st` — works but image copies may hang due to GemStone connection attempts at startup; also popups about saving changes
- **GemStone**: 3.7.4.3 server at `invgemprd101.metmom.mmih.biz`
- **Sandbox**: `C:\Users\ammaganyane\forge\` — safe write location
- **Safety**: NEVER modify running VW images, system files, or C:\WEALTH\

## Current State

### Phase 1 script: `C:\Users\ammaganyane\forge\phase1_probe.st`
- **Status**: REVIEWED — READY
- **What**: Read-only widget discovery probe
- **How**: Paste into VW workspace, Ctrl+E (Do It), check Transcript
- **Tests**: which classes exist, which windows are open, widget tree enumeration

### Phase 2 script: `C:\Users\ammaganyane\forge\phase2_bridge.st`
- **Status**: REVIEWED — NEEDS FIXES (see below)
- **What**: TCP/HTTP bridge that exposes widgets on 127.0.0.1:9876
- **How**: File → File In (NOT workspace Do It — uses `!` chunk format)

### Phase 2 Known Issues
| Issue | Severity | Detail |
|-------|----------|--------|
| `!` chunk format | BLOCKER | Must use File→File In, NOT workspace Do It |
| `formatWith:` | HIGH | May not exist in VW; use `expandMacrosWithArguments:` or manual concat |
| `separatedBy:` | HIGH | Pharo syntax; may not work in VW |
| `UUID new` | MEDIUM | VW likely uses `UUIDGenerator next` |
| `Processor userBackgroundPriority` | MEDIUM | May need numeric `4` |
| `SpOpStream>>listenOn:` | MEDIUM | May need `listenOn:backlog:` |

## Next Steps (for next session)

1. **Run Phase 1** in the running VW GUI — user pastes `phase1_probe.st` into workspace, Do It, reports Transcript output
2. **Fix Phase 2** based on Phase 1 output (which classes actually exist determines the API fixes needed)
3. **File-in Phase 2** into running VW via File → File In
4. **Test bridge**: `curl http://127.0.0.1:9876/health` → `curl http://127.0.0.1:9876/windows`
5. If bridge works: extend with click/type/screenshot endpoints
6. Long-term: bake bridge into dev image so it auto-starts on image boot (eliminate manual setup for CI)

## Files Created
- `C:\Users\ammaganyane\forge\phase1_probe.st` — widget discovery probe
- `C:\Users\ammaganyane\forge\phase2_bridge.st` — TCP bridge (needs fixes)
- `C:\Users\ammaganyane\forge\widget_probe.st` — alternative probe (not reviewed)
- `C:\Users\ammaganyane\forge\discover.st` — earlier probe attempt (superseded by phase1)
- `C:\Users\ammaganyane\forge\smoke.st` — basic smoke test
- `C:\Users\ammaganyane\forge\filetest.st` — file output test
- `C:\Users\ammaganyane\forge\eval.st` — minimal eval test

## Reference Repos (read-only, in `repos/`)
- **Jasper** — VS Code GemStone IDE with MCP server (29 tools, GCI-based)
- **WebGS** — HTTP + OpenAPI for GemStone
- **gemstone-py** — modern Python→GemStone bridge
- **GciForPython** — legacy Python GCI FFI
- **Jade** — Windows IDE for GemStone (Dolphin Smalltalk)
