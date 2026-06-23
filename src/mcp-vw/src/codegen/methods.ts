/**
 * codegen/methods.ts — vw_compile_method + vw_define_action + vw_define_aspect.
 *
 * Three closely-related V2 tools that share Smalltalk emission logic:
 *
 *   - **vw_compile_method**: typed method compile (instance or class side)
 *     with carry-forward #41 guard (refuses VWB.* targets pre-call).
 *   - **vw_define_action**: convenience wrapper — adds an instance-side
 *     action method classified 'actions'.
 *   - **vw_define_aspect**: convenience wrapper — adds an instance-side
 *     lazy-init aspect accessor (the canonical `aspectName isNil ifTrue:
 *     [aspectName := <default> asValue] ifFalse: [aspectName]` pattern from
 *     architecture.md §6.5 / research/05-vw-native-development.md §5.1)
 *     classified 'aspects'.
 *
 * Per architecture.md §5.2 (tools 22, 23, 28) + §6.5.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidSelector,
  quoteSmalltalkString,
  unquoteSmalltalkString,
  validateParenBalance,
  formatParenBalanceError,
} from '../smalltalk.js';
import type { ToolDef } from '../tools/types.js';

// -----------------------------------------------------------------------------
// Pure emitters
// -----------------------------------------------------------------------------

export interface LazyAspectAccessorInput {
  aspectName: string;
  /** Smalltalk expression for the initial value. Default: `''`. */
  defaultExpression?: string;
}

/**
 * Emits the canonical lazy-init aspect accessor:
 *
 *   aspectName
 *       ^aspectName isNil
 *           ifTrue: [aspectName := <defaultExpression> asValue]
 *           ifFalse: [aspectName]
 *
 * The `asValue` selector wraps any expression as a ValueHolder. Idiomatic
 * VW per research/05-vw-native-development.md §5.1.
 */
export function emitLazyAspectAccessor(input: LazyAspectAccessorInput): string {
  const defaultExpr = input.defaultExpression ?? "''";
  return `${input.aspectName}
    "MCP-generated lazy aspect accessor. ValueHolder wraps the initial value."
    ^${input.aspectName} isNil
        ifTrue: [${input.aspectName} := ${defaultExpr} asValue]
        ifFalse: [${input.aspectName}]`;
}

export interface ActionMethodInput {
  actionName: string;
  body: string;
}

/**
 * Emits an action method: selector + 4-space-indented body.
 */
export function emitActionMethod(input: ActionMethodInput): string {
  // Indent each line of the body for readability.
  const indentedBody = input.body
    .split(/\r?\n/)
    .map((line) => (line.length > 0 ? `    ${line}` : line))
    .join('\n');
  return `${input.actionName}\n${indentedBody}`;
}

// -----------------------------------------------------------------------------
// Common guards
// -----------------------------------------------------------------------------

function refusesVWB(className: string): boolean {
  return className === 'VWB' || className.startsWith('VWB.');
}

function vwbRefusal(toolName: string, className: string): ToolResult {
  return errorResult(
    `${toolName} refuses targets in the VWB namespace (className "${className}"; carry-forward #41 — compile on VWB.* wedges the bridge via UI announcement fan-out). ` +
      'Pick a MAS application class instead. The bridge class is OFF-LIMITS for mid-/eval mutation.'
  );
}

function buildCompileExpression(
  className: string,
  isMeta: boolean,
  category: string,
  methodSource: string
): string {
  const receiver = isMeta ? `${className} class` : className;
  return `${receiver} compile: ${quoteSmalltalkString(methodSource)} classified: ${quoteSmalltalkString(category)}`;
}

// -----------------------------------------------------------------------------
// vw_compile_method
// -----------------------------------------------------------------------------

const compileMethodSchema = {
  className: z
    .string()
    .min(1)
    .max(200)
    .describe('Target class. Single segment or namespace-qualified. REFUSED for VWB.*.'),
  isMeta: z
    .boolean()
    .optional()
    .describe('true = class-side (metaclass), false / omitted = instance-side. Default false.'),
  category: z
    .string()
    .min(1)
    .max(200)
    .describe('Browser category for the method (e.g. "accessing", "actions", "interface specs").'),
  source: z
    .string()
    .min(1)
    .max(200_000)
    .describe(
      'Full method source including selector + body. The selector is the first token; the body is everything after.'
    ),
};

export function makeCompileMethodTool(
  bridge: BridgeClientLike
): ToolDef<typeof compileMethodSchema> {
  return {
    name: 'vw_compile_method',
    description:
      'NATIVE-TYPED method compile: pass {className, isMeta, category, source} JSON; tool emits the canonical "<Class> [class] compile: ... classified: ..." Smalltalk + dispatches via /eval. ' +
      'GUARDS: refuses VWB.* targets (carry-forward #41 — would wedge the bridge). ' +
      'For lazy-init aspect accessors use vw_define_aspect; for action methods use vw_define_action (cleaner JSON shapes for those common patterns).',
    inputSchema: compileMethodSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_compile_method: invalid className "${input.className}". Must match class-identifier regex.`
        );
      }
      if (refusesVWB(input.className)) {
        return vwbRefusal('vw_compile_method', input.className);
      }
      if (input.category.trim().length === 0) {
        return errorResult('vw_compile_method: category is empty.');
      }
      if (input.source.trim().length === 0) {
        return errorResult('vw_compile_method: source is empty.');
      }

      // s23 Bug 7 fix — pre-flight paren-balance check. VW's compiler error
      // on unbalanced literals has NO line/column ("Syntax error: array
      // element or right parenthesis expected -> "). Catching imbalance in
      // JS before the round-trip lets us return delta + line/column hints.
      const parenCheck = validateParenBalance(input.source);
      if (!parenCheck.balanced) {
        return errorResult(formatParenBalanceError('vw_compile_method', input.source, parenCheck));
      }

      const isMeta = input.isMeta ?? false;
      const expression = buildCompileExpression(input.className, isMeta, input.category, input.source);

      const evalResult = await bridge.postEval(expression);
      if (!evalResult.ok) {
        return errorResult(
          `vw_compile_method: VW eval failed for ${input.className}${isMeta ? ' class' : ''}: ${evalResult.error ?? '(no error)'}\n\nEmitted Smalltalk source:\n${input.source}`
        );
      }

      return {
        content: [
          text(
            `Compiled ${input.className}${isMeta ? ' class' : ''} method in category '${input.category}'. ` +
              `Result: ${evalResult.result ?? '(no result)'}`
          ),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_define_action
// -----------------------------------------------------------------------------

const defineActionSchema = {
  className: z.string().min(1).max(200),
  actionName: z
    .string()
    .min(1)
    .max(200)
    .describe('Action selector (instance-side). Unary or keyword. Becomes the method name.'),
  body: z
    .string()
    .min(1)
    .max(100_000)
    .describe('Method body — everything after the selector. Tool indents each line.'),
  category: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe("Optional Browser category override. Default 'actions'."),
};

export function makeDefineActionTool(
  bridge: BridgeClientLike
): ToolDef<typeof defineActionSchema> {
  return {
    name: 'vw_define_action',
    description:
      'NATIVE-TYPED: add an instance-side action method to a class. ' +
      'Wraps vw_compile_method with category=\'actions\' (overridable). Refuses VWB.*.',
    inputSchema: defineActionSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_define_action: invalid className "${input.className}". Must match class-identifier regex.`
        );
      }
      if (refusesVWB(input.className)) {
        return vwbRefusal('vw_define_action', input.className);
      }
      if (!isValidSelector(input.actionName)) {
        return errorResult(
          `vw_define_action: invalid actionName "${input.actionName}". Must match unary/binary/keyword selector regex.`
        );
      }

      const category = input.category ?? 'actions';
      const source = emitActionMethod({ actionName: input.actionName, body: input.body });
      const expression = buildCompileExpression(input.className, false, category, source);

      const evalResult = await bridge.postEval(expression);
      if (!evalResult.ok) {
        return errorResult(
          `vw_define_action: VW eval failed defining ${input.className}>>${input.actionName}: ${evalResult.error ?? '(no error)'}`
        );
      }

      return {
        content: [
          text(`Defined ${input.className}>>${input.actionName} in category '${category}'.`),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_define_aspect
// -----------------------------------------------------------------------------

const defineAspectSchema = {
  className: z.string().min(1).max(200),
  aspectName: z
    .string()
    .min(1)
    .max(200)
    .describe('Aspect name. Becomes the accessor selector + the instance variable name.'),
  defaultExpression: z
    .string()
    .min(1)
    .max(2_000)
    .optional()
    .describe(
      "Smalltalk expression for the initial value. Default `''` (empty string). Examples: `0`, `nil`, `OrderedCollection new`."
    ),
  category: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe("Optional Browser category override. Default 'aspects'."),
};

export function makeDefineAspectTool(
  bridge: BridgeClientLike
): ToolDef<typeof defineAspectSchema> {
  return {
    name: 'vw_define_aspect',
    description:
      'NATIVE-TYPED: add an instance-side lazy-init aspect accessor to an ApplicationModel class. ' +
      "Emits the canonical pattern: `aspect ^aspect isNil ifTrue: [aspect := <default> asValue] ifFalse: [aspect]`. " +
      "PRE-FLIGHT CHECK: probes `cls allInstVarNames` before compiling and REFUSES if the aspect name is not a declared " +
      "instance variable on the class (own or inherited). Without the ivar, VW's compiler resolves the bareword as a " +
      "ResolvedDeferredBinding literal — state then lives image-wide in the compiled method's literal array as a singleton " +
      "rather than per-instance (s23 Bug 2). Add the ivar via vw_compile_class_definition first, or use " +
      "vw_create_application_model which declares aspects as ivars in one shot. Refuses VWB.*.",
    inputSchema: defineAspectSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_define_aspect: invalid className "${input.className}". Must match class-identifier regex.`
        );
      }
      if (refusesVWB(input.className)) {
        return vwbRefusal('vw_define_aspect', input.className);
      }
      if (!/^[a-z_][A-Za-z0-9_]*$/.test(input.aspectName)) {
        return errorResult(
          `vw_define_aspect: invalid aspectName "${input.aspectName}". Must match /^[a-z_][A-Za-z0-9_]*$/.`
        );
      }

      // -----------------------------------------------------------------------
      // s23 Bug 2 fix — pre-flight ivar validation
      //
      // VW's compiler does NOT error on an undeclared bareword in a method
      // body — it resolves the name as a ResolvedDeferredBinding literal in
      // the CompiledMethod's literal array. The lazy-init pattern we emit
      // then assigns into that literal, producing an image-wide singleton
      // ValueHolder shared by every call to the accessor. AI tests with one
      // instance see state persist (looks correct); multi-instance code
      // silently aliases. Refuse fail-fast when the ivar is missing.
      //
      // `;` separator survives the bridge JSON whitespace collapse (#43);
      // LF would be flattened to a single space.
      // -----------------------------------------------------------------------
      const ivarsProbe = `| ws |
ws := WriteStream on: String new.
${input.className} allInstVarNames do: [:each | ws nextPutAll: each; nextPutAll: ';'].
ws contents`;
      const ivarsResult = await bridge.postEval(ivarsProbe);
      if (!ivarsResult.ok) {
        return errorResult(
          `vw_define_aspect: could not probe instance variables on ${input.className}: ${ivarsResult.error ?? '(no error)'}. ` +
            `Class may not exist — use vw_create_class first, or check spelling.`
        );
      }
      const ivars = unquoteSmalltalkString(ivarsResult.result ?? '')
        .split(';')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      if (!ivars.includes(input.aspectName)) {
        const available = ivars.length > 0 ? ivars.join(', ') : '(none)';
        return errorResult(
          `vw_define_aspect: aspect name "${input.aspectName}" is not a declared instance variable on ${input.className}.\n` +
            `available-ivars: [${available}]\n` +
            `consequence: VW's compiler would resolve "${input.aspectName}" as a ResolvedDeferredBinding literal — the accessor's lazy-init slot would live image-wide in the CompiledMethod literals as a shared singleton, NOT per-instance (s23 Bug 2).\n` +
            `fix: add the ivar via vw_compile_class_definition first, OR use vw_create_application_model which declares aspects as ivars in one shot.`
        );
      }

      const category = input.category ?? 'aspects';
      const source = emitLazyAspectAccessor({
        aspectName: input.aspectName,
        ...(input.defaultExpression !== undefined ? { defaultExpression: input.defaultExpression } : {}),
      });
      const expression = buildCompileExpression(input.className, false, category, source);

      const evalResult = await bridge.postEval(expression);
      if (!evalResult.ok) {
        return errorResult(
          `vw_define_aspect: VW eval failed defining ${input.className}>>${input.aspectName}: ${evalResult.error ?? '(no error)'}`
        );
      }

      return {
        content: [
          text(
            `Defined ${input.className}>>${input.aspectName} (lazy aspect accessor) in category '${category}'. ` +
              `Pre-flight verified ivar exists on ${input.className} or its superclasses.`
          ),
        ],
      };
    }),
  };
}
