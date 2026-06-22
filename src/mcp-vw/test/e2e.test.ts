/**
 * e2e.test.ts — end-to-end MCP protocol smoke test.
 *
 * Spins up a real McpServer with all 18 MVP tools registered (bound to a
 * stubbed BridgeClient), connects an MCP Client via InMemoryTransport pair,
 * and exercises:
 *
 *   1. tools/list  → exactly 18 vw_* tools, all with descriptions + schemas
 *   2. Sample tool calls covering each category (liveness, eval, schema,
 *      reading, navigation, codegen, parcel, ui_inspect, ui_drive).
 *   3. Failure paths (validation guards) — confirm isError flows through
 *      the protocol, not as JSON-RPC errors.
 *
 * If this passes, the wire-level protocol works end-to-end on this image.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import type { BridgeClientLike } from '../src/bridge.js';
import type { ToolDef } from '../src/tools/types.js';
import { stubBridge } from './_helpers.js';

import { makeLivenessTools } from '../src/tools/liveness.js';
import { makeEvalTool } from '../src/tools/eval.js';
import { makeSchemaTools } from '../src/tools/schema.js';
import { makeReadingTools } from '../src/tools/reading.js';
import { makeNavigationTools } from '../src/tools/navigation.js';
import { makeCreateClassTool } from '../src/codegen/class.js';
import { makeParcelTools } from '../src/tools/parcel.js';
import { makeUiInspectTools } from '../src/tools/ui_inspect.js';
import { makeUiDriveTools } from '../src/tools/ui_drive.js';
import { makeCreateWindowSpecTool } from '../src/codegen/windowSpec.js';
import {
  makeCompileMethodTool,
  makeDefineActionTool,
  makeDefineAspectTool,
} from '../src/codegen/methods.js';
import { makeCreateApplicationModelTool } from '../src/codegen/applicationModel.js';
import { makeCreateDialogTool } from '../src/codegen/dialog.js';
import { makeTestingTools } from '../src/tools/testing.js';
import { makeIntrospectionTools } from '../src/tools/introspection.js';
import { makeDestructiveTools } from '../src/tools/destructive.js';
import { makeDialogTools } from '../src/tools/dialogs.js';
import { makeWaitTools } from '../src/tools/wait.js';
import { makeScreenshotTools } from '../src/tools/screenshot.js';
import { makeCreateParcelTool } from '../src/codegen/parcel.js';

/** Mirror of index.ts buildAllTools() but accepting a stub bridge. */
function buildAllTools(bridge: BridgeClientLike): ToolDef[] {
  return [
    ...makeLivenessTools(bridge),
    makeEvalTool(bridge),
    ...makeSchemaTools(bridge),
    ...makeReadingTools(bridge),
    ...makeNavigationTools(bridge),
    makeCreateClassTool(bridge),
    ...makeParcelTools(bridge),
    ...makeUiInspectTools(bridge),
    ...makeUiDriveTools(bridge),
    // V2
    makeCreateWindowSpecTool(bridge),
    makeCompileMethodTool(bridge),
    makeDefineActionTool(bridge),
    makeDefineAspectTool(bridge),
    makeCreateApplicationModelTool(bridge),
    makeCreateDialogTool(bridge),
    ...makeTestingTools(bridge),
    // V3
    ...makeIntrospectionTools(bridge),
    ...makeDestructiveTools(bridge),
    ...makeDialogTools(bridge),
    ...makeWaitTools(bridge),
    ...makeScreenshotTools(bridge),
    makeCreateParcelTool(bridge),
  ];
}

const EXPECTED_TOOL_NAMES = [
  // MVP (18)
  'vw_health',
  'vw_version',
  'vw_status',
  'vw_eval',
  'vw_list_namespaces',
  'vw_list_namespace_entries',
  'vw_get_class_definition',
  'vw_list_methods',
  'vw_find_senders',
  'vw_create_class',
  'vw_load_parcel',
  'vw_unload_parcel',
  'vw_list_loaded_parcels',
  'vw_list_windows',
  'vw_describe_window',
  'vw_click',
  'vw_type',
  'vw_open_application',
  // V2 (+13)
  'vw_describe_class',
  'vw_find_implementors',
  'vw_find_references_to',
  'vw_get_widget_value',
  'vw_create_window_spec',
  'vw_compile_method',
  'vw_define_action',
  'vw_define_aspect',
  'vw_create_application_model',
  'vw_create_dialog',
  'vw_run_test_class',
  'vw_run_test_method',
  'vw_list_failing_tests',
  // V3 (+17)
  'vw_list_namespace_classes',
  'vw_list_all_classes',
  'vw_list_test_classes',
  'vw_get_method_fingerprint',
  'vw_get_class_hierarchy',
  'vw_export_class',
  'vw_search_method_messages',
  'vw_compile_class_definition',
  'vw_delete_method',
  'vw_delete_class',
  'vw_set_class_comment',
  'vw_list_dialogs',
  'vw_respond_dialog',
  'vw_wait',
  'vw_screenshot',
  'vw_describe_test_failure',
  'vw_create_parcel',
].sort();

interface ServerSetup {
  server: McpServer;
  client: Client;
  bridge: ReturnType<typeof stubBridge>;
  cleanup: () => Promise<void>;
}

async function bootServer(bridgeOverrides?: Parameters<typeof stubBridge>[0]): Promise<ServerSetup> {
  const bridge = stubBridge(bridgeOverrides);
  const tools = buildAllTools(bridge);

  const server = new McpServer({ name: 'vw-bridge', version: '0.1.0-test' });
  for (const tool of tools) {
    server.registerTool(
      tool.name,
      { description: tool.description, inputSchema: tool.inputSchema },
      // SDK ToolCallback type is broader than ours; cast is safe because
      // Zod parses input before reaching the handler.
      tool.handler as Parameters<typeof server.registerTool>[2]
    );
  }

  const client = new Client({ name: 'mcp-vw-e2e-test', version: '0.1.0' });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([
    server.connect(serverTransport),
    client.connect(clientTransport),
  ]);

  return {
    server,
    client,
    bridge,
    cleanup: async () => {
      await client.close();
      await server.close();
    },
  };
}

describe('e2e — tool registration', () => {
  let setup: ServerSetup | null = null;

  beforeEach(async () => {
    setup = await bootServer();
  });
  afterEach(async () => {
    await setup?.cleanup();
    setup = null;
  });

  it('lists exactly 48 vw_* tools (18 MVP + 13 V2 + 17 V3)', async () => {
    const result = await setup!.client.listTools();

    expect(result.tools).toHaveLength(48);
    const names = result.tools.map((t) => t.name).sort();
    expect(names).toEqual(EXPECTED_TOOL_NAMES);
  });

  it('every tool has a non-empty description', async () => {
    const result = await setup!.client.listTools();
    for (const tool of result.tools) {
      expect(tool.description).toBeTruthy();
      expect(tool.description!.length).toBeGreaterThan(10);
    }
  });

  it('every tool has an inputSchema (even if empty)', async () => {
    const result = await setup!.client.listTools();
    for (const tool of result.tools) {
      expect(tool.inputSchema).toBeDefined();
      expect(tool.inputSchema.type).toBe('object');
    }
  });
});

describe('e2e — happy-path tool calls', () => {
  let setup: ServerSetup | null = null;

  afterEach(async () => {
    await setup?.cleanup();
    setup = null;
  });

  it('vw_health returns the bridge health JSON', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({ name: 'vw_health', arguments: {} });

    expect(result.isError).toBeFalsy();
    expect(Array.isArray(result.content)).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    const parsed = JSON.parse(content[0]!.text);
    expect(parsed.status).toBe('ok');
    expect(parsed.version).toBe('0.10.0');
  });

  it('vw_version returns 4-field build metadata', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({ name: 'vw_version', arguments: {} });

    const content = result.content as Array<{ type: string; text: string }>;
    const parsed = JSON.parse(content[0]!.text);
    expect(parsed.version).toBe('0.10.0');
    expect(parsed.buildCommitSha).toMatch(/^[0-9a-f]{40}$/);
    expect(parsed.parcelMode).toBe('Parcel');
  });

  it('vw_eval evaluates an expression', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({
      name: 'vw_eval',
      arguments: { source: '1 + 2' },
    });

    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0]!.text).toContain('42'); // stub default
  });

  it('vw_list_namespaces returns sorted JSON array', async () => {
    setup = await bootServer({
      postEval: async () => ({ ok: true, result: "'Core;Kernel;Smalltalk;Tools;'" }),
    });

    const result = await setup.client.callTool({
      name: 'vw_list_namespaces',
      arguments: {},
    });

    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    const parsed = JSON.parse(content[0]!.text);
    expect(parsed).toEqual(['Core', 'Kernel', 'Smalltalk', 'Tools']);
  });

  it('vw_create_class emits subclass: form + posts to /eval', async () => {
    let lastSource: string | undefined;
    setup = await bootServer({
      postEval: async (source: string) => {
        lastSource = source;
        return { ok: true, result: 'Customer' };
      },
    });

    const result = await setup.client.callTool({
      name: 'vw_create_class',
      arguments: {
        className: 'Customer',
        namespace: 'Smalltalk',
        superclass: 'Object',
        instanceVariableNames: ['name', 'email'],
      },
    });

    expect(result.isError).toBeFalsy();
    // defineClass: 8-kw form per s23 benchmark Bug 1 fix (was: 'subclass: #Customer').
    expect(lastSource).toContain('Smalltalk defineClass: #Customer');
    expect(lastSource).toContain('superclass: #{Smalltalk.Object}');
    expect(lastSource).toContain("instanceVariableNames: 'name email'");
  });

  it('vw_list_windows wraps /windows getJson', async () => {
    let calledPath: string | undefined;
    setup = await bootServer({
      getJson: async <T,>(path: string): Promise<T> => {
        calledPath = path;
        return [{ title: 'Workspace', id: 1 }] as unknown as T;
      },
    });

    const result = await setup.client.callTool({ name: 'vw_list_windows', arguments: {} });

    expect(result.isError).toBeFalsy();
    expect(calledPath).toBe('/windows');
  });
});

describe('e2e — failure paths (isError flows over protocol)', () => {
  let setup: ServerSetup | null = null;

  afterEach(async () => {
    await setup?.cleanup();
    setup = null;
  });

  it('vw_eval Bug #5 guard rejects with isError:true (NOT JSON-RPC error)', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({
      name: 'vw_eval',
      arguments: { source: 'VWBridge singleton dispatch' },
    });

    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0]!.text).toMatch(/#5|dispatch|VWBridge/i);
  });

  it('vw_create_class refuses VWB.* namespace with isError', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({
      name: 'vw_create_class',
      arguments: {
        className: 'Foo',
        namespace: 'VWB',
        superclass: 'Object',
      },
    });

    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0]!.text).toMatch(/#41|VWB|wedge/i);
  });

  it('vw_unload_parcel refuses unloading VWBridge', async () => {
    setup = await bootServer();

    const result = await setup.client.callTool({
      name: 'vw_unload_parcel',
      arguments: { name: 'VWBridge' },
    });

    expect(result.isError).toBe(true);
  });

  it('unknown tool name returns isError:true (SDK validates pre-dispatch)', async () => {
    setup = await bootServer();

    // The MCP SDK ^1.29.0 returns isError:true with a "Tool not found" message
    // rather than throwing — protocol stays connected. Either behavior is
    // acceptable per spec; this test accepts both.
    let result;
    try {
      result = await setup.client.callTool({ name: 'vw_nonexistent', arguments: {} });
    } catch (err) {
      // If the SDK chose to throw (older versions / strict mode), that's fine.
      expect(err).toBeInstanceOf(Error);
      return;
    }
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0]!.text.toLowerCase()).toMatch(/not.*found|unknown|invalid.*name/);
  });

  it('invalid input (zod validation) returns isError:true with -32602 hint', async () => {
    setup = await bootServer();

    // The SDK does zod validation BEFORE the handler runs and surfaces the
    // failure as isError:true with the JSON-RPC -32602 code embedded in text.
    let result;
    try {
      result = await setup.client.callTool({
        name: 'vw_eval',
        arguments: { source: 42 as unknown as string },
      });
    } catch (err) {
      // Some SDK versions throw; accept either.
      expect(err).toBeInstanceOf(Error);
      return;
    }
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0]!.text.toLowerCase()).toMatch(/validation|invalid|expected.*string/);
  });
});
