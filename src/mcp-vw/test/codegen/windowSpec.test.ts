import { describe, it, expect, vi } from 'vitest';
import {
  emitWindowSpecMethod,
  emitFullSpecLiteral,
  emitComponentLiteral,
  emitLayoutLiteral,
  emitDataSetColumnLiteral,
  makeCreateWindowSpecTool,
} from '../../src/codegen/windowSpec.js';
import { stubBridge, firstText } from '../_helpers.js';

// -----------------------------------------------------------------------------
// emitLayoutLiteral — Graphics.LayoutFrame 8-number form
// -----------------------------------------------------------------------------

describe('emitLayoutLiteral', () => {
  it('emits #(#{Graphics.LayoutFrame} l lf t tf r rf b bf)', () => {
    const layout = emitLayoutLiteral({ l: 10, lf: 0, t: 10, tf: 0, r: 100, rf: 0, b: 30, bf: 0 });
    expect(layout).toBe('#(#{Graphics.LayoutFrame} 10 0 10 0 100 0 30 0)');
  });

  it('handles negative offsets (from-right/from-bottom)', () => {
    const layout = emitLayoutLiteral({ l: -90, lf: 1, t: -35, tf: 1, r: -10, rf: 1, b: -10, bf: 1 });
    expect(layout).toBe('#(#{Graphics.LayoutFrame} -90 1 -35 1 -10 1 -10 1)');
  });
});

// -----------------------------------------------------------------------------
// emitComponentLiteral — single widget spec
// -----------------------------------------------------------------------------

describe('emitComponentLiteral — Label', () => {
  it('emits canonical LabelSpec form', () => {
    const out = emitComponentLiteral({
      type: 'Label',
      name: 'searchLabel',
      label: 'Search for:',
      layout: { l: 10, lf: 0, t: 10, tf: 0, r: 100, rf: 0, b: 30, bf: 0 },
    });
    expect(out).toContain('#{UI.LabelSpec}');
    expect(out).toContain('#name: #searchLabel');
    expect(out).toContain("#label: 'Search for:'");
    expect(out).toContain('#layout: #(#{Graphics.LayoutFrame} 10 0 10 0 100 0 30 0)');
  });
});

describe('emitComponentLiteral — ActionButton', () => {
  it('emits canonical ActionButtonSpec with isDefault + defaultable', () => {
    const out = emitComponentLiteral({
      type: 'ActionButton',
      name: 'searchButton',
      label: 'Search',
      model: 'doSearch',
      layout: { l: -80, lf: 1, t: 10, tf: 0, r: -10, rf: 1, b: 30, bf: 0 },
      isDefault: true,
      defaultable: true,
    });
    expect(out).toContain('#{UI.ActionButtonSpec}');
    expect(out).toContain('#name: #searchButton');
    expect(out).toContain("#label: 'Search'");
    expect(out).toContain('#model: #doSearch');
    expect(out).toContain('#isDefault: true');
    expect(out).toContain('#defaultable: true');
  });

  it('omits isDefault when not provided', () => {
    const out = emitComponentLiteral({
      type: 'ActionButton',
      name: 'btn',
      label: 'OK',
      model: 'accept',
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).not.toContain('isDefault');
    expect(out).not.toContain('defaultable');
  });
});

describe('emitComponentLiteral — InputField', () => {
  it('emits InputFieldSpec with optional numChars + type', () => {
    const out = emitComponentLiteral({
      type: 'InputField',
      name: 'searchInput',
      model: 'searchString',
      layout: { l: 110, lf: 0, t: 10, tf: 0, r: -90, rf: 1, b: 30, bf: 0 },
      numChars: 50,
      inputType: 'string',
    });
    expect(out).toContain('#{UI.InputFieldSpec}');
    expect(out).toContain('#model: #searchString');
    expect(out).toContain('#numChars: 50');
    expect(out).toContain('#type: #string');
  });

  it('omits optional fields when missing', () => {
    const out = emitComponentLiteral({
      type: 'InputField',
      name: 'i',
      model: 'm',
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).not.toContain('numChars');
    expect(out).not.toContain('#type:');
  });
});

describe('emitComponentLiteral — SequenceView (list)', () => {
  it('emits SequenceViewSpec (replaces ListSpec)', () => {
    const out = emitComponentLiteral({
      type: 'SequenceView',
      name: 'resultsList',
      model: 'results',
      layout: { l: 10, lf: 0, t: 40, tf: 0, r: -10, rf: 1, b: -10, bf: 1 },
    });
    expect(out).toContain('#{UI.SequenceViewSpec}');
    expect(out).toContain('#name: #resultsList');
    expect(out).toContain('#model: #results');
  });
});

describe('emitComponentLiteral — CheckBox', () => {
  it('emits CheckBoxSpec', () => {
    const out = emitComponentLiteral({
      type: 'CheckBox',
      name: 'agree',
      label: 'I agree',
      model: 'agreed',
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).toContain('#{UI.CheckBoxSpec}');
    expect(out).toContain('#model: #agreed');
  });
});

describe('emitComponentLiteral — escaping', () => {
  it('escapes apostrophes in labels', () => {
    const out = emitComponentLiteral({
      type: 'Label',
      name: 'l',
      label: "don't panic",
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).toContain("#label: 'don''t panic'");
  });
});

describe('emitComponentLiteral — unknown type', () => {
  it('throws on unknown component type', () => {
    expect(() =>
      emitComponentLiteral({
        // @ts-expect-error - intentional invalid type
        type: 'NopeWidget',
        name: 'x',
        layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
      })
    ).toThrow(/unknown component type/i);
  });
});

// -----------------------------------------------------------------------------
// emitFullSpecLiteral — top-level FullSpec wrapper
// -----------------------------------------------------------------------------

describe('emitFullSpecLiteral', () => {
  it('emits canonical FullSpec wrapper with window + components', () => {
    const out = emitFullSpecLiteral({
      window: {
        label: 'Party Search',
        bounds: [100, 100, 700, 500],
        sizeType: 'specifiedSize',
        positionType: 'screenCenter',
        openType: 'advanced',
      },
      components: [
        {
          type: 'Label',
          name: 'lbl',
          label: 'Search:',
          layout: { l: 10, lf: 0, t: 10, tf: 0, r: 100, rf: 0, b: 30, bf: 0 },
        },
      ],
    });

    expect(out).toContain('#{UI.FullSpec}');
    expect(out).toContain('#{UI.WindowSpec}');
    expect(out).toContain('#{UI.SpecCollection}');
    expect(out).toContain("#label: 'Party Search'");
    expect(out).toContain('#bounds: #(#{Graphics.Rectangle} 100 100 700 500)');
    expect(out).toContain('#{UI.PropertyListDictionary}');
    expect(out).toContain('#sizeType #specifiedSize');
    expect(out).toContain('#positionType #screenCenter');
    expect(out).toContain('#openType #advanced');
    expect(out).toContain('#{UI.LabelSpec}');
  });

  it('emits min + max as Core.Point', () => {
    const out = emitFullSpecLiteral({
      window: {
        label: 'X',
        bounds: [0, 0, 100, 100],
        min: [200, 150],
        max: [800, 600],
      },
      components: [],
    });

    expect(out).toContain('#min: #(#{Core.Point} 200 150)');
    expect(out).toContain('#max: #(#{Core.Point} 800 600)');
  });

  it('handles empty component list', () => {
    const out = emitFullSpecLiteral({
      window: { label: 'Empty', bounds: [0, 0, 100, 100] },
      components: [],
    });
    expect(out).toContain('#{UI.SpecCollection}');
    expect(out).toContain('#collection: #()');
  });

  it('omits hasMenuBar when not provided', () => {
    const out = emitFullSpecLiteral({
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });
    expect(out).not.toContain('hasMenuBar');
  });

  it('emits hasMenuBar: true when provided', () => {
    const out = emitFullSpecLiteral({
      window: { label: 'X', bounds: [0, 0, 100, 100], hasMenuBar: true },
      components: [],
    });
    expect(out).toContain('#hasMenuBar: true');
  });
});

// -----------------------------------------------------------------------------
// emitWindowSpecMethod — full method source for compile:
// -----------------------------------------------------------------------------

describe('emitWindowSpecMethod', () => {
  it('emits selector + <resource: #canvas> pragma + ^<literal>', () => {
    const src = emitWindowSpecMethod({
      selector: 'windowSpec',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });

    expect(src.startsWith('windowSpec')).toBe(true);
    expect(src).toContain('<resource: #canvas>');
    expect(src).toContain('^#(#{UI.FullSpec}');
  });

  it('uses custom selector when provided', () => {
    const src = emitWindowSpecMethod({
      selector: 'detailWindowSpec',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });
    expect(src.startsWith('detailWindowSpec')).toBe(true);
  });
});

// -----------------------------------------------------------------------------
// vw_create_window_spec tool
// -----------------------------------------------------------------------------

describe('vw_create_window_spec — tool def', () => {
  it('exposes vw_create_window_spec', () => {
    const tool = makeCreateWindowSpecTool(stubBridge());
    expect(tool.name).toBe('vw_create_window_spec');
    expect(tool.description.length).toBeGreaterThan(40);
  });
});

describe('vw_create_window_spec — happy path', () => {
  it('compiles emitted windowSpec onto the class metaclass', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'a CompiledMethod' };
      }),
    });
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'PartySearchView',
      window: { label: 'Party Search', bounds: [100, 100, 700, 500] },
      components: [
        {
          type: 'ActionButton',
          name: 'ok',
          label: 'OK',
          model: 'accept',
          layout: { l: -80, lf: 1, t: -35, tf: 1, r: -10, rf: 1, b: -10, bf: 1 },
          isDefault: true,
        },
      ],
    });

    expect(result.isError).toBeFalsy();
    expect(lastSource).toContain('PartySearchView class compile:');
    expect(lastSource).toContain("classified: 'interface specs'");
    // Apostrophes doubled for the outer compile: string.
    expect(lastSource).toContain("classified: 'interface specs'");
    // The windowSpec method body is embedded as the compile: source.
    expect(lastSource).toContain('windowSpec');
  });

  it('uses windowSpec as default selector', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateWindowSpecTool(bridge);

    await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });

    // The compile: source body begins with the selector name.
    expect(lastSource).toMatch(/compile:\s*'windowSpec/);
  });

  it('escapes apostrophes when embedding in compile: literal', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateWindowSpecTool(bridge);

    await tool.handler({
      className: 'Foo',
      window: { label: "Joe's app", bounds: [0, 0, 100, 100] },
      components: [],
    });

    // Single label "Joe's app" → 'Joe''s app' in the windowSpec literal →
    // 'Joe''''s app' (quadrupled) in the outer compile: string.
    expect(lastSource).toContain("''''s app");
  });
});

describe('vw_create_window_spec — guards', () => {
  it('refuses VWB.* className (carry-forward #41)', async () => {
    const bridge = stubBridge();
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'VWB.VWBridge',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWB|#41|wedge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: "Bad'Class",
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid widget name', async () => {
    const bridge = stubBridge();
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [
        {
          type: 'Label',
          name: "bad'name",
          label: 'X',
          layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
        },
      ],
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('surfaces in-band compile failure', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: 'undefined class: UI.FullSpec',
      }),
    });
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('undefined class');
  });
});

// -----------------------------------------------------------------------------
// emitDataSetColumnLiteral — one DataSet column (s23 benchmark Bug 6)
// -----------------------------------------------------------------------------

describe('emitDataSetColumnLiteral — one DataSet column (s23 Bug 6)', () => {
  it('emits canonical DataSetColumnSpec with required fields only', () => {
    const out = emitDataSetColumnLiteral({
      label: 'Source Fund',
      width: 200,
      readSelector: 'sourceFund',
    });
    expect(out).toBe(
      "#(#{UI.DataSetColumnSpec} #label: 'Source Fund' #width: 200 #readSelector: #sourceFund)"
    );
  });

  it('includes optional printSelector + alignment + type + menu', () => {
    const out = emitDataSetColumnLiteral({
      label: 'Qty',
      width: 80,
      readSelector: 'quantity',
      printSelector: 'printString',
      alignment: 'right',
      type: 'number',
      menu: 'qtyMenu',
    });
    expect(out).toContain('#printSelector: #printString');
    expect(out).toContain('#alignment: #right');
    expect(out).toContain('#type: #number');
    expect(out).toContain('#menu: #qtyMenu');
  });

  it('escapes apostrophes in column label', () => {
    const out = emitDataSetColumnLiteral({
      label: "Mum's Cash",
      width: 100,
      readSelector: 'cash',
    });
    expect(out).toContain("#label: 'Mum''s Cash'");
  });

  it('omits optional fields when not provided', () => {
    const out = emitDataSetColumnLiteral({
      label: 'X',
      width: 50,
      readSelector: 'x',
    });
    expect(out).not.toContain('printSelector');
    expect(out).not.toContain('alignment');
    expect(out).not.toContain('#type:');
    expect(out).not.toContain('menu');
  });
});

// -----------------------------------------------------------------------------
// emitComponentLiteral — DataSet (s23 benchmark Bug 6 fix)
// -----------------------------------------------------------------------------

describe('emitComponentLiteral — DataSet (s23 Bug 6 fix)', () => {
  it('emits canonical DataSetSpec with name + model + columns + layout', () => {
    const out = emitComponentLiteral({
      type: 'DataSet',
      name: 'subInstructionsTable',
      model: 'subInstructions',
      columns: [
        { label: 'Source', width: 100, readSelector: 'sourceFund' },
        { label: 'Target', width: 100, readSelector: 'targetFund' },
      ],
      layout: { l: 20, lf: 0, t: 20, tf: 0, r: -20, rf: 1, b: -20, bf: 1 },
    });
    expect(out).toContain('#{UI.DataSetSpec}');
    expect(out).toContain('#name: #subInstructionsTable');
    expect(out).toContain('#model: #subInstructions');
    expect(out).toContain('#columns:');
    expect(out).toContain('#{UI.DataSetColumnSpec}');
    expect(out).toContain('#layout: #(#{Graphics.LayoutFrame} 20 0 20 0 -20 1 -20 1)');
    const colCount = (out.match(/#\{UI\.DataSetColumnSpec\}/g) ?? []).length;
    expect(colCount).toBe(2);
  });

  it('emits multipleSelections + labelsAsButtons when provided', () => {
    const out = emitComponentLiteral({
      type: 'DataSet',
      name: 't',
      model: 'm',
      columns: [{ label: 'X', width: 50, readSelector: 'x' }],
      multipleSelections: true,
      labelsAsButtons: false,
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).toContain('#multipleSelections: true');
    expect(out).toContain('#labelsAsButtons: false');
  });

  it('omits optional flags when not provided', () => {
    const out = emitComponentLiteral({
      type: 'DataSet',
      name: 't',
      model: 'm',
      columns: [{ label: 'X', width: 50, readSelector: 'x' }],
      layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
    });
    expect(out).not.toContain('multipleSelections');
    expect(out).not.toContain('labelsAsButtons');
  });
});

// -----------------------------------------------------------------------------
// vw_create_window_spec — DataSet handler integration (s23 Bug 6)
// -----------------------------------------------------------------------------

describe('vw_create_window_spec — DataSet handler integration (s23 Bug 6)', () => {
  it('accepts DataSet with valid columns and compiles', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 800, 500] },
      components: [
        {
          type: 'DataSet',
          name: 'table',
          model: 'rows',
          columns: [
            { label: 'A', width: 100, readSelector: 'fieldA' },
            { label: 'B', width: 100, readSelector: 'fieldB', printSelector: 'printString' },
          ],
          layout: { l: 10, lf: 0, t: 10, tf: 0, r: -10, rf: 1, b: -10, bf: 1 },
        },
      ],
    });

    expect(result.isError).toBeFalsy();
    expect(lastSource).toContain('UI.DataSetSpec');
    expect(lastSource).toContain('UI.DataSetColumnSpec');
    expect(lastSource).toContain('#columns:');
  });

  it('rejects DataSet with empty columns array', async () => {
    const bridge = stubBridge();
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [
        {
          type: 'DataSet',
          name: 't',
          model: 'm',
          columns: [],
          layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
        },
      ],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/columns|DataSet/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects DataSet column with invalid readSelector', async () => {
    const bridge = stubBridge();
    const tool = makeCreateWindowSpecTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      window: { label: 'X', bounds: [0, 0, 100, 100] },
      components: [
        {
          type: 'DataSet',
          name: 't',
          model: 'm',
          columns: [{ label: 'X', width: 50, readSelector: "bad'sel" }],
          layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 0, b: 0, bf: 0 },
        },
      ],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/readSelector/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});
