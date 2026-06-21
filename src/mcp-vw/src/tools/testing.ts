/**
 * testing.ts — vw_run_test_class + vw_run_test_method + vw_list_failing_tests (V2).
 *
 * SUnit gate tools using the canonical direct-invoke pattern (AGENTS.md
 * + carry-forward #20 + session-16 v2 with Notification-resume):
 *
 *   [[[tc setUp. tc perform: aSelector]
 *     on: Core.Notification do: [:nex | nex resume]]
 *     on: Core.Exception do: [:ex | ...]]
 *     ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]]
 *
 * NEVER `cls suite run` or `cls buildSuite` — those walk MAS-customized
 * `testClasses` (hundreds of GemStoneClasses.*Tests.*) and wedge the bridge
 * for 10-15 min. Direct-invoke is the proven-safe path.
 *
 * Per architecture.md §5.2 (tools 29, 30, 31).
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  splitOn,
  unquoteSmalltalkString,
  isValidClassIdentifier,
  isValidSelector,
  RECORD_SEP,
  FIELD_SEP,
} from '../smalltalk.js';
import type { ToolDef } from './types.js';

export function makeTestingTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    makeRunTestClassTool(bridge),
    makeRunTestMethodTool(bridge),
    makeListFailingTestsTool(bridge),
    makeDescribeTestFailureTool(bridge),
  ];
}

// -----------------------------------------------------------------------------
// Direct-invoke probe (single test method)
// -----------------------------------------------------------------------------

function buildSingleTestProbe(className: string, selector: string): string {
  return `| tc testFailureClass result errMsg |
tc := ${className} new.
testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
result := 'PASS'.
errMsg := ''.
[[[tc setUp. tc perform: #${selector}]
    on: Core.Notification do: [:nex | nex resume]]
    on: Core.Exception
    do: [:ex |
        (testFailureClass notNil and: [ex isKindOf: testFailureClass])
            ifTrue: [result := 'FAIL'. errMsg := ex messageText ifNil: [ex class name asString]]
            ifFalse: [result := 'ERR'. errMsg := ex class name asString , ': ' , (ex messageText ifNil: [''])]]]
    ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]].
result , '${FIELD_SEP}' , errMsg`;
}

// -----------------------------------------------------------------------------
// Direct-invoke probe (entire class — iterate local test* selectors)
// -----------------------------------------------------------------------------

function buildRunTestClassProbe(className: string): string {
  return `| cls s sep fieldSep |
cls := ${className}.
s := WriteStream on: String new.
sep := '${RECORD_SEP}'.
fieldSep := '${FIELD_SEP}'.
(cls selectors asSortedCollection select: [:sel | sel asString startsWith: 'test'])
    do: [:sel | | tc testFailureClass result errMsg |
        tc := cls new.
        testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
        result := 'PASS'.
        errMsg := ''.
        [[[tc setUp. tc perform: sel]
            on: Core.Notification do: [:nex | nex resume]]
            on: Core.Exception
            do: [:ex |
                (testFailureClass notNil and: [ex isKindOf: testFailureClass])
                    ifTrue: [result := 'FAIL'. errMsg := ex messageText ifNil: [ex class name asString]]
                    ifFalse: [result := 'ERR'. errMsg := ex class name asString , ': ' , (ex messageText ifNil: [''])]]]
            ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]].
        s nextPutAll: sel asString; nextPutAll: fieldSep.
        s nextPutAll: result; nextPutAll: fieldSep.
        s nextPutAll: errMsg; nextPutAll: sep].
s contents`;
}

interface TestResult {
  selector: string;
  result: 'PASS' | 'FAIL' | 'ERR';
  errorMessage: string;
}

interface SuiteSummary {
  className: string;
  total: number;
  passed: number;
  failed: number;
  errored: number;
  tests: TestResult[];
}

function parseTestResults(className: string, raw: string): SuiteSummary {
  const summary: SuiteSummary = {
    className,
    total: 0,
    passed: 0,
    failed: 0,
    errored: 0,
    tests: [],
  };
  for (const record of splitOn(raw, RECORD_SEP)) {
    const parts = record.split(FIELD_SEP);
    if (parts.length < 2) continue;
    const selector = parts[0] ?? '';
    const result = parts[1] ?? '';
    const errorMessage = parts.slice(2).join(FIELD_SEP);
    if (!selector || (result !== 'PASS' && result !== 'FAIL' && result !== 'ERR')) continue;
    summary.total++;
    if (result === 'PASS') summary.passed++;
    else if (result === 'FAIL') summary.failed++;
    else summary.errored++;
    summary.tests.push({ selector, result: result as TestResult['result'], errorMessage });
  }
  return summary;
}

// -----------------------------------------------------------------------------
// vw_run_test_class
// -----------------------------------------------------------------------------

const runTestClassSchema = {
  className: z.string().min(1).max(200).describe('TestCase subclass to run (e.g. "MyAppTest").'),
};

function makeRunTestClassTool(bridge: BridgeClientLike): ToolDef<typeof runTestClassSchema> {
  return {
    name: 'vw_run_test_class',
    description:
      'Run every test* selector on a TestCase class via the SAFE direct-invoke gate pattern (AGENTS.md + carry-forward #20 + Notification-resume). ' +
      'NEVER walks MAS-customized testClasses (which would wedge the bridge 10-15 min). ' +
      'Returns JSON suite summary: {className, total, passed, failed, errored, tests:[{selector, result, errorMessage}]}.',
    inputSchema: runTestClassSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_run_test_class: invalid className "${input.className}".`);
      }

      const evalResult = await bridge.postEval(buildRunTestClassProbe(input.className));
      if (!evalResult.ok) {
        return errorResult(
          `vw_run_test_class: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const summary = parseTestResults(input.className, raw);
      return { content: [text(JSON.stringify(summary))] };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_run_test_method
// -----------------------------------------------------------------------------

const runTestMethodSchema = {
  className: z.string().min(1).max(200),
  selector: z.string().min(1).max(200).describe('Single test method selector (e.g. "testSomething").'),
};

function makeRunTestMethodTool(bridge: BridgeClientLike): ToolDef<typeof runTestMethodSchema> {
  return {
    name: 'vw_run_test_method',
    description:
      'Run ONE test method on a TestCase class via the safe direct-invoke gate pattern. ' +
      'Returns JSON {className, selector, result, errorMessage} where result is PASS / FAIL / ERR.',
    inputSchema: runTestMethodSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_run_test_method: invalid className "${input.className}".`);
      }
      if (!isValidSelector(input.selector)) {
        return errorResult(`vw_run_test_method: invalid selector "${input.selector}".`);
      }

      const evalResult = await bridge.postEval(buildSingleTestProbe(input.className, input.selector));
      if (!evalResult.ok) {
        return errorResult(
          `vw_run_test_method: VW eval failed for ${input.className}>>${input.selector}: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const parts = raw.split(FIELD_SEP);
      const result = parts[0] ?? '';
      const errorMessage = parts.slice(1).join(FIELD_SEP);
      return {
        content: [
          text(
            JSON.stringify({
              className: input.className,
              selector: input.selector,
              result,
              errorMessage,
            })
          ),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_list_failing_tests
// -----------------------------------------------------------------------------

function makeListFailingTestsTool(
  bridge: BridgeClientLike
): ToolDef<typeof runTestClassSchema> {
  return {
    name: 'vw_list_failing_tests',
    description:
      'Run every test* selector on a TestCase class via the safe direct-invoke gate, then return ONLY the failures + errors (excludes passes). ' +
      'Returns JSON {className, total, failed, errored, failures:[{selector, result, errorMessage}]}. ' +
      'Concise diagnostic alternative to vw_run_test_class when you only care about what is broken.',
    inputSchema: runTestClassSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_list_failing_tests: invalid className "${input.className}".`);
      }

      const evalResult = await bridge.postEval(buildRunTestClassProbe(input.className));
      if (!evalResult.ok) {
        return errorResult(
          `vw_list_failing_tests: VW eval failed for ${input.className}: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const summary = parseTestResults(input.className, raw);
      const failures = summary.tests.filter((t) => t.result !== 'PASS');
      return {
        content: [
          text(
            JSON.stringify({
              className: summary.className,
              total: summary.total,
              failed: summary.failed,
              errored: summary.errored,
              failures,
            })
          ),
        ],
      };
    }),
  };
}

// -----------------------------------------------------------------------------
// vw_describe_test_failure (V3) — re-run + structured exception capture
// -----------------------------------------------------------------------------

function buildDescribeFailureProbe(className: string, selector: string): string {
  return `| tc testFailureClass exClass exMsg exStack fieldSep |
tc := ${className} new.
testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
exClass := ''.
exMsg := ''.
exStack := ''.
fieldSep := '${FIELD_SEP}'.
[[[tc setUp. tc perform: #${selector}]
    on: Core.Notification do: [:nex | nex resume]]
    on: Core.Exception
    do: [:ex |
        exClass := ex class name asString.
        exMsg := ex messageText ifNil: [''].
        "Capture brief stack: just the top-most senders."
        exStack := (thisContext sender printString)]]
    ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]].
exClass , fieldSep , exMsg , fieldSep , exStack`;
}

const describeFailureSchema = {
  className: z.string().min(1).max(200),
  selector: z.string().min(1).max(200),
};

function makeDescribeTestFailureTool(
  bridge: BridgeClientLike
): ToolDef<typeof describeFailureSchema> {
  return {
    name: 'vw_describe_test_failure',
    description:
      'Re-run a single failing test in isolation and capture structured exception details. ' +
      'Returns JSON {className, selector, exceptionClass, messageText, stackSnippet}. ' +
      'Use after vw_list_failing_tests to drill into WHY a specific test failed.',
    inputSchema: describeFailureSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      if (!isValidClassIdentifier(input.className)) {
        return errorResult(`vw_describe_test_failure: invalid className "${input.className}".`);
      }
      if (!isValidSelector(input.selector)) {
        return errorResult(`vw_describe_test_failure: invalid selector "${input.selector}".`);
      }

      const evalResult = await bridge.postEval(
        buildDescribeFailureProbe(input.className, input.selector)
      );
      if (!evalResult.ok) {
        return errorResult(
          `vw_describe_test_failure: VW eval failed: ${evalResult.error ?? '(no error)'}`
        );
      }
      const raw = unquoteSmalltalkString(evalResult.result ?? '');
      const parts = raw.split(FIELD_SEP);
      return {
        content: [
          text(
            JSON.stringify({
              className: input.className,
              selector: input.selector,
              exceptionClass: parts[0] ?? '',
              messageText: parts[1] ?? '',
              stackSnippet: parts.slice(2).join(FIELD_SEP),
            })
          ),
        ],
      };
    }),
  };
}
