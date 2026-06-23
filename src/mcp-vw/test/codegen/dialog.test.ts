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
