/**
 * codegen/windowSpec.ts — vw_create_window_spec NATIVE-TYPED emitter.
 *
 * THE DESIGN UNLOCK (architecture.md §6.1, probe-3): the canonical VW
 * class-side `windowSpec` method is a ONE-LINER returning a nested literal
 * array. Verified against `Tools.AboutVisualWorksDialog` (probe-3) and
 * `Browser.AbstractCodeModel` (POC-2) — two unrelated classes, same shape.
 *
 * AI passes structured JSON (window props + components tree). This emitter
 * walks the tree + emits the literal. AI never sees:
 *   - The `#{Namespace.ClassName}` ResolvedDeferredBinding form
 *   - LayoutFrame's 8-number ordering
 *   - The `#properties: #(#{UI.PropertyListDictionary} ...)` wrapping for
 *     sizeType/positionType/openType
 *   - The single-quote apostrophe-doubling for nested string literals
 *
 * Per architecture.md §5.2 (tool 20) + §6.1.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidSelector,
  quoteSmalltalkString,
} from '../smalltalk.js';
import type { ToolDef } from '../tools/types.js';
import {
  type Layout,
  type DataSetColumn,
  type Component,
  type WindowProps,
  type FullSpecInput,
  type WindowSpecPayload,
  componentSchema,
  windowSchema,
} from './componentTypes.js';

// Re-export so existing importers (and AI agents reading tool signatures)
// keep finding these names in one place. Anti-drift rule still applies —
// the actual declarations live in componentTypes.ts (s23 Bug 6+ fix).
export type { Layout, DataSetColumn, Component, WindowProps, FullSpecInput };

/** Backwards-compat alias for the scaffolder-embedded windowSpec shape. */
export type WindowSpecMethodInput = WindowSpecPayload;

// -----------------------------------------------------------------------------
// emitLayoutLiteral
// -----------------------------------------------------------------------------

export function emitLayoutLiteral(layout: Layout): string {
  return `#(#{Graphics.LayoutFrame} ${layout.l} ${layout.lf} ${layout.t} ${layout.tf} ${layout.r} ${layout.rf} ${layout.b} ${layout.bf})`;
}

// -----------------------------------------------------------------------------
// emitDataSetColumnLiteral — one DataSet column spec (s23 benchmark Bug 6)
// -----------------------------------------------------------------------------

export function emitDataSetColumnLiteral(col: DataSetColumn): string {
  const parts: string[] = [`#{UI.DataSetColumnSpec}`];
  parts.push(`#label: ${quoteSmalltalkString(col.label)}`);
  parts.push(`#width: ${col.width}`);
  parts.push(`#readSelector: #${col.readSelector}`);
  if (col.printSelector !== undefined) {
    parts.push(`#printSelector: #${col.printSelector}`);
  }
  if (col.alignment !== undefined) {
    parts.push(`#alignment: #${col.alignment}`);
  }
  if (col.type !== undefined) {
    parts.push(`#type: #${col.type}`);
  }
  if (col.menu !== undefined) {
    parts.push(`#menu: #${col.menu}`);
  }
  return `#(${parts.join(' ')})`;
}

// -----------------------------------------------------------------------------
// emitComponentLiteral — one widget spec
// -----------------------------------------------------------------------------

/** Map JSON component type → Smalltalk spec class. */
const COMPONENT_SPEC_CLASS: Record<Component['type'], string> = {
  Label: 'UI.LabelSpec',
  ActionButton: 'UI.ActionButtonSpec',
  InputField: 'UI.InputFieldSpec',
  CheckBox: 'UI.CheckBoxSpec',
  RadioButton: 'UI.RadioButtonSpec',
  ComboBox: 'UI.ComboBoxSpec',
  SequenceView: 'UI.SequenceViewSpec',
  TableView: 'UI.TableViewSpec',
  TreeView: 'UI.TreeViewSpec',
  TextEditor: 'UI.TextEditorSpec',
  GroupBox: 'UI.GroupBoxSpec',
  Divider: 'UI.DividerSpec',
  DataSet: 'UI.DataSetSpec',
  SubCanvas: 'UI.SubCanvasSpec',
};

export function emitComponentLiteral(comp: Component): string {
  const specClass = COMPONENT_SPEC_CLASS[comp.type];
  if (!specClass) {
    throw new Error(`emitComponentLiteral: unknown component type "${comp.type}"`);
  }

  const parts: string[] = [`#{${specClass}}`];
  if (comp.name !== undefined) {
    parts.push(`#name: #${comp.name}`);
  }

  switch (comp.type) {
    case 'Label':
      parts.push(`#label: ${quoteSmalltalkString(comp.label)}`);
      break;
    case 'ActionButton':
      parts.push(`#label: ${quoteSmalltalkString(comp.label)}`);
      parts.push(`#model: #${comp.model}`);
      if (comp.isDefault !== undefined) parts.push(`#isDefault: ${comp.isDefault}`);
      if (comp.defaultable !== undefined) parts.push(`#defaultable: ${comp.defaultable}`);
      break;
    case 'InputField':
      parts.push(`#model: #${comp.model}`);
      if (comp.numChars !== undefined) parts.push(`#numChars: ${comp.numChars}`);
      if (comp.inputType !== undefined) parts.push(`#type: #${comp.inputType}`);
      break;
    case 'CheckBox':
      parts.push(`#label: ${quoteSmalltalkString(comp.label)}`);
      parts.push(`#model: #${comp.model}`);
      break;
    case 'RadioButton':
      parts.push(`#label: ${quoteSmalltalkString(comp.label)}`);
      parts.push(`#model: #${comp.model}`);
      parts.push(`#select: ${emitLiteralValue(comp.select)}`);
      break;
    case 'ComboBox':
    case 'SequenceView':
    case 'TableView':
    case 'TreeView':
    case 'TextEditor':
    case 'SubCanvas':
      parts.push(`#model: #${comp.model}`);
      break;
    case 'DataSet': {
      parts.push(`#model: #${comp.model}`);
      if (comp.multipleSelections !== undefined) {
        parts.push(`#multipleSelections: ${comp.multipleSelections}`);
      }
      if (comp.labelsAsButtons !== undefined) {
        parts.push(`#labelsAsButtons: ${comp.labelsAsButtons}`);
      }
      const colLiterals = comp.columns.map((c) => emitDataSetColumnLiteral(c)).join(' ');
      parts.push(`#columns: #(${colLiterals})`);
      break;
    }
    case 'GroupBox':
      if (comp.label !== undefined) parts.push(`#label: ${quoteSmalltalkString(comp.label)}`);
      break;
    case 'Divider':
      // No additional fields.
      break;
  }

  parts.push(`#layout: ${emitLayoutLiteral(comp.layout)}`);
  return `#(${parts.join(' ')})`;
}

function emitLiteralValue(v: string | number | boolean): string {
  if (typeof v === 'string') return quoteSmalltalkString(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  return String(v);
}

// -----------------------------------------------------------------------------
// emitFullSpecLiteral — top-level FullSpec wrapper
// -----------------------------------------------------------------------------

export function emitFullSpecLiteral(input: FullSpecInput): string {
  const windowParts: string[] = [`#{UI.WindowSpec}`];

  windowParts.push(`#label: ${quoteSmalltalkString(input.window.label)}`);
  windowParts.push(
    `#bounds: #(#{Graphics.Rectangle} ${input.window.bounds.join(' ')})`
  );

  if (input.window.min !== undefined) {
    windowParts.push(`#min: #(#{Core.Point} ${input.window.min[0]} ${input.window.min[1]})`);
  }
  if (input.window.max !== undefined) {
    windowParts.push(`#max: #(#{Core.Point} ${input.window.max[0]} ${input.window.max[1]})`);
  }

  const propPairs: string[] = [];
  if (input.window.sizeType !== undefined) {
    propPairs.push(`#sizeType #${input.window.sizeType}`);
  }
  if (input.window.positionType !== undefined) {
    propPairs.push(`#positionType #${input.window.positionType}`);
  }
  if (input.window.openType !== undefined) {
    propPairs.push(`#openType #${input.window.openType}`);
  }
  if (propPairs.length > 0) {
    windowParts.push(
      `#properties: #(#{UI.PropertyListDictionary} ${propPairs.join(' ')})`
    );
  }

  if (input.window.hasMenuBar !== undefined) {
    windowParts.push(`#hasMenuBar: ${input.window.hasMenuBar}`);
  }

  const componentLiterals = input.components.map((c) => emitComponentLiteral(c)).join(' ');
  const componentTree = `#(#{UI.SpecCollection} #collection: #(${componentLiterals}))`;

  return `#(#{UI.FullSpec} #window: #(${windowParts.join(' ')}) #component: ${componentTree})`;
}

// -----------------------------------------------------------------------------
// emitWindowSpecMethod — full Smalltalk method source for compile:
// -----------------------------------------------------------------------------

export function emitWindowSpecMethod(input: WindowSpecMethodInput): string {
  const selector = input.selector ?? 'windowSpec';
  const literal = emitFullSpecLiteral(input);
  return `${selector}
    "MCP-generated by vw_create_window_spec. Edit via the tool or UIPainter."
    <resource: #canvas>
    ^${literal}`;
}

// -----------------------------------------------------------------------------
// vw_create_window_spec tool — Zod schemas imported from componentTypes (s23 Bug 6+)
// -----------------------------------------------------------------------------

const createWindowSpecSchema = {
  className: z
    .string()
    .min(1)
    .max(200)
    .describe('Class to install the windowSpec method on (class-side). REFUSED for VWB.*.'),
  selector: z
    .string()
    .min(1)
    .max(200)
    .optional()
    .describe('Method selector. Default "windowSpec". Use "detailWindowSpec" etc for alternate views.'),
  window: windowSchema.describe('Window-level properties (label, bounds, sizeType, etc.).'),
  components: z
    .array(componentSchema)
    .describe('Array of widget specs. Each has type, name?, label?, model?, layout. Empty array allowed.'),
};

const TOOL_DESCRIPTION =
  'NATIVE-TYPED canvas/windowSpec emitter: takes structured JSON, emits the canonical literal-array form (the probe-3 design unlock), ' +
  'and compiles it as a class-side method on the target class. AI never sees `#{UI.FullSpec}` / `#{Graphics.LayoutFrame}` / PropertyListDictionary syntax. ' +
  'Supports 14 component types (Label, ActionButton, InputField, CheckBox, RadioButton, ComboBox, SequenceView, TableView, TreeView, TextEditor, GroupBox, Divider, SubCanvas, DataSet). ' +
  'DataSet (column-based table per s23 benchmark Bug 6) requires `model` (aspect returning a SelectionInList of row objects) plus `columns: [{label, width, readSelector, printSelector?, alignment?, type?, menu?}]`. ' +
  'Layout uses {l, lf, t, tf, r, rf, b, bf} offset+fraction form. Refuses VWB.* targets (#41).';

export function makeCreateWindowSpecTool(
  bridge: BridgeClientLike
): ToolDef<typeof createWindowSpecSchema> {
  return {
    name: 'vw_create_window_spec',
    description: TOOL_DESCRIPTION,
    inputSchema: createWindowSpecSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // -----------------------------------------------------------------------
      // Identifier validation
      // -----------------------------------------------------------------------
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(
          `vw_create_window_spec: invalid className "${input.className}". Must match class-identifier regex.`
        );
      }
      if (input.className.startsWith('VWB.') || input.className === 'VWB') {
        return errorResult(
          `vw_create_window_spec refuses targets in the VWB namespace (carry-forward #41 — compile on VWB.* wedges the bridge).`
        );
      }
      const selector = input.selector ?? 'windowSpec';
      if (!isValidSelector(selector)) {
        return errorResult(
          `vw_create_window_spec: invalid selector "${selector}". Must match unary/binary/keyword selector regex.`
        );
      }

      // Validate each component's name + model symbols.
      for (const comp of input.components) {
        if (comp.name !== undefined && !/^[a-z_][A-Za-z0-9_]*$/.test(comp.name)) {
          return errorResult(
            `vw_create_window_spec: invalid widget name "${comp.name}". Must match /^[a-z_][A-Za-z0-9_]*$/.`
          );
        }
        if ('model' in comp && typeof comp.model === 'string' && !/^[a-z_][A-Za-z0-9_:]*$/.test(comp.model)) {
          return errorResult(
            `vw_create_window_spec: invalid model symbol "${comp.model}" on widget "${comp.name ?? '(unnamed)'}".`
          );
        }
        // DataSet-specific validation (s23 benchmark Bug 6): non-empty columns +
        // per-column selector identifiers.
        if (comp.type === 'DataSet') {
          const columns = comp.columns;
          if (!Array.isArray(columns) || columns.length === 0) {
            return errorResult(
              `vw_create_window_spec: DataSet "${comp.name ?? '(unnamed)'}" requires a non-empty columns array.`
            );
          }
          for (const col of columns) {
            if (!/^[a-z_][A-Za-z0-9_]*$/.test(col.readSelector)) {
              return errorResult(
                `vw_create_window_spec: DataSet column "${col.label}" has invalid readSelector "${col.readSelector}". Must be a unary identifier selector.`
              );
            }
            if (col.printSelector !== undefined && !/^[a-z_][A-Za-z0-9_]*$/.test(col.printSelector)) {
              return errorResult(
                `vw_create_window_spec: DataSet column "${col.label}" has invalid printSelector "${col.printSelector}".`
              );
            }
            if (col.menu !== undefined && !/^[a-z_][A-Za-z0-9_]*$/.test(col.menu)) {
              return errorResult(
                `vw_create_window_spec: DataSet column "${col.label}" has invalid menu "${col.menu}".`
              );
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // Emit + compile
      // -----------------------------------------------------------------------
      const methodSource = emitWindowSpecMethod({
        selector,
        window: input.window,
        components: input.components as Component[],
      });

      const compileExpression = `${input.className} class compile: ${quoteSmalltalkString(methodSource)} classified: 'interface specs'`;
      // NOTE: the methodSource may contain ' (single quote) inside string literals.
      // quoteSmalltalkString doubles them; the outer compile: string wraps the result.

      const evalResult = await bridge.postEval(compileExpression);
      if (!evalResult.ok) {
        return errorResult(
          `vw_create_window_spec: VW eval failed compiling ${input.className} class>>${selector}: ${evalResult.error ?? '(no error)'}\n\nEmitted Smalltalk:\n${methodSource}`
        );
      }

      return {
        content: [
          text(
            `Compiled ${input.className} class>>${selector} (${input.components.length} component${input.components.length === 1 ? '' : 's'}). ` +
              `Result: ${evalResult.result ?? '(no result)'}`
          ),
        ],
      };
    }),
  };
}
