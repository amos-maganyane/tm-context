import { describe, it, expect, vi } from 'vitest';
import { makeParcelTools } from '../../src/tools/parcel.js';
import { stubBridge, firstText } from '../_helpers.js';

describe('parcel tools — registration', () => {
  it('returns 3 MVP tools', () => {
    const tools = makeParcelTools(stubBridge());
    expect(tools.map((t) => t.name).sort()).toEqual([
      'vw_list_loaded_parcels',
      'vw_load_parcel',
      'vw_unload_parcel',
    ]);
  });
});

describe('vw_load_parcel', () => {
  it('emits Kernel.Parcel loadParcelFrom: with quoted path', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "a Kernel.Parcel('MyApp')" }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_load_parcel')!;

    await tool.handler({
      path: 'C:\\Users\\me\\parcels\\MyApp.pcl',
    });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('Kernel.Parcel loadParcelFrom:');
    expect(probe).toContain('asFilename');
    expect(probe).toContain("'C:\\Users\\me\\parcels\\MyApp.pcl'");
  });

  it('escapes apostrophes in path', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'a Parcel' }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_load_parcel')!;

    await tool.handler({ path: "C:\\joe's stuff\\MyApp.pcl" });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain("'C:\\joe''s stuff\\MyApp.pcl'");
  });

  it('returns success message with parcel result', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "a Parcel('MyApp')" }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_load_parcel')!;

    const result = await tool.handler({ path: 'C:\\x.pcl' });

    expect(result.isError).toBeFalsy();
    expect(firstText(result)).toMatch(/loaded|MyApp|Parcel/i);
  });

  it('rejects empty path', async () => {
    const bridge = stubBridge();
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_load_parcel')!;

    const result = await tool.handler({ path: '' });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('surfaces bridge error if parcel load fails', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: false,
        error: 'ParcelMissingError: file not found',
      }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_load_parcel')!;

    const result = await tool.handler({ path: 'C:\\nonexistent.pcl' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/ParcelMissingError|not found/i);
  });
});

describe('vw_unload_parcel', () => {
  it('wraps removeParcelNamed: with Notification-resume (carry-forward #38)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'nil' }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_unload_parcel')!;

    await tool.handler({ name: 'MyApp' });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('removeParcelNamed:');
    expect(probe).toContain("'MyApp'");
    // Notification-resume per carry-forward #38
    expect(probe).toContain('Core.Notification');
    expect(probe).toContain('resume');
  });

  it('refuses unloading VWBridge parcel', async () => {
    const bridge = stubBridge();
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_unload_parcel')!;

    const result = await tool.handler({ name: 'VWBridge' });

    expect(result.isError).toBe(true);
    expect(firstText(result)).toMatch(/VWBridge|self-unload|bridge/i);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });

  it('escapes apostrophes in parcel name', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: 'nil' }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_unload_parcel')!;

    await tool.handler({ name: "weird's parcel" });

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain("'weird''s parcel'");
  });

  it('rejects empty parcel name', async () => {
    const bridge = stubBridge();
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_unload_parcel')!;

    const result = await tool.handler({ name: '' });

    expect(result.isError).toBe(true);
    expect(bridge.postEval).not.toHaveBeenCalled();
  });
});

describe('vw_list_loaded_parcels', () => {
  it('returns JSON array of parcel names (#43-safe ; separator)', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({
        ok: true,
        result: "'VWBridge;MyApp;ThirdPartyTools;'",
      }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_list_loaded_parcels')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    const parsed = JSON.parse(firstText(result));
    expect(parsed).toEqual(['VWBridge', 'MyApp', 'ThirdPartyTools']);
    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain("';'");
    expect(probe).not.toContain('Character lf');
  });

  it('handles no parcels loaded', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_list_loaded_parcels')!;

    const result = await tool.handler({});

    expect(result.isError).toBeFalsy();
    expect(JSON.parse(firstText(result))).toEqual([]);
  });

  it('uses Kernel.Parcel as the source', async () => {
    const bridge = stubBridge({
      postEval: vi.fn().mockResolvedValue({ ok: true, result: "''" }),
    });
    const tool = makeParcelTools(bridge).find((t) => t.name === 'vw_list_loaded_parcels')!;

    await tool.handler({});

    const probe = vi.mocked(bridge.postEval).mock.calls[0]?.[0] ?? '';
    expect(probe).toContain('Kernel.Parcel');
  });
});
