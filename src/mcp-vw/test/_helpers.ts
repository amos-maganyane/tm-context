import { vi } from 'vitest';
import type { BridgeClientLike, BridgeHealth, BridgeVersion, BridgeEvalResult } from '../src/bridge.js';

/**
 * Test helper: build a stub BridgeClientLike with sensible defaults.
 * Overrides via spread; tests can replace any method per-test.
 *
 * Example:
 *   const bridge = stubBridge({
 *     health: vi.fn().mockResolvedValue({ status: 'ok', version: '0.10.0' }),
 *     postEval: vi.fn().mockRejectedValue(new BridgeError(401, 'unauthorized')),
 *   });
 */
export function stubBridge(overrides: Partial<BridgeClientLike> = {}): BridgeClientLike {
  const defaultHealth: BridgeHealth = { status: 'ok', version: '0.10.0' };
  const defaultVersion: BridgeVersion = {
    version: '0.10.0',
    buildCommitSha: 'b9e53579b5708648ffda211addfdf1d4270b2c02',
    buildTimestamp: '2026-06-21T17:07:23Z',
    parcelMode: 'Parcel',
  };
  const defaultEval: BridgeEvalResult = { ok: true, result: '42' };

  return {
    health: vi.fn().mockResolvedValue(defaultHealth),
    version: vi.fn().mockResolvedValue(defaultVersion),
    getJson: vi.fn().mockResolvedValue({}),
    postJson: vi.fn().mockResolvedValue({}),
    postEval: vi.fn().mockResolvedValue(defaultEval),
    postEvalRaw: vi.fn().mockResolvedValue(JSON.stringify(defaultEval)),
    getBinary: vi.fn().mockResolvedValue({
      bytes: new Uint8Array([0x89, 0x50, 0x4e, 0x47]),
      contentType: 'image/png',
    }),
    ...overrides,
  };
}

/**
 * Helper to extract the first text content from a ToolResult.
 * Throws if shape is wrong (test should fail loudly).
 */
export function firstText(result: {
  content: Array<{ type: string; text?: string }>;
  isError?: boolean;
}): string {
  const first = result.content[0];
  if (!first || first.type !== 'text' || typeof first.text !== 'string') {
    throw new Error(`Expected first content to be text, got ${JSON.stringify(result.content)}`);
  }
  return first.text;
}
