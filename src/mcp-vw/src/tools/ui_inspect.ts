/**
 * ui_inspect.ts — vw_list_windows + vw_describe_window (MVP).
 *
 * Thin wrappers over the bridge's existing /windows + /windows/tree endpoints
 * (shipped in Phase A/B). No /eval involved here — the bridge already does
 * the introspection in-image and returns JSON directly.
 *
 * Per architecture.md §5.1 (tools 12 + 13).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

export function makeUiInspectTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeListWindowsTool(bridge),
    makeDescribeWindowTool(bridge),
    makeGetWidgetValueTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// vw_list_windows
// -----------------------------------------------------------------------------

function makeListWindowsTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_list_windows',
    description:
      'Enumerate every VW window currently on screen (Workspace, MAS app windows, dialogs, etc.). ' +
      'Returns JSON array of {title, id, label, ...}. ' +
      'Use to discover what UI is live before driving it with vw_click / vw_type or inspecting with vw_describe_window.',
    inputSchema: {},
    handler: safeHandler(async (): Promise<ToolResult> => {
      const windows = await bridge.getJson('/windows');
      return { content: [text(JSON.stringify(windows))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_describe_window
// -----------------------------------------------------------------------------

const describeWindowSchema = {
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .describe('Exact title of the window to inspect. Use vw_list_windows to discover titles.'),
};

function makeDescribeWindowTool(bridge: BridgeClientLike): ToolDef<typeof describeWindowSchema> {
  return {
    name: 'vw_describe_window',
    description:
      'Get the full widget tree for a named window (recursively). ' +
      'Returns JSON node with type, name, layout, label, model, children. ' +
      'Use after vw_list_windows to inspect what aspects/widgets are clickable / typeable.',
    inputSchema: describeWindowSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.windowTitle.trim().length === 0) {
        return errorResult('vw_describe_window: windowTitle is empty.');
      }
      const path = `/windows/tree?windowTitle=${encodeURIComponent(input.windowTitle)}`;
      const tree = await bridge.getJson(path);
      return { content: [text(JSON.stringify(tree))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_get_widget_value (V2) — read aspect value from live app
// -----------------------------------------------------------------------------

const getWidgetValueSchema = {
  aspect: z.string().min(1).max(200).describe('Widget aspect name (the #name: or #model: symbol).'),
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .optional()
    .describe('Optional window title to disambiguate when multiple windows share an aspect.'),
};

function makeGetWidgetValueTool(bridge: BridgeClientLike): ToolDef<typeof getWidgetValueSchema> {
  return {
    name: 'vw_get_widget_value',
    description:
      'Read the live value of a widget (input field, list selection, etc.) from a running VW window. ' +
      'Wraps the bridge GET /value?aspect=X[&windowTitle=Y] endpoint. Returns JSON {ok, aspect, value}. ' +
      'Use to verify vw_type / vw_click actually updated the model.',
    inputSchema: getWidgetValueSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.aspect.trim().length === 0) {
        return errorResult('vw_get_widget_value: aspect is empty.');
      }
      const params = new URLSearchParams({ aspect: input.aspect });
      if (input.windowTitle !== undefined) {
        params.set('windowTitle', input.windowTitle);
      }
      const path = `/value?${params.toString()}`;
      const value = await bridge.getJson(path);
      return { content: [text(JSON.stringify(value))] };
    }),
  };
}
