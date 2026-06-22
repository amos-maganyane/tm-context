/**
 * index.ts — mcp-vw stdio server entry point.
 *
 * Boot sequence:
 *   1. Resolve config from env (VW_RUNTIME_API_URL, VW_RUNTIME_API_TOKEN_FILE,
 *      MCP_VW_SINGLE_OWNER, MCP_VW_LOCK_FILE).
 *   2. Acquire single-owner lock. Exit code 75 (EX_TEMPFAIL) if another
 *      live mcp-vw already holds it (architecture.md §9).
 *   3. Construct BridgeClient.
 *   4. Build all 31 tools (18 MVP + 13 V2) via factories.
 *   5. Register each tool with the McpServer.
 *   6. Connect StdioServerTransport.
 *   7. Wire SIGINT/SIGTERM → release lock + close server.
 *
 * All progress + errors go to stderr (stdout is reserved for MCP protocol).
 *
 * Per architecture.md §17 Appendix A.
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import process from 'node:process';

import { BridgeClient } from './bridge.js';
import { OwnerLock } from './lock.js';
import type { ToolDef } from './tools/types.js';

// MVP tool factories (18 tools)
import { makeLivenessTools } from './tools/liveness.js';
import { makeEvalTool } from './tools/eval.js';
import { makeSchemaTools } from './tools/schema.js';
import { makeReadingTools } from './tools/reading.js';
import { makeNavigationTools } from './tools/navigation.js';
import { makeCreateClassTool } from './codegen/class.js';
import { makeParcelTools } from './tools/parcel.js';
import { makeUiInspectTools } from './tools/ui_inspect.js';
import { makeUiDriveTools } from './tools/ui_drive.js';

// V2 tool factories (+ 13 tools)
import { makeCreateWindowSpecTool } from './codegen/windowSpec.js';
import {
  makeCompileMethodTool,
  makeDefineActionTool,
  makeDefineAspectTool,
} from './codegen/methods.js';
import { makeCreateApplicationModelTool } from './codegen/applicationModel.js';
import { makeCreateDialogTool } from './codegen/dialog.js';
import { makeTestingTools } from './tools/testing.js';

// V3 tool factories (+ 17 tools)
import { makeIntrospectionTools } from './tools/introspection.js';
import { makeDestructiveTools } from './tools/destructive.js';
import { makeDialogTools } from './tools/dialogs.js';
import { makeWaitTools } from './tools/wait.js';
import { makeScreenshotTools } from './tools/screenshot.js';
import { makeCreateParcelTool } from './codegen/parcel.js';

const SERVER_NAME = 'vw-bridge';
const SERVER_VERSION = '0.3.0'; // V3 — 48 tools (full architecture.md v2 surface)
const DEFAULT_BRIDGE_URL = 'http://127.0.0.1:9876';
const EXIT_SINGLE_OWNER_HELD = 75; // EX_TEMPFAIL per BSD sysexits.h

interface Config {
  bridgeUrl: string;
  tokenFile: string;
  lockFile: string;
  singleOwner: boolean | undefined;
}

function resolveConfig(): Config {
  const bridgeUrl = process.env['VW_RUNTIME_API_URL'] ?? DEFAULT_BRIDGE_URL;

  const tokenFile =
    process.env['VW_RUNTIME_API_TOKEN_FILE'] ??
    resolveDefaultTokenFile();

  const lockFile = process.env['MCP_VW_LOCK_FILE'] ?? join(tmpdir(), 'mcp-vw.lock');

  let singleOwner: boolean | undefined;
  const env = process.env['MCP_VW_SINGLE_OWNER'];
  if (env !== undefined) {
    const v = env.trim().toLowerCase();
    singleOwner = !(v === '0' || v === 'false' || v === 'off' || v === 'no');
  }

  return { bridgeUrl, tokenFile, lockFile, singleOwner };
}

/**
 * Production-grade default token file location.
 * %LOCALAPPDATA%\Enviro365\vw-runtime-api\token on Windows. Microsoft-documented
 * home for per-user, non-roaming application state. Brand-scoped subdir so
 * future Enviro365 products can colocate. Mirrors VWBridge.st>>tokenStateDir.
 * Falls back to %USERPROFILE%\AppData\Local if LOCALAPPDATA is somehow unset,
 * then to the Node homedir() as a last resort.
 */
function resolveDefaultTokenFile(): string {
  const localAppData =
    process.env['LOCALAPPDATA'] ??
    join(process.env['USERPROFILE'] ?? homedir(), 'AppData', 'Local');
  return join(localAppData, 'Enviro365', 'vw-runtime-api', 'token');
}

/** All 48 tool factories collected into one array (18 MVP + 13 V2 + 17 V3). */
function buildAllTools(bridge: BridgeClient): ToolDef[] {
  return [
    // --- MVP (18 tools) ---
    ...makeLivenessTools(bridge),     // vw_health, vw_version, vw_status
    makeEvalTool(bridge),             // vw_eval
    ...makeSchemaTools(bridge),       // vw_list_namespaces, vw_list_namespace_entries, +V3 vw_list_namespace_classes/all_classes/test_classes
    ...makeReadingTools(bridge),      // vw_get_class_definition, vw_list_methods, +V2 vw_describe_class
    ...makeNavigationTools(bridge),   // vw_find_senders, +V2 vw_find_implementors, vw_find_references_to
    makeCreateClassTool(bridge),      // vw_create_class
    ...makeParcelTools(bridge),       // vw_load_parcel, vw_unload_parcel, vw_list_loaded_parcels
    ...makeUiInspectTools(bridge),    // vw_list_windows, vw_describe_window, +V2 vw_get_widget_value
    ...makeUiDriveTools(bridge),      // vw_click, vw_type, vw_open_application

    // --- V2 (+13 tools beyond the extensions to existing files) ---
    makeCreateWindowSpecTool(bridge),       // vw_create_window_spec
    makeCompileMethodTool(bridge),          // vw_compile_method
    makeDefineActionTool(bridge),           // vw_define_action
    makeDefineAspectTool(bridge),           // vw_define_aspect
    makeCreateApplicationModelTool(bridge), // vw_create_application_model
    makeCreateDialogTool(bridge),           // vw_create_dialog
    ...makeTestingTools(bridge),            // vw_run_test_class, vw_run_test_method, vw_list_failing_tests, +V3 vw_describe_test_failure

    // --- V3 (+17 tools beyond the extensions) ---
    ...makeIntrospectionTools(bridge), // vw_get_method_fingerprint, vw_get_class_hierarchy, vw_export_class, vw_search_method_messages
    ...makeDestructiveTools(bridge),   // vw_compile_class_definition, vw_delete_method, vw_delete_class, vw_set_class_comment
    ...makeDialogTools(bridge),        // vw_list_dialogs, vw_respond_dialog
    ...makeWaitTools(bridge),          // vw_wait
    ...makeScreenshotTools(bridge),    // vw_screenshot
    makeCreateParcelTool(bridge),      // vw_create_parcel
  ];
}

/** Register every tool def with the MCP server. */
function registerTools(server: McpServer, tools: ToolDef[]): void {
  for (const tool of tools) {
    server.registerTool(
      tool.name,
      {
        description: tool.description,
        inputSchema: tool.inputSchema,
      },
      // Cast: our ToolDef.handler shape matches the SDK's ToolCallback at runtime.
      tool.handler as Parameters<typeof server.registerTool>[2]
    );
  }
}

function log(msg: string): void {
  process.stderr.write(`[mcp-vw] ${msg}\n`);
}

async function main(): Promise<void> {
  const config = resolveConfig();
  log(`starting (bridge=${config.bridgeUrl}, tokenFile=${config.tokenFile})`);

  // -------------------------------------------------------------------------
  // Single-owner gate (architecture.md §9)
  // -------------------------------------------------------------------------
  const lock = new OwnerLock({
    lockFile: config.lockFile,
    ...(config.singleOwner !== undefined ? { singleOwner: config.singleOwner } : {}),
  });
  const acquireResult = await lock.acquire();
  if (!acquireResult.acquired) {
    process.stderr.write(
      `[mcp-vw] FATAL: another mcp-vw process (PID ${acquireResult.heldByPid}) holds the single-owner lock at ${config.lockFile}.\n` +
        '[mcp-vw] If that process is gone, delete the lockfile and retry.\n' +
        '[mcp-vw] To run multiple instances anyway, set MCP_VW_SINGLE_OWNER=0.\n'
    );
    process.exit(EXIT_SINGLE_OWNER_HELD);
  }

  // -------------------------------------------------------------------------
  // Build server + tools
  // -------------------------------------------------------------------------
  const bridge = new BridgeClient({
    bridgeUrl: config.bridgeUrl,
    tokenFile: config.tokenFile,
  });
  const tools = buildAllTools(bridge);
  log(`registering ${tools.length} tools`);

  const server = new McpServer({
    name: SERVER_NAME,
    version: SERVER_VERSION,
  });
  registerTools(server, tools);

  // -------------------------------------------------------------------------
  // Graceful shutdown
  // -------------------------------------------------------------------------
  let shuttingDown = false;
  const shutdown = async (signal: string): Promise<void> => {
    if (shuttingDown) return;
    shuttingDown = true;
    log(`received ${signal}, shutting down`);
    try {
      await server.close();
    } catch (err) {
      log(`server.close() failed: ${err instanceof Error ? err.message : String(err)}`);
    }
    try {
      await lock.release();
    } catch (err) {
      log(`lock.release() failed: ${err instanceof Error ? err.message : String(err)}`);
    }
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  // Exit when stdin closes (Claude Desktop's signal to terminate).
  process.stdin.on('close', () => void shutdown('stdin-close'));

  // -------------------------------------------------------------------------
  // Connect transport
  // -------------------------------------------------------------------------
  const transport = new StdioServerTransport();
  await server.connect(transport);
  log(`ready on stdio (server=${SERVER_NAME}@${SERVER_VERSION})`);
}

main().catch((err) => {
  process.stderr.write(
    `[mcp-vw] FATAL: ${err instanceof Error ? err.stack ?? err.message : String(err)}\n`
  );
  process.exit(1);
});
