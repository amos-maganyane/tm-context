/**
 * codegen/applicationModel.ts — vw_create_application_model.
 *
 * The HEAVYWEIGHT NATIVE-TYPED scaffolder. AI passes one JSON describing
 * the entire ApplicationModel (class + ivs + aspect accessors + action
 * methods + windowSpec + optional lifecycle hooks); this tool emits + compiles
 * everything in sequence, with detailed per-step error reporting.
 *
 * Pieces emitted (in order):
 *
 *   1. Class definition (with instanceVariableNames = aspect names)
 *   2. N lazy aspect accessors (one per aspect)
 *   3. N action methods
 *   4. K hook overrides (postBuildWith:, postOpenWith:, etc.)
 *   5. Class-side windowSpec (the canonical literal-array form)
 *
 * Per architecture.md §5.2 (tool 19) + §6.2.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidNamespaceIdentifier,
  isValidSelector,
  quoteSmalltalkString,
} from '../smalltalk.js';
import type { ToolDef } from '../tools/types.js';

import { emitCreateClassSmalltalk } from './class.js';
import { emitLazyAspectAccessor, emitActionMethod } from './methods.js';
import { emitWindowSpecMethod, type Component, type WindowProps } from './windowSpec.js';

// -----------------------------------------------------------------------------
// Input schema
// -----------------------------------------------------------------------------

const layoutSchema = z.object({
  l: z.number(),
  lf: z.number(),
  t: z.number(),
  tf: z.number(),
  r: z.number(),
  rf: z.number(),
  b: z.number(),
  bf: z.number(),
});

const aspectSchema = z.object({
  name: z.string().min(1).max(200),
  defaultExpression: z.string().min(1).max(2_000).optional(),
});

const actionSchema = z.object({
  name: z.string().min(1).max(200),
  body: z.string().min(1).max(100_000),
});

const windowSchema = z.object({
  label: z.string(),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
  min: z.tuple([z.number(), z.number()]).optional(),
  max: z.tuple([z.number(), z.number()]).optional(),
  sizeType: z.enum(['specifiedSize', 'fixedSize', 'maxScreenSize']).optional(),
  positionType: z.enum(['screenCenter', 'mouseCenter']).optional(),
  openType: z.enum(['advanced', 'simple']).optional(),
  hasMenuBar: z.boolean().optional(),
});

const componentSchema = z.object({
  type: z.enum([
    'Label',
    'ActionButton',
    'InputField',
    'CheckBox',
    'RadioButton',
    'ComboBox',
    'SequenceView',
    'TableView',
    'TreeView',
    'TextEditor',
    'GroupBox',
    'Divider',
    'SubCanvas',
  ]),
  name: z.string().optional(),
  label: z.string().optional(),
  model: z.string().optional(),
  layout: layoutSchema,
  isDefault: z.boolean().optional(),
  defaultable: z.boolean().optional(),
  numChars: z.number().optional(),
  inputType: z.enum(['string', 'number', 'date']).optional(),
  select: z.union([z.string(), z.number(), z.boolean()]).optional(),
}).passthrough();

const windowSpecPayloadSchema = z.object({
  selector: z.string().min(1).max(200).optional(),
  window: windowSchema,
  components: z.array(componentSchema),
});

const createAppModelSchema = {
  className: z.string().min(1).max(200),
  namespace: z.string().min(1).max(100),
  superclass: z
    .string()
    .min(1)
    .max(200)
    .describe('Typically "ApplicationModel" or a subclass (e.g. "Tools.UIPainter"). Refused for VWB.*.'),
  category: z.string().max(200).optional(),
  aspects: z.array(aspectSchema).optional(),
  actions: z.array(actionSchema).optional(),
  hooks: z
    .record(z.string().min(1), z.string().min(1).max(100_000))
    .optional()
    .describe('Map of hook selector → body. Common selectors: "postBuildWith:", "postOpenWith:", "preBuildWith:".'),
  windowSpec: windowSpecPayloadSchema.optional(),
};

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

const VALID_IVAR_RE = /^[a-z_][A-Za-z0-9_]*$/;

function buildInstanceCompileExpression(
  className: string,
  isMeta: boolean,
  category: string,
  methodSource: string
): string {
  const receiver = isMeta ? `${className} class` : className;
  return `${receiver} compile: ${quoteSmalltalkString(methodSource)} classified: ${quoteSmalltalkString(category)}`;
}

interface CompileStep {
  label: string;
  source: string;
}

// -----------------------------------------------------------------------------
// Tool factory
// -----------------------------------------------------------------------------

const TOOL_DESCRIPTION =
  'NATIVE-TYPED heavyweight scaffolder for ApplicationModel subclasses. ' +
  'AI passes ONE JSON describing the whole app (class + namespace + aspects + actions + hooks + windowSpec); ' +
  'tool compiles 5+ pieces in sequence: class definition (with instance variables from aspect names) → N lazy aspect accessors → N action methods → K lifecycle hooks → class-side windowSpec. ' +
  'Detailed per-step error reporting. Refuses VWB.* targets (#41). ' +
  'For single-method additions to an existing class use vw_compile_method / vw_define_aspect / vw_define_action.';

export function makeCreateApplicationModelTool(
  bridge: BridgeClientLike
): ToolDef<typeof createAppModelSchema> {
  return {
    name: 'vw_create_application_model',
    description: TOOL_DESCRIPTION,
    inputSchema: createAppModelSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // -------------------------------------------------------------------
      // Identifier validation
      // -------------------------------------------------------------------
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_create_application_model: invalid className "${input.className}".`
        );
      }
      if (!isValidNamespaceIdentifier(input.namespace)) {
        return errorResult(
          `vw_create_application_model: invalid namespace "${input.namespace}".`
        );
      }
      if (!isValidClassIdentifier(input.superclass)) {
        return errorResult(
          `vw_create_application_model: invalid superclass "${input.superclass}".`
        );
      }

      if (
        input.namespace === 'VWB' ||
        input.className.startsWith('VWB.') ||
        input.superclass.startsWith('VWB.')
      ) {
        return errorResult(
          `vw_create_application_model refuses targets in the VWB namespace (carry-forward #41).`
        );
      }

      const aspects = input.aspects ?? [];
      const actions = input.actions ?? [];
      const hooks = input.hooks ?? {};

      // Validate each aspect name + action name + hook selector.
      for (const a of aspects) {
        if (!VALID_IVAR_RE.test(a.name)) {
          return errorResult(
            `vw_create_application_model: invalid aspect name "${a.name}". Must match /^[a-z_][A-Za-z0-9_]*$/.`
          );
        }
      }
      for (const a of actions) {
        if (!isValidSelector(a.name)) {
          return errorResult(
            `vw_create_application_model: invalid action name "${a.name}".`
          );
        }
      }
      for (const sel of Object.keys(hooks)) {
        if (!isValidSelector(sel)) {
          return errorResult(
            `vw_create_application_model: invalid hook selector "${sel}".`
          );
        }
      }

      // -------------------------------------------------------------------
      // Build compile-step list
      // -------------------------------------------------------------------
      const steps: CompileStep[] = [];

      // 1. Class definition (with ivs)
      const classDefArgs: Parameters<typeof emitCreateClassSmalltalk>[0] = {
        className: input.className,
        namespace: input.namespace,
        superclass: input.superclass,
        instanceVariableNames: aspects.map((a) => a.name),
      };
      if (input.category !== undefined) classDefArgs.category = input.category;
      steps.push({
        label: 'class definition',
        source: emitCreateClassSmalltalk(classDefArgs),
      });

      // 2. N aspect accessors
      for (const a of aspects) {
        const accessorSrc = emitLazyAspectAccessor({
          aspectName: a.name,
          ...(a.defaultExpression !== undefined
            ? { defaultExpression: a.defaultExpression }
            : {}),
        });
        steps.push({
          label: `aspect ${a.name}`,
          source: buildInstanceCompileExpression(
            input.className,
            false,
            'aspects',
            accessorSrc
          ),
        });
      }

      // 3. N action methods
      for (const a of actions) {
        const actionSrc = emitActionMethod({ actionName: a.name, body: a.body });
        steps.push({
          label: `action ${a.name}`,
          source: buildInstanceCompileExpression(
            input.className,
            false,
            'actions',
            actionSrc
          ),
        });
      }

      // 4. K hook methods
      for (const [selector, body] of Object.entries(hooks)) {
        const hookSrc = emitActionMethod({ actionName: selector, body });
        steps.push({
          label: `hook ${selector}`,
          source: buildInstanceCompileExpression(
            input.className,
            false,
            'hooks',
            hookSrc
          ),
        });
      }

      // 5. Class-side windowSpec
      if (input.windowSpec !== undefined) {
        const windowSpecArgs: Parameters<typeof emitWindowSpecMethod>[0] = {
          window: input.windowSpec.window as WindowProps,
          components: input.windowSpec.components as Component[],
        };
        if (input.windowSpec.selector !== undefined) {
          windowSpecArgs.selector = input.windowSpec.selector;
        }
        const wsSrc = emitWindowSpecMethod(windowSpecArgs);
        const wsSelector = input.windowSpec.selector ?? 'windowSpec';
        steps.push({
          label: `windowSpec ${wsSelector}`,
          source: buildInstanceCompileExpression(
            input.className,
            true,
            'interface specs',
            wsSrc
          ),
        });
      }

      // -------------------------------------------------------------------
      // Execute step 1 (class def) — special case because it's not a compile:
      // expression but a `<Super> subclass: ...` expression.
      // -------------------------------------------------------------------
      const completed: string[] = [];
      const total = steps.length;

      // Step 0 (class def) — emit as raw class definition expression.
      const firstStep = steps[0];
      if (!firstStep) {
        return errorResult('vw_create_application_model: no compile steps to run (internal error).');
      }
      const firstResult = await bridge.postEval(firstStep.source);
      if (!firstResult.ok) {
        return errorResult(
          `vw_create_application_model: failed at step 1 of ${total} (${firstStep.label}): ${firstResult.error ?? '(no error)'}\n\nEmitted Smalltalk:\n${firstStep.source}`
        );
      }
      completed.push(firstStep.label);

      // Subsequent steps (compile:s).
      for (let i = 1; i < steps.length; i++) {
        const step = steps[i]!;
        const result = await bridge.postEval(step.source);
        if (!result.ok) {
          return errorResult(
            `vw_create_application_model: failed at step ${i + 1} of ${total} (${step.label}): ${result.error ?? '(no error)'}\n\n` +
              `Completed steps before failure: ${completed.join(', ')}\n\nEmitted Smalltalk:\n${step.source}`
          );
        }
        completed.push(step.label);
      }

      // -------------------------------------------------------------------
      // Success summary
      // -------------------------------------------------------------------
      return {
        content: [
          text(
            `Created ${input.namespace}.${input.className} (superclass: ${input.superclass}). ` +
              `Completed ${total} compile step${total === 1 ? '' : 's'}: ${completed.join(', ')}.`
          ),
        ],
      };
    }),
  };
}
