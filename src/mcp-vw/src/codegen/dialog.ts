/**
 * codegen/dialog.ts — vw_create_dialog.
 *
 * SimpleDialog cousin of vw_create_application_model. Same machinery,
 * different default superclass (`SimpleDialog`). For MVP V2 we support
 * Mode A only (spec-based windowSpec literal-array). Mode B (programmatic
 * `add*` builder calls) is V3.
 *
 * Per architecture.md §5.2 (tool 21) + §6.4 (Mode A only for V2).
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

const layoutSchema = z.object({
  l: z.number(), lf: z.number(),
  t: z.number(), tf: z.number(),
  r: z.number(), rf: z.number(),
  b: z.number(), bf: z.number(),
});

const componentSchema = z.object({
  type: z.enum([
    'Label', 'ActionButton', 'InputField', 'CheckBox', 'RadioButton',
    'ComboBox', 'SequenceView', 'TableView', 'TreeView', 'TextEditor',
    'GroupBox', 'Divider', 'SubCanvas',
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

const windowSpecSchema = z.object({
  selector: z.string().min(1).max(200).optional(),
  window: windowSchema,
  components: z.array(componentSchema),
});

const aspectSchema = z.object({
  name: z.string().min(1).max(200),
  defaultExpression: z.string().min(1).max(2_000).optional(),
});

const actionSchema = z.object({
  name: z.string().min(1).max(200),
  body: z.string().min(1).max(100_000),
});

const createDialogSchema = {
  className: z.string().min(1).max(200),
  namespace: z.string().min(1).max(100),
  superclass: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe('Optional. Default "SimpleDialog". Override if subclassing your own dialog base.'),
  category: z.string().max(200).optional(),
  aspects: z.array(aspectSchema).optional(),
  actions: z.array(actionSchema).optional(),
  windowSpec: windowSpecSchema.optional(),
};

const VALID_IVAR_RE = /^[a-z_][A-Za-z0-9_]*$/;

function buildCompile(className: string, isMeta: boolean, category: string, source: string): string {
  const receiver = isMeta ? `${className} class` : className;
  return `${receiver} compile: ${quoteSmalltalkString(source)} classified: ${quoteSmalltalkString(category)}`;
}

export function makeCreateDialogTool(bridge: BridgeClientLike): ToolDef<typeof createDialogSchema> {
  return {
    name: 'vw_create_dialog',
    description:
      'NATIVE-TYPED SimpleDialog scaffolder. Same machinery as vw_create_application_model but defaults to superclass="SimpleDialog". ' +
      'V2 supports Mode A (spec-based windowSpec literal-array). Mode B (programmatic add* builder) is V3. ' +
      'Refuses VWB.* targets.',
    inputSchema: createDialogSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      const superclass = input.superclass ?? 'SimpleDialog';

      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_create_dialog: invalid className "${input.className}".`);
      }
      if (!isValidNamespaceIdentifier(input.namespace)) {
        return errorResult(`vw_create_dialog: invalid namespace "${input.namespace}".`);
      }
      if (!isValidClassIdentifier(superclass)) {
        return errorResult(`vw_create_dialog: invalid superclass "${superclass}".`);
      }

      if (
        input.namespace === 'VWB' ||
        input.className.startsWith('VWB.') ||
        superclass.startsWith('VWB.')
      ) {
        return errorResult(
          `vw_create_dialog refuses targets in the VWB namespace (carry-forward #41).`
        );
      }

      const aspects = input.aspects ?? [];
      const actions = input.actions ?? [];

      for (const a of aspects) {
        if (!VALID_IVAR_RE.test(a.name)) {
          return errorResult(`vw_create_dialog: invalid aspect name "${a.name}".`);
        }
      }
      for (const a of actions) {
        if (!isValidSelector(a.name)) {
          return errorResult(`vw_create_dialog: invalid action name "${a.name}".`);
        }
      }

      // Build compile-step list.
      const steps: { label: string; source: string }[] = [];

      const classDefArgs: Parameters<typeof emitCreateClassSmalltalk>[0] = {
        className: input.className,
        namespace: input.namespace,
        superclass,
        instanceVariableNames: aspects.map((a) => a.name),
      };
      if (input.category !== undefined) classDefArgs.category = input.category;
      steps.push({ label: 'class definition', source: emitCreateClassSmalltalk(classDefArgs) });

      for (const a of aspects) {
        const accessor = emitLazyAspectAccessor({
          aspectName: a.name,
          ...(a.defaultExpression !== undefined ? { defaultExpression: a.defaultExpression } : {}),
        });
        steps.push({
          label: `aspect ${a.name}`,
          source: buildCompile(input.className, false, 'aspects', accessor),
        });
      }

      for (const a of actions) {
        const actionSrc = emitActionMethod({ actionName: a.name, body: a.body });
        steps.push({
          label: `action ${a.name}`,
          source: buildCompile(input.className, false, 'actions', actionSrc),
        });
      }

      if (input.windowSpec !== undefined) {
        const wsArgs: Parameters<typeof emitWindowSpecMethod>[0] = {
          window: input.windowSpec.window as WindowProps,
          components: input.windowSpec.components as Component[],
        };
        if (input.windowSpec.selector !== undefined) wsArgs.selector = input.windowSpec.selector;
        const wsSrc = emitWindowSpecMethod(wsArgs);
        const wsSel = input.windowSpec.selector ?? 'windowSpec';
        steps.push({
          label: `windowSpec ${wsSel}`,
          source: buildCompile(input.className, true, 'interface specs', wsSrc),
        });
      }

      const completed: string[] = [];
      for (let i = 0; i < steps.length; i++) {
        const step = steps[i]!;
        const result = await bridge.postEval(step.source);
        if (!result.ok) {
          return errorResult(
            `vw_create_dialog: failed at step ${i + 1} of ${steps.length} (${step.label}): ${result.error ?? '(no error)'}\n\nCompleted: ${completed.join(', ')}`
          );
        }
        completed.push(step.label);
      }

      return {
        content: [
          text(
            `Created ${input.namespace}.${input.className} (SimpleDialog scaffold; superclass: ${superclass}). ` +
              `Completed ${steps.length} step${steps.length === 1 ? '' : 's'}.`
          ),
        ],
      };
    }),
  };
}
