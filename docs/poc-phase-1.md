PoC complete — all 5 tasks done. Widgets are exposed over HTTP from the live VW image. 
Proof (verified end-to-end by me, via curl from outside the image)
Endpoint	Result
GET /health	200 OK, exact Content-Length, {"status":"ok","version":"0.5"}
GET /windows	Valid JSON — 3 windows with title, appClass, viewClass, screen bounds
GET /windows/tree	3,747 bytes, parser-validated JSON — 29 widgets across 3 windows
Sample payload — real widgets with live values, straight off the wire:
{"aspect":"loginRpcWidget", "widgetClass":"ActionButtonView", "label":"Login RPC", "value":"false"}
{"aspect":"commitWidget",   "widgetClass":"ActionButtonView", "label":"Commit",    "value":"false"}
{"aspect":"parametersListWidget", "widgetClass":"SequenceView", "value":"List ('x' on 'development64' @ 'invgemdev101' ...)"}
The full chain works: external process → TCP 127.0.0.1:9876 → VW image → ScheduledControllers → builder → namedComponents → JSON back. The WEALTH/MAS windows weren't open during the test, but the mechanism is window-agnostic — open them and they'll appear in /windows/tree immediately.
What made it work (for the record)
- This GBS image shadows kernel names (VisualAgeCompatibility, GemStoneClasses) → everything is qualified Root.Smalltalk / Core.*
- No Semaphore timeout API in this image → Delay-watchdog pattern guards the UI-process interrupt
- lineEndTransparent on socket streams protects HTTP framing from VW's line-end conversion
Notes
- VWBridge is in-memory only — it dies with the image unless you save the image. VWBridge stop halts the listener; re-file-in or VWBridge start restarts it.
- Next steps per the handoff: /click, /type, /screenshot endpoints (Phase 3), then bake auto-start into the dev image for CI.
- GemStone side untouched — no commits/aborts pending. But the Jasper MCP session is returning internal compiler errors on every call (even status) and needs separate attention.
- Want me to update HANDOFF.md (file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/HANDOFF.md) to reflect Phase 1+2 complete?
▣  Sisyphus - Ultraworker · Claude Fable 5 · 1m 11s
PoC complete — both gates proven. Final state:
What was proven end-to-end
curl (external process) → TCP 127.0.0.1:9876 → VWBridge in live storedev64 → widget tree → JSON
Endpoint	Result
GET /health	200 OK, {"status":"ok","version":"0.5"}, exact Content-Length, clean CRLF framing
GET /windows	Valid JSON — 3 windows with title/appClass/viewClass/bounds
GET /windows/tree	3,747 bytes of valid JSON (passed ConvertFrom-Json) — 29 widgets across 3 windows
Sample of what test automation can now see over plain HTTP — including live values:
aspect	widgetClass
loginRpcWidget	ActionButtonView
commitWidget	ActionButtonView
autoWidget	RadioButtonView
parametersListWidget	SequenceView
Key learnings baked into the artifacts
- This is a GBS image with ambiguous unqualified names (VisualAgeCompatibility, GemStoneClasses shadow kernel names) — all code must use Root.Smalltalk / Core.* qualification. This cost us two probe iterations and is now documented in both file headers.
- No Semaphore timeout API in VW 9.3.1 → Delay-watchdog pattern in onUIDo:.
- Socket layer: SocketAccessor newTCPserverAtPort: + readAppendStream + lineEndTransparent is the working recipe.
Operational notes
- VWBridge lives only in the running image's memory — gone on image exit unless you save the image. Stop anytime with VWBridge stop; restart with VWBridge start; re-install by re-evaluating the file-in line.
- Next steps per the handoff roadmap: open the WEALTH app windows and re-curl /windows/tree (the walker is window-agnostic), then extend with interaction endpoints (/click, /type, value-set) and enforce the token. Say the word and I'll build those.
- ⚠ The GemStone MCP (Jasper) session is broken — every call, even status, returns ComStrmSetCursor: cursor out of range compiler errors. Nothing was changed in the GemStone image (all my calls failed read-only), but the session needs a restart/look before any GemStone-side work.
- HANDOFF.md (file:///C:/Users/ammaganyane/tm/remote-desktop/remote-desktop/visual-works/HANDOFF.md) is now outdated (file list + "Phase 2 needs fixes" status). Want me to update it with today's results?