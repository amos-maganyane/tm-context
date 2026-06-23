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
 * Deep walk (s26 fix)
 * -------------------
 * Earlier (s25) the mutation was a single-pass over the top-level shape,
 * so nested errors (`windowSpec.components.0.type` enum miss) fell
 * through to zod's default because the inner ZodArray + ZodObject + ZodEnum
 * carried no errorMap. `applyErrorMapToSchema` now walks the schema tree
 * recursively, attaching the map to every reachable ZodType node so a
 * deeply-nested validation failure gets the custom message too. Cycles via
 * `z.lazy(...)` are guarded with a WeakSet of visited node references.
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
 *   - `_def.typeName` — the discriminator the walker uses to descend.
 *   - `_def.shape()` (ZodObject) / `_def.type` (ZodArray, ZodPromise) /
 *     `_def.innerType` (ZodOptional / Nullable / Default / Readonly /
 *      Branded / Catch) / `_def.options` (ZodUnion /
 *      DiscriminatedUnion) / `_def.left`+`right` (ZodIntersection) /
 *     `_def.schema` (ZodEffects) / `_def.items`+`rest` (ZodTuple) /
 *     `_def.valueType`+`keyType` (ZodRecord, ZodMap, ZodSet) /
 *     `_def.getter()` (ZodLazy) / `_def.in`+`out` (ZodPipeline) — the
 *     child accessors per Zod node type.
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
 * Recursively attach the MCP error map to a Zod schema and every reachable
 * child schema. Mutates `_def.errorMap` in place.
 *
 * Handles the standard Zod v3 wrapper node types via `_def.typeName`. The
 * `visited` WeakSet of already-mutated node references guards against
 * infinite recursion on self-referential schemas built with `z.lazy(...)`.
 *
 * Defensive: returns silently for non-object values or values without `_def`,
 * so a stray non-zod entry that slips through ToolAnnotations-style records
 * cannot crash registration.
 */
export function applyErrorMapToSchema(
  schema: unknown,
  visited: WeakSet<object> = new WeakSet()
): void {
  if (!schema || typeof schema !== 'object') return;
  if (visited.has(schema as object)) return;
  visited.add(schema as object);

  const candidate = schema as { _def?: ZodDefShape };
  if (!candidate._def || typeof candidate._def !== 'object') return;
  const def = candidate._def;

  // Set the map on this node first - works for primitive leaf schemas
  // (ZodString, ZodNumber, ZodBoolean, ZodEnum, ZodLiteral, ZodDate,
  // ZodBigInt, etc.) plus every wrapper/composite we descend into below.
  def.errorMap = mcpErrorMap;

  const typeName = def.typeName;
  switch (typeName) {
    case 'ZodObject': {
      // ZodObject>>_def.shape is a thunk: `() => ZodRawShape`.
      const shapeGetter = def.shape;
      if (typeof shapeGetter === 'function') {
        let inner: z.ZodRawShape | undefined;
        try {
          inner = shapeGetter();
        } catch {
          /* defensive - extremely unlikely but keep registration safe */
          inner = undefined;
        }
        if (inner) {
          for (const key of Object.keys(inner)) {
            applyErrorMapToSchema(inner[key], visited);
          }
        }
      }
      break;
    }
    case 'ZodArray': {
      // ZodArray>>_def.type holds the element schema.
      if (def.type) applyErrorMapToSchema(def.type, visited);
      break;
    }
    case 'ZodTuple': {
      if (Array.isArray(def.items)) {
        for (const item of def.items) applyErrorMapToSchema(item, visited);
      }
      if (def.rest) applyErrorMapToSchema(def.rest, visited);
      break;
    }
    case 'ZodUnion':
    case 'ZodDiscriminatedUnion': {
      if (Array.isArray(def.options)) {
        for (const opt of def.options) applyErrorMapToSchema(opt, visited);
      }
      break;
    }
    case 'ZodIntersection': {
      if (def.left) applyErrorMapToSchema(def.left, visited);
      if (def.right) applyErrorMapToSchema(def.right, visited);
      break;
    }
    case 'ZodOptional':
    case 'ZodNullable':
    case 'ZodDefault':
    case 'ZodReadonly':
    case 'ZodBranded':
    case 'ZodCatch': {
      if (def.innerType) applyErrorMapToSchema(def.innerType, visited);
      break;
    }
    case 'ZodEffects': {
      // ZodEffects wraps a base schema in `_def.schema` for .transform /
      // .refine / .superRefine.
      if (def.schema) applyErrorMapToSchema(def.schema, visited);
      break;
    }
    case 'ZodRecord':
    case 'ZodMap': {
      if (def.valueType) applyErrorMapToSchema(def.valueType, visited);
      if (def.keyType) applyErrorMapToSchema(def.keyType, visited);
      break;
    }
    case 'ZodSet': {
      if (def.valueType) applyErrorMapToSchema(def.valueType, visited);
      break;
    }
    case 'ZodLazy': {
      // `_def.getter` materializes the (potentially self-referential)
      // schema. The visited WeakSet prevents infinite recursion when the
      // returned schema cycles back to a parent node.
      if (typeof def.getter === 'function') {
        let inner: unknown;
        try {
          inner = def.getter();
        } catch {
          inner = undefined;
        }
        if (inner) applyErrorMapToSchema(inner, visited);
      }
      break;
    }
    case 'ZodPipeline': {
      if (def.in) applyErrorMapToSchema(def.in, visited);
      if (def.out) applyErrorMapToSchema(def.out, visited);
      break;
    }
    case 'ZodPromise': {
      if (def.type) applyErrorMapToSchema(def.type, visited);
      break;
    }
    // Primitive leaf types (ZodString, ZodNumber, ZodBoolean, ZodEnum,
    // ZodLiteral, ZodNativeEnum, ZodDate, ZodBigInt, ZodUndefined,
    // ZodNull, ZodVoid, ZodAny, ZodUnknown, ZodNever, ZodSymbol, ZodNaN,
    // ZodFunction) have no Zod child schemas - the errorMap is set above
    // and that is all we need.
    default:
      break;
  }
}

/**
 * Attach the MCP error map to every field schema in a tool-input shape,
 * recursively walking into nested ZodObject / ZodArray / ZodUnion / etc.
 * Mutates in place; returns the shape so call sites can chain.
 *
 * Defensive: only attaches when `_def` is reachable on the value (skips
 * non-zod values that might slip through ToolAnnotations-style records).
 */
export function applyErrorMapToShape<T extends z.ZodRawShape>(shape: T): T {
  const visited = new WeakSet<object>();
  for (const key of Object.keys(shape)) {
    const candidate = shape[key] as unknown;
    if (
      candidate &&
      typeof candidate === 'object' &&
      '_def' in candidate &&
      typeof (candidate as { _def: unknown })._def === 'object'
    ) {
      applyErrorMapToSchema(candidate, visited);
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

/**
 * Loose shape of a ZodType's `_def` slot. Each property is optional
 * because different node types use different subsets - the walker reads
 * each one defensively under a `typeName` switch.
 */
interface ZodDefShape {
  errorMap?: z.ZodErrorMap;
  typeName?: string;
  // ZodObject
  shape?: () => z.ZodRawShape;
  // ZodArray, ZodPromise
  type?: z.ZodTypeAny;
  // ZodTuple
  items?: z.ZodTypeAny[];
  rest?: z.ZodTypeAny | null;
  // ZodUnion, ZodDiscriminatedUnion
  options?: z.ZodTypeAny[];
  // ZodIntersection
  left?: z.ZodTypeAny;
  right?: z.ZodTypeAny;
  // ZodOptional / Nullable / Default / Readonly / Branded / Catch
  innerType?: z.ZodTypeAny;
  // ZodEffects
  schema?: z.ZodTypeAny;
  // ZodRecord, ZodMap, ZodSet
  valueType?: z.ZodTypeAny;
  keyType?: z.ZodTypeAny;
  // ZodLazy
  getter?: () => z.ZodTypeAny;
  // ZodPipeline
  in?: z.ZodTypeAny;
  out?: z.ZodTypeAny;
}
