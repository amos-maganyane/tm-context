/**
 * util.ts — MCP-shaped helpers shared across every tool.
 *
 * Three concerns:
 *
 *   1. **Result shape** — `text()` and `errorResult()` produce the MCP
 *      `{content: [...], isError?: boolean}` shape so call sites never
 *      hand-roll it.
 *
 *   2. **Safety net** — `safeHandler()` wraps a tool body. ANY throw
 *      becomes `isError: true` with a formatted message. Per
 *      architecture.md §10: NEVER throw out of an MCP tool handler —
 *      protocol-level errors can disconnect the client.
 *
 *   3. **Recovery-action errors** — `BridgeError` + `formatBridgeError()`
 *      turn raw HTTP / network failures into messages that say what the
 *      AI should do next ("re-read $VW_RUNTIME_API_TOKEN_FILE", "restart via
 *      Start-VWBridge.bat", "carry-forward #41 — would wedge"). The AI
 *      reading the error text can act without round-tripping.
 *
 * Carry-forward constraints surfaced in error messages:
 *   - #5  Bug #5 recursive dispatch — substring guard on vw_eval
 *   - #28 HTTP /eval Bug #5 inherent limit
 *   - #41 compile-on-VWB.* wedge
 *   - #42 ensure: block no-binding after parcel manipulation
 */

/** MCP TextContent shape. Locally typed so this module has zero SDK coupling. */
export type TextContent = { type: 'text'; text: string };

/** MCP ImageContent shape (for vw_screenshot etc.). */
export type ImageContent = { type: 'image'; data: string; mimeType: string };

/** Union of MCP content shapes we emit. */
export type McpContent = TextContent | ImageContent;

/**
 * MCP CallToolResult-equivalent shape (subset we use). All tools return this;
 * the server adapter wraps these into the SDK's `CallToolResult` at registration.
 */
export type ToolResult = {
  content: McpContent[];
  isError?: boolean;
};

/** Wrap a string as MCP TextContent. */
export function text(s: string): TextContent {
  return { type: 'text', text: s };
}

/** Wrap base64-encoded image bytes as MCP ImageContent. */
export function image(base64: string, mimeType: string): ImageContent {
  return { type: 'image', data: base64, mimeType };
}

/**
 * Wrap a message as a tool error result.
 * `isError: true` tells the AI the tool ran but the operation failed — it can
 * adjust and retry. NEVER use JSON-RPC errors for tool failures (architecture.md §10).
 */
export function errorResult(message: string): ToolResult {
  return {
    content: [text(message)],
    isError: true,
  };
}

/**
 * Wrap a tool handler so exceptions become `isError: true` results.
 *
 * - Caught: synchronous throws, async rejections, BridgeError, non-Error throws (string/null/undefined/object).
 * - Guarantee: this wrapper NEVER re-throws. The MCP transport stays connected.
 *
 * Per architecture.md §10 + Python SDK migration guide: tool failures via isError,
 * protocol failures via throw. This wrapper makes the protocol guarantee.
 */
export function safeHandler<I>(
  handler: (input: I) => Promise<ToolResult>
): (input: I) => Promise<ToolResult> {
  return async (input: I) => {
    try {
      return await handler(input);
    } catch (err) {
      return errorResult(formatBridgeError(err));
    }
  };
}

/**
 * Domain error for HTTP failures against the VW Runtime API.
 *
 * - `status` = HTTP status code (or 0 for network-level failures).
 * - `bodyText` = response body (truncated in `.message`, full in `.bodyText`).
 *
 * Throw from `BridgeClient`; catch via `safeHandler` → `formatBridgeError`.
 */
export class BridgeError extends Error {
  public readonly status: number;
  public readonly bodyText: string;

  constructor(status: number, bodyText: string = '') {
    const messageBody = bodyText ? `: ${bodyText.slice(0, 200)}` : '';
    super(`Bridge HTTP ${status}${messageBody}`);
    this.name = 'BridgeError';
    this.status = status;
    this.bodyText = bodyText;
  }
}

/**
 * Format any thrown value into a recovery-action message for tool result text.
 *
 * Strategy:
 *   1. BridgeError → status-specific message with VW-context recovery action.
 *   2. AbortError → "request timed out; bridge may be wedged".
 *   3. Network TypeError (Node undici fetch) → ECONNREFUSED / ETIMEDOUT explanation.
 *   4. Generic Error → preserve `.message`.
 *   5. Non-Error throws → `String()` coercion with null/undefined handled.
 */
export function formatBridgeError(err: unknown): string {
  if (err instanceof BridgeError) {
    return formatHttpStatus(err);
  }

  if (err instanceof Error) {
    if (err.name === 'AbortError') {
      return (
        `Request to VW Runtime API timed out. The bridge may be wedged (carry-forward #41 — compile-on-VWB.*) ` +
        `or the /eval body may be long-running. Consider increasing the timeout, breaking work into smaller probes, ` +
        `or restarting the bridge (Start-VWBridge.bat -KillExisting).`
      );
    }

    if (err instanceof TypeError && 'cause' in err) {
      const cause = (err as TypeError & { cause?: { code?: string; message?: string } }).cause;
      const code = cause?.code;
      if (code === 'ECONNREFUSED') {
        return (
          `VW Runtime API is not responding (ECONNREFUSED). Check that the VisualWorks image is running ` +
          `and the bridge is started. Run Start-VWBridge.bat (or Start-VWBridge.ps1) to launch it. ` +
          `Ensure VW_RUNTIME_API_HOME is set in your User env vars.`
        );
      }
      if (code === 'ETIMEDOUT' || code === 'ENETUNREACH' || code === 'EHOSTUNREACH') {
        return (
          `VW Runtime API is unreachable (${code}). Check the bridge URL configuration and that ` +
          `the VisualWorks image is healthy. /health should respond within seconds when up.`
        );
      }
      if (code === 'ENOTFOUND') {
        return (
          `VW Runtime API hostname could not be resolved (ENOTFOUND). Bridge URL is misconfigured — ` +
          `expected http://127.0.0.1:9876.`
        );
      }
      return (
        `VW Runtime API is down or unreachable (${code ?? 'fetch failed'}). Check /health and restart ` +
        `via Start-VWBridge.bat if needed.`
      );
    }

    return err.message;
  }

  if (typeof err === 'string') {
    return err;
  }
  if (err === null || err === undefined) {
    return 'Unknown error (no message available).';
  }
  return String(err);
}

/** Subroutine: VW-flavored recovery messages per HTTP status. */
function formatHttpStatus(err: BridgeError): string {
  const { status, bodyText } = err;

  if (status === 0) {
    return (
      `VW Runtime API is not responding at the configured URL. Check that the VisualWorks image ` +
      `is running and the bridge is started (Start-VWBridge.bat).`
    );
  }
  if (status === 401) {
    return (
      `VW Runtime API rejected the auth token (HTTP 401). The bridge rotates this on every cold start — ` +
      `re-read $VW_RUNTIME_API_TOKEN_FILE (default src/vw-bridge/.token) and retry. ` +
      `If the file is stale, restart the bridge (Start-VWBridge.bat).`
    );
  }
  if (status === 403) {
    return (
      `VW Runtime API refused the request (HTTP 403). Verify the token in $VW_RUNTIME_API_TOKEN_FILE matches ` +
      `the running bridge instance, and check the bridge log for the rejection reason.`
    );
  }
  if (status === 404) {
    return (
      `VW Runtime API endpoint not found (HTTP 404). The bridge may be an older version without this endpoint. ` +
      `Check /version (auth-exempt) and update if needed.`
    );
  }
  if (status === 408 || status === 504) {
    return (
      `VW Runtime API timed out (HTTP ${status}). The /eval body may be hung in a wedge — ` +
      `see carry-forward #41 (compile-on-VWB.* wedges via UI announcement fan-out) ` +
      `or #28 (Bug #5 recursive dispatch inherent limit). Restart via Start-VWBridge.bat -KillExisting.`
    );
  }
  if (status === 429) {
    return (
      `VW Runtime API rate-limited the request (HTTP 429). Back off and retry. ` +
      `If this is a tight loop, batch the work into a single /eval probe instead.`
    );
  }
  if (status >= 500) {
    return (
      `VW Runtime API server error (HTTP ${status}): ${bodyText.slice(0, 300)}. ` +
      `The bridge may have crashed mid-request — check /health, then restart via Start-VWBridge.bat -KillExisting if needed.`
    );
  }
  if (status >= 400) {
    const bodyHint = bodyText ? `: ${bodyText.slice(0, 300)}` : '';
    return `VW Runtime API rejected the request (HTTP ${status})${bodyHint}.`;
  }
  return err.message;
}
