import { describe, it, expect, vi } from 'vitest';
import { makeReadingTools } from '../../src/tools/reading.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('reading tools — registration', () => {
  it('returns 3 tool defs (MVP + V2)', () => {
    const tools = makeReadingTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_describe_class',
      'vw_get_class_definition',
      'vw_list_methods',
    ]);
  });
});

describe('vw_get_class_definition', () => {
  it('returns the class definition source for a simple class', async () => {
    const definition =
      "Smalltalk.Object subclass: #Customer\n\tinstanceVariableNames: 'name email'\n\tclassVariableNames: ''\n\tpoolDictionaries: ''\n\tcategory: 'MyApp-Model'";
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: `'${definition.replace(/'/g, "''")}'`,
      }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_get_class_definition')!;

    const result = await tool.handler({ className: 'Customer' });

    expect(result.isError).toBeFalsy();
    expect(firstText(result)).toContain('Customer');
    expect(firstText(result)).toContain('subclass:');
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('Customer');
    expect(probe).toContain('definition');
  });

  it('supports namespace-qualified class names', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'Tools.UIPainter definition stub'",
      }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_get_class_definition')!;

    const result = await tool.handler({ className: 'Tools.UIPainter' });

    expect(result.isError).toBeFalsy();
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('Tools.UIPainter');
  });

  it('rejects invalid class identifiers (injection guard)', async () => {
    const bridge = stubBridge();
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_get_class_definition')!;

    const result = await tool.handler({ className: "Customer'; bad" });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/invalid|identifier|className/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('surfaces VW MNU when class is absent', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: 'MessageNotUnderstood: #definition for nil',
      }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_get_class_definition')!;

    const result = await tool.handler({ className: 'NoSuchClass' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/MessageNotUnderstood|absent|not found/i);
  });
});

describe('vw_list_methods', () => {
  it('returns pipe-separated side|category|selector records (carry-forward #43)', async () => {
    // Field separator: '|', record separator: ';' — chosen because the
    // bridge collapses whitespace (LF/CR/TAB) to space in JSON responses.
    const probeOutput =
      "'instance|accessing|name;instance|accessing|email;class|initialize|new;'";
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: probeOutput }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_list_methods')!;

    const result = await tool.handler({ className: 'Customer' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(Array.isArray(parsed)).toBe(true);
    expect(parsed).toEqual([
      { side: 'instance', category: 'accessing', selector: 'name' },
      { side: 'instance', category: 'accessing', selector: 'email' },
      { side: 'class', category: 'initialize', selector: 'new' },
    ]);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // Probe MUST use #43-safe separators.
    expect(probe).toContain("'|'");
    expect(probe).toContain("';'");
    expect(probe).not.toContain('Character lf');
    expect(probe).not.toContain('Character tab');
  });

  it('handles class with no methods (empty array)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_list_methods')!;

    const result = await tool.handler({ className: 'EmptyClass' });

    expect(result.isError).toBeFalsy();
    expect(JSON.parse(firstText(result))).toEqual([]);
  });

  it('skips malformed records (defensive)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'instance|accessing|name;malformed_no_pipes;class|init|new;'",
      }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_list_methods')!;

    const result = await tool.handler({ className: 'Customer' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toHaveLength(2);
    expect(parsed[0]?.selector).toBe('name');
    expect(parsed[1]?.selector).toBe('new');
  });

  it('rejects invalid class identifiers', async () => {
    const bridge = stubBridge();
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_list_methods')!;

    const result = await tool.handler({ className: 'Cls injection' });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});
