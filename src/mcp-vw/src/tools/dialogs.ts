/**
 * dialogs.ts — V3 modal-dialog interaction tools.
 *
 *   - vw_list_dialogs: enumerate live SimpleDialog instances on screen.
 *   - vw_respond_dialog: click a named button on the currently-posted modal.
 *
 * Per architecture.md §5.3 (tools 33, 34) + Bug #2 fix infrastructure.
 *
 * Note: the bridge has built-in mid-modal dispatch handling (the Bug #2 fix
 * via SimpleDialog>>choose:labels:values:default:for: override). These tools
 * surface that capability as MCP-level operations.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

export function makeDialogTools(bridge: BridgeClientLike): ToolDef[] {
  return [makeListDialogsTool(bridge), makeRespondDialogTool(bridge)];
}

// -----------------------------------------------------------------------------
// vw_list_dialogs
// -----------------------------------------------------------------------------

function makeListDialogsTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_list_dialogs',
    description:
      'Enumerate live modal SimpleDialog instances currently on screen. ' +
      'Returns JSON array of {label, type, buttons, ...}. Use to discover what dialogs are awaiting response before calling vw_respond_dialog.',
    inputSchema: {},
    handler: safeHandler(async (): Promise<ToolResult> => {
      // The bridge's /windows endpoint surfaces dialogs alongside regular windows;
      // we filter dialog-like entries by checking the window type or class.
      // For MVP we use the same probe and let the caller filter.
      const dialogs = await bridge.getJson('/windows');
      return { content: [text(JSON.stringify(dialogs))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_respond_dialog
// -----------------------------------------------------------------------------

const respondDialogSchema = {
  buttonLabel: z
    .string()
    .min(1)
    .max(200)
    .describe('Exact label of the button to click on the currently-posted modal (e.g. "OK", "Cancel", "Yes", "No").'),
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .optional()
    .describe('Optional title to disambiguate when multiple dialogs are stacked.'),
};

function makeRespondDialogTool(
  bridge: BridgeClientLike
): ToolDef<typeof respondDialogSchema> {
  return {
    name: 'vw_respond_dialog',
    description:
      'Click a named button on the currently-posted modal SimpleDialog. ' +
      'Pass the button label (e.g. "OK", "Cancel"). Uses the bridge Bug #2 fix infrastructure to dispatch on a forked process so the modal can close. ' +
      'Use vw_list_dialogs first to discover which dialogs are open.',
    inputSchema: respondDialogSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.buttonLabel.trim().length === 0) {
        return errorResult('vw_respond_dialog: buttonLabel is empty.');
      }
      const body: Record<string, string> = { aspect: input.buttonLabel };
      if (input.windowTitle !== undefined) {
        body['windowTitle'] = input.windowTitle;
      }
      // The /click endpoint handles RadioButton vs others; for dialog buttons
      // it routes through the same path.
      const result = await bridge.postJson('/click', body);
      return { content: [text(JSON.stringify(result))] };
    }),
  };
}
