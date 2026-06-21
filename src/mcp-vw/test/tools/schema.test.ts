import { describe, it, expect, vi } from 'vitest';
import { makeSchemaTools } from '../../src/tools/schema.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('schema tools — registration', () => {
  it('returns 5 tool defs (MVP + V3)', () => {
    const tools = makeSchemaTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_list_all_classes',
      'vw_list_namespace_classes',
      'vw_list_namespace_entries',
      'vw_list_namespaces',
      'vw_list_test_classes',
    ]);
  });
});

describe('vw_list_namespaces', () => {
  it('runs /eval with allNameSpaces probe + returns sorted namespace JSON array', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'Core;Kernel;Smalltalk;Store;Tools;UI;'",
      }),
    });
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespaces')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(Array.isArray(parsed)).toBe(true);
    expect(parsed).toContain('Core');
    expect(parsed).toContain('Kernel');
    expect(parsed).toContain('Tools');
    expect(parsed).toContain('UI');
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('allNameSpaces');
    // Carry-forward #43: probe must use ';' separator, NOT lf/cr/tab.
    expect(probe).toContain("';'");
    expect(probe).not.toContain('Character lf');
  });

  it('handles empty namespace list (defensive)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespaces')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    expect(JSON.parse(firstText(result))).toEqual([]);
  });

  it('surfaces bridge error', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: false, error: 'something broke' }),
    });
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespaces')!;

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('something broke');
  });
});

describe('vw_list_namespace_entries', () => {
  it('returns sorted JSON array of bindings in the namespace', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'AboutVisualWorksDialog;UIPainter;UIPainterController;'",
      }),
    });
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespace_entries')!;

    const result = await tool.handler({ namespace: 'Tools' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(['AboutVisualWorksDialog', 'UIPainter', 'UIPainterController']);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('Tools');
    expect(probe).toContain('ifAbsent');
  });

  it('returns isError when namespace name is invalid', async () => {
    const bridge = stubBridge();
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespace_entries')!;

    const result = await tool.handler({ namespace: "Tools'injection" });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/invalid|namespace|identifier/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('returns isError when namespace does not exist', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "'ABSENT'" }),
    });
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespace_entries')!;

    const result = await tool.handler({ namespace: 'NonexistentNS' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/absent|not found|does not exist/i);
  });

  it('rejects dotted namespace names (flat namespaces only in this image)', async () => {
    const bridge = stubBridge();
    const tool = makeSchemaTools(bridge).find((t) => t.name === 'vw_list_namespace_entries')!;

    const result = await tool.handler({ namespace: 'Smalltalk.Core' });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});
