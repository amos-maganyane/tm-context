import { describe, it, expect, vi } from 'vitest';
import { makeNavigationTools } from '../../src/tools/navigation.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('navigation tools — registration', () => {
  it('returns 3 tools (MVP vw_find_senders + V2 vw_find_implementors + vw_find_references_to)', () => {
    const tools = makeNavigationTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_find_implementors',
      'vw_find_references_to',
      'vw_find_senders',
    ]);
  });
});

describe('vw_find_senders', () => {
  it('returns JSON array of Class>>selector sender pairs (#43-safe ; separator)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result:
          "'Customer>>printOn:;CustomerView>>refresh;CustomerView class>>open;'",
      }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: 'name' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual([
      'Customer>>printOn:',
      'CustomerView>>refresh',
      'CustomerView class>>open',
    ]);
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // Carry-forward #43: ';' separator, no Character lf.
    expect(probe).toContain("';'");
    expect(probe).not.toContain('Character lf');
  });

  it('embeds the target selector in the probe', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    await tool.handler({ selector: 'printOn:' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('#printOn:');
    expect(probe).toContain('messages');
  });

  it('caps results at the 500-entry limit', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    await tool.handler({ selector: 'do:' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // Probe should encode the limit literally.
    expect(probe).toContain('500');
  });

  it('returns empty array when no senders found', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: 'nonExistentSelectorXyz' });

    expect(result.isError).toBeFalsy();
    expect(JSON.parse(firstText(result))).toEqual([]);
  });

  it('accepts binary selectors', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: '+' });

    expect(result.isError).toBeFalsy();
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('#+');
  });

  it('accepts keyword selectors', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: 'at:put:' });

    expect(result.isError).toBeFalsy();
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('#at:put:');
  });

  it('rejects invalid selectors (injection guard)', async () => {
    const bridge = stubBridge();
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: "foo'; bad" });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/invalid|selector/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('scope=namespace narrows the search', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'Tools.UIPainter>>foo;'",
      }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    await tool.handler({ selector: 'foo', scope: 'Tools' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // Probe should reference the Tools namespace rather than allClasses.
    expect(probe).toMatch(/Tools|at:\s*#Tools/);
  });

  it('rejects invalid scope namespace', async () => {
    const bridge = stubBridge();
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_senders')!;

    const result = await tool.handler({ selector: 'foo', scope: "bad'NS" });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});
