/**
 * codegen/class.ts — vw_create_class NATIVE-TYPED scaffolder (MVP).
 *
 * The first of the v2 native-UI-construction tools. The AI passes a typed
 * JSON spec (className, namespace, superclass, iVars, cVars, etc.) and this
 * tool emits the canonical VW class definition Smalltalk, posts it to /eval,
 * and surfaces a clean success/error result.
 *
 * Why NATIVE-TYPED:
 *   - AI never crafts raw Smalltalk → no apostrophe-escape bugs.
 *   - All identifier inputs are validated via `isValidClassIdentifier` /
 *     `isValidNamespaceIdentifier` → no Smalltalk injection.
 *   - Namespace placement is via the `defineClass:` receiver
 *     (`Smalltalk.<NS> defineClass: ...`), NOT a misnamed `inDictionary:`
 *     keyword (which does not exist in Cincom VW — see s23 benchmark Bug 1).
 *     Cross-namespace superclasses (e.g. `MyApp.Foo` extending
 *     `UI.ApplicationModel`) are natively supported via `#{NS.Class}` literals.
 *   - The carry-forward #41 VWB.* wedge is refused fail-fast in the tool
 *     layer, not by the bridge (which would still wedge).
 *
 * Emitted form (canonical Cincom VW `defineClass:` 8-kw, per s23 benchmark
 * Bug 1 — the legacy 6-kw `subclass:...:inDictionary:category:` selector
 * does NOT exist in this image; verified live false against `Object` and
 * `ApplicationModel`):
 *
 *   Smalltalk.<Namespace> defineClass: #ClassName
 *       superclass: #{<Superclass>}
 *       indexedType: #none
 *       private: false
 *       instanceVariableNames: 'iv1 iv2'
 *       classInstanceVariableNames: ''
 *       imports: ''
 *       category: 'My-Category'
 *
 * Notes:
 *   - Receiver is bare `Smalltalk` when namespace=Smalltalk, else
 *     namespace-qualified `Smalltalk.<NS>`.
 *   - Superclass literal: dotted forms used as-is in `#{<X.Y>}`; bare
 *     identifiers prefixed `#{Smalltalk.<X>}` to rely on Smalltalk's
 *     import chain to resolve `Core.*` classes.
 *   - The 8-kw form has NO `classVariableNames` or `poolDictionaries`
 *     keywords. Non-empty inputs for those legacy fields are rejected at
 *     the handler layer with a migration hint (use `vw_compile_method`
 *     against the metaclass or `imports:` for namespace-scoped sharing).
 *   - `category:` is required by the 8-kw form; emit `category: ''` when
 *     not provided.
 *
 * Per architecture.md §5.1 (tool 10) + §6.3 + §17 Appendix A — §6.3's
 * `subclass:...inDictionary:...` snippet is superseded by the form above.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidNamespaceIdentifier,
  quoteSmalltalkStringBody,
} from '../smalltalk.js';
import type { ToolDef } from '../tools/types.js';

// -----------------------------------------------------------------------------
// Input shape
// -----------------------------------------------------------------------------

const createClassInputSchema = {
  className: z
    .string()
    .min(1)
    .max(200)
    .describe('Class name to create. Single segment, uppercase-start.'),
  namespace: z
    .string()
    .min(1)
    .max(100)
    .describe(
      'Namespace to place the new class in. Single-segment identifier (e.g. "Smalltalk", "MyApp"). REFUSED for "VWB" — carry-forward #41.'
    ),
  superclass: z
    .string()
    .min(1)
    .max(200)
    .describe(
      'Superclass identifier. Single segment or namespace-qualified (e.g. "Object", "Smalltalk.Object", "Tools.UIPainter").'
    ),
  instanceVariableNames: z
    .array(z.string())
    .optional()
    .describe('Instance variable names. Validated as lowercase-start identifiers.'),
  classVariableNames: z
    .array(z.string())
    .optional()
    .describe('Class variable names. Validated as uppercase-start identifiers.'),
  poolDictionaries: z
    .array(z.string())
    .optional()
    .describe('Pool dictionary names. Validated as uppercase-start identifiers.'),
  category: z
    .string()
    .max(200)
    .optional()
    .describe('Optional Browser category string (free-form; apostrophes get escaped).'),
};

// -----------------------------------------------------------------------------
// Pure emitter (exported for golden-file testing)
// -----------------------------------------------------------------------------

export interface CreateClassInput {
  className: string;
  namespace: string;
  superclass: string;
  instanceVariableNames?: string[];
  classVariableNames?: string[];
  poolDictionaries?: string[];
  category?: string;
}

export function emitCreateClassSmalltalk(input: CreateClassInput): string {
  const ivars = (input.instanceVariableNames ?? []).join(' ');

  // Receiver: Smalltalk root namespace itself uses bare `Smalltalk`;
  // child namespaces use `Smalltalk.<NS>` qualification.
  const receiver =
    input.namespace === 'Smalltalk'
      ? 'Smalltalk'
      : `Smalltalk.${input.namespace}`;

  // Superclass literal: dotted forms used as-is in `#{<X.Y>}`; bare
  // identifiers prefixed `#{Smalltalk.<X>}` to rely on Smalltalk's
  // import chain to resolve `Core.*` classes (Object → Core.Object etc.).
  const superLit = input.superclass.includes('.')
    ? `#{${input.superclass}}`
    : `#{Smalltalk.${input.superclass}}`;

  // defineClass: 8-kw form REQUIRES category — emit empty string when omitted.
  const category =
    input.category !== undefined
      ? quoteSmalltalkStringBody(input.category)
      : '';

  return [
    `${receiver} defineClass: #${input.className}`,
    `    superclass: ${superLit}`,
    `    indexedType: #none`,
    `    private: false`,
    `    instanceVariableNames: '${ivars}'`,
    `    classInstanceVariableNames: ''`,
    `    imports: ''`,
    `    category: '${category}'`,
  ].join('\n');
}

// -----------------------------------------------------------------------------
// Identifier validation
// -----------------------------------------------------------------------------

const IVAR_RE = /^[a-z_][A-Za-z0-9_]*$/;
const CVAR_RE = /^[A-Z][A-Za-z0-9_]*$/;
const POOL_RE = /^[A-Z][A-Za-z0-9_]*$/;

function validateIdentifierList(
  names: string[] | undefined,
  re: RegExp
): { ok: true } | { ok: false; bad: string } {
  if (!names) return { ok: true };
  for (const n of names) {
    if (!re.test(n)) {
      return { ok: false, bad: n };
    }
  }
  return { ok: true };
}

// -----------------------------------------------------------------------------
// Tool factory
// -----------------------------------------------------------------------------

const TOOL_DESCRIPTION =
  'NATIVE-TYPED class creator: emits canonical "<Superclass> subclass:..." Smalltalk from JSON params. ' +
  'AI passes structured JSON (className, namespace, superclass, instVars, classVars, poolDicts, category); ' +
  'tool emits + compiles via /eval. ' +
  'GUARDS: refuses any class targeting the VWB namespace (carry-forward #41 — wedges the bridge). ' +
  'All identifiers are validated against Smalltalk-safe regex to prevent injection. ' +
  'Use this tool to create domain classes, helpers, test classes — for full ApplicationModel scaffolding (class + initialize + aspect accessors + windowSpec) use vw_create_application_model (V2).';

export function makeCreateClassTool(
  bridge: BridgeClientLike
): ToolDef<typeof createClassInputSchema> {
  return {
    name: 'vw_create_class',
    description: TOOL_DESCRIPTION,
    inputSchema: createClassInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // -----------------------------------------------------------------------
      // Identifier validation
      // -----------------------------------------------------------------------
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_create_class: invalid className "${input.className}". Must match /^[A-Z][A-Za-z0-9_]*$/ or namespace-qualified form.`
        );
      }
      if (!isValidNamespaceIdentifier(input.namespace)) {
        return errorResult(
          `vw_create_class: invalid namespace "${input.namespace}". Must match /^[A-Z][A-Za-z0-9_]*$/ (single segment).`
        );
      }
      if (!isValidClassIdentifier(input.superclass)) {
        return errorResult(
          `vw_create_class: invalid superclass "${input.superclass}". Must match class-identifier regex.`
        );
      }

      // -----------------------------------------------------------------------
      // Carry-forward #41 guard: refuse VWB.* targets
      // -----------------------------------------------------------------------
      if (
        input.namespace === 'VWB' ||
        input.className === 'VWB' ||
        input.className.startsWith('VWB.') ||
        input.superclass.startsWith('VWB.')
      ) {
        return errorResult(
          `vw_create_class refuses targets in the VWB namespace (carry-forward #41 — compile on VWB.* wedges the bridge via UI announcement fan-out). ` +
            'Pick a MAS application namespace instead. The bridge class is OFF-LIMITS for mid-/eval mutation.'
        );
      }

      // -----------------------------------------------------------------------
      // defineClass: 8-kw form limitations: no classVariableNames or
      // poolDictionaries keywords exist (s23 benchmark Bug 1). The schema
      // preserves those fields for backwards compatibility, but non-empty
      // inputs are refused with a migration hint rather than silently
      // dropped.
      // -----------------------------------------------------------------------
      if ((input.classVariableNames?.length ?? 0) > 0) {
        return errorResult(
          `vw_create_class: classVariableNames not supported by the canonical Cincom VW defineClass: 8-kw form. ` +
            `The new emission uses Smalltalk.<NS> defineClass: ... (no classVariableNames keyword). ` +
            `To add class variables to the created class, use vw_compile_method on its metaclass with addClassVarName: instead.`
        );
      }
      if ((input.poolDictionaries?.length ?? 0) > 0) {
        return errorResult(
          `vw_create_class: poolDictionaries not supported by the canonical Cincom VW defineClass: 8-kw form. ` +
            `The 8-kw form has imports: instead (namespace-scoped). ` +
            `Use vw_compile_method to recompile the class with imports if needed, or migrate to namespace imports.`
        );
      }

      // -----------------------------------------------------------------------
      // Validate variable lists (each entry must be a safe identifier).
      // -----------------------------------------------------------------------
      const ivCheck = validateIdentifierList(input.instanceVariableNames, IVAR_RE);
      if (!ivCheck.ok) {
        return errorResult(
          `vw_create_class: invalid instance variable name "${ivCheck.bad}". Must match /^[a-z_][A-Za-z0-9_]*$/.`
        );
      }
      const cvCheck = validateIdentifierList(input.classVariableNames, CVAR_RE);
      if (!cvCheck.ok) {
        return errorResult(
          `vw_create_class: invalid class variable name "${cvCheck.bad}". Must match /^[A-Z][A-Za-z0-9_]*$/.`
        );
      }
      const poolCheck = validateIdentifierList(input.poolDictionaries, POOL_RE);
      if (!poolCheck.ok) {
        return errorResult(
          `vw_create_class: invalid pool dictionary "${poolCheck.bad}". Must match /^[A-Z][A-Za-z0-9_]*$/.`
        );
      }

      // -----------------------------------------------------------------------
      // Emit + dispatch
      // -----------------------------------------------------------------------
      const src = emitCreateClassSmalltalk(input);
      const evalResult = await bridge.postEval(src);

      if (!evalResult.ok) {
        return errorResult(
          `vw_create_class: VW eval failed when creating ${input.namespace}.${input.className}: ${evalResult.error ?? '(no error)'}\n\nEmitted Smalltalk:\n${src}`
        );
      }

      return {
        content: [
          text(
            `Created ${input.namespace}.${input.className} (superclass: ${input.superclass}). ` +
              `Result: ${evalResult.result ?? '(no result)'}`
          ),
        ],
      };
    }),
  };
}
