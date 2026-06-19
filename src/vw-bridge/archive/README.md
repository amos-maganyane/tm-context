# VWBridge — archived patch chain (pre-consolidation)

**Status:** reference-only. **DO NOT file in.**

This folder preserves the 7-file incremental patch chain that built the VWBridge
HTTP automation bridge up to v0.8.5. As of [`CONSOLIDATION-NOTES.md`](../../../knowledge/CONSOLIDATION-NOTES.md)
(2026-06-19), all of these files were collapsed into a single canonical
[`../VWBridge.st`](../VWBridge.st). The single file is the only thing you should
file in to install the bridge into a fresh VW image.

These archived files remain useful as:

- **Audit trail** — each patch shows which behavior was added when, and why.
  Useful when investigating a regression or wondering "when did X start
  working / break?"
- **Source for future ports** — if someone needs to port the bridge to a
  different image (different VW version, different GBS configuration), the
  incremental patches are easier to digest one at a time than the
  consolidated file.
- **Design context** — each patch header explains the design decisions
  (probe results, gotchas, alternatives considered). The consolidated file
  preserves the key notes but trims the patch-by-patch narrative.

## Version chain

| File | Version | Adds |
|---|---|---|
| `VWBridge.st` | v0.5 | Base class, socket layer, listener loop, `GET /health` `/windows` `/windows/tree`, JSON serializer, namespace-qualified globals lookup |
| `VWBridge-phaseA.st` | v0.7 | Bearer-token auth, full HTTP read (headers + body), `POST /click` `/type`, `GET /value`, `PUT /value`, JSON parser (flat objects), URL decoder |
| `VWBridge-phaseB.st` | v0.8 / v0.8.1 | `GET /menu` (tree dump), `POST /menu/click` (Symbol + BlockClosure dispatch), window-change tracking on click responses, `LabelWithAccessor` text extraction, JSON parser extended for arrays |
| `VWBridge-phaseB1.st` | v0.8.2 | `listenerLoop` forks `serve:` per connection so a wedged request cannot block the listener. Bridge serves `/health` etc. even mid-modal. |
| `VWBridge-phaseB2.st` | v0.8.3 | `POST /eval` — accepts arbitrary Smalltalk source, returns `printString` of the result. The introspection breakthrough; eliminated all workspace probe file-ins. |
| `VWBridge-phaseB3.st` | v0.8.4 | `GET /dialogs` (enumerate `SimpleDialog` modals), `POST /dialogs/respond`, `resolveAspect:` defensive `valuesDo:` fallback for `WealthPublishedPundleVersionsTool` |
| `VWBridge-phaseB4.st` | v0.8.5 | `doListDialogs` filters via `scheduledControllers` (not stale `allInstances`), `describeDialog:` extracts `ComposedText` via `asString`, `doRespondDialog:` rewritten to use `target closeAndUnschedule` (the only reliable modal-dismiss mechanism) |
| `VWBridge-phaseA-workspace.st` | n/a | Deprecated stub. Originally tried to file the bridge in by writing it back through `FileStream` / `SourceManager` APIs that don't work in VW 9.3.1 here. Documents the dead end. |

## If you ever need to file these in again (not recommended)

The original instructions were: file in each `.st` file in this exact order via
Workspace Do It:

```smalltalk
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseA.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseB.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseB1.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseB2.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseB3.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\archive\VWBridge-phaseB4.st' asFilename fileIn.
```

The result is functionally identical to file-in of the consolidated
`../VWBridge.st`, just spread across 7 chunks.

**Do not use Launcher → File Browser → File In.** That mechanism has chunk-parser
quirks that fail on these files (the consolidation session discovered this the
hard way). Use the Workspace `'path' asFilename fileIn.` form above.

## See also

- [`../VWBridge.st`](../VWBridge.st) — the canonical single-file v0.8.5 bridge (file this in, not the archive files)
- [`../../../knowledge/CONSOLIDATION-NOTES.md`](../../../knowledge/CONSOLIDATION-NOTES.md) — full record of what was merged, dead code dropped, validation results
- [`../../../knowledge/HANDOFF-2026-06-19.md`](../../../knowledge/HANDOFF-2026-06-19.md) — session handoff that scoped and executed the consolidation
- [`../SESSION-RESUME.md`](../SESSION-RESUME.md) — earlier Phase B session-resume notes (now superseded for file-in instructions)
