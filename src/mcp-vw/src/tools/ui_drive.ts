/**
 * ui_drive.ts — vw_click + vw_type + vw_open_application (MVP).
 *
 * Driving the live VW UI:
 *   - vw_click: wraps POST /click (bridge already implements the right
 *     RadioButton-vs-other dispatch internally per architecture.md §5.1
 *     row 14).
 *   - vw_type: wraps POST /type (set the value of an input field).
 *   - vw_open_application: emits Smalltalk "<className> open" or
 *     "<className> new openInterface: #specSelector" via /eval.
 *
 * Per architecture.md §5.1 (tools 11, 14, 15).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import { isValidClassIdentifier, isValidSelector } from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeUiDriveTools(bridge: BridgeClientLike): ToolDef[] {
  return [makeClickTool(bridge), makeTypeTool(bridge), makeOpenApplicationTool(bridge)];
}

// -----------------------------------------------------------------------------
// vw_click
// -----------------------------------------------------------------------------

const clickSchema = {
  aspect: z
    .string()
    .min(1)
    .max(200)
    .describe('Widget aspect name (the #name: symbol in the windowSpec).'),
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .optional()
    .describe('Optional window title to disambiguate when multiple windows share an aspect.'),
};

function makeClickTool(bridge: BridgeClientLike): ToolDef<typeof clickSchema> {
  return {
    name: 'vw_click',
    description:
      'Click a named widget (button, checkbox, radio button) in a live VW window. ' +
      'Pass the widget\'s aspect name from windowSpec. Bridge auto-detects RadioButton vs others. ' +
      'Use vw_list_windows + vw_describe_window first to discover aspect names.',
    inputSchema: clickSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.aspect.trim().length === 0) {
        return errorResult('vw_click: aspect is empty.');
      }
      const body: Record<string, string> = { aspect: input.aspect };
      if (input.windowTitle !== undefined) {
        body['windowTitle'] = input.windowTitle;
      }
      const result = await bridge.postJson('/click', body);
      return { content: [text(JSON.stringify(result))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_type
// -----------------------------------------------------------------------------

const typeSchema = {
  aspect: z
    .string()
    .min(1)
    .max(200)
    .describe('Widget aspect name (the #name: or #model: symbol in the windowSpec).'),
  value: z
    .string()
    .max(100_000)
    .describe('Value to set. Empty string is allowed (clears the field).'),
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .optional()
    .describe('Optional window title to disambiguate.'),
};

function makeTypeTool(bridge: BridgeClientLike): ToolDef<typeof typeSchema> {
  return {
    name: 'vw_type',
    description:
      'Set the value of an input field, text editor, or any writable widget in a live VW window. ' +
      'Pass empty string to clear the field. ' +
      'Use vw_list_windows + vw_describe_window first to discover aspect names.',
    inputSchema: typeSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.aspect.trim().length === 0) {
        return errorResult('vw_type: aspect is empty.');
      }
      const body: Record<string, string> = { aspect: input.aspect, value: input.value };
      if (input.windowTitle !== undefined) {
        body['windowTitle'] = input.windowTitle;
      }
      const result = await bridge.postJson('/type', body);
      return { content: [text(JSON.stringify(result))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_open_application
// -----------------------------------------------------------------------------

const openAppSchema = {
  className: z
    .string()
    .min(1)
    .max(200)
    .describe('ApplicationModel subclass name (e.g. "PartySearchView", "Tools.UIPainter").'),
  specSelector: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe(
      'Optional canvas/window-spec method selector (default: omit → `MyApp open` uses the default windowSpec).'
    ),
};

function makeOpenApplicationTool(bridge: BridgeClientLike): ToolDef<typeof openAppSchema> {
  return {
    name: 'vw_open_application',
    description:
      'Open an ApplicationModel subclass as a new window. Emits "<className> open" by default ' +
      '(uses the default windowSpec) or "<className> new openInterface: #specSelector" when specSelector provided. ' +
      'Side effect: a real VW window appears on screen. ' +
      'REFUSED for VWB.* classes (carry-forward #41).',
    inputSchema: openAppSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_open_application: invalid className "${input.className}". Must match class-identifier regex.`
        );
      }
      if (input.className === 'VWB' || input.className.startsWith('VWB.')) {
        return errorResult(
          `vw_open_application refuses VWB.* classes (carry-forward #41). The bridge class is not openable as an application.`
        );
      }
      if (input.specSelector !== undefined && !isValidSelector(input.specSelector)) {
        return errorResult(
          `vw_open_application: invalid specSelector "${input.specSelector}". Must match unary/binary/keyword selector regex.`
        );
      }

      const probe =
        input.specSelector === undefined
          ? `${input.className} open`
          : `${input.className} new openInterface: #${input.specSelector}`;

      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(
          `vw_open_application: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }

      return {
        content: [
          text(
            `Opened ${input.className}${input.specSelector ? ` (spec: #${input.specSelector})` : ''}. ` +
              `Result: ${evalResult.result ?? '(no result)'}`
          ),
        ],
      };
    }),
  };
}
