/**
 * reading.ts — vw_get_class_definition + vw_list_methods (MVP).
 *
 * Read class shape + method list. Cheap probes via /eval.
 *
 * Sources are stripped in this image (`getSource` returns nil) so:
 *   - vw_get_class_definition uses `Cls definition` which is reconstructed
 *     from the metaclass shape (instVars, classVars, category, superclass).
 *     NOTE: per carry-forward #43, multi-line definitions come back with
 *     LFs collapsed to spaces. Still readable, just single-line.
 *   - vw_list_methods returns side+category+selector (not source) — for
 *     method bodies, AI must use vw_get_method_fingerprint (V2) which
 *     surfaces `numArgs`/`numTemps`/`messages`/`literals` instead of source.
 *     Uses `|` for field separator + `;` for record separator (#43).
 *
 * Per architecture.md §5.1 (tools 7 + 8).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  isValidClassIdentifier,
  RECORD_SEP,
  FIELD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeReadingTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeGetClassDefinitionTool(bridge),
    makeListMethodsTool(bridge),
    makeDescribeClassTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// vw_get_class_definition
// -----------------------------------------------------------------------------

const definitionInputSchema = {
  className: z
    .string()
    .min(1)
    .max(200)
    .describe(
      'Smalltalk class identifier. Single segment ("Customer") or namespace-qualified ("Tools.UIPainter", "VWB.VWBridge").'
    ),
};

function makeGetClassDefinitionTool(bridge: BridgeClientLike): ToolDef<typeof definitionInputSchema> {
  return {
    name: 'vw_get_class_definition',
    description:
      'Get the class definition source for a VW class. ' +
      'Returns the canonical Cincom VW form, typically "Smalltalk.<NS> defineClass: #X superclass: #{<NS>.<Super>} indexedType: #none private: false instanceVariableNames:... classInstanceVariableNames: \'\' imports: \'\' category:..." (modern 8-kw defineClass:), or "<Super> subclass: #X ... category:..." (legacy 5-kw) for older classes. ' +
      'NOTE: bridge collapses whitespace (#43) so multi-line definitions come back on one line — still readable. ' +
      'For instance/class methods, use vw_list_methods.',
    inputSchema: definitionInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_get_class_definition: invalid className "${input.className}". ` +
            'Must match /^[A-Z][A-Za-z0-9_]*(\\.[A-Z][A-Za-z0-9_]*)*$/. Reject special chars to prevent Smalltalk injection.'
        );
      }

      const probe = `${input.className} definition`;
      const evalResult = await bridge.postEval(probe);

      if (!evalResult.ok) {
        return errorResult(
          `vw_get_class_definition: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      return { content: [text(raw)] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_methods
// -----------------------------------------------------------------------------

function buildListMethodsProbe(className: string): string {
  // className already validated. Format: side|category|selector;...
  // Use `|` and `;` because LF/TAB collapse to spaces in the bridge response (#43).
  return `| s cls fieldSep recSep |
cls := ${className}.
s := WriteStream on: String new.
fieldSep := '${FIELD_SEP}'.
recSep := '${RECORD_SEP}'.
cls selectors asSortedCollection do: [:sel |
    s nextPutAll: 'instance'; nextPutAll: fieldSep.
    s nextPutAll: (cls organization categoryOfElement: sel) asString.
    s nextPutAll: fieldSep.
    s nextPutAll: sel asString.
    s nextPutAll: recSep].
cls class selectors asSortedCollection do: [:sel |
    s nextPutAll: 'class'; nextPutAll: fieldSep.
    s nextPutAll: (cls class organization categoryOfElement: sel) asString.
    s nextPutAll: fieldSep.
    s nextPutAll: sel asString.
    s nextPutAll: recSep].
s contents`;
}

interface MethodRecord {
  side: 'instance' | 'class';
  category: string;
  selector: string;
}

function makeListMethodsTool(bridge: BridgeClientLike): ToolDef<typeof definitionInputSchema> {
  return {
    name: 'vw_list_methods',
    description:
      'List every method on a VW class (both instance + class side), grouped by category. ' +
      'Returns JSON array of {side, category, selector}. side is "instance" or "class". ' +
      'For method body inspection use vw_eval with `cls compiledMethodAt: #sel` or vw_get_method_fingerprint (V2).',
    inputSchema: definitionInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_list_methods: invalid className "${input.className}". ` +
            'Must match /^[A-Z][A-Za-z0-9_]*(\\.[A-Z][A-Za-z0-9_]*)*$/.'
        );
      }

      const evalResult = await bridge.postEval(buildListMethodsProbe(input.className));

      if (!evalResult.ok) {
        return errorResult(
          `vw_list_methods: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const records: MethodRecord[] = [];
      for (const record of splitOn(raw, RECORD_SEP)) {
        const parts = record.split(FIELD_SEP);
        if (parts.length < 3) continue;
        const [side, category, selector] = parts;
        if ((side !== 'instance' && side !== 'class') || !selector) continue;
        records.push({
          side: side as 'instance' | 'class',
          category: category ?? '(uncategorized)',
          selector,
        });
      }

      return { content: [text(JSON.stringify(records))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_describe_class (V2) — composite of definition + comment + grouped methods
// -----------------------------------------------------------------------------

function buildDescribeClassProbe(className: string): string {
  return `| cls s fieldSep recSep |
cls := ${className}.
s := WriteStream on: String new.
fieldSep := '${FIELD_SEP}'.
recSep := '${RECORD_SEP}'.
"definition section"
s nextPutAll: 'DEF'; nextPutAll: fieldSep.
s nextPutAll: cls definition; nextPutAll: recSep.
"comment section"
s nextPutAll: 'CMT'; nextPutAll: fieldSep.
s nextPutAll: (cls comment ifNil: ['']); nextPutAll: recSep.
"instance methods"
cls selectors asSortedCollection do: [:sel |
    s nextPutAll: 'IM'; nextPutAll: fieldSep.
    s nextPutAll: (cls organization categoryOfElement: sel) asString.
    s nextPutAll: fieldSep.
    s nextPutAll: sel asString.
    s nextPutAll: recSep].
"class methods"
cls class selectors asSortedCollection do: [:sel |
    s nextPutAll: 'CM'; nextPutAll: fieldSep.
    s nextPutAll: (cls class organization categoryOfElement: sel) asString.
    s nextPutAll: fieldSep.
    s nextPutAll: sel asString.
    s nextPutAll: recSep].
s contents`;
}

interface DescribeResult {
  className: string;
  definition: string;
  comment: string;
  instanceMethods: Array<{ category: string; selector: string }>;
  classMethods: Array<{ category: string; selector: string }>;
}

function makeDescribeClassTool(bridge: BridgeClientLike): ToolDef<typeof definitionInputSchema> {
  return {
    name: 'vw_describe_class',
    description:
      'Composite class description in ONE call: definition + comment + instance methods (grouped by category) + class methods (grouped by category). ' +
      'Returns JSON {className, definition, comment, instanceMethods, classMethods}. ' +
      'Use instead of separate vw_get_class_definition + vw_list_methods when you want the full shape of a class.',
    inputSchema: definitionInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_describe_class: invalid className "${input.className}".`
        );
      }

      const evalResult = await bridge.postEval(buildDescribeClassProbe(input.className));
      if (!evalResult.ok) {
        return errorResult(
          `vw_describe_class: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const records: DescribeResult = {
        className: input.className,
        definition: '',
        comment: '',
        instanceMethods: [],
        classMethods: [],
      };

      for (const record of splitOn(raw, RECORD_SEP)) {
        const parts = record.split(FIELD_SEP);
        if (parts.length < 2) continue;
        const tag = parts[0];
        if (tag === 'DEF') {
          records.definition = parts.slice(1).join(FIELD_SEP);
        } else if (tag === 'CMT') {
          records.comment = parts.slice(1).join(FIELD_SEP);
        } else if (tag === 'IM' && parts.length >= 3) {
          records.instanceMethods.push({
            category: parts[1] ?? '(uncategorized)',
            selector: parts[2] ?? '',
          });
        } else if (tag === 'CM' && parts.length >= 3) {
          records.classMethods.push({
            category: parts[1] ?? '(uncategorized)',
            selector: parts[2] ?? '',
          });
        }
      }

      return { content: [text(JSON.stringify(records))] };
    }),
  };
}
