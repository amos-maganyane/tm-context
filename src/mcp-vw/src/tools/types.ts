/**
 * Shared tool-definition shape used by every tool factory.
 *
 * Each factory in `src/tools/*.ts` returns a `ToolDef` (or array of them).
 * `src/index.ts` collects all ToolDefs and registers them with the MCP server.
 *
 * Decoupling tool logic from MCP registration means:
 *   1. Tests can invoke `handler(input)` directly — no MCP transport needed.
 *   2. Registration is a single loop in `index.ts` — easy to audit "is tool X registered?".
 *   3. Tool implementations stay agnostic of SDK version/API drift.
 *
 * Why method syntax for `handler` instead of arrow property:
 *   - TypeScript treats method-syntax params as bivariant (vs strict
 *     contravariance for arrow properties). That lets a specific
 *     `ToolDef<{source: ZodString}>` widen to `ToolDef<ZodRawShape>` in
 *     a generic `ToolDef[]` array — which is what `buildAllTools()` returns.
 *   - The Zod schema at runtime parses + validates input before reaching
 *     the handler, so the bivariance widening is safe in practice.
 */

import type { z } from 'zod';
import type { ToolResult } from '../util.js';

export interface ToolDef<I extends z.ZodRawShape = z.ZodRawShape> {
  /** MCP tool name (must be prefixed `vw_` per architecture.md §4). */
  name: string;
  /** Human + AI-readable description. SHOULD include "use vw_X first" hints. */
  description: string;
  /** Zod raw shape (object of zod schemas) — passed to McpServer.registerTool(). */
  inputSchema: I;
  /**
   * Tool body. Receives the parsed/validated input.
   * NEVER throws — wrap with `safeHandler` from util.ts.
   * `z.infer<z.ZodObject<I>>` preserves `.optional()` markers correctly
   * (a naive mapped type loses optionality and forces `| undefined` to be required).
   */
  handler(input: z.infer<z.ZodObject<I>>): Promise<ToolResult>;
}

/** Convenience: a list of tool defs collected from a factory. */
export type ToolDefList = ReadonlyArray<ToolDef>;
