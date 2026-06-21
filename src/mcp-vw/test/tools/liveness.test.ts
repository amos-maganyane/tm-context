import { describe, it, expect, vi } from 'vitest';
import { makeLivenessTools } from '../../src/tools/liveness.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('liveness tools — registration', () => {
  it('returns 3 tool defs with vw_ prefix', () => {
    const bridge = stubBridge();
    const tools = makeLivenessTools(bridge);

    expect(tools).toHaveLength(3);
    expect(tools.map((t) => t.name).sort()).toEqual(['vw_health', 'vw_status', 'vw_version']);
    for (const tool of tools) {
      expect(tool.name).toMatch(/^vw_/);
      expect(tool.description.length).toBeGreaterThan(20);
      expect(tool.inputSchema).toBeDefined();
    }
  });
});

describe('vw_health', () => {
  it('returns the bridge /health response as JSON text', async () => {
    const bridge = stubBridge({
      health: vi.fn().mockResolvedValue({ status: 'ok', version: '0.10.0' }),
    });
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_health')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual({ status: 'ok', version: '0.10.0' });
    expect(bridge.health).toHaveBeenCalledTimes(1);
  });

  it('returns errorResult when bridge is down', async () => {
    const bridge = stubBridge({
      health: vi.fn().mockRejectedValue(new TypeError('fetch failed')),
    });
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_health')!;

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/down|unreachable|not responding|fetch/i);
  });
});

describe('vw_version', () => {
  it('returns the bridge /version response with all 4 fields', async () => {
    const bridge = stubBridge();
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_version')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.version).toBe('0.10.0');
    expect(parsed.buildCommitSha).toMatch(/^[0-9a-f]{40}$/);
    expect(parsed.buildTimestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(parsed.parcelMode).toBe('Parcel');
  });

  it('surfaces version() errors via isError', async () => {
    const bridge = stubBridge({
      version: vi.fn().mockRejectedValue(new Error('boom')),
    });
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_version')!;

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(firstText(result)).toContain('boom');
  });
});

describe('vw_status', () => {
  it('returns combined health + version + eval probe', async () => {
    const bridge = stubBridge();
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_status')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.bridge.status).toBe('ok');
    expect(parsed.build.version).toBe('0.10.0');
    expect(parsed.build.parcelMode).toBe('Parcel');
    expect(parsed.evalProbe.ok).toBe(true);
  });

  it('hits all 3 bridge methods exactly once', async () => {
    const bridge = stubBridge();
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_status')!;

    await tool.handler({});

    expect(bridge.health).toHaveBeenCalledTimes(1);
    expect(bridge.version).toHaveBeenCalledTimes(1);
    expect(bridge.postEval).toHaveBeenCalledTimes(1);
  });

  it('uses a side-effect-free eval probe (literal integer or constant)', async () => {
    const bridge = stubBridge();
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_status')!;

    await tool.handler({});

    const evalCall = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    // No compile, no class creation, no I/O — just a literal expression.
    expect(evalCall).not.toMatch(/compile|create|fileIn|fileOut|Parcel|class\s+compile/i);
    // Should be a short single-line probe (status is meant to be cheap).
    expect(evalCall.length).toBeLessThan(50);
  });

  it('still returns OK structure when only the eval probe fails', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockRejectedValue(new Error('dispatch wedged')),
    });
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_status')!;

    const result = await tool.handler({});

    // health + version still ran — partial status is informative.
    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed.bridge.status).toBe('ok');
    expect(parsed.build.version).toBe('0.10.0');
    expect(parsed.evalProbe.ok).toBe(false);
    expect(parsed.evalProbe.error).toMatch(/dispatch wedged|wedged/i);
  });

  it('surfaces full error when health() itself fails', async () => {
    const bridge = stubBridge({
      health: vi.fn().mockRejectedValue(new TypeError('fetch failed')),
    });
    const tool = makeLivenessTools(bridge).find((t) => t.name === 'vw_status')!;

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/bridge|down|unreachable|fetch/i);
  });
});
