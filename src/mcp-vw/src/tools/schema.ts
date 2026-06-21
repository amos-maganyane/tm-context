/**
 * schema.ts — vw_list_namespaces + vw_list_namespace_entries (MVP).
 *
 * Browse the VW image's namespace tree. Cheap reads via /eval.
 *
 * Per architecture.md §5.1 (tools 5 + 6) — wrappers around `Smalltalk allNameSpaces`
 * and per-namespace key enumeration.
 *
 * **Carry-forward #43**: the bridge collapses whitespace (LF/CR/TAB → space)
 * in its JSON response, so probes use `;` (RECORD_SEP) as the record separator.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  isValidNamespaceIdentifier,
  RECORD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeSchemaTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeListNamespacesTool(bridge),
    makeListNamespaceEntriesTool(bridge),
    makeListNamespaceClassesTool(bridge),
    makeListAllClassesTool(bridge),
    makeListTestClassesTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// vw_list_namespaces
// -----------------------------------------------------------------------------

const LIST_NAMESPACES_PROBE = `| s sep |
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
(Smalltalk allNameSpaces asSortedCollection: [:a :b | a name <= b name])
    do: [:ns | s nextPutAll: ns name asString; nextPutAll: sep].
s contents`;

function makeListNamespacesTool(bridge: BridgeClientLike): ToolDef {
  return {
    name: 'vw_list_namespaces',
    description:
      'List every namespace in the VW image (sorted, ~312 entries on storedev64). ' +
      'Returns a JSON string array. Use to discover where a class lives before calling vw_list_namespace_entries or vw_get_class_definition.',
    inputSchema: {},
    handler: safeHandler(async (): Promise<ToolResult> => {
      const evalResult = await bridge.postEval(LIST_NAMESPACES_PROBE);
      if (!evalResult.ok) {
        return errorResult(`vw_list_namespaces: VW eval failed: ${evalResult.error ?? '(no error)'}`);
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const names = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(names))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_namespace_entries
// -----------------------------------------------------------------------------

const listEntriesInputSchema = {
  namespace: z
    .string()
    .min(1)
    .max(100)
    .describe(
      'Single-segment namespace identifier (e.g. "Tools", "UI", "Kernel"). ' +
        'Dotted names are NOT supported — namespaces are flat in this image. Discover names via vw_list_namespaces.'
    ),
};

function buildListNamespaceEntriesProbe(namespace: string): string {
  // namespace already validated against /^[A-Z][A-Za-z0-9_]*$/ — safe to embed.
  return `| ns s sep |
ns := Smalltalk at: #${namespace} ifAbsent: [nil].
ns isNil
    ifTrue: ['ABSENT']
    ifFalse: [
        s := WriteStream on: String new.
        sep := '${RECORD_SEP}'.
        ns keys asArray asSortedCollection do: [:k | s nextPutAll: k asString; nextPutAll: sep].
        s contents]`;
}

function makeListNamespaceEntriesTool(bridge: BridgeClientLike): ToolDef<typeof listEntriesInputSchema> {
  return {
    name: 'vw_list_namespace_entries',
    description:
      'List every binding (class + global) in a single namespace, sorted alphabetically. ' +
      'Returns JSON string array. Example: namespace="Tools" returns ~272 keys including "UIPainter". ' +
      'Use after vw_list_namespaces to drill into a specific namespace before calling vw_get_class_definition.',
    inputSchema: listEntriesInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidNamespaceIdentifier(input.namespace)) {
        return errorResult(
          `vw_list_namespace_entries: invalid namespace identifier "${input.namespace}". ` +
            'Must match /^[A-Z][A-Za-z0-9_]*$/ — single-segment, uppercase-start, no dots. ' +
            'For nested-looking names like "Tools.Refactoring", use the leaf segment ("Refactoring") if it exists as a top-level namespace.'
        );
      }

      const evalResult = await bridge.postEval(buildListNamespaceEntriesProbe(input.namespace));
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_namespace_entries: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'ABSENT') {
        return errorResult(
          `vw_list_namespace_entries: namespace "${input.namespace}" does not exist in this image. ` +
            'List available namespaces via vw_list_namespaces.'
        );
      }

      const entries = splitOn(raw, RECORD_SEP);
      return { content: [text(JSON.stringify(entries))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_namespace_classes (V3) — filtered: only class objects in a namespace
// -----------------------------------------------------------------------------

function buildListNamespaceClassesProbe(namespace: string): string {
  return `| ns s sep |
ns := Smalltalk at: #${namespace} ifAbsent: [nil].
ns isNil
    ifTrue: ['ABSENT']
    ifFalse: [
        s := WriteStream on: String new.
        sep := '${RECORD_SEP}'.
        (ns keys asArray asSortedCollection) do: [:k | | val |
            val := ns at: k ifAbsent: [nil].
            (val isKindOf: Behavior) ifTrue: [
                s nextPutAll: k asString; nextPutAll: sep]].
        s contents]`;
}

function makeListNamespaceClassesTool(
  bridge: BridgeClientLike
): ToolDef<typeof listEntriesInputSchema> {
  return {
    name: 'vw_list_namespace_classes',
    description:
      'List ONLY the class bindings (Behavior instances) in a namespace, filtering out shared variables + pool dictionaries + globals. ' +
      'Returns JSON string array. Use when vw_list_namespace_entries returns too much noise.',
    inputSchema: listEntriesInputSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidNamespaceIdentifier(input.namespace)) {
        return errorResult(
          `vw_list_namespace_classes: invalid namespace identifier "${input.namespace}".`
        );
      }

      const evalResult = await bridge.postEval(buildListNamespaceClassesProbe(input.namespace));
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_namespace_classes: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }

      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'ABSENT') {
        return errorResult(
          `vw_list_namespace_classes: namespace "${input.namespace}" does not exist.`
        );
      }
      return { content: [text(JSON.stringify(splitOn(raw, RECORD_SEP)))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_all_classes (V3) — bulk enumeration across all namespaces
// -----------------------------------------------------------------------------

const listAllClassesSchema = {
  maxResults: z
    .number()
    .int()
    .positive()
    .max(20_000)
    .optional()
    .describe('Optional cap. Default 5000. Image has 17,000+ classes; raise carefully.'),
};

const DEFAULT_MAX_ALL_CLASSES = 5_000;

function buildListAllClassesProbe(maxResults: number): string {
  return `| s sep limit count |
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
limit := ${maxResults}.
count := 0.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray asSortedCollection) do: [:k |
        count < limit ifTrue: [
            ((ns at: k ifAbsent: [nil]) isKindOf: Behavior) ifTrue: [
                s nextPutAll: ns name asString; nextPutAll: '.'.
                s nextPutAll: k asString; nextPutAll: sep.
                count := count + 1]]]].
s contents`;
}

function makeListAllClassesTool(bridge: BridgeClientLike): ToolDef<typeof listAllClassesSchema> {
  return {
    name: 'vw_list_all_classes',
    description:
      `Bulk enumerate every class across all namespaces as "Namespace.ClassName". Default cap ${DEFAULT_MAX_ALL_CLASSES}; raise via maxResults. ` +
      'Use for broad discovery; for a specific namespace use vw_list_namespace_classes.',
    inputSchema: listAllClassesSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      const max = input.maxResults ?? DEFAULT_MAX_ALL_CLASSES;
      const evalResult = await bridge.postEval(buildListAllClassesProbe(max));
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_all_classes: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      return { content: [text(JSON.stringify(splitOn(raw, RECORD_SEP)))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_test_classes (V3) — discover TestCase subclasses
// -----------------------------------------------------------------------------

const listTestClassesSchema = {
  scope: z
    .string()
    .min(1)
    .max(100)
    .optional()
    .describe('Optional namespace name to filter the result. Omit for image-wide.'),
};

function buildListTestClassesProbe(scope?: string): string {
  const filterExpr = scope
    ? `((ns name asString = '${scope}') and: [(c name asString endsWith: 'Test') or: [c name asString endsWith: 'Tests']])`
    : `((c name asString endsWith: 'Test') or: [c name asString endsWith: 'Tests'])`;
  return `| s sep tcClass scope |
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
tcClass := Smalltalk at: #TestCase ifAbsent: [^'NO_TESTCASE'].
"Walk allSubclasses safely (avoids MAS testClasses walk)."
scope := tcClass allSubclasses.
scope do: [:c | | ns |
    ns := c environment.
    ${filterExpr}
        ifTrue: [
            s nextPutAll: ns name asString; nextPutAll: '.'.
            s nextPutAll: c name asString; nextPutAll: sep]].
s contents`;
}

function makeListTestClassesTool(bridge: BridgeClientLike): ToolDef<typeof listTestClassesSchema> {
  return {
    name: 'vw_list_test_classes',
    description:
      'Discover all TestCase subclasses whose name ends with "Test" or "Tests" (the naming convention). ' +
      'Returns JSON array of "Namespace.ClassName". Optional scope filter by namespace. ' +
      'Uses TestCase allSubclasses (NOT cls suite which walks MAS-customized testClasses and wedges).',
    inputSchema: listTestClassesSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (input.scope !== undefined && !isValidNamespaceIdentifier(input.scope)) {
        return errorResult(`vw_list_test_classes: invalid scope namespace "${input.scope}".`);
      }
      const evalResult = await bridge.postEval(buildListTestClassesProbe(input.scope));
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_test_classes: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      if (raw === 'NO_TESTCASE') {
        return errorResult('vw_list_test_classes: TestCase class not found in image.');
      }
      return { content: [text(JSON.stringify(splitOn(raw, RECORD_SEP)))] };
    }),
  };
}
