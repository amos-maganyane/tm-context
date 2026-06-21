import { describe, it, expect, vi } from 'vitest';
import {
  text,
  errorResult,
  safeHandler,
  formatBridgeError,
  BridgeError,
  type ToolResult,
} from '../src/util.js';

// Local helper: type-narrow the first content block as text.
function firstTextOf(r: ToolResult): string {
  const c = r.content[0];
  if (!c || c.type !== 'text') throw new Error(`expected text content, got ${JSON.stringify(c)}`);
  return c.text;
}

describe('text()', () => {
  it('wraps a string as MCP TextContent', () => {
    expect(text('hello')).toEqual({ type: 'text', text: 'hello' });
  });

  it('handles empty string', () => {
    expect(text('')).toEqual({ type: 'text', text: '' });
  });

  it('handles multi-line text without modification', () => {
    expect(text('a\nb\nc')).toEqual({ type: 'text', text: 'a\nb\nc' });
  });
});

describe('errorResult()', () => {
  it('wraps a message as a tool result with isError:true', () => {
    expect(errorResult('boom')).toEqual({
      content: [{ type: 'text', text: 'boom' }],
      isError: true,
    });
  });

  it('preserves multi-line recovery-action messages', () => {
    const msg =
      'VW Bridge is not responding at http://127.0.0.1:9876.\n' +
      'Check that the VisualWorks image is running and the bridge is started.';
    expect(errorResult(msg)).toEqual({
      content: [{ type: 'text', text: msg }],
      isError: true,
    });
  });
});

describe('safeHandler()', () => {
  it('passes through happy-path result', async () => {
    const handler = vi.fn(async (input: { x: number }): Promise<ToolResult> => ({
      content: [{ type: 'text', text: `got ${input.x}` }],
    }));
    const wrapped = safeHandler(handler);
    const result = await wrapped({ x: 42 });
    expect(result).toEqual({ content: [{ type: 'text', text: 'got 42' }] });
    expect(handler).toHaveBeenCalledWith({ x: 42 });
  });

  it('converts synchronous throws into errorResult', async () => {
    const wrapped = safeHandler(async () => {
      throw new Error('synchronous boom');
    });
    const result = await wrapped({});
    expect(result.isError).toBe(true);
    expect(firstTextOf(result)).toContain('synchronous boom');
  });

  it('converts async rejections into errorResult', async () => {
    const wrapped = safeHandler(
      () =>
        new Promise<ToolResult>((_, reject) => {
          setTimeout(() => reject(new Error('async boom')), 1);
        })
    );
    const result = await wrapped({});
    expect(result.isError).toBe(true);
    expect(firstTextOf(result)).toContain('async boom');
  });

  it('formats BridgeError 401 with auth recovery action', async () => {
    const wrapped = safeHandler(async () => {
      throw new BridgeError(401, 'unauthorized');
    });
    const result = await wrapped({});
    expect(result.isError).toBe(true);
    const message = firstTextOf(result);
    expect(message).toContain('401');
    expect(message).toMatch(/token/i);
    expect(message).toMatch(/cold start|rotate|restart/i);
  });

  it('formats non-Error throws as readable string', async () => {
    const wrapped = safeHandler(async () => {
      // Anti-pattern but must not crash safeHandler.
      // eslint-disable-next-line @typescript-eslint/no-throw-literal
      throw 'plain string thrown';
    });
    const result = await wrapped({});
    expect(result.isError).toBe(true);
    expect(firstTextOf(result)).toContain('plain string thrown');
  });

  it('never throws out of the wrapper (protocol guarantee)', async () => {
    // Even nightmarish throws (undefined, null, objects with circular refs)
    // must not escape — protocol-level errors may disconnect the MCP client.
    const wrapped = safeHandler(async () => {
      // eslint-disable-next-line @typescript-eslint/no-throw-literal
      throw undefined;
    });
    await expect(wrapped({})).resolves.toBeDefined();
  });
});

describe('formatBridgeError()', () => {
  it('formats 401 with auth recovery action', () => {
    const msg = formatBridgeError(new BridgeError(401, 'unauthorized'));
    expect(msg).toContain('401');
    expect(msg).toMatch(/token/i);
    expect(msg).toMatch(/cold start|rotate|re-read/i);
  });

  it('formats 403 with token-mismatch hint', () => {
    const msg = formatBridgeError(new BridgeError(403, 'forbidden'));
    expect(msg).toContain('403');
    expect(msg).toMatch(/token|forbidden|refused/i);
  });

  it('formats 404 with endpoint-not-found hint', () => {
    const msg = formatBridgeError(new BridgeError(404, 'not found'));
    expect(msg).toContain('404');
    expect(msg).toMatch(/endpoint|version|update/i);
  });

  it('formats 5xx as server error with restart hint', () => {
    const msg = formatBridgeError(new BridgeError(503, 'Service Unavailable'));
    expect(msg).toContain('503');
    expect(msg).toMatch(/server|service/i);
    expect(msg).toMatch(/Start-VWBridge|restart/i);
  });

  it('formats 408 timeout with carry-forward #41 hint', () => {
    const msg = formatBridgeError(new BridgeError(408, 'timeout'));
    expect(msg).toContain('408');
    expect(msg).toMatch(/timed out|timeout/i);
    expect(msg).toMatch(/#41|wedge|hung/i);
  });

  it('formats network ECONNREFUSED as bridge-down', () => {
    const err = new TypeError('fetch failed');
    (err as TypeError & { cause: { code: string } }).cause = { code: 'ECONNREFUSED' };
    const msg = formatBridgeError(err);
    expect(msg).toMatch(/not responding|down|ECONNREFUSED/i);
    expect(msg).toMatch(/Start-VWBridge|VisualWorks/);
  });

  it('formats ETIMEDOUT network error', () => {
    const err = new TypeError('fetch failed');
    (err as TypeError & { cause: { code: string } }).cause = { code: 'ETIMEDOUT' };
    const msg = formatBridgeError(err);
    expect(msg).toMatch(/unreachable|ETIMEDOUT/i);
  });

  it('formats AbortError (timeout) with wedge hint', () => {
    const err = new Error('The operation was aborted.');
    err.name = 'AbortError';
    const msg = formatBridgeError(err);
    expect(msg).toMatch(/timed out|timeout|aborted/i);
  });

  it('formats generic Error with the message preserved', () => {
    const msg = formatBridgeError(new Error('something else'));
    expect(msg).toContain('something else');
  });

  it('handles plain string throws', () => {
    expect(formatBridgeError('plain string')).toContain('plain string');
  });

  it('handles null + undefined', () => {
    expect(formatBridgeError(null)).toMatch(/unknown/i);
    expect(formatBridgeError(undefined)).toMatch(/unknown/i);
  });

  it('handles object throws via String() coercion', () => {
    expect(formatBridgeError({ weird: 'obj' })).toBeTruthy();
  });
});

describe('BridgeError', () => {
  it('is an Error subclass with status + bodyText', () => {
    const err = new BridgeError(503, 'Service Unavailable');
    expect(err.status).toBe(503);
    expect(err.bodyText).toBe('Service Unavailable');
    expect(err instanceof Error).toBe(true);
    expect(err instanceof BridgeError).toBe(true);
    expect(err.name).toBe('BridgeError');
  });

  it('encodes status in the message', () => {
    expect(new BridgeError(401, 'unauthorized').message).toContain('401');
    expect(new BridgeError(500).message).toContain('500');
  });

  it('handles missing bodyText (default empty string)', () => {
    const err = new BridgeError(500);
    expect(err.bodyText).toBe('');
  });

  it('truncates very long bodyText in message (DOS guard)', () => {
    const longBody = 'x'.repeat(5000);
    const err = new BridgeError(500, longBody);
    // Body is captured in full on the field but message stays bounded.
    expect(err.bodyText.length).toBe(5000);
    expect(err.message.length).toBeLessThan(500);
  });
});
