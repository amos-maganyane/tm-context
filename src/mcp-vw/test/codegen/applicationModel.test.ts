import { describe, it, expect, vi } from 'vitest';
import { makeCreateApplicationModelTool } from '../../src/codegen/applicationModel.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('vw_create_application_model — tool def', () => {
  it('exposes vw_create_application_model', () => {
    const tool = makeCreateApplicationModelTool(stubBridge());
    expect(tool.name).toBe('vw_create_application_model');
    expect(tool.description).toContain('NATIVE');
  });
});

describe('vw_create_application_model — happy path', () => {
  it('compiles class + N aspect accessors + N actions + windowSpec', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'PartySearchView',
      namespace: 'MyAppPackage',
      superclass: 'ApplicationModel',
      category: 'MyApp-UI',
      aspects: [
        { name: 'searchString' },
        { name: 'results', defaultExpression: 'OrderedCollection new' },
      ],
      actions: [
        { name: 'doSearch', body: 'results value: (self databaseSearch: searchString value)' },
      ],
      windowSpec: {
        window: { label: 'Party Search', bounds: [100, 100, 600, 400] },
        components: [
          {
            type: 'InputField',
            name: 'searchInput',
            model: 'searchString',
            layout: { l: 10, lf: 0, t: 10, tf: 0, r: -10, rf: 1, b: 30, bf: 0 },
          },
        ],
      },
    });

    expect(result.isError).toBeFalsy();
    // Expect at least: 1 class def + 2 aspect accessors + 1 action + 1 windowSpec = 5 POSTs.
    expect(sources.length).toBeGreaterThanOrEqual(5);

    // Class definition (defineClass: 8-kw form per s23 benchmark Bug 1 fix —
    // namespace placement is via the receiver, not a 6-kw inDictionary: selector).
    expect(sources[0]).toContain('Smalltalk.MyAppPackage defineClass: #PartySearchView');
    expect(sources[0]).toContain('superclass: #{Smalltalk.ApplicationModel}');
    expect(sources[0]).toContain("instanceVariableNames: 'searchString results'");

    // Aspect accessors — FQN receiver (s27 Bug A fix: scaffolder must thread
    // namespace through so non-Smalltalk namespaces work; namespace=Smalltalk
    // also emits FQN form for consistency, and `Smalltalk.X compile:` resolves
    // identically to bare `X compile:`).
    const aspectSrcs = sources.slice(1, 3);
    expect(aspectSrcs.some((s) => s.includes('MyAppPackage.PartySearchView compile:') && s.includes('searchString isNil'))).toBe(true);
    expect(aspectSrcs.some((s) => s.includes('results isNil') && s.includes('OrderedCollection new'))).toBe(true);

    // Action
    expect(sources.some((s) => s.includes('doSearch') && s.includes("classified: 'actions'"))).toBe(true);

    // windowSpec (class-side) — FQN receiver per s27 Bug A fix.
    expect(sources.some((s) => s.includes('MyAppPackage.PartySearchView class compile:') && s.includes('UI.FullSpec'))).toBe(true);
  });

  it('omits aspects + actions + windowSpec when not provided (minimal class only)', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'Minimal',
      namespace: 'MyApp',
      superclass: 'ApplicationModel',
    });

    expect(result.isError).toBeFalsy();
    expect(sources.length).toBe(1); // class def only
    // defineClass: 8-kw form per s23 benchmark Bug 1 fix.
    expect(sources[0]).toContain('Smalltalk.MyApp defineClass: #Minimal');
  });

  it('includes hook methods when provided', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    await tool.handler({
      className: 'Foo',
      namespace: 'MyApp',
      superclass: 'ApplicationModel',
      hooks: {
        'postBuildWith:': 'aBuilder componentAt: #searchInput',
        'postOpenWith:': 'self loadInitialData',
      },
    });

    expect(sources.some((s) => s.includes('postBuildWith:') && s.includes("classified: 'hooks'"))).toBe(true);
    expect(sources.some((s) => s.includes('postOpenWith:') && s.includes('loadInitialData'))).toBe(true);
  });
});

describe('vw_create_application_model — guards + validation', () => {
  it('refuses VWB.* namespace', async () => {
    const bridge = stubBridge();
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'VWB',
      superclass: 'Object',
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWB|#41|wedge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid aspect name', async () => {
    const bridge = stubBridge();
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'MyApp',
      superclass: 'Object',
      aspects: [{ name: "bad'aspect" }],
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('stops on first compile failure and reports which step', async () => {
    let callCount = 0;
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async () => {
        callCount++;
        if (callCount === 2) return { ok: false, error: 'compile failed: simulated' };
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'Foo',
      namespace: 'MyApp',
      superclass: 'Object',
      aspects: [{ name: 'iv1' }, { name: 'iv2' }],
    });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('compile failed: simulated');
  });
});

describe('vw_create_application_model — DataSet acceptance s23 Bug 6+ fix', () => {
  it('accepts DataSet component in embedded windowSpec without Zod rejection', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    const result = await tool.handler({
      className: 'TableViewApp',
      namespace: 'MyApp',
      superclass: 'ApplicationModel',
      aspects: [{ name: 'rows', defaultExpression: 'SelectionInList with: OrderedCollection new' }],
      windowSpec: {
        window: { label: 'Tbl', bounds: [0, 0, 400, 300] },
        components: [
          {
            type: 'DataSet',
            name: 'tbl',
            model: 'rows',
            columns: [
              { label: 'Name', width: 100, readSelector: 'yourself' },
              { label: 'Size', width: 60, readSelector: 'size', printSelector: 'printString' },
            ],
            layout: { l: 0, lf: 0, t: 0, tf: 0, r: 0, rf: 1, b: 0, bf: 1 },
          },
        ],
      },
    });

    expect(result.isError).toBeFalsy();
    // The windowSpec compile must have emitted DataSetSpec + DataSetColumnSpec literals.
    // s27 Bug A fix: receiver is FQN `MyApp.TableViewApp class`, not bare leaf.
    const wsSrc = sources.find((s) => s.includes('MyApp.TableViewApp class compile:'));
    expect(wsSrc).toBeDefined();
    expect(wsSrc).toContain('UI.DataSetSpec');
    expect(wsSrc).toContain('UI.DataSetColumnSpec');
    expect(wsSrc).toContain('#readSelector: #yourself');
    expect(wsSrc).toContain('#readSelector: #size');
    expect(wsSrc).toContain('#printSelector: #printString');
  });
});

// -----------------------------------------------------------------------------
// s27 Bug A — scaffolder must thread `namespace` into the compile receiver.
//
// Before s27, buildInstanceCompileExpression emitted just `${className}` as the
// receiver, regardless of the input namespace. That works for
// namespace=Smalltalk (bareword auto-resolves via the Smalltalk
// SystemDictionary) but FAILS for every other namespace — receiver evaluates
// to nil and the compile: step raises MNU #compile:classified:. After the fix
// every compile step (aspect / action / hook / windowSpec) emits the
// fully-qualified `${namespace}.${className}` receiver, which resolves
// correctly under any namespace AND remains correct for Smalltalk.
//
// Memory entity: `Scaffolder-unqualified-className-receiver-bug`.
// -----------------------------------------------------------------------------
describe('vw_create_application_model — namespace handling (s27 Bug A fix)', () => {
  it('emits FQN compile receiver for namespace=Smalltalk (consistency)', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    await tool.handler({
      className: 'Foo',
      namespace: 'Smalltalk',
      superclass: 'ApplicationModel',
      aspects: [{ name: 'bar' }],
      actions: [{ name: 'doIt', body: '^nil' }],
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    // class def + aspect + action + windowSpec = 4 sources
    expect(sources.length).toBe(4);
    // All compile steps (sources[1..]) emit FQN receiver.
    const compileSteps = sources.slice(1);
    for (const s of compileSteps) {
      expect(s).toMatch(/Smalltalk\.Foo (class )?compile:/);
    }
  });

  it('emits FQN compile receiver for namespace=Examples (the bug)', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    await tool.handler({
      className: 'Foo',
      namespace: 'Examples',
      superclass: 'ApplicationModel',
      aspects: [{ name: 'bar' }],
      actions: [{ name: 'doIt', body: '^nil' }],
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    expect(sources.length).toBe(4);
    const compileSteps = sources.slice(1);
    for (const s of compileSteps) {
      // s27 Bug A fix: every compile must qualify with the namespace.
      expect(s).toMatch(/Examples\.Foo (class )?compile:/);
      // Bug A symptom: bare-leaf `Foo compile:` would resolve to nil under
      // Examples context → MNU at runtime. Negative-match guards regression.
      // The lookbehind ensures we don't false-match the FQN form.
      expect(s).not.toMatch(/(?<![\w.])Foo (class )?compile:/);
    }
  });

  it('threads namespace through aspect + action + hook + windowSpec consistently', async () => {
    const sources: string[] = [];
    const bridge = stubBridge({
      postEval: vi.fn().mockImplementation(async (s: string) => {
        sources.push(s);
        return { ok: true, result: 'ok' };
      }),
    });
    const tool = makeCreateApplicationModelTool(bridge);

    await tool.handler({
      className: 'View',
      namespace: 'GemStoneClasses',
      superclass: 'ApplicationModel',
      aspects: [{ name: 'a1' }, { name: 'a2' }],
      actions: [{ name: 'act1', body: '^1' }],
      hooks: { 'postBuildWith:': 'aBuilder componentAt: #x' },
      windowSpec: {
        window: { label: 'x', bounds: [0, 0, 100, 100] },
        components: [],
      },
    });

    // class def + 2 aspects + 1 action + 1 hook + 1 windowSpec = 6 sources
    expect(sources.length).toBe(6);
    const compileSteps = sources.slice(1);
    expect(compileSteps.length).toBe(5);
    for (const s of compileSteps) {
      expect(s).toMatch(/GemStoneClasses\.View (class )?compile:/);
    }
    // Sanity: each category appears.
    expect(compileSteps.some((s) => s.includes("classified: 'aspects'") && s.includes('a1 isNil'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'aspects'") && s.includes('a2 isNil'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'actions'") && s.includes('act1'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'hooks'") && s.includes('postBuildWith:'))).toBe(true);
    expect(compileSteps.some((s) => s.includes("classified: 'interface specs'") && s.includes('UI.FullSpec'))).toBe(true);
  });
});
