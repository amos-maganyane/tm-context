import { describe, it, expect, vi } from 'vitest';
import {
  makeCreateClassTool,
  emitCreateClassSmalltalk,
} from '../../src/codegen/class.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('emitCreateClassSmalltalk — pure emitter', () => {
  it('emits canonical subclass: form with single-segment names', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Customer',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['name', 'email'],
      classVariableNames: [],
      poolDictionaries: [],
      category: 'MyApp-Model',
    });

    expect(src).toContain('subclass: #Customer');
    expect(src).toContain("instanceVariableNames: 'name email'");
    expect(src).toContain("classVariableNames: ''");
    expect(src).toContain("poolDictionaries: ''");
    expect(src).toContain("inDictionary: 'Smalltalk'");
    expect(src).toContain("category: 'MyApp-Model'");
  });

  it('handles empty instance + class variables', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Empty',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src).toContain("instanceVariableNames: ''");
    expect(src).toContain("classVariableNames: ''");
  });

  it('joins multiple instance variables with single space', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Multi',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['a', 'b', 'c', 'd'],
      classVariableNames: ['X', 'Y'],
      poolDictionaries: [],
    });

    expect(src).toContain("instanceVariableNames: 'a b c d'");
    expect(src).toContain("classVariableNames: 'X Y'");
  });

  it('joins pool dictionaries with single space', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: ['Pool1', 'Pool2'],
    });

    expect(src).toContain("poolDictionaries: 'Pool1 Pool2'");
  });

  it('omits category when not provided', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    // No category line at all.
    expect(src).not.toMatch(/category:\s*'/);
  });

  it('supports namespace-qualified superclass', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Painter',
      namespace: 'MyApp',
      superclass: 'Tools.UIPainter',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src.startsWith('Tools.UIPainter subclass: #Painter')).toBe(true);
    expect(src).toContain("inDictionary: 'MyApp'");
  });

  it('escapes apostrophes in category', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
      category: "MyApp's Category",
    });

    // Doubled apostrophe in Smalltalk literal.
    expect(src).toContain("category: 'MyApp''s Category'");
  });
});

describe('vw_create_class — registration', () => {
  it('exposes vw_create_class', () => {
    const tool = makeCreateClassTool(stubBridge());
    expect(tool.name).toBe('vw_create_class');
    expect(tool.description.length).toBeGreaterThan(40);
  });

  it('description mentions native-typed + namespace guard', () => {
    const tool = makeCreateClassTool(stubBridge());
    expect(tool.description.toLowerCase()).toMatch(/native|typed|json/i);
    expect(tool.description).toContain('#41');
  });
});

describe('vw_create_class — happy path', () => {
  it('posts emitted Smalltalk to /eval and returns success', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'Customer' }),
    });
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Customer',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['name', 'email'],
      classVariableNames: [],
      poolDictionaries: [],
      category: 'MyApp-Model',
    });

    expect(result.isError).toBeFalsy();
    expect(firstText(result)).toMatch(/Customer|created/i);
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('subclass: #Customer');
    expect(probe).toContain("inDictionary: 'Smalltalk'");
  });

  it('uses sensible defaults for omitted fields', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'Foo' }),
    });
    const tool = makeCreateClassTool(bridge);

    await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
    });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain("instanceVariableNames: ''");
    expect(probe).toContain("classVariableNames: ''");
    expect(probe).toContain("poolDictionaries: ''");
  });
});

describe('vw_create_class — carry-forward #41 guard (VWB.* refusal)', () => {
  it('refuses namespace="VWB"', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'NewClass',
      namespace: 'VWB',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/#41|VWB|wedge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('refuses className starting with VWB.', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'VWB.Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/#41|VWB|wedge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

describe('vw_create_class — validation', () => {
  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: "Bad'Class",
      namespace: 'Smalltalk',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/invalid|className/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid namespace', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'bad ns',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid superclass identifier', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: "Object'; bad",
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid instance variable names', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['valid', "bad'name"],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/instance|variable|identifier/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

describe('vw_create_class — bridge failures', () => {
  it('surfaces in-band MNU as isError', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: "namespace 'NonexistentNS' does not exist",
      }),
    });
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'NonexistentNS',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('NonexistentNS');
  });

  it('surfaces network failures via formatBridgeError', async () => {
    const networkErr = new TypeError('fetch failed');
    (networkErr as TypeError & { cause: { code: string } }).cause = { code: 'ECONNREFUSED' };
    const bridge = stubBridge({
      postEval: vi.fn().mockRejectedValue(networkErr),
    });
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/ECONNREFUSED|bridge|down/i);
  });
});
