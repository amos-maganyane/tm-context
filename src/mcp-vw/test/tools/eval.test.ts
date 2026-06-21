import { describe, it, expect, vi } from 'vitest';
import { makeEvalTool } from '../../src/tools/eval.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('vw_eval — tool def', () => {
  it('exposes vw_eval with a source input', () => {
    const tool = makeEvalTool(stubBridge());
    expect(tool.name).toBe('vw_eval');
    expect(tool.description.length).toBeGreaterThan(40);
    expect(tool.inputSchema['source']).toBeDefined();
  });

  it('description steers AI toward typed tools first', () => {
    const tool = makeEvalTool(stubBridge());
    // "Use vw_create_class etc FIRST" hint per architecture.md §5.1 row 4.
    expect(tool.description.toLowerCase()).toMatch(/escape hatch|first|prefer|typed|vw_create/i);
  });
});

describe('vw_eval — happy path', () => {
  it('passes source to bridge.postEval and returns the result string', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: '3' }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: '1 + 2' });

    expect(result.isError).toBeFalsy();
    expect(firstText(result)).toContain('3');
    expect(bridge.postEval).toHaveBeenCalledWith('1 + 2');
  });

  it('preserves multi-line source verbatim', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: '#(1 2 3)' }),
    });
    const tool = makeEvalTool(bridge);
    const source = '| a |\na := #(1 2 3).\na';

    await tool.handler({ source });

    expect(bridge.postEval).toHaveBeenCalledWith(source);
  });
});

describe('vw_eval — Bug #5 substring guard (carry-forward #5 + #28)', () => {
  it('rejects source containing BOTH "VWBridge" AND "dispatch"', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: 'VWBridge singleton handleSomething dispatch',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/#5|recursive|dispatch|both.*substring/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('allows source containing ONLY "VWBridge"', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a Symbol' }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: 'VWB.VWBridge name' });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
  });

  it('allows source containing ONLY "dispatch"', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'ok' }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: 'self performDispatch: #foo' });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
  });

  it('error message suggests a workaround', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: 'VWBridge singleton dispatch: #foo',
    });

    expect(result.isError).toBe(true);
    // Should hint at handleX direct call or rephrasing
    expect(firstText(result)).toMatch(/direct|handle|workaround|rephrase|router/i);
  });
});

describe('vw_eval — carry-forward #41 guard (compile-on-VWB.*)', () => {
  it('rejects source that compiles on VWB.VWBridge', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: "VWB.VWBridge compile: 'foo ^42' classified: 'temp'",
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/#41|wedge|VWB\.|VWB namespace/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects source that compiles on VWB.VWBridge class (metaclass)', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: "VWB.VWBridge class compile: 'foo ^42' classified: 'cat'",
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects any VWB.* compile target (not just VWBridge)', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: "VWB.SomeOtherClass compile: 'method ^1'",
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('allows compile: on non-VWB classes (e.g. MAS application code)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a CompiledMethod' }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({
      source: "Customer compile: 'name ^name' classified: 'accessing'",
    });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
  });

  it('allows references to VWB.VWBridge that are NOT compile (reads are OK)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a String' }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: 'VWB.VWBridge name' });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalled();
  });

  it('does NOT match VWBridgeOther.compile: (different namespace prefix)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'ok' }),
    });
    const tool = makeEvalTool(bridge);

    // "VWBridgeFoo" is its own identifier, not "VWB" namespace.
    const result = await tool.handler({
      source: "VWBridgeFoo compile: 'method'",
    });

    expect(result.isError).toBeFalsy();
  });
});

describe('vw_eval — in-band failures', () => {
  it('returns isError when bridge.postEval responds {ok:false, error:...}', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: 'MessageNotUnderstood: #fooBar in Integer 42',
      }),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: '42 fooBar' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('MessageNotUnderstood');
  });

  it('returns isError when bridge connection fails', async () => {
    const networkErr = new TypeError('fetch failed');
    (networkErr as TypeError & { cause: { code: string } }).cause = { code: 'ECONNREFUSED' };
    const bridge = stubBridge({
      postEval: vi.fn().mockRejectedValue(networkErr),
    });
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: '1 + 1' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/not responding|ECONNREFUSED|bridge/i);
  });
});

describe('vw_eval — input validation', () => {
  it('rejects empty source', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: '' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/empty|required|source/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects whitespace-only source', async () => {
    const bridge = stubBridge();
    const tool = makeEvalTool(bridge);

    const result = await tool.handler({ source: '   \n\t  ' });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});
