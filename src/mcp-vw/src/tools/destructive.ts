/**
 * destructive.ts — V3 destructive/mutating ops with strict #41 + VWB.* guards.
 *
 *   - vw_compile_class_definition: full class definition compile (re-shape).
 *   - vw_delete_method: remove a method from a class.
 *   - vw_delete_class: remove a class entirely (use `cls removeFromSystem`).
 *   - vw_set_class_comment: set the class comment.
 *
 * All four refuse targets in the VWB namespace per carry-forward #41. The
 * delete tools surface "destructive" prominently in their description.
 *
 * Per architecture.md §5.3 (tools 44, 45, 46, 47).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidSelector,
  quoteSmalltalkString,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeDestructiveTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeCompileClassDefinitionTool(bridge),
    makeDeleteMethodTool(bridge),
    makeDeleteClassTool(bridge),
    makeSetClassCommentTool(bridge),
  ];
}

function refusesVWB(className: string): boolean {
  return className === 'VWB' || className.startsWith('VWB.');
}

// -----------------------------------------------------------------------------
// vw_compile_class_definition
// -----------------------------------------------------------------------------

const compileClassDefSchema = {
  source: z
    .string()
    .min(1)
    .max(200_000)
    .describe(
      'Full class definition source. Example: "Object subclass: #Foo instanceVariableNames: \'a b\' classVariableNames: \'\' poolDictionaries: \'\' inDictionary: \'MyApp\' category: \'foo\'"'
    ),
};

function makeCompileClassDefinitionTool(
  bridge: BridgeClientLike
): ToolDef<typeof compileClassDefSchema> {
  return {
    name: 'vw_compile_class_definition',
    description:
      'Compile a raw class definition (Smalltalk source). Use when you need full control over the class shape (e.g. re-shaping instance variables). ' +
      'For typed class creation prefer vw_create_class which builds the source for you. ' +
      'REFUSED if the source targets the VWB namespace (#41 — would wedge the bridge).',
    inputSchema: compileClassDefSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // Quick safety check: scan for VWB targeting + Bug #5 substrings.
      if (/(?:^|[^.\w])VWB\.\w+/.test(input.source) || /#VWB[A-Z]\w*/.test(input.source)) {
        return errorResult(
          `vw_compile_class_definition refuses sources that target VWB.* (carry-forward #41 — would wedge the bridge).`
        );
      }
      if (input.source.includes('VWBridge') && input.source.includes('dispatch')) {
        return errorResult(
          `vw_compile_class_definition refuses sources containing both 'VWBridge' and 'dispatch' substrings (Bug #5).`
        );
      }

      const evalResult = await bridge.postEval(input.source);
      if (!evalResult.ok) {
        return errorResult(
          `vw_compile_class_definition: VW eval failed: ${evalResult.error ?? '(no error)'}\n\nEmitted:\n${input.source}`
        );
      }
      return { content: [text(`Compiled class definition. Result: ${evalResult.result ?? '(no result)'}`)] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_delete_method
// -----------------------------------------------------------------------------

const deleteMethodSchema = {
  className: z.string().min(1).max(200),
  selector: z.string().min(1).max(200),
  isMeta: z.boolean().optional().describe('true = class-side. Default false.'),
};

function makeDeleteMethodTool(bridge: BridgeClientLike): ToolDef<typeof deleteMethodSchema> {
  return {
    name: 'vw_delete_method',
    description:
      'DESTRUCTIVE: remove a method from a class via `Cls removeSelector: #sel`. ' +
      'Refuses VWB.* targets (#41). Method removal is naturally defensive (no error if selector absent — see carry-forward #31). ' +
      'Use vw_find_senders FIRST to confirm nothing still calls the method before deleting.',
    inputSchema: deleteMethodSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_delete_method: invalid className "${input.className}".`);
      }
      if (refusesVWB(input.className)) {
        return errorResult(
          `vw_delete_method refuses VWB.* targets (carry-forward #41).`
        );
      }
      if (!isValidSelector(input.selector)) {
        return errorResult(`vw_delete_method: invalid selector "${input.selector}".`);
      }

      const receiver = input.isMeta === true ? `${input.className} class` : input.className;
      const probe = `${receiver} removeSelector: #${input.selector}`;
      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(
          `vw_delete_method: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      return {
        content: [
          text(`Removed ${input.className}${input.isMeta ? ' class' : ''}>>${input.selector}.`),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_delete_class (DESTRUCTIVE — extra guard)
// -----------------------------------------------------------------------------

const deleteClassSchema = {
  className: z.string().min(1).max(200),
  confirm: z
    .literal(true)
    .describe('Must pass `true` to confirm class deletion. Defensive guard against accidental drops.'),
};

function makeDeleteClassTool(bridge: BridgeClientLike): ToolDef<typeof deleteClassSchema> {
  return {
    name: 'vw_delete_class',
    description:
      'DESTRUCTIVE: remove a class entirely via `Cls removeFromSystem`. ' +
      'REFUSED for VWB.* (carry-forward #41) AND requires `confirm: true` to fire (defensive — no accidental drops). ' +
      'Use vw_find_senders + vw_find_implementors FIRST to verify nothing references the class. ' +
      'Subclasses, references, and methods all break if this class disappears.',
    inputSchema: deleteClassSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_delete_class: invalid className "${input.className}".`);
      }
      if (refusesVWB(input.className)) {
        return errorResult(`vw_delete_class refuses VWB.* targets (#41).`);
      }
      if (input.confirm !== true) {
        return errorResult(`vw_delete_class: confirm must be true to actually delete.`);
      }

      const probe = `${input.className} removeFromSystem`;
      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(
          `vw_delete_class: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      return { content: [text(`Removed class ${input.className} from system.`)] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_set_class_comment
// -----------------------------------------------------------------------------

const setCommentSchema = {
  className: z.string().min(1).max(200),
  comment: z.string().max(20_000).describe('New class comment text. Apostrophes auto-escaped.'),
};

function makeSetClassCommentTool(bridge: BridgeClientLike): ToolDef<typeof setCommentSchema> {
  return {
    name: 'vw_set_class_comment',
    description:
      'Set the class comment. Comment is a human-readable description of what the class is for. ' +
      'Apostrophes auto-escaped. Refuses VWB.* (#41).',
    inputSchema: setCommentSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_set_class_comment: invalid className "${input.className}".`);
      }
      if (refusesVWB(input.className)) {
        return errorResult(`vw_set_class_comment refuses VWB.* targets (#41).`);
      }

      const probe = `${input.className} comment: ${quoteSmalltalkString(input.comment)}`;
      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(
          `vw_set_class_comment: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      return { content: [text(`Set comment on ${input.className} (${input.comment.length} chars).`)] };
    }),
  };
}
