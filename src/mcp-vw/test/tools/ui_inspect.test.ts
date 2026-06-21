import { describe, it, expect, vi } from 'vitest';
import { makeUiInspectTools } from '../../src/tools/ui_inspect.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('ui_inspect tools — registration', () => {
  it('returns 3 tools (MVP + V2 vw_get_widget_value)', () => {
    const tools = makeUiInspectTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_describe_window',
      'vw_get_widget_value',
      'vw_list_windows',
    ]);
  });
});

describe('vw_list_windows', () => {
  it('GETs /windows + returns the array as text', async () => {
    const windowsList = [
      { title: 'Workspace', id: 1, label: 'wsp' },
      { title: 'Party Search', id: 2, label: 'psv' },
    ];
    const bridge = stubBridge({
      getJson: vi.fn().mockResolvedValue(windowsList),
    });
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_list_windows')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(windowsList);
    expect(bridge.getJson).toHaveBeenCalledWith('/windows');
  });

  it('surfaces bridge error', async () => {
    const bridge = stubBridge({
      getJson: vi.fn().mockRejectedValue(new TypeError('fetch failed')),
    });
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_list_windows')!;

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/bridge|fetch|down/i);
  });
});

describe('vw_describe_window', () => {
  it('GETs /windows/tree with windowTitle query param', async () => {
    const tree = { title: 'Party Search', children: [{ type: 'InputField', name: 'searchInput' }] };
    const bridge = stubBridge({
      getJson: vi.fn().mockResolvedValue(tree),
    });
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_describe_window')!;

    const result = await tool.handler({ windowTitle: 'Party Search' });

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(tree);
    expect(bridge.getJson).toHaveBeenCalledTimes(1);
    const calledPath = vi.mocked(bridge.getJson).mock.calls[0]?.[0] ?? '';
    expect(calledPath).toContain('/windows/tree');
    expect(calledPath).toContain('windowTitle=');
    expect(calledPath).toContain(encodeURIComponent('Party Search'));
  });

  it('URL-encodes special chars in windowTitle', async () => {
    const bridge = stubBridge({
      getJson: vi.fn().mockResolvedValue({}),
    });
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_describe_window')!;

    await tool.handler({ windowTitle: 'Search & Filter?' });

    const calledPath = vi.mocked(bridge.getJson).mock.calls[0]?.[0] ?? '';
    expect(calledPath).toContain(encodeURIComponent('Search & Filter?'));
    expect(calledPath).not.toContain(' & '); // Verify it actually got encoded.
  });

  it('rejects empty windowTitle', async () => {
    const bridge = stubBridge();
    const tool = makeUiInspectTools(bridge).find((t) => t.name === 'vw_describe_window')!;

    const result = await tool.handler({ windowTitle: '' });

    expect(result.isError).toBe(true);
    expect(bridge.getJson).not.toHaveBeenCalled();
  });
});
