import { describe, it, expect, vi } from 'vitest';
import { makeCreateDialogTool } from '../../src/codegen/dialog.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('vw_create_dialog', () => {
  it('creates a SimpleDialog subclass by default', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    const result = await tool.handler({
      className: 'ConfirmDialog',
      namespace: 'MyApp',
      windowSpec: {
        window: { label: 'Confirm', bounds: [0, 0, 300, 150] },
        components: [
          {
            type: 'Label',
            name: 'msg',
            label: 'Are you sure?',
            layout: { l: 10, lf: 0, t: 10, tf: 0, r: -10, rf: 1, b: 40, bf: 0 },
          },
        ],
      },
    });

    expect(result.isError).toBeFalsy();
    // defineClass: 8-kw form per s23 benchmark Bug 1 fix.
    expect(sources[0]).toContain('Smalltalk.MyApp defineClass: #ConfirmDialog');
    expect(sources[0]).toContain('superclass: #{Smalltalk.SimpleDialog}');
  });

  it('accepts custom superclass override', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    await tool.handler({
      className: 'CustomDialog',
      namespace: 'MyApp',
      superclass: 'MyApp.BaseDialog',
    });

    // defineClass: 8-kw form per s23 benchmark Bug 1 fix.
    // Dotted superclass goes into the literal verbatim; receiver carries namespace.
    expect(sources[0]).toContain('Smalltalk.MyApp defineClass: #CustomDialog');
    expect(sources[0]).toContain('superclass: #{MyApp.BaseDialog}');
  });

  it('refuses VWB.* namespace', async () => {
    const bridge = stubBridge();
    const tool = makeCreateDialogTool(bridge);

    const result = await tool.handler({
      className: 'X',
      namespace: 'VWB',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWB|#41/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('accepts DataSet component in dialog windowSpec — s23 Bug 6+ fix', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    const result = await tool.handler({
      className: 'RowPickerDialog',
      namespace: 'MyApp',
      aspects: [{ name: 'rows', defaultExpression: 'SelectionInList with: OrderedCollection new' }],
      windowSpec: {
        window: { label: 'Pick Row', bounds: [0, 0, 500, 350] },
        components: [
          {
            type: 'DataSet',
            name: 'tbl',
            model: 'rows',
            columns: [
              { label: 'Name', width: 200, readSelector: 'name' },
              { label: 'Kind', width: 100, readSelector: 'kind' },
            ],
            layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 1, b: -40, bf: 1 },
          },
        ],
      },
    });

    expect(result.isError).toBeFalsy();
    const wsSrc = sources.find((s) => s.includes('RowPickerDialog class compile:'));
    expect(wsSrc).toBeDefined();
    expect(wsSrc).toContain('UI.DataSetSpec');
    expect(wsSrc).toContain('UI.DataSetColumnSpec');
    expect(wsSrc).toContain('#readSelector: #name');
    expect(wsSrc).toContain('#readSelector: #kind');
  });
});

// -----------------------------------------------------------------------------
// s27 Bug A — dialog scaffolder must thread namespace into compile receiver.
// Same root cause as the applicationModel scaffolder. See applicationModel.test.ts
// for the full explanation. Memory entity:
// `Scaffolder-unqualified-className-receiver-bug`.
// -----------------------------------------------------------------------------
describe('vw_create_dialog — namespace handling (s27 Bug A fix)', () => {
  it('emits FQN compile receiver for namespace=Examples (the bug)', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    await tool.handler({
      className: 'D',
      namespace: 'Examples',
      aspects: [{ name: 'a' }],
      actions: [{ name: 'accept', body: '^self accept' }],
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    // class def + aspect + action + windowSpec = 4 sources.
    expect(sources.length).toBe(4);
    const compileSteps = sources.slice(1);
    for (const s of compileSteps) {
      expect(s).toMatch(/Examples\.D (class )?compile:/);
      // Negative-match: bare-leaf receiver is the bug.
      expect(s).not.toMatch(/(?<![\w.])D (class )?compile:/);
    }
  });

  it('threads namespace through aspect + action + windowSpec consistently', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    await tool.handler({
      className: 'Picker',
      namespace: 'GemStoneClasses',
      aspects: [{ name: 'sel' }],
      actions: [{ name: 'choose', body: '^self chosen' }],
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    expect(sources.length).toBe(4);
    const compileSteps = sources.slice(1);
    expect(compileSteps.length).toBe(3);
    for (const s of compileSteps) {
      expect(s).toMatch(/GemStoneClasses\.Picker (class )?compile:/);
    }
    expect(compileSteps.some((s) => s.includes("classified: 'aspects'") && s.includes('sel isNil'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'actions'") && s.includes('choose'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'interface specs'") && s.includes('UI.FullSpec'))).toBe(true);
  });

  it('emits FQN receiver for namespace=Smalltalk (consistency)', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateDialogTool(bridge);

    await tool.handler({
      className: 'Plain',
      namespace: 'Smalltalk',
      aspects: [{ name: 'note' }],
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    expect(sources.length).toBe(3);
    const compileSteps = sources.slice(1);
    for (const s of compileSteps) {
      expect(s).toMatch(/Smalltalk\.Plain (class )?compile:/);
    }
  });
});
