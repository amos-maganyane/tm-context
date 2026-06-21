/**
 * introspection.ts — V3 code-shape introspection tools.
 *
 *   - vw_get_method_fingerprint: behavioral fingerprint (numArgs, numTemps,
 *     messages, literals) since sources are stripped in this image.
 *   - vw_get_class_hierarchy: superclass chain + direct subclasses.
 *   - vw_export_class: structural dump (definition + comment + every method's
 *     fingerprint). Useful for AI to understand a class without source.
 *   - vw_search_method_messages: substring search across methods' `messages` sets.
 *
 * Per architecture.md §5.3 (tools 37, 38, 39, 40).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  isValidClassIdentifier,
  isValidSelector,
  isValidNamespaceIdentifier,
  RECORD_SEP,
  FIELD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeIntrospectionTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeGetMethodFingerprintTool(bridge),
    makeGetClassHierarchyTool(bridge),
    makeExportClassTool(bridge),
    makeSearchMethodMessagesTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// vw_get_method_fingerprint
// -----------------------------------------------------------------------------

const fingerprintSchema = {
  className: z.string().min(1).max(200),
  selector: z.string().min(1).max(200),
  isMeta: z.boolean().optional().describe('true = class-side method. Default false.'),
};

function buildFingerprintProbe(className: string, selector: string, isMeta: boolean): string {
  const receiver = isMeta ? `${className} class` : className;
  return `| cls m s fieldSep |
cls := ${receiver}.
m := cls compiledMethodAt: #${selector} ifAbsent: [nil].
m isNil
    ifTrue: ['ABSENT']
    ifFalse: [
        s := WriteStream on: String new.
        fieldSep := '${FIELD_SEP}'.
        s nextPutAll: m numArgs printString; nextPutAll: fieldSep.
        s nextPutAll: m numTemps printString; nextPutAll: fieldSep.
        s nextPutAll: (m messages asSortedCollection asArray) printString; nextPutAll: fieldSep.
        s nextPutAll: m literals printString.
        s contents]`;
}

function makeGetMethodFingerprintTool(
  bridge: BridgeClientLike
): ToolDef<typeof fingerprintSchema> {
  return {
    name: 'vw_get_method_fingerprint',
    description:
      'Behavioral fingerprint of a method (sources stripped in this image, so this surfaces structure instead of text). ' +
      'Returns JSON {numArgs, numTemps, messages, literals}. ' +
      'Use to reason about what a method DOES via the selectors it sends and the literals it references.',
    inputSchema: fingerprintSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_get_method_fingerprint: invalid className "${input.className}".`);
      }
      if (!isValidSelector(input.selector)) {
        return errorResult(`vw_get_method_fingerprint: invalid selector "${input.selector}".`);
      }
      const evalResult = await bridge.postEval(
        buildFingerprintProbe(input.className, input.selector, input.isMeta ?? false)
      );
      if (!evalResult.ok) {
        return errorResult(
          `vw_get_method_fingerprint: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'ABSENT') {
        return errorResult(
          `vw_get_method_fingerprint: ${input.className}${input.isMeta ? ' class' : ''}>>${input.selector} does not exist.`
        );
      }
      const parts = raw.split(FIELD_SEP);
      return {
        content: [
          text(
            JSON.stringify({
              className: input.className,
              selector: input.selector,
              isMeta: input.isMeta ?? false,
              numArgs: Number.parseInt(parts[0] ?? '0', 10),
              numTemps: Number.parseInt(parts[1] ?? '0', 10),
              messages: parts[2] ?? '()',
              literals: parts[3] ?? '()',
            })
          ),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_get_class_hierarchy
// -----------------------------------------------------------------------------

const hierarchySchema = {
  className: z.string().min(1).max(200),
};

function buildHierarchyProbe(className: string): string {
  return `| cls s sep cur subs |
cls := ${className}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
"Superclass chain (root → cls)."
s nextPutAll: 'CHAIN'; nextPutAll: '${FIELD_SEP}'.
cur := cls.
[cur notNil] whileTrue: [
    s nextPutAll: cur name asString.
    cur := cur superclass.
    cur notNil ifTrue: [s nextPutAll: ',']].
s nextPutAll: sep.
"Direct subclasses (cls > immediate kids)."
s nextPutAll: 'KIDS'; nextPutAll: '${FIELD_SEP}'.
subs := cls subclasses asSortedCollection: [:a :b | a name <= b name].
subs do: [:c | s nextPutAll: c name asString. s nextPutAll: ','].
s contents`;
}

function makeGetClassHierarchyTool(
  bridge: BridgeClientLike
): ToolDef<typeof hierarchySchema> {
  return {
    name: 'vw_get_class_hierarchy',
    description:
      'Walk a class hierarchy: returns JSON {chain, directSubclasses}. ' +
      'chain = superclass chain root→cls (Object first). directSubclasses = immediate kids of cls (NOT recursive). ' +
      'For deep subclass discovery, walk via repeated calls.',
    inputSchema: hierarchySchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_get_class_hierarchy: invalid className "${input.className}".`);
      }
      const evalResult = await bridge.postEval(buildHierarchyProbe(input.className));
      if (!evalResult.ok) {
        return errorResult(
          `vw_get_class_hierarchy: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const result: { className: string; chain: string[]; directSubclasses: string[] } = {
        className: input.className,
        chain: [],
        directSubclasses: [],
      };
      for (const record of splitOn(raw, RECORD_SEP)) {
        const [tag, payload] = record.split(FIELD_SEP);
        const items = (payload ?? '').split(',').filter((s) => s.length > 0);
        if (tag === 'CHAIN') result.chain = items.reverse(); // root → cls
        else if (tag === 'KIDS') result.directSubclasses = items;
      }
      return { content: [text(JSON.stringify(result))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_export_class
// -----------------------------------------------------------------------------

function buildExportClassProbe(className: string): string {
  return `| cls s sep fieldSep |
cls := ${className}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
fieldSep := '${FIELD_SEP}'.
s nextPutAll: 'DEF'; nextPutAll: fieldSep; nextPutAll: cls definition; nextPutAll: sep.
s nextPutAll: 'CMT'; nextPutAll: fieldSep; nextPutAll: (cls comment ifNil: ['']); nextPutAll: sep.
"Each method: TAG|side|category|selector|numArgs|numMessages"
cls selectors asSortedCollection do: [:sel | | m |
    m := cls compiledMethodAt: sel ifAbsent: [nil].
    m notNil ifTrue: [
        s nextPutAll: 'IM'; nextPutAll: fieldSep.
        s nextPutAll: (cls organization categoryOfElement: sel) asString.
        s nextPutAll: fieldSep.
        s nextPutAll: sel asString; nextPutAll: fieldSep.
        s nextPutAll: m numArgs printString; nextPutAll: fieldSep.
        s nextPutAll: m messages size printString; nextPutAll: sep]].
cls class selectors asSortedCollection do: [:sel | | m |
    m := cls class compiledMethodAt: sel ifAbsent: [nil].
    m notNil ifTrue: [
        s nextPutAll: 'CM'; nextPutAll: fieldSep.
        s nextPutAll: (cls class organization categoryOfElement: sel) asString.
        s nextPutAll: fieldSep.
        s nextPutAll: sel asString; nextPutAll: fieldSep.
        s nextPutAll: m numArgs printString; nextPutAll: fieldSep.
        s nextPutAll: m messages size printString; nextPutAll: sep]].
s contents`;
}

function makeExportClassTool(bridge: BridgeClientLike): ToolDef<typeof hierarchySchema> {
  return {
    name: 'vw_export_class',
    description:
      'Structural dump of a class — definition + comment + every method with category, selector, numArgs, message count. ' +
      'Sources are stripped so no method body text. Returns JSON {className, definition, comment, instanceMethods, classMethods} ' +
      'where each method has {category, selector, numArgs, numMessages}.',
    inputSchema: hierarchySchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_export_class: invalid className "${input.className}".`);
      }
      const evalResult = await bridge.postEval(buildExportClassProbe(input.className));
      if (!evalResult.ok) {
        return errorResult(
          `vw_export_class: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      interface MethodEntry {
        category: string;
        selector: string;
        numArgs: number;
        numMessages: number;
      }
      const out: {
        className: string;
        definition: string;
        comment: string;
        instanceMethods: MethodEntry[];
        classMethods: MethodEntry[];
      } = {
        className: input.className,
        definition: '',
        comment: '',
        instanceMethods: [],
        classMethods: [],
      };
      for (const record of splitOn(raw, RECORD_SEP)) {
        const parts = record.split(FIELD_SEP);
        const tag = parts[0];
        if (tag === 'DEF') {
          out.definition = parts.slice(1).join(FIELD_SEP);
        } else if (tag === 'CMT') {
          out.comment = parts.slice(1).join(FIELD_SEP);
        } else if ((tag === 'IM' || tag === 'CM') && parts.length >= 5) {
          const entry: MethodEntry = {
            category: parts[1] ?? '(uncategorized)',
            selector: parts[2] ?? '',
            numArgs: Number.parseInt(parts[3] ?? '0', 10),
            numMessages: Number.parseInt(parts[4] ?? '0', 10),
          };
          if (tag === 'IM') out.instanceMethods.push(entry);
          else out.classMethods.push(entry);
        }
      }
      return { content: [text(JSON.stringify(out))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_search_method_messages
// -----------------------------------------------------------------------------

const searchSchema = {
  substring: z
    .string()
    .min(2)
    .max(100)
    .describe('Substring to find in selectors sent by methods. Min 2 chars (single-char would explode result count).'),
  scope: z.string().min(1).max(100).optional(),
};

const SEARCH_LIMIT = 500;

function buildSearchMessagesProbe(substring: string, scope?: string): string {
  // Embed substring as Smalltalk string literal — escape apostrophes.
  const literal = `'${substring.replaceAll("'", "''")}'`;
  const scopeExpr = scope
    ? `(Smalltalk at: #${scope} ifAbsent: [^'NS_ABSENT']) classes`
    : `Smalltalk allClasses`;
  return `| hits limit s sep needle scope |
hits := OrderedCollection new.
limit := ${SEARCH_LIMIT}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
needle := ${literal}.
scope := ${scopeExpr}.
scope do: [:cls |
    hits size >= limit ifFalse: [
        cls selectors do: [:sel |
            hits size >= limit ifFalse: [
                (cls compiledMethodAt: sel ifAbsent: [nil]) ifNotNil: [:m |
                    (m messages anySatisfy: [:msel | (msel asString indexOfSubCollection: needle startingAt: 1) > 0])
                        ifTrue: [hits add: cls name asString , '>>' , sel asString]]]]]].
hits do: [:e | s nextPutAll: e; nextPutAll: sep].
s contents`;
}

function makeSearchMethodMessagesTool(
  bridge: BridgeClientLike
): ToolDef<typeof searchSchema> {
  return {
    name: 'vw_search_method_messages',
    description:
      `Find every "Class>>selector" pair whose method SENDS any selector containing the given substring. ` +
      `Walks compiledMethod #messages set. Cap ${SEARCH_LIMIT}. Min substring 2 chars. ` +
      `(Sources stripped in this image so we can't text-search bodies — this is the closest approximation.)`,
    inputSchema: searchSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.scope !== undefined && !isValidNamespaceIdentifier(input.scope)) {
        return errorResult(`vw_search_method_messages: invalid scope "${input.scope}".`);
      }
      const evalResult = await bridge.postEval(buildSearchMessagesProbe(input.substring, input.scope));
      if (!evalResult.ok) {
        return errorResult(
          `vw_search_method_messages: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'NS_ABSENT') {
        return errorResult(`vw_search_method_messages: scope "${input.scope}" does not exist.`);
      }
      const hits = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(hits))] };
    }),
  };
}
