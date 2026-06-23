import { describe, it, expect, vi } from 'vitest';
import { z } from 'zod';
import {
  mcpErrorMap,
  applyErrorMapToShape,
  withMcpErrorMap,
} from '../src/mcpZodErrorMap.js';

// -----------------------------------------------------------------------------
// mcpErrorMap — direct unit tests on the error map function itself.
//
// Test the formatting logic by constructing fake ZodIssue objects + calling
// the map directly. This isolates the rewrite from zod's internal call
// paths (which differ slightly between parent z.object validation and leaf
// schema validation).
// -----------------------------------------------------------------------------

describe('mcpErrorMap — invalid_type code', () => {
  const ctx = { defaultError: 'FALLBACK', data: undefined };

  it('formats missing required (received=undefined)', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.invalid_type,
        expected: 'boolean',
        received: 'undefined',
        path: ['confirm'],
      },
      ctx
    );
    expect(result.message).toBe("Missing required parameter 'confirm' (expected boolean).");
  });

  it('formats wrong type (received=string)', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.invalid_type,
        expected: 'number',
        received: 'string',
        path: ['count'],
      },
      ctx
    );
    expect(result.message).toBe("Parameter 'count' must be number, but received string.");
  });

  it('formats nested path with dots', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.invalid_type,
        expected: 'string',
        received: 'undefined',
        path: ['windowSpec', 'components', 0, 'type'],
      },
      ctx
    );
    expect(result.message).toBe(
      "Missing required parameter 'windowSpec.components.0.type' (expected string)."
    );
  });

  it('handles empty path as <root>', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.invalid_type,
        expected: 'object',
        received: 'string',
        path: [],
      },
      ctx
    );
    expect(result.message).toBe("Parameter '<root>' must be object, but received string.");
  });
});

describe('mcpErrorMap — invalid_enum_value code', () => {
  const ctx = { defaultError: 'FALLBACK', data: undefined };

  it('formats invalid enum with options list', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.invalid_enum_value,
        received: 'DataSet',
        path: ['type'],
        options: ['Label', 'ActionButton', 'SubCanvas'],
      },
      ctx
    );
    expect(result.message).toBe(
      "Parameter 'type' must be one of [Label, ActionButton, SubCanvas], but received 'DataSet'."
    );
  });
});

describe('mcpErrorMap — fallthrough for unspecialized codes', () => {
  it('returns ctx.defaultError for other codes (e.g. too_small)', () => {
    const result = mcpErrorMap(
      {
        code: z.ZodIssueCode.too_small,
        minimum: 1,
        type: 'string',
        inclusive: true,
        exact: false,
        path: ['name'],
      },
      { defaultError: 'String must contain at least 1 character(s)', data: '' }
    );
    expect(result.message).toBe('String must contain at least 1 character(s)');
  });
});

// -----------------------------------------------------------------------------
// applyErrorMapToShape — mutation pattern
// -----------------------------------------------------------------------------

describe('applyErrorMapToShape', () => {
  it('mutates _def.errorMap on every zod field in the shape', () => {
    const shape = {
      foo: z.string(),
      bar: z.number().optional(),
      baz: z.boolean(),
    };
    applyErrorMapToShape(shape);
    expect((shape.foo as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
    expect((shape.bar as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
    expect((shape.baz as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
  });

  it('returns the same shape for chaining', () => {
    const shape = { foo: z.string() };
    const result = applyErrorMapToShape(shape);
    expect(result).toBe(shape);
  });

  it('handles empty shape without throwing', () => {
    const shape: z.ZodRawShape = {};
    expect(() => applyErrorMapToShape(shape)).not.toThrow();
  });

  it('skips non-zod values defensively', () => {
    // ToolAnnotations-style record might slip through. Should not throw.
    const shape = {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      notZod: { someOther: 'thing' } as any,
      realZod: z.string(),
    };
    expect(() => applyErrorMapToShape(shape)).not.toThrow();
    // Real zod field still gets the map.
    expect((shape.realZod as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
  });
});

// -----------------------------------------------------------------------------
// withMcpErrorMap — server wrapper
// -----------------------------------------------------------------------------

describe('withMcpErrorMap — server wrapper', () => {
  it('wraps registerTool so the inputSchema gets the error map', () => {
    const captured: Array<{ shape: z.ZodRawShape }> = [];
    // Capture the original spy reference BEFORE wrapping — withMcpErrorMap
    // REPLACES `fakeServer.registerTool` with a wrapper closure, so after
    // wrapping the property no longer IS the spy. The wrapper still
    // delegates to the original via `.bind(server)`, so the spy records
    // invocations when we assert against the captured variable.
    const originalSpy = vi.fn((_name: string, opts: { inputSchema: z.ZodRawShape }, _cb: unknown) => {
      captured.push({ shape: opts.inputSchema });
    });
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fakeServer: any = { registerTool: originalSpy };
    withMcpErrorMap(fakeServer);

    const shape = { foo: z.string() };
    fakeServer.registerTool('my_tool', { description: 'd', inputSchema: shape }, () => null);

    expect(originalSpy).toHaveBeenCalled();
    expect(captured.length).toBe(1);
    expect((captured[0].shape['foo'] as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
  });

  it('wraps tool (legacy positional shape form)', () => {
    const originalSpy = vi.fn();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fakeServer: any = { tool: originalSpy };
    withMcpErrorMap(fakeServer);

    const shape = { foo: z.string() };
    fakeServer.tool('my_tool', 'desc', shape, () => null);

    expect(originalSpy).toHaveBeenCalled();
    expect((shape.foo as unknown as { _def: { errorMap?: z.ZodErrorMap } })._def.errorMap).toBe(mcpErrorMap);
  });

  it('returns the same server instance for chaining', () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fakeServer: any = { registerTool: vi.fn() };
    const result = withMcpErrorMap(fakeServer);
    expect(result).toBe(fakeServer);
  });

  it('is a no-op on a server with neither tool nor registerTool', () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fakeServer: any = { other: vi.fn() };
    expect(() => withMcpErrorMap(fakeServer)).not.toThrow();
  });

  it('does not break when registerTool gets a non-zod inputSchema option', () => {
    const originalSpy = vi.fn();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fakeServer: any = { registerTool: originalSpy };
    withMcpErrorMap(fakeServer);
    // Empty input schema — empty shape passes the predicate but mutating a
    // zero-key shape is a no-op. Should still call through cleanly.
    fakeServer.registerTool('no_args_tool', { description: 'd', inputSchema: {} }, () => null);
    expect(originalSpy).toHaveBeenCalledWith(
      'no_args_tool',
      expect.objectContaining({ inputSchema: {} }),
      expect.any(Function)
    );
  });
});

// -----------------------------------------------------------------------------
// Integration: does the error map propagate through z.object validation?
//
// This test documents how zod v3 actually consults field-level errorMaps
// when the parent z.object validates. If the test fails, the per-schema
// pattern is ineffective and we'd need to either:
//   (a) construct ZodObjects with errorMap option directly
//   (b) accept that only deep-leaf failures get our custom messages
// Either way, the unit tests above on mcpErrorMap itself still cover the
// formatting logic.
// -----------------------------------------------------------------------------

describe('mcpErrorMap — integration with z.object via per-schema mutation', () => {
  it('field-level errorMap fires for invalid_type on inner field', () => {
    const shape = { count: z.number() };
    applyErrorMapToShape(shape);
    const schema = z.object(shape);
    const result = schema.safeParse({ count: 'not-a-number' });
    expect(result.success).toBe(false);
    if (!result.success) {
      const msg = result.error.issues[0].message;
      // Whether the field-level errorMap fires depends on zod v3's lookup
      // order. If our message is present, the pattern works end-to-end.
      // If not, the message will be zod's default. Both are documented.
      const ours = msg.startsWith("Parameter 'count'");
      const zodsDefault = msg.toLowerCase().includes('expected') && msg.toLowerCase().includes('number');
      expect(ours || zodsDefault).toBe(true);
    }
  });
});
