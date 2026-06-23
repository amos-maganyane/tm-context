import { describe, it, expect, vi } from 'vitest';
import {
  emitLazyAspectAccessor,
  emitActionMethod,
  makeCompileMethodTool,
  makeDefineActionTool,
  makeDefineAspectTool,
} from '../../src/codegen/methods.js';
import { stubBridge, firstText } from '../_helpers.js';

// -----------------------------------------------------------------------------
// emitLazyAspectAccessor — pure
// -----------------------------------------------------------------------------

describe('emitLazyAspectAccessor', () => {
  it("emits canonical lazy pattern with '' asValue default", () => {
    const src = emitLazyAspectAccessor({ aspectName: 'searchString', defaultExpression: "''" });
    expect(src).toContain('searchString');
    expect(src).toContain("searchString isNil");
    expect(src).toContain("ifTrue: [searchString := '' asValue]");
    expect(src).toContain('ifFalse: [searchString]');
  });

  it('handles OrderedCollection default', () => {
    const src = emitLazyAspectAccessor({
      aspectName: 'results',
      defaultExpression: 'OrderedCollection new',
    });
    expect(src).toContain('results := OrderedCollection new asValue');
  });

  it('handles nil default', () => {
    const src = emitLazyAspectAccessor({
      aspectName: 'selected',
      defaultExpression: 'nil',
    });
    expect(src).toContain('selected := nil asValue');
  });

  it("uses '' asValue when defaultExpression is omitted", () => {
    const src = emitLazyAspectAccessor({ aspectName: 'name' });
    expect(src).toContain("name := '' asValue");
  });
});

// -----------------------------------------------------------------------------
// emitActionMethod — pure
// -----------------------------------------------------------------------------

describe('emitActionMethod', () => {
  it('emits selector + indented body', () => {
    const src = emitActionMethod({
      actionName: 'doSearch',
      body: 'results value: (self databaseSearch: searchString value)',
    });
    expect(src.startsWith('doSearch')).toBe(true);
    expect(src).toContain('results value: (self databaseSearch: searchString value)');
  });

  it('preserves multi-line body', () => {
    const src = emitActionMethod({
      actionName: 'accept',
      body: '| x |\nx := 42.\n^x',
    });
    expect(src).toContain('| x |');
    expect(src).toContain('x := 42.');
    expect(src).toContain('^x');
  });
});

// -----------------------------------------------------------------------------
// vw_compile_method
// -----------------------------------------------------------------------------

describe('vw_compile_method — tool def', () => {
  it('exposes vw_compile_method', () => {
    const tool = makeCompileMethodTool(stubBridge());
    expect(tool.name).toBe('vw_compile_method');
    expect(tool.description).toContain('#41');
  });
});

describe('vw_compile_method — happy path', () => {
  it('compiles on instance side when isMeta=false (or omitted)', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'a CompiledMethod' };
      }),
    });
    const tool = makeCompileMethodTool(bridge);

    await tool.handler({
      className: 'Customer',
      isMeta: false,
      category: 'accessing',
      source: 'name\n    ^name',
    });

    expect(lastSource).toContain('Customer compile:');
    expect(lastSource).not.toContain('Customer class compile:');
    expect(lastSource).toContain("classified: 'accessing'");
  });

  it('compiles on class side when isMeta=true', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'a CompiledMethod' };
      }),
    });
    const tool = makeCompileMethodTool(bridge);

    await tool.handler({
      className: 'Customer',
      isMeta: true,
      category: 'initialize',
      source: "defaultName\n    ^'Anonymous'",
    });

    expect(lastSource).toContain('Customer class compile:');
  });

  it('escapes apostrophes in source body', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCompileMethodTool(bridge);

    await tool.handler({
      className: 'Customer',
      category: 'accessing',
      source: "greeting\n    ^'don''t panic'",
    });

    // 'don''t panic' in source → 'don''''t panic' in compile: literal (quadruple-escaped)
    expect(lastSource).toContain("''''t panic");
  });
});

describe('vw_compile_method — #41 guard', () => {
  it('refuses VWB.VWBridge', async () => {
    const bridge = stubBridge();
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: 'VWB.VWBridge',
      category: 'accessing',
      source: 'foo\n    ^42',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWB|#41|wedge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('refuses any VWB.* class', async () => {
    const bridge = stubBridge();
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: 'VWB.SomeClass',
      category: 'accessing',
      source: 'foo\n    ^42',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('allows non-VWB classes', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'ok' }),
    });
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: 'MyApp.Customer',
      category: 'accessing',
      source: 'foo\n    ^42',
    });

    expect(result.isError).toBeFalsy();
    expect(bridge.postEval).toHaveBeenCalled();
  });
});

describe('vw_compile_method — validation', () => {
  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: "Bad'Class",
      category: 'accessing',
      source: 'foo\n    ^42',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects empty source', async () => {
    const bridge = stubBridge();
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      category: 'accessing',
      source: '',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects empty category', async () => {
    const bridge = stubBridge();
    const tool = makeCompileMethodTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      category: '',
      source: 'foo\n    ^42',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// vw_define_action
// -----------------------------------------------------------------------------

describe('vw_define_action', () => {
  it('compiles an instance-side action method in actions category', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeDefineActionTool(bridge);

    await tool.handler({
      className: 'PartySearchView',
      actionName: 'doSearch',
      body: 'results value: (self databaseSearch: searchString value)',
    });

    expect(lastSource).toContain('PartySearchView compile:');
    expect(lastSource).toContain("classified: 'actions'");
    expect(lastSource).toContain('doSearch');
  });

  it('refuses VWB.* className', async () => {
    const bridge = stubBridge();
    const tool = makeDefineActionTool(bridge);

    const result = await tool.handler({
      className: 'VWB.VWBridge',
      actionName: 'doFoo',
      body: '^42',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid actionName', async () => {
    const bridge = stubBridge();
    const tool = makeDefineActionTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      actionName: "bad'action",
      body: '^42',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// vw_define_aspect
// -----------------------------------------------------------------------------

describe('vw_define_aspect', () => {
  it('compiles a lazy-init accessor in aspects category', async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        // s23 Bug 2 fix: vw_define_aspect now probes allInstVarNames first.
        if (s.includes('allInstVarNames')) {
          return { ok: true, result: "'searchString;'" };
        }
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeDefineAspectTool(bridge);

    await tool.handler({
      className: 'PartySearchView',
      aspectName: 'searchString',
      defaultExpression: "''",
    });

    expect(lastSource).toContain('PartySearchView compile:');
    expect(lastSource).toContain("classified: 'aspects'");
    expect(lastSource).toContain('searchString isNil');
    expect(lastSource).toContain('asValue');
  });

  it("defaults to '' asValue when defaultExpression omitted", async () => {
    let lastSource: string | undefined;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        if (s.includes('allInstVarNames')) {
          return { ok: true, result: "'name;'" };
        }
        lastSource = s;
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeDefineAspectTool(bridge);

    await tool.handler({
      className: 'Foo',
      aspectName: 'name',
    });

    // The accessor source has `name := '' asValue`. The outer compile: string
    // wraps that, doubling every apostrophe → `''''` (4 quotes) in lastSource.
    expect(lastSource).toContain("name := '''' asValue");
  });

  it('refuses VWB.* className', async () => {
    const bridge = stubBridge();
    const tool = makeDefineAspectTool(bridge);

    const result = await tool.handler({
      className: 'VWB.VWBridge',
      aspectName: 'foo',
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid aspectName', async () => {
    const bridge = stubBridge();
    const tool = makeDefineAspectTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      aspectName: "bad'aspect",
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects when aspectName is not in allInstVarNames — s23 Bug 2 fix', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        if (s.includes('allInstVarNames')) {
          // Class has 'declaredOnly' as its only ivar — does NOT include 'undeclared'.
          return { ok: true, result: "'declaredOnly;'" };
        }
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeDefineAspectTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      aspectName: 'undeclared',
    });

    expect(result.isError).toBe(true);
    const text = firstText(result);
    expect(text).toMatch(/not a declared instance variable/i);
    expect(text).toMatch(/ResolvedDeferredBinding/i);
    expect(text).toMatch(/declaredOnly/);
    expect(text).toMatch(/s23 Bug 2/i);

    // Probe was called exactly once. Compile was NOT called (refused before).
    expect((bridge.postEval as unknown as ReturnType<typeof vi.fn>).mock.calls.length).toBe(1);
    expect((bridge.postEval as unknown as ReturnType<typeof vi.fn>).mock.calls[0][0]).toContain('allInstVarNames');
  });

  it('surfaces probe failure with hint about non-existent class — s23 Bug 2 fix', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        if (s.includes('allInstVarNames')) {
          // Class doesn't exist — bridge eval fails.
          return { ok: false, error: 'Message not understood: #allInstVarNames' };
        }
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeDefineAspectTool(bridge);

    const result = await tool.handler({
      className: 'NonExistentClass',
      aspectName: 'foo',
    });

    expect(result.isError).toBe(true);
    const text = firstText(result);
    expect(text).toMatch(/could not probe/i);
    expect(text).toMatch(/vw_create_class/i);
  });
});
