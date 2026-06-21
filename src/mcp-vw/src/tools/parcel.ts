/**
 * parcel.ts — vw_load_parcel + vw_unload_parcel + vw_list_loaded_parcels (MVP).
 *
 * Carry-forward constraints honored:
 *   - #38: `removeParcelNamed:` raises Core.Notification — MUST wrap with
 *     `on: Core.Notification do: [:n | n resume]` or the call aborts.
 *   - #43: bridge collapses whitespace (LF/CR/TAB → space) in JSON responses,
 *     so we use `;` (RECORD_SEP) as the list separator.
 *   - Self-unload guard: refuse `vw_unload_parcel { name: "VWBridge" }`
 *     because that would unload the bridge listener itself and break the
 *     /eval channel mid-call.
 *
 * Per architecture.md §5.1 (tools 16, 17, 18) + §6.7 (V3 vw_create_parcel
 * is NOT in MVP — only load/unload/list here).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  quoteSmalltalkString,
  RECORD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeParcelTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeLoadParcelTool(bridge),
    makeUnloadParcelTool(bridge),
    makeListLoadedParcelsTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// vw_load_parcel
// -----------------------------------------------------------------------------

const loadParcelSchema = {
  path: z
    .string()
    .min(1)
    .max(2_000)
    .describe(
      'Absolute or relative filesystem path to the .pcl file. ' +
        'Apostrophes in the path are escaped for Smalltalk safety.'
    ),
};

function makeLoadParcelTool(bridge: BridgeClientLike): ToolDef<typeof loadParcelSchema> {
  return {
    name: 'vw_load_parcel',
    description:
      'Load a binary .pcl parcel into the VW image via Kernel.Parcel loadParcelFrom:. ' +
      'Pass the absolute file path. Companion .pst (source) file should sit alongside the .pcl. ' +
      'Returns the loaded Parcel printString on success. ' +
      'For un-loading use vw_unload_parcel, for inventory use vw_list_loaded_parcels.',
    inputSchema: loadParcelSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.path.trim().length === 0) {
        return errorResult('vw_load_parcel: path is empty.');
      }

      const probe = `Kernel.Parcel loadParcelFrom: ${quoteSmalltalkString(input.path)} asFilename`;
      const evalResult = await bridge.postEval(probe);

      if (!evalResult.ok) {
        return errorResult(
          `vw_load_parcel: VW eval failed for ${input.path}: ${evalResult.error ?? '(no error)'}`
        );
      }

      return {
        content: [
          text(`Loaded parcel from ${input.path}. Result: ${evalResult.result ?? '(no result)'}`),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_unload_parcel
// -----------------------------------------------------------------------------

const unloadParcelSchema = {
  name: z
    .string()
    .min(1)
    .max(200)
    .describe('Parcel name as registered in the image (NOT a filesystem path).'),
};

function makeUnloadParcelTool(bridge: BridgeClientLike): ToolDef<typeof unloadParcelSchema> {
  return {
    name: 'vw_unload_parcel',
    description:
      'Unload a previously-loaded parcel by name via Kernel.Parcel removeParcelNamed:, ' +
      'wrapped with on: Core.Notification do: [:n | n resume] (carry-forward #38). ' +
      'REFUSES unloading "VWBridge" (would tear down the listener mid-call). ' +
      'Use vw_list_loaded_parcels to discover names first.',
    inputSchema: unloadParcelSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.name.trim().length === 0) {
        return errorResult('vw_unload_parcel: parcel name is empty.');
      }

      if (input.name === 'VWBridge' || input.name === 'VWBridge-Tests') {
        return errorResult(
          `vw_unload_parcel refused: cannot unload "${input.name}" — that would tear down the bridge listener and break this /eval channel mid-call. ` +
            'If you need to reload the bridge, use Start-VWBridge.bat -KillExisting outside the MCP server.'
        );
      }

      const probe = `[Kernel.Parcel removeParcelNamed: ${quoteSmalltalkString(input.name)}] on: Core.Notification do: [:n | n resume]`;
      const evalResult = await bridge.postEval(probe);

      if (!evalResult.ok) {
        return errorResult(
          `vw_unload_parcel: VW eval failed for "${input.name}": ${evalResult.error ?? '(no error)'}`
        );
      }

      return {
        content: [text(`Unloaded parcel "${input.name}". Result: ${evalResult.result ?? '(no result)'}`)],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_loaded_parcels
// -----------------------------------------------------------------------------

const LIST_PARCELS_PROBE = `| s sep |
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
((Kernel.Parcel allInstances collect: [:p | p name asString]) asSortedCollection)
    do: [:n | s nextPutAll: n; nextPutAll: sep].
s contents`;

function makeListLoadedParcelsTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_list_loaded_parcels',
    description:
      'List the names of every parcel currently loaded in the VW image (sorted). ' +
      'Returns JSON string array. Inventory before calling vw_unload_parcel.',
    inputSchema: {},
    handler: safeHandler(async (): Promise<ToolResult> => {
      const evalResult = await bridge.postEval(LIST_PARCELS_PROBE);
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_loaded_parcels: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      return { content: [text(JSON.stringify(splitOn(raw, RECORD_SEP)))] };
    }),
  };
}
