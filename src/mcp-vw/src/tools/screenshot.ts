/**
 * screenshot.ts — V3 vw_screenshot tool wrapping the bridge /screenshot endpoint.
 *
 * The bridge captures the full VW screen or a named window as PNG bytes
 * (Phase F v0.9.1). This tool calls BridgeClient.getBinary to fetch raw
 * bytes, base64-encodes them, and returns MCP ImageContent so Claude
 * Desktop renders inline.
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
    .describe('Optional window title to capture just that window. Omit for full screen.'),
};

function makeScreenshotTool(bridge: BridgeClientLike): ToolDef<typeof screenshotSchema> {
  return {
    name: 'vw_screenshot',
    description:
      'Capture a PNG screenshot of the VW screen or a named window. ' +
      'Returns MCP ImageContent (base64-encoded PNG) for direct rendering in Claude Desktop. ' +
      'Use after vw_click / vw_type to visually verify the UI state.',
    inputSchema: screenshotSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      const params = new URLSearchParams();
      if (input.windowTitle !== undefined) {
        params.set('windowTitle', input.windowTitle);
      }
      const path = params.toString().length > 0
        ? `/screenshot?${params.toString()}`
        : `/screenshot`;

      const { bytes, contentType } = await bridge.getBinary(path);
      const base64 = Buffer.from(bytes).toString('base64');
      const mimeType = contentType.startsWith('image/') ? contentType : 'image/png';

      return { content: [image(base64, mimeType)] };
    }),
  };
}
