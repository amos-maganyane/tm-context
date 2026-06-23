/**
 * screenshot.ts — V3 vw_screenshot tool wrapping the bridge POST /screenshot endpoint.
 *
 * Bridge contract (verified live against vw-runtime-api v0.10.0,
 * VWBridge.st handleScreenshotBody: + parseAndValidateScreenshotRequest:):
 *
 *   POST /screenshot
 *   Content-Type: application/json
 *   Body: {
 *     "target": { "type": "screen"|"window", "appClass"?: str, "titleContains"?: str },
 *     "format"?: "png",        // only png supported in v1; 415 on others
 *     "maxBytes"?: int,        // 1..16_777_216, default 16 MiB
 *     "timeoutMs"?: int        // 1..30_000, default 10000
 *   }
 *
 * "target" is REQUIRED — empty body returns 400. For window targets the
 * bridge REQUIRES at least one of appClass / titleContains (no implicit
 * "any window" matching).
 *
 * s23 Bug 4 fix: vw_screenshot previously called bridge.getBinary which
 * issues GET /screenshot. The bridge route table only lists /screenshot
 * under POST handlers, so every call 404'd. Switching to bridge.postBinary
 * with the JSON spec body matches the contract.
 *
 * Per architecture.md §5.3 (tool 36) + Phase F v0.9.1.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { image, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

export function makeScreenshotTools(bridge: BridgeClientLike): ToolDef[] {
  return [makeScreenshotTool(bridge)];
}

const screenshotSchema = {
  windowTitle: z
    .string()
    .min(1)
    .max(500)
    .optional()
    .describe(
      'Optional case-insensitive substring of the window title to capture. ' +
        'Omit (and omit appClass) to capture the full screen.'
    ),
  appClass: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe(
      'Optional VW application class name (e.g. "Tools.UIPainter") to disambiguate ' +
        'window targeting when multiple windows match the title. Omit for screen capture.'
    ),
};

interface ScreenshotInput {
  windowTitle?: string;
  appClass?: string;
}

function buildScreenshotSpec(input: ScreenshotInput): Record<string, unknown> {
  if (input.windowTitle === undefined && input.appClass === undefined) {
    // Full-screen capture.
    return { target: { type: 'screen' }, format: 'png' };
  }
  // Window capture — at least one filter is present (the bridge requires it).
  const target: Record<string, unknown> = { type: 'window' };
  if (input.appClass !== undefined) target['appClass'] = input.appClass;
  if (input.windowTitle !== undefined) target['titleContains'] = input.windowTitle;
  return { target, format: 'png' };
}

function makeScreenshotTool(bridge: BridgeClientLike): ToolDef<typeof screenshotSchema> {
  return {
    name: 'vw_screenshot',
    description:
      'Capture a PNG screenshot of the VW screen or a named window via POST /screenshot. ' +
      'Returns MCP ImageContent (base64-encoded PNG) for direct rendering in Claude Desktop. ' +
      'Omit windowTitle + appClass for full-screen capture. Provide either or both for window capture ' +
      '(bridge requires at least one filter for window targets — empty filter would accept any window).',
    inputSchema: screenshotSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      const spec = buildScreenshotSpec(input);
      const { bytes, contentType } = await bridge.postBinary('/screenshot', spec);
      const base64 = Buffer.from(bytes).toString('base64');
      const mimeType = contentType.startsWith('image/') ? contentType : 'image/png';
      return { content: [image(base64, mimeType)] };
    }),
  };
}

