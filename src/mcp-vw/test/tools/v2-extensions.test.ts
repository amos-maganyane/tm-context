import { describe, it, expect, vi } from 'vitest';
import { makeReadingTools } from '../../src/tools/reading.js';
import { makeNavigationTools } from '../../src/tools/navigation.js';
import { makeUiInspectTools } from '../../src/tools/ui_inspect.js';
import { makeTestingTools } from '../../src/tools/testing.js';
import { stubBridge, firstText } from '../_helpers.js';

// -----------------------------------------------------------------------------
// vw_describe_class
// -----------------------------------------------------------------------------

describe('vw_describe_class', () => {
  it('parses DEF + CMT + IM/CM tagged records into structured shape', async () => {
    const probeOutput =
      "'DEF|MyClass subclass: #Customer ...;CMT|A customer record;IM|accessing|name;IM|accessing|email;CM|initialize|new;'";
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: probeOutput }),
    });
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_describe_class')!;

    const result = await tool.handler({ className: 'Customer' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.className).toBe('Customer');
    expect(parsed.definition).toContain('subclass: #Customer');
    expect(parsed.comment).toBe('A customer record');
    expect(parsed.instanceMethods).toHaveLength(2);
    expect(parsed.instanceMethods[0]).toEqual({ category: 'accessing', selector: 'name' });
    expect(parsed.classMethods).toHaveLength(1);
    expect(parsed.classMethods[0]).toEqual({ category: 'initialize', selector: 'new' });
  });

  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeReadingTools(bridge).find((t) => t.name === 'vw_describe_class')!;
    const result = await tool.handler({ className: "Bad'Class" });
    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// vw_find_implementors
// -----------------------------------------------------------------------------

describe('vw_find_implementors', () => {
  it('returns JSON array of Class>>selector implementing pairs', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'Customer>>printOn:;Object>>printOn:;'",
      }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_implementors')!;

    const result = await tool.handler({ selector: 'printOn:' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(['Customer>>printOn:', 'Object>>printOn:']);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('includesSelector');
    expect(probe).toContain('#printOn:');
  });

  it('rejects invalid selector', async () => {
    const bridge = stubBridge();
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_implementors')!;
    const result = await tool.handler({ selector: "bad'sel" });
    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// vw_find_references_to
// -----------------------------------------------------------------------------

describe('vw_find_references_to', () => {
  it('returns JSON array of methods referencing a global', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'Foo>>useBar;FooTest>>testBar;'",
      }),
    });
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_references_to')!;

    const result = await tool.handler({ globalName: 'Bar' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(['Foo>>useBar', 'FooTest>>testBar']);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('#Bar');
    expect(probe).toContain('literals');
  });

  it('rejects invalid globalName', async () => {
    const bridge = stubBridge();
    const tool = makeNavigationTools(bridge).find((t) => t.name === 'vw_find_references_to')!;
    const result = await tool.handler({ globalName: 'lowercase' });
    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// vw_get_widget_value
// -----------------------------------------------------------------------------

describe('vw_get_widget_value', () => {
  it('GETs /value with aspect + optional windowTitle', async () => {
    const bridge = stubBridge({
      getJson: vi.fn().mockResolvedValue({ ok: true, aspect: 'searchString', value: 'Smith' }),
    });
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_get_widget_value')!;

    const result = await tool.handler({ aspect: 'searchString', windowTitle: 'Party Search' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.value).toBe('Smith');
    const calledPath = vi.mocked(bridge.getJson).mock.calls[0]?.[0] ?? '';
    expect(calledPath).toContain('/value?');
    expect(calledPath).toContain('aspect=searchString');
    expect(calledPath).toContain('windowTitle=Party+Search');
  });

  it('rejects empty aspect', async () => {
    const bridge = stubBridge();
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_get_widget_value')!;
    const result = await tool.handler({ aspect: '' });
    expect(result.isError).toBe(true);
    expect(bridge.getJson).not.toHaveBeenCalled();
  });
});

// -----------------------------------------------------------------------------
// testing tools (3)
// -----------------------------------------------------------------------------

describe('testing tools — registration', () => {
  it('returns 4 tool defs (V2 + V3 vw_describe_test_failure)', () => {
    const tools = makeTestingTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_describe_test_failure',
      'vw_list_failing_tests',
      'vw_run_test_class',
      'vw_run_test_method',
    ]);
  });
});

describe('vw_run_test_class', () => {
  it('parses PASS/FAIL/ERR records into JSON summary', async () => {
    const probeOutput =
      "'testOne|PASS|;testTwo|FAIL|expected 1 got 2;testThree|ERR|MessageNotUnderstood: #foo;'";
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: probeOutput }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_class')!;

    const result = await tool.handler({ className: 'MyTest' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.className).toBe('MyTest');
    expect(parsed.total).toBe(3);
    expect(parsed.passed).toBe(1);
    expect(parsed.failed).toBe(1);
    expect(parsed.errored).toBe(1);
    expect(parsed.tests).toHaveLength(3);
    expect(parsed.tests[0]).toEqual({ selector: 'testOne', result: 'PASS', errorMessage: '' });
    expect(parsed.tests[1]).toEqual({
      selector: 'testTwo',
      result: 'FAIL',
      errorMessage: 'expected 1 got 2',
    });
  });

  it('uses direct-invoke gate pattern (#20)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_class')!;

    await tool.handler({ className: 'MyTest' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // Should NOT use cls suite run / cls buildSuite (would walk MAS testClasses).
    expect(probe).not.toMatch(/suite\s+run/);
    expect(probe).not.toMatch(/buildSuite\b/);
    // Should use Notification-resume + Core.Exception catch.
    expect(probe).toContain('Core.Notification');
    expect(probe).toContain('Core.Exception');
    expect(probe).toContain('ensure:');
  });

  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_class')!;
    const result = await tool.handler({ className: "Bad'" });
    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

describe('vw_run_test_method', () => {
  it('returns single test result with selector + result', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "'PASS|'" }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_method')!;

    const result = await tool.handler({ className: 'MyTest', selector: 'testFoo' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.result).toBe('PASS');
    expect(parsed.className).toBe('MyTest');
    expect(parsed.selector).toBe('testFoo');
  });

  it('captures error messages on FAIL', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'FAIL|expected 1 but got 2'",
      }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_method')!;

    const result = await tool.handler({ className: 'MyTest', selector: 'testBar' });

    const parsed = JSON.parse(firstText(result));
    expect(parsed.result).toBe('FAIL');
    expect(parsed.errorMessage).toBe('expected 1 but got 2');
  });

  it('rejects invalid selector', async () => {
    const bridge = stubBridge();
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_run_test_method')!;
    const result = await tool.handler({ className: 'MyTest', selector: "bad'" });
    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

describe('vw_list_failing_tests', () => {
  it('returns ONLY failures + errors (no passes)', async () => {
    const probeOutput =
      "'testOne|PASS|;testTwo|FAIL|expected 1 got 2;testThree|ERR|MessageNotUnderstood: #foo;testFour|PASS|;'";
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: probeOutput }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_list_failing_tests')!;

    const result = await tool.handler({ className: 'MyTest' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.className).toBe('MyTest');
    expect(parsed.total).toBe(4);
    expect(parsed.failed).toBe(1);
    expect(parsed.errored).toBe(1);
    expect(parsed.failures).toHaveLength(2);
    expect(parsed.failures.every((f: { result: string }) => f.result !== 'PASS')).toBe(true);
  });

  it('returns empty failures when all pass', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "'testOne|PASS|;testTwo|PASS|;'" }),
    });
    const tool = makeTestingTools(bridge).find((t) => t.name === 'vw_list_failing_tests')!;

    const result = await tool.handler({ className: 'MyTest' });

    const parsed = JSON.parse(firstText(result));
    expect(parsed.failures).toEqual([]);
    expect(parsed.failed).toBe(0);
    expect(parsed.errored).toBe(0);
  });
});
