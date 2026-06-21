import { describe, it, expect, vi } from 'vitest';
import { makeUiDriveTools } from '../../src/tools/ui_drive.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('ui_drive tools — registration', () => {
  it('returns 3 MVP tools', () => {
    const tools = makeUiDriveTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_click',
      'vw_open_application',
      'vw_type',
    ]);
  });
});

describe('vw_click', () => {
  it('POSTs /click with aspect + windowTitle JSON body', async () => {
    const bridge = stubBridge({
      postJson: vi.fn().mockResolvedValue({ ok: true }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_click')!;

    const result = await tool.handler({
      aspect: 'searchButton',
      windowTitle: 'Party Search',
    });

    expect(result.isError).toBeFalsy();
    expect(bridge.postJson).toHaveBeenCalledWith('/click', {
      aspect: 'searchButton',
      windowTitle: 'Party Search',
    });
  });

  it('allows omitting windowTitle (uses bridge default)', async () => {
    const bridge = stubBridge({
      postJson: vi.fn().mockResolvedValue({ ok: true }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_click')!;

    const result = await tool.handler({ aspect: 'okButton' });

    expect(result.isError).toBeFalsy();
    expect(bridge.postJson).toHaveBeenCalledWith('/click', { aspect: 'okButton' });
  });

  it('rejects empty aspect', async () => {
    const bridge = stubBridge();
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_click')!;

    const result = await tool.handler({ aspect: '' });

    expect(result.isError).toBe(true);
    expect(bridge.postJson).not.toHaveBeenCalled();
  });
});

describe('vw_type', () => {
  it('POSTs /type with aspect + value + windowTitle JSON body', async () => {
    const bridge = stubBridge({
      postJson: vi.fn().mockResolvedValue({ ok: true }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_type')!;

    const result = await tool.handler({
      aspect: 'searchInput',
      value: 'Smith',
      windowTitle: 'Party Search',
    });

    expect(result.isError).toBeFalsy();
    expect(bridge.postJson).toHaveBeenCalledWith('/type', {
      aspect: 'searchInput',
      value: 'Smith',
      windowTitle: 'Party Search',
    });
  });

  it('accepts empty value (clear-input case)', async () => {
    const bridge = stubBridge({
      postJson: vi.fn().mockResolvedValue({ ok: true }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_type')!;

    const result = await tool.handler({ aspect: 'input', value: '' });

    expect(result.isError).toBeFalsy();
  });

  it('rejects empty aspect', async () => {
    const bridge = stubBridge();
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_type')!;

    const result = await tool.handler({ aspect: '', value: 'x' });

    expect(result.isError).toBe(true);
    expect(bridge.postJson).not.toHaveBeenCalled();
  });
});

describe('vw_open_application', () => {
  it('emits "<className> open" when no specSelector', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a Window' }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    const result = await tool.handler({ className: 'PartySearchView' });

    expect(result.isError).toBeFalsy();
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toBe('PartySearchView open');
  });

  it('emits openInterface: when specSelector provided', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a Window' }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    await tool.handler({
      className: 'PartySearchView',
      specSelector: 'detailWindowSpec',
    });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toBe('PartySearchView new openInterface: #detailWindowSpec');
  });

  it('supports namespace-qualified class names', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a Window' }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    await tool.handler({ className: 'Tools.UIPainter' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toBe('Tools.UIPainter open');
  });

  it('refuses VWB.* class names (carry-forward #41)', async () => {
    const bridge = stubBridge();
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    const result = await tool.handler({ className: 'VWB.VWBridge' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWB|#41|bridge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid className', async () => {
    const bridge = stubBridge();
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    const result = await tool.handler({ className: "Bad'Class" });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('rejects invalid specSelector', async () => {
    const bridge = stubBridge();
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    const result = await tool.handler({
      className: 'Foo',
      specSelector: "bad'sel",
    });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('surfaces in-band MNU as isError', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: "MessageNotUnderstood: #open for nil",
      }),
    });
    const tool = makeUiDriveTools(bridge).find((t) => t.name === 'vw_open_application')!;

    const result = await tool.handler({ className: 'NoSuchClass' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/MessageNotUnderstood/i);
  });
});
