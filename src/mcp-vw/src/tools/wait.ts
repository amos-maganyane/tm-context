/**
 * wait.ts — V3 vw_wait tool wrapping the bridge /wait endpoint.
 *
 * Block until a UI predicate is satisfied (e.g. a window appears, an aspect
 * changes value). The bridge already implements the wait logic in-image
 * (Phase B); this tool wraps the HTTP endpoint cleanly.
 *
 * Per architecture.md §5.3 (tool 35) + Phase B v0.9.0.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

export function makeWaitTools(bridge: BridgeClientLike): ToolDef[] {
  return [makeWaitTool(bridge)];
}

const waitSchema = {
  predicate: z
    .enum(['windowExists', 'aspectEquals', 'aspectNotEmpty', 'dialogExists', 'dialogGone'])
    .describe('Wait predicate type.'),
  windowTitle: z.string().min(1).max(500).optional(),
  aspect: z.string().min(1).max(200).optional(),
  value: z.string().max(10_000).optional().describe('Expected value for aspectEquals predicate.'),
  timeoutMs: z
    .number()
    .int()
    .positive()
    .max(120_000)
    .optional()
    .describe('Optional timeout in ms. Default 10000.'),
};

function makeWaitTool(bridge: BridgeClientLike): ToolDef<typeof waitSchema> {
  return {
    name: 'vw_wait',
    description:
      'Block until a UI predicate is satisfied. Predicates: windowExists, aspectEquals (needs aspect + value), aspectNotEmpty, dialogExists, dialogGone. ' +
      'Default timeout 10s; max 120s. Useful between vw_click and vw_get_widget_value to give the UI time to react.',
    inputSchema: waitSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // The bridge /wait endpoint accepts predicate + params in a JSON body.
      const body: Record<string, unknown> = { predicate: input.predicate };
      if (input.windowTitle !== undefined) body['windowTitle'] = input.windowTitle;
      if (input.aspect !== undefined) body['aspect'] = input.aspect;
      if (input.value !== undefined) body['value'] = input.value;
      if (input.timeoutMs !== undefined) body['timeoutMs'] = input.timeoutMs;

      const result = await bridge.postJson('/wait', body);
      return { content: [text(JSON.stringify(result))] };
    }),
  };
}
