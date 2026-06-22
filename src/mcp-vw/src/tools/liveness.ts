/**
 * liveness.ts — 3 MVP tools: vw_health, vw_version, vw_status.
 *
 * Cheap dispatchers that wrap the bridge's auth-exempt liveness endpoints
 * (/health, /version) plus a side-effect-free eval probe for vw_status.
 *
 * Tool descriptions explicitly mention "auth-exempt" so the AI knows these
 * work even when the token has rotated and the AI hasn't re-read it yet —
 * useful for "is the bridge alive at all?" sanity checks.
 *
 * Per architecture.md §5.1 (tools 1, 2, 3).
 */

import { z } from 'zod';
import type { BridgeClientLike, BridgeEvalResult } from '../bridge.js';
import { text, safeHandler, type ToolResult } from '../util.js';
import type { ToolDef } from './types.js';

const emptyInput = {};

/**
 * Build the 3 liveness tools bound to a given bridge.
 */
export function makeLivenessTools(bridge: BridgeClientLike): ToolDef[] {
  return [makeHealthTool(bridge), makeVersionTool(bridge), makeStatusTool(bridge)];
}

// -----------------------------------------------------------------------------
// vw_health
// -----------------------------------------------------------------------------

function makeHealthTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_health',
    description:
      'Auth-exempt liveness check against the VW Runtime API. Returns JSON {status, version}. ' +
      'Use as the FIRST tool call when diagnosing "is the bridge running at all?" — works even when the auth token has rotated.',
    inputSchema: emptyInput,
    handler: safeHandler(async (): Promise<ToolResult> => {
      const health = await bridge.health();
      return { content: [text(JSON.stringify(health))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_version
// -----------------------------------------------------------------------------

function makeVersionTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_version',
    description:
      'Auth-exempt build metadata for the VW Runtime API. Returns JSON {version, buildCommitSha, buildTimestamp, parcelMode}. ' +
      'Use to verify bridge compatibility (mcp-vw expects bridge >= 0.10.0) or to pin SDK behavior to a specific build.',
    inputSchema: emptyInput,
    handler: safeHandler(async (): Promise<ToolResult> => {
      const version = await bridge.version();
      return { content: [text(JSON.stringify(version))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_status — composite probe
// -----------------------------------------------------------------------------

// Tiny side-effect-free Smalltalk expression. Returns the literal Integer 42.
// Result printString in bridge /eval response is "42" — proves dispatch works
// end-to-end without compiling, creating classes, or touching the filesystem.
const STATUS_EVAL_PROBE = '42';

const StatusEvalResult = z.object({
  ok: z.boolean(),
  result: z.string().optional(),
  error: z.string().optional(),
});

function makeStatusTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_status',
    description:
      'Composite VW image + bridge status: combines /health + /version + a cheap eval probe (literal Integer 42). ' +
      'Returns JSON {bridge, build, evalProbe}. Use to verify "everything works end-to-end" before running real work. ' +
      'If the eval probe fails but /health + /version succeed, the dispatcher is wedged (carry-forward #28 or #41) — restart via Start-VWBridge.bat.',
    inputSchema: emptyInput,
    handler: safeHandler(async (): Promise<ToolResult> => {
      // health + version must succeed — if they don't, surface the bridge failure.
      const [health, build] = await Promise.all([bridge.health(), bridge.version()]);

      // eval probe is best-effort — partial status is still informative.
      let evalProbe: BridgeEvalResult;
      try {
        const raw = await bridge.postEval(STATUS_EVAL_PROBE);
        evalProbe = StatusEvalResult.parse(raw) as BridgeEvalResult;
      } catch (err) {
        evalProbe = {
          ok: false,
          error: err instanceof Error ? err.message : String(err),
        };
      }

      const combined = { bridge: health, build, evalProbe };
      return { content: [text(JSON.stringify(combined, null, 2))] };
    }),
  };
}
