/**
 * eval.ts — vw_eval escape-hatch tool.
 *
 * AI-FRIENDLINESS: the tool description explicitly steers AI toward
 * typed tools (vw_create_class, vw_compile_method, vw_create_window_spec)
 * FIRST. vw_eval is for one-off expressions and probes — using it as the
 * default means losing the safety + structure that typed tools provide.
 *
 * Two MCP-layer guards that fail-fast BEFORE round-tripping to the bridge:
 *
 *   1. **Bug #5 substring guard** (carry-forward #5 + #28):
 *      Source containing BOTH 'VWBridge' AND 'dispatch' substrings is
 *      rejected. The bridge's HTTP /eval re-enters its own dispatcher when
 *      the AI accidentally writes `VWB.VWBridge dispatch:` style code,
 *      which trips an inherent recursion limit. We mirror the bridge's
 *      Stage 1 substring guard here so the round-trip fails fast with a
 *      more actionable message.
 *
 *   2. **Compile-on-VWB.* refusal** (carry-forward #41):
 *      Source matching `VWB.SomeClass [class] compile:` is rejected.
 *      Compiling onto the bridge class wedges the listener via the UI
 *      announcement fan-out path that the Cursor>>showWhile: monkey-patch
 *      does NOT cover. Empirically demonstrated session-20.
 *
 * Per architecture.md §5.1 row 4 + §7.3.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

const inputSchema = {
  source: z
    .string()
    .min(1)
    .max(200_000)
    .describe('Smalltalk source to evaluate via POST /eval. Bounded to 200 KB.'),
};

const TOOL_DESCRIPTION =
  'Evaluate arbitrary Smalltalk source via the VW Runtime API /eval endpoint. ' +
  'ESCAPE HATCH — prefer the typed tools FIRST: vw_create_class to create classes, ' +
  'vw_compile_method (V2) to add methods, vw_create_window_spec (V2) to build UI, ' +
  'vw_list_namespaces / vw_get_class_definition / vw_list_methods to read code. ' +
  'Use vw_eval for one-off expressions, debugging probes, or capabilities not yet wrapped by a typed tool. ' +
  'GUARDS: rejects source that would trigger Bug #5 (both "VWBridge" + "dispatch" substrings) ' +
  'or carry-forward #41 (compile: on any VWB.* class would wedge the bridge).';

/** Matches `VWB.SomeClass [class] compile:` — the carry-forward #41 wedge pattern. */
const VWB_COMPILE_RE = /(?:^|[^.\w])VWB\.\w+(?:\s+class)?\s+compile:/;

export function makeEvalTool(bridge: BridgeClientLike): ToolDef<typeof inputSchema> {
  return {
    name: 'vw_eval',
    description: TOOL_DESCRIPTION,
    inputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      const source = input.source;

      // Local input validation (Zod already enforced min 1; this catches whitespace-only).
      if (source.trim().length === 0) {
        return errorResult(
          'vw_eval: source is empty or whitespace-only. Provide a Smalltalk expression like "1 + 2" or a full probe block.'
        );
      }

      // Guard #1: Bug #5 substring (carry-forward #5 + #28)
      if (source.includes('VWBridge') && source.includes('dispatch')) {
        return errorResult(
          'vw_eval refused: source contains both "VWBridge" AND "dispatch" substrings, which trips Bug #5 ' +
            '(carry-forward #28 — HTTP /eval recursive dispatch inherent limit). ' +
            'Workarounds: (1) call a handler method directly, e.g. `VWB.VWBridge singleton handleWindows`, ' +
            'rather than going through `dispatch:`. (2) Rephrase comments to avoid the substring trigger ' +
            '(use "router" instead of "dispatch" in comments).'
        );
      }

      // Guard #2: compile-on-VWB.* refusal (carry-forward #41)
      const compileMatch = VWB_COMPILE_RE.exec(source);
      if (compileMatch) {
        return errorResult(
          `vw_eval refused: source contains "${compileMatch[0].trim()}" which compiles on a VWB.* namespace class. ` +
            'Empirically wedges the bridge via UI announcement fan-out even with the Cursor>>showWhile: monkey-patch installed ' +
            '(carry-forward #41, session-20). The bridge class is off-limits for mid-/eval mutation. ' +
            'Use vw_compile_method on a MAS class instead, or restart the bridge and apply via file-in (Start-VWBridge.bat).'
        );
      }

      // All guards passed — round-trip to the bridge.
      const evalResult = await bridge.postEval(source);

      // In-band Smalltalk failure (e.g., MNU on a speculative selector).
      if (!evalResult.ok) {
        return errorResult(
          `VW eval failed: ${evalResult.error ?? '(no error message returned)'}`
        );
      }

      // Happy path. result is the printString of the evaluated expression.
      const resultText = evalResult.result ?? '(no result)';
      return { content: [text(resultText)] };
    }),
  };
}
