# tm-context knowledge artifacts

Hard-won knowledge from working with the VW image and the VW widget bridge. Organized by topic — read whichever applies.

## Files

| File | When to read |
|---|---|
| [vw-dialogs.md](./vw-dialogs.md) | Anytime you're dealing with `Dialog confirm:` / `SimpleDialog` / modal popups in MAS. Critical pre-reading before designing any bridge feature that touches dialogs. |
| [vw-bridge-testing.md](./vw-bridge-testing.md) | Before running a new test cycle on the VW bridge. Documents the testing-methodology mistakes that have bitten us, and the recovery patterns. **Read this BEFORE accumulating /click wedges.** |
| [vw-bridge-known-issues.md](./vw-bridge-known-issues.md) | Bugs and rough edges in the v0.8.5 bridge. Read before designing fixes, working around bridge limitations, or interpreting unexpected `/click` / `/dialogs` behavior. Covers RadioButtonSpec `/click` corruption + `Dialog confirm:` dismissal returning wrong value. |
| [vw-eval-cookbook.md](./vw-eval-cookbook.md) | Quick-reference for useful Smalltalk snippets to send via `POST /eval`. The bridge's eval endpoint is the swiss-army knife for VW introspection; this file is the cheat sheet. |
| [vw-party-search.md](./vw-party-search.md) | How to drive PartySearchView (the MAS party/contract search window) via the bridge. Includes bypass recipes for known bridge bugs and known-good test data (`PP0` -> 19 contracts in storedev64). |
| [vw-input-recovery.md](./vw-input-recovery.md) | When VW input locks (can't click, `activeControllerProcess: nil`, etc.). Diagnostic steps + recovery options up to and including a clean image restart. |
| [smalltalk-gotchas.md](./smalltalk-gotchas.md) | Anytime you write Smalltalk that gets file'd into the VW (GBS) image. Covers chunk format, namespace qualification, the `$'` character literal foot-gun, and protocol surprises (`valuesDo:`, `indexOfSubCollection:`, etc.). |

## How this folder grew

Created at the end of session 2026-06-19 after a deep dive into VW's modal-dialog mechanics produced enough findings to merit dedicated knowledge files. The session culminated in v0.8.5 of the bridge ([VWBridge-phaseB4.st](../src/vw-bridge/VWBridge-phaseB4.st)), but the journey through v0.8.2 / v0.8.3 / v0.8.4 produced more reusable insights than the patches themselves.

## When in doubt

- For live image state, use `POST /eval` (see [vw-eval-cookbook.md](./vw-eval-cookbook.md)) — beats writing `.st` probe files every time.
- For the bridge's own behavior, see [`../src/vw-bridge/SESSION-RESUME.md`](../src/vw-bridge/SESSION-RESUME.md).
- For GemStone-side knowledge, see [`../AGENTS.md`](../AGENTS.md) and the GemStone skills under `.opencode/skills/`.

## Add to this folder when

You learn something about the VW image / bridge / Smalltalk that:
- took more than a few minutes to figure out, AND
- is likely to be needed again

Keep entries grounded in concrete probes / file references. Avoid speculative documentation.
