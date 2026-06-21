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
    expect(sources[0]).toContain('SimpleDialog subclass: #ConfirmDialog');
    expect(sources[0]).toContain("inDictionary: 'MyApp'");
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

    expect(sources[0]).toContain('MyApp.BaseDialog subclass: #CustomDialog');
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
});
