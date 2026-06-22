import { describe, it, expect, vi } from 'vitest';
import {
  makeCreateClassTool,
  emitCreateClassSmalltalk,
} from '../../src/codegen/class.js';
import { stubBridge, firstText } from '../_helpers.js';

// -----------------------------------------------------------------------------
// Pure emitter tests — canonical Cincom VW defineClass: 8-kw form.
//
// Rewritten per session 23 benchmark Bug 1: the legacy 6-kw
//   `Object subclass: #X ... inDictionary: 'NS' category: '...'`
// selector does NOT exist in Cincom VW 9.3.1 (verified live: false). The
// canonical form actually understood by the image is:
//
//   Smalltalk.<NS> defineClass: #ClassName
//       superclass: #{<Superclass>}
//       indexedType: #none
//       private: false
//       instanceVariableNames: '...'
//       classInstanceVariableNames: ''
//       imports: ''
//       category: '...'
//
// This 8-kw form has NO `classVariableNames` or `poolDictionaries` keywords;
// non-empty inputs for those fields are now rejected at the handler layer.
// -----------------------------------------------------------------------------

describe('emitCreateClassSmalltalk — pure emitter (defineClass: form)', () => {
  it('produces full canonical defineClass: 8-kw output for a typical class', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['bar', 'baz'],
      classVariableNames: [],
      poolDictionaries: [],
      category: 'MyCat',
    });

    const expected = [
      'Smalltalk defineClass: #Foo',
      '    superclass: #{Smalltalk.Object}',
      '    indexedType: #none',
      '    private: false',
      "    instanceVariableNames: 'bar baz'",
      "    classInstanceVariableNames: ''",
      "    imports: ''",
      "    category: 'MyCat'",
    ].join('\n');

    expect(src).toBe(expected);
  });

  it('emits canonical defineClass: form with Smalltalk root namespace', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Customer',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['name', 'email'],
      classVariableNames: [],
      poolDictionaries: [],
      category: 'MyApp-Model',
    });

    expect(src).toContain('Smalltalk defineClass: #Customer');
    expect(src).toContain('superclass: #{Smalltalk.Object}');
    expect(src).toContain('indexedType: #none');
    expect(src).toContain('private: false');
    expect(src).toContain("instanceVariableNames: 'name email'");
    expect(src).toContain("classInstanceVariableNames: ''");
    expect(src).toContain("imports: ''");
    expect(src).toContain("category: 'MyApp-Model'");
  });

  it('emits empty instanceVariableNames + classInstanceVariableNames + imports when not provided', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Empty',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src).toContain("instanceVariableNames: ''");
    expect(src).toContain("classInstanceVariableNames: ''");
    expect(src).toContain("imports: ''");
  });

  it('joins multiple instance variables with single space', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Multi',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: ['a', 'b', 'c', 'd'],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src).toContain("instanceVariableNames: 'a b c d'");
  });

  it('emits empty category when not provided (defineClass: requires the keyword)', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src).toContain("category: ''");
  });

  it('uses Smalltalk.<NS> receiver for child namespace + uses dotted superclass as-is in #{}', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Painter',
      namespace: 'MyApp',
      superclass: 'Tools.UIPainter',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(src.startsWith('Smalltalk.MyApp defineClass: #Painter')).toBe(true);
    expect(src).toContain('superclass: #{Tools.UIPainter}');
  });

  it('prefixes bare superclass with Smalltalk. to leverage import chain', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'OrderedCollection',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    // Bare identifier (no dot) gets the Smalltalk. prefix in the literal.
    expect(src).toContain('superclass: #{Smalltalk.OrderedCollection}');
  });

  it('preserves namespace-qualified superclass starting with Smalltalk. as-is', () => {
    const src = emitCreateClassSmalltalk({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Smalltalk.Object',
      instanceVariableNames: [],
      classVariableNames: [],
      poolDictionaries: [],
    });

    // Already-qualified superclass goes into the literal verbatim.
    expect(src).toContain('superclass: #{Smalltalk.Object}');
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
  it('posts emitted defineClass: Smalltalk to /eval and returns success', async () => {
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
    expect(probe).toContain('Smalltalk defineClass: #Customer');
    expect(probe).toContain('superclass: #{Smalltalk.Object}');
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
    expect(probe).toContain("classInstanceVariableNames: ''");
    expect(probe).toContain("imports: ''");
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

  it('rejects non-empty classVariableNames (defineClass: form has no classVariableNames keyword)', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      classVariableNames: ['CV1'],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/classVariableNames|defineClass/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects non-empty poolDictionaries (defineClass: form has no poolDictionaries keyword)', async () => {
    const bridge = stubBridge();
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      poolDictionaries: ['SomePool'],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/poolDictionaries|defineClass|imports/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('still accepts empty classVariableNames + poolDictionaries arrays (backwards compat)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'Foo' }),
    });
    const tool = makeCreateClassTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'Object',
      classVariableNames: [],
      poolDictionaries: [],
    });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
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
