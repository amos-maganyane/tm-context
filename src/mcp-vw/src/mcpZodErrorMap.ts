/**
 * mcpZodErrorMap.ts — actionable zod error map for MCP tool input validation.
 *
 * Why this exists: when an MCP tool call fails schema validation, the SDK
 * passes zod's error message through to the JSON-RPC response verbatim.
 * Zod's default — `"Invalid input: expected boolean, received undefined"` —
 * does NOT name which parameter was wrong, so an AI agent reading just the
 * message can't recover without parsing the structured issue.
 *
 * With this map attached:
 *
 *   `Missing required parameter 'confirm' (expected boolean).`
 *   `Parameter 'windowSpec.components.0.type' must be one of [Label, ...,
 *     DataSet], but received 'WidgetX'.`
 *
 * Per-schema, NOT global
 * ----------------------
 * The MCP SDK uses zod internally to parse JSON-RPC messages via
 * discriminated unions. Failed branches emit `invalid_type` issues as a
 * normal control-flow signal. Setting `z.setErrorMap(mcpErrorMap)` globally
 * rewrites THOSE messages too and breaks the SDK's protocol parsing
 * (manifests as request hangs at runtime).
 *
 * The fix: attach the map per tool-input field via the schema's own
 * `_def.errorMap` slot — which zod v3 consults BEFORE the global override —
 * scoping our custom messages to schemas we own.
 *
 * Why we mutate `_def.errorMap` directly: McpServer's `registerTool(name,
 * { inputSchema }, cb)` takes a raw ZodRawShape, not a ZodObject, so we
 * can't pass an `errorMap` option through the public ZodObject constructor
 * at call sites. Mutating `_def.errorMap` imperatively preserves all
 * chained metadata (.describe, .optional, etc.) on each field.
 *
 * Why wrap rather than monkey-patch the prototype: keeps the change local
 * to registerTools so tests that exercise the raw McpServer don't see an
 * instrumented prototype.
 *
 * zod v3 API surface used here:
 *   - `z.ZodErrorMap` — type alias for `(issue, ctx) => { message: string }`
 *   - `z.ZodIssueCode.invalid_type` / `invalid_enum_value` — the two codes
 *     we specialize (cover ~95% of real MCP tool-input failures).
 *   - `_def.errorMap` — the per-schema slot zod consults first.
 */

import { z } from 'zod';

/**
 * Custom zod error map. Specializes the two issue codes that account for
 * almost all MCP tool-input failures:
 *
 *   - `invalid_type` — missing required (received === 'undefined') OR wrong type
 *   - `invalid_enum_value` — value not in the allowed enum set
 *
 * Other issue codes fall through to `ctx.defaultError`, preserving zod's
 * built-in messages for things we don't specialize.
 */
export const mcpErrorMap: z.ZodErrorMap = (issue, ctx) => {
  if (issue.code === z.ZodIssueCode.invalid_type) {
    const path = formatPath(issue.path);
    const expected = String(issue.expected);
    if (issue.received === 'undefined') {
      return {
        message: `Missing required parameter '${path}' (expected ${expected}).`,
      };
    }
    return {
      message: `Parameter '${path}' must be ${expected}, but received ${String(issue.received)}.`,
    };
  }
  if (issue.code === z.ZodIssueCode.invalid_enum_value) {
    const path = formatPath(issue.path);
    const options = issue.options.map((o) => String(o)).join(', ');
    const received = String(issue.received);
    return {
      message: `Parameter '${path}' must be one of [${options}], but received '${received}'.`,
    };
  }
  return { message: ctx.defaultError };
};

/**
 * Attach the MCP error map to every field schema in a tool-input shape.
 * Mutates in place; returns the shape so call sites can chain.
 *
 * Defensive: only attaches when `_def` is reachable on the value (skips
 * non-zod values that might slip through ToolAnnotations-style records).
 */
export function applyErrorMapToShape<T extends z.ZodRawShape>(shape: T): T {
  for (const key of Object.keys(shape)) {
    const candidate = shape[key] as unknown;
    if (
      candidate &&
      typeof candidate === 'object' &&
      '_def' in candidate &&
      typeof (candidate as { _def: unknown })._def === 'object'
    ) {
      const def = (candidate as { _def: { errorMap?: z.ZodErrorMap } })._def;
      def.errorMap = mcpErrorMap;
    }
  }
  return shape;
}

/**
 * Shape predicate: a tool-input shape is a plain object whose values are
 * ZodType instances (have `_def`). ToolAnnotations also pass as a record
 * but its values lack `_def`, so we filter via the `_def` check. Empty
 * shapes (`{}`) are caught and pass through harmlessly.
 */
function isToolInputShape(value: unknown): value is z.ZodRawShape {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj);
  if (keys.length === 0) return true;
  return keys.every((k) => {
    const v = obj[k];
    return !!v && typeof v === 'object' && '_def' in v;
  });
}

/**
 * Public surface for wrapping. Loose typing because McpServer's `tool` and
 * `registerTool` have overloaded signatures we forward through dynamically.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type McpServerLike = {
  tool?: (...args: any[]) => any;
  registerTool?: (...args: any[]) => any;
};

/**
 * Wrap an McpServer so every tool registration applies the MCP error map
 * to its input shape automatically. Mutates `server.tool` /
 * `server.registerTool` in place and returns the same instance for
 * chaining.
 *
 * Supports both SDK surfaces:
 *   - `server.tool(name, [desc], shape, cb)`        — older
 *   - `server.registerTool(name, { inputSchema }, cb)` — current (what mcp-vw uses)
 */
export function withMcpErrorMap<T extends McpServerLike>(server: T): T {
  if (typeof server.tool === 'function') {
    const original = server.tool.bind(server);
    server.tool = ((...args: unknown[]) => {
      for (const arg of args) {
        if (isToolInputShape(arg)) {
          applyErrorMapToShape(arg);
          break;
        }
      }
      return original(...args);
    }) as typeof server.tool;
  }
  if (typeof server.registerTool === 'function') {
    const original = server.registerTool.bind(server);
    server.registerTool = ((...args: unknown[]) => {
      const opts = args[1];
      if (
        opts &&
        typeof opts === 'object' &&
        'inputSchema' in opts &&
        isToolInputShape((opts as { inputSchema: unknown }).inputSchema)
      ) {
        applyErrorMapToShape((opts as { inputSchema: z.ZodRawShape }).inputSchema);
      }
      // Fallback positional shape (older `tool(name, desc, shape, cb)` style)
      for (const arg of args) {
        if (isToolInputShape(arg)) {
          applyErrorMapToShape(arg);
          break;
        }
      }
      return original(...args);
    }) as typeof server.registerTool;
  }
  return server;
}

function formatPath(path: PropertyKey[] | undefined): string {
  if (!path || path.length === 0) return '<root>';
  return path.map((p) => String(p)).join('.');
}
