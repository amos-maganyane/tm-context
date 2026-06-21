/**
 * navigation.ts — vw_find_senders (MVP).
 *
 * Walks the image's class graph emitting "Class>>selector" for every method
 * whose CompiledMethod's `messages` set includes the target selector.
 *
 * Capped at 500 hits to bound /eval response size. Optional `scope` arg
 * narrows the search to a single namespace (e.g. "Tools") for speed.
 *
 * Per architecture.md §5.1 (tool 9) + carry-forward #14 (`Behavior` has 12826
 * subclasses; an unbounded walk is realistic in this MAS image but slow).
 *
 * Records separated by `;` per carry-forward #43 (bridge collapses LF/CR/TAB).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  isValidSelector,
  isValidNamespaceIdentifier,
  quoteSmalltalkString,
  RECORD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeNavigationTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeFindSendersTool(bridge),
    makeFindImplementorsTool(bridge),
    makeFindReferencesToTool(bridge),
  ];
}

const findSendersInputSchema = {
  selector: z
    .string()
    .min(1)
    .max(200)
    .describe(
      'The selector to search for. Unary ("printOn"), binary ("+", "=="), or keyword ("at:put:").'
    ),
  scope: z
    .string()
    .min(1)
    .max(100)
    .optional()
    .describe(
      'Optional namespace identifier to narrow the search (e.g. "Tools", "UI"). ' +
        'Omit for image-wide search. Image-wide can take 5-30s on the MAS image (12826 classes).'
    ),
};

const SENDERS_LIMIT = 500;

function buildFindSendersProbe(selector: string, scope?: string): string {
  // selector + scope already validated.
  const targetSymbol = `#${selector}`;
  const scopeExpr = scope ? `(Smalltalk at: #${scope} ifAbsent: [^'NS_ABSENT']) classes` : `Smalltalk allClasses`;

  return `| senders limit s sep scope |
senders := OrderedCollection new.
limit := ${SENDERS_LIMIT}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
scope := ${scopeExpr}.
scope do: [:cls |
    senders size >= limit ifFalse: [
        cls selectors do: [:sel |
            senders size >= limit ifFalse: [
                (cls compiledMethodAt: sel ifAbsent: [nil]) ifNotNil: [:m |
                    (m messages includes: ${targetSymbol})
                        ifTrue: [senders add: cls name asString , '>>' , sel asString]]]].
        cls class selectors do: [:sel |
            senders size >= limit ifFalse: [
                (cls class compiledMethodAt: sel ifAbsent: [nil]) ifNotNil: [:m |
                    (m messages includes: ${targetSymbol})
                        ifTrue: [senders add: cls name asString , ' class>>' , sel asString]]]]]].
senders do: [:e | s nextPutAll: e; nextPutAll: sep].
s contents`;
}

function makeFindSendersTool(bridge: BridgeClientLike): ToolDef<typeof findSendersInputSchema> {
  return {
    name: 'vw_find_senders',
    description:
      `Find every "Class>>selector" pair that SENDS a given selector. Walks the class graph, scans each compiledMethod's #messages set. ` +
      `Capped at ${SENDERS_LIMIT} hits. Optional "scope" arg (namespace name) narrows the search; omit for image-wide. ` +
      `Note: image-wide search can take 5-30s in this MAS image (12826 classes). Use scope when the senders are known to live in one namespace.`,
    inputSchema: findSendersInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidSelector(input.selector)) {
        return errorResult(
          `vw_find_senders: invalid selector "${input.selector}". ` +
            'Must be unary (`foo`), binary (`+`, `==`), or keyword (`at:put:`). ' +
            'Special chars rejected to prevent Smalltalk injection.'
        );
      }

      if (input.scope !== undefined && !isValidNamespaceIdentifier(input.scope)) {
        return errorResult(
          `vw_find_senders: invalid scope namespace "${input.scope}". ` +
            'Must match /^[A-Z][A-Za-z0-9_]*$/. Discover valid names via vw_list_namespaces.'
        );
      }

      const probe = buildFindSendersProbe(input.selector, input.scope);
      const evalResult = await bridge.postEval(probe);

      if (!evalResult.ok) {
        return errorResult(
          `vw_find_senders: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'NS_ABSENT') {
        return errorResult(
          `vw_find_senders: scope namespace "${input.scope}" does not exist. ` +
            'List available namespaces via vw_list_namespaces.'
        );
      }

      const senders = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(senders))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_find_implementors (V2) — find every "Class>>selector" that DEFINES the selector
// -----------------------------------------------------------------------------

const IMPLEMENTORS_LIMIT = 500;

function buildFindImplementorsProbe(selector: string, scope?: string): string {
  const targetSymbol = `#${selector}`;
  const scopeExpr = scope
    ? `(Smalltalk at: #${scope} ifAbsent: [^'NS_ABSENT']) classes`
    : `Smalltalk allClasses`;
  return `| hits limit s sep scope |
hits := OrderedCollection new.
limit := ${IMPLEMENTORS_LIMIT}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
scope := ${scopeExpr}.
scope do: [:cls |
    hits size >= limit ifFalse: [
        (cls includesSelector: ${targetSymbol})
            ifTrue: [hits add: cls name asString , '>>' , ${quoteSmalltalkString(selector)}].
        (cls class includesSelector: ${targetSymbol})
            ifTrue: [hits add: cls name asString , ' class>>' , ${quoteSmalltalkString(selector)}]]].
hits do: [:e | s nextPutAll: e; nextPutAll: sep].
s contents`;
}

function makeFindImplementorsTool(bridge: BridgeClientLike): ToolDef<typeof findSendersInputSchema> {
  return {
    name: 'vw_find_implementors',
    description:
      `Find every "Class>>selector" pair that DEFINES (implements) a given selector. ` +
      `Capped at ${IMPLEMENTORS_LIMIT}. Optional "scope" (namespace name) narrows the search; omit for image-wide. ` +
      `Use to discover all places where a method is defined (vs vw_find_senders for places that CALL it).`,
    inputSchema: findSendersInputSchema, // same shape as senders
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidSelector(input.selector)) {
        return errorResult(`vw_find_implementors: invalid selector "${input.selector}".`);
      }
      if (input.scope !== undefined && !isValidNamespaceIdentifier(input.scope)) {
        return errorResult(`vw_find_implementors: invalid scope namespace "${input.scope}".`);
      }

      const probe = buildFindImplementorsProbe(input.selector, input.scope);
      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(`vw_find_implementors: VW eval failed: ${evalResult.error ?? '(no error)'}`);
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'NS_ABSENT') {
        return errorResult(
          `vw_find_implementors: scope namespace "${input.scope}" does not exist.`
        );
      }
      const hits = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(hits))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_find_references_to (V2) — find every "Class>>selector" referencing a named global
// -----------------------------------------------------------------------------

const REFERENCES_LIMIT = 500;
const findReferencesInputSchema = {
  globalName: z
    .string()
    .min(1)
    .max(200)
    .describe('Global identifier to find references to (class name, namespace name, shared variable, pool dictionary).'),
  scope: z
    .string()
    .min(1)
    .max(100)
    .optional()
    .describe('Optional namespace identifier to narrow the search.'),
};

function buildFindReferencesToProbe(globalName: string, scope?: string): string {
  const scopeExpr = scope
    ? `(Smalltalk at: #${scope} ifAbsent: [^'NS_ABSENT']) classes`
    : `Smalltalk allClasses`;
  return `| hits limit s sep scope target |
hits := OrderedCollection new.
limit := ${REFERENCES_LIMIT}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
target := #${globalName}.
scope := ${scopeExpr}.
scope do: [:cls |
    hits size >= limit ifFalse: [
        cls selectors do: [:sel |
            hits size >= limit ifFalse: [
                (cls compiledMethodAt: sel ifAbsent: [nil]) ifNotNil: [:m |
                    (m literals includes: target)
                        ifTrue: [hits add: cls name asString , '>>' , sel asString]]]].
        cls class selectors do: [:sel |
            hits size >= limit ifFalse: [
                (cls class compiledMethodAt: sel ifAbsent: [nil]) ifNotNil: [:m |
                    (m literals includes: target)
                        ifTrue: [hits add: cls name asString , ' class>>' , sel asString]]]]]].
hits do: [:e | s nextPutAll: e; nextPutAll: sep].
s contents`;
}

function makeFindReferencesToTool(bridge: BridgeClientLike): ToolDef<typeof findReferencesInputSchema> {
  return {
    name: 'vw_find_references_to',
    description:
      `Find every "Class>>selector" pair that REFERENCES a given global (class name, namespace, shared variable, pool dictionary). ` +
      `Walks compiledMethod #literals for the target symbol. Capped at ${REFERENCES_LIMIT}. Optional scope narrows.`,
    inputSchema: findReferencesInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!/^[A-Z][A-Za-z0-9_]*$/.test(input.globalName)) {
        return errorResult(
          `vw_find_references_to: invalid globalName "${input.globalName}". Must match /^[A-Z][A-Za-z0-9_]*$/ (single-segment, uppercase-start).`
        );
      }
      if (input.scope !== undefined && !isValidNamespaceIdentifier(input.scope)) {
        return errorResult(`vw_find_references_to: invalid scope namespace "${input.scope}".`);
      }

      const probe = buildFindReferencesToProbe(input.globalName, input.scope);
      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(`vw_find_references_to: VW eval failed: ${evalResult.error ?? '(no error)'}`);
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'NS_ABSENT') {
        return errorResult(`vw_find_references_to: scope namespace "${input.scope}" does not exist.`);
      }
      const hits = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(hits))] };
    }),
  };
}
