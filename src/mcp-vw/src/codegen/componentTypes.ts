/**
 * codegen/componentTypes.ts — shared component types + Zod schemas.
 *
 * SINGLE SOURCE OF TRUTH for the widget catalogue exposed by:
 *
 *   - vw_create_window_spec  (standalone canvas/windowSpec emitter)
 *   - vw_create_application_model  (heavyweight scaffolder embedding windowSpec)
 *   - vw_create_dialog  (SimpleDialog scaffolder embedding windowSpec)
 *
 * Before this module existed each of those three places redeclared its own
 * `Component` union + componentSchema enum. Adding a new widget (e.g.
 * DataSet, s23 benchmark Bug 6) required touching all three in lockstep —
 * easy to forget. The s23 follow-up (Bug 6+) caught exactly that drift:
 * vw_create_window_spec gained DataSet but the two scaffolders kept their
 * old 13-type enum, so AI calling the scaffolders saw Zod reject DataSet
 * even though the standalone emitter accepted it.
 *
 * Anti-drift rule: every component-shape addition lands here ONLY. Importers
 * pick up the change automatically.
 */

import { z } from 'zod';

// -----------------------------------------------------------------------------
// Layout — Graphics.LayoutFrame 8-number form (offset+fraction per edge)
// -----------------------------------------------------------------------------

export interface Layout {
  l: number;
  lf: number;
  t: number;
  tf: number;
  r: number;
  rf: number;
  b: number;
  bf: number;
}

export const layoutSchema = z.object({
  l: z.number(),
  lf: z.number(),
  t: z.number(),
  tf: z.number(),
  r: z.number(),
  rf: z.number(),
  b: z.number(),
  bf: z.number(),
});

// -----------------------------------------------------------------------------
// DataSetColumn — one column within a DataSet table (s23 benchmark Bug 6)
//
// DataSetColumnSpec writable properties verified live against
// `(UI.DataSetColumnSpec new respondsTo: #...)`:
//   - label, width, readSelector, printSelector, alignment, type, menu → true
//   - writeSelector, editable, displayWidget, showWidget → false (omitted)
// -----------------------------------------------------------------------------

export interface DataSetColumn {
  label: string;
  width: number;
  readSelector: string;
  printSelector?: string;
  alignment?: 'left' | 'right' | 'center';
  type?: 'string' | 'number';
  menu?: string;
}

export const dataSetColumnSchema = z.object({
  label: z.string(),
  width: z.number(),
  readSelector: z.string(),
  printSelector: z.string().optional(),
  alignment: z.enum(['left', 'right', 'center']).optional(),
  type: z.enum(['string', 'number']).optional(),
  menu: z.string().optional(),
});

// -----------------------------------------------------------------------------
// Component — discriminated union of every widget type
//
// Adding a new component type: extend BOTH the TS union AND the
// COMPONENT_TYPE_NAMES array below. The two are linked by the same string
// literals; keep them in lockstep.
// -----------------------------------------------------------------------------

interface BaseComponent {
  name?: string;
  layout: Layout;
}

export type Component =
  | (BaseComponent & { type: 'Label'; label: string })
  | (BaseComponent & {
      type: 'ActionButton';
      label: string;
      model: string;
      isDefault?: boolean;
      defaultable?: boolean;
    })
  | (BaseComponent & {
      type: 'InputField';
      model: string;
      numChars?: number;
      inputType?: 'string' | 'number' | 'date';
    })
  | (BaseComponent & { type: 'CheckBox'; label: string; model: string })
  | (BaseComponent & {
      type: 'RadioButton';
      label: string;
      model: string;
      select: string | number | boolean;
    })
  | (BaseComponent & { type: 'ComboBox'; model: string })
  | (BaseComponent & { type: 'SequenceView'; model: string })
  | (BaseComponent & { type: 'TableView'; model: string })
  | (BaseComponent & { type: 'TreeView'; model: string })
  | (BaseComponent & { type: 'TextEditor'; model: string })
  | (BaseComponent & { type: 'GroupBox'; label?: string })
  | (BaseComponent & { type: 'Divider' })
  | (BaseComponent & {
      type: 'DataSet';
      model: string;
      columns: DataSetColumn[];
      multipleSelections?: boolean;
      labelsAsButtons?: boolean;
    })
  | (BaseComponent & { type: 'SubCanvas'; model: string });

/**
 * String-literal array of every supported `Component['type']` value.
 * Source of truth for the Zod enum below — adding a new component type
 * means adding ONE entry here.
 */
export const COMPONENT_TYPE_NAMES = [
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
  'DataSet',
] as const;

export type ComponentTypeName = (typeof COMPONENT_TYPE_NAMES)[number];

export const componentSchema = z
  .object({
    type: z.enum(COMPONENT_TYPE_NAMES),
    name: z.string().optional(),
    label: z.string().optional(),
    model: z.string().optional(),
    layout: layoutSchema,
    isDefault: z.boolean().optional(),
    defaultable: z.boolean().optional(),
    numChars: z.number().optional(),
    inputType: z.enum(['string', 'number', 'date']).optional(),
    select: z.union([z.string(), z.number(), z.boolean()]).optional(),
    // DataSet-specific (s23 benchmark Bug 6)
    columns: z.array(dataSetColumnSchema).optional(),
    multipleSelections: z.boolean().optional(),
    labelsAsButtons: z.boolean().optional(),
  })
  .passthrough();

// -----------------------------------------------------------------------------
// WindowProps — window-level properties (label, bounds, sizing, etc.)
// -----------------------------------------------------------------------------

export interface WindowProps {
  label: string;
  bounds: [number, number, number, number]; // [left, top, right, bottom]
  min?: [number, number];
  max?: [number, number];
  sizeType?: 'specifiedSize' | 'fixedSize' | 'maxScreenSize';
  positionType?: 'screenCenter' | 'mouseCenter';
  openType?: 'advanced' | 'simple';
  hasMenuBar?: boolean;
}

export const windowSchema = z.object({
  label: z.string(),
  bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
  min: z.tuple([z.number(), z.number()]).optional(),
  max: z.tuple([z.number(), z.number()]).optional(),
  sizeType: z.enum(['specifiedSize', 'fixedSize', 'maxScreenSize']).optional(),
  positionType: z.enum(['screenCenter', 'mouseCenter']).optional(),
  openType: z.enum(['advanced', 'simple']).optional(),
  hasMenuBar: z.boolean().optional(),
});

// -----------------------------------------------------------------------------
// FullSpecInput — top-level windowSpec emit input (window props + components)
// -----------------------------------------------------------------------------

export interface FullSpecInput {
  window: WindowProps;
  components: Component[];
}

// -----------------------------------------------------------------------------
// WindowSpecPayload — scaffolder-embedded windowSpec input
//
// Same as FullSpecInput but with an optional method selector (defaults to
// 'windowSpec'). Used by vw_create_application_model + vw_create_dialog when
// they embed a windowSpec generation step.
// -----------------------------------------------------------------------------

export interface WindowSpecPayload extends FullSpecInput {
  selector?: string;
}

export const windowSpecPayloadSchema = z.object({
  selector: z.string().min(1).max(200).optional(),
  window: windowSchema,
  components: z.array(componentSchema),
});
