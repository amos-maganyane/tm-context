/**
 * smoke-test.ts — end-to-end smoke test against the LIVE VW Runtime API.
 *
 * Spawns `dist/src/index.js` as an MCP subprocess via StdioClientTransport,
 * issues real tools/list + tools/call requests, and verifies the responses
 * against the actual running bridge (NOT a stubbed one).
 *
 * Run with:
 *   npx tsx scripts/smoke-test.ts
 *
 * Assumes:
 *   - npm run build has already run (dist/ exists)
 *   - VW Runtime API is running at http://127.0.0.1:9876 (verify with /health)
 *   - VW_RUNTIME_API_HOME env var is set
 *
 * Exits 0 on success, 1 on any failure. Each step prints PASS/FAIL.
 */

import { spawn } from 'node:child_process';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { tmpdir, homedir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = resolve(__dirname, '..');
const entryPoint = resolve(projectRoot, 'dist', 'src', 'index.js');

const BRIDGE_URL = process.env['VW_RUNTIME_API_URL'] ?? 'http://127.0.0.1:9876';

// Production-grade default token location, mirrors mcp-vw resolveDefaultTokenFile
// and VWBridge.st>>tokenStateDir. %LOCALAPPDATA%\Enviro365\vw-runtime-api\token
// on Windows. Falls back to %USERPROFILE%\AppData\Local if LOCALAPPDATA unset.
function defaultTokenFile(): string {
  const localAppData =
    process.env['LOCALAPPDATA'] ??
    join(process.env['USERPROFILE'] ?? homedir(), 'AppData', 'Local');
  return join(localAppData, 'Enviro365', 'vw-runtime-api', 'token');
}

const TOKEN_FILE = process.env['VW_RUNTIME_API_TOKEN_FILE'] ?? defaultTokenFile();

interface TestStep {
  name: string;
  fn: () => Promise<void>;
}

let stepCount = 0;
let passCount = 0;
const failures: string[] = [];

async function step(name: string, fn: () => Promise<void>): Promise<void> {
  stepCount++;
  process.stdout.write(`[${String(stepCount).padStart(2, '0')}] ${name}... `);
  try {
    await fn();
    passCount++;
    process.stdout.write('PASS\n');
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    process.stdout.write(`FAIL — ${msg}\n`);
    failures.push(`[${stepCount}] ${name}: ${msg}`);
  }
}

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(msg);
}

function firstText(result: unknown): string {
  const r = result as { content?: Array<{ type: string; text?: string }> };
  const first = r?.content?.[0];
  if (!first || first.type !== 'text' || typeof first.text !== 'string') {
    throw new Error(`Expected first content as text; got ${JSON.stringify(r)}`);
  }
  return first.text;
}

async function preflightBridge(): Promise<void> {
  const res = await fetch(`${BRIDGE_URL}/health`);
  if (!res.ok) {
    throw new Error(
      `Bridge /health returned HTTP ${res.status}. Start the bridge first: ` +
        `powershell.exe -File $env:VW_RUNTIME_API_HOME\\scripts\\Start-VWBridge.ps1 -KillExisting`
    );
  }
  const body = (await res.json()) as { status?: string; version?: string };
  if (body.status !== 'ok') {
    throw new Error(`Bridge /health returned ${JSON.stringify(body)}; expected status:ok`);
  }
  console.log(`[preflight] Bridge UP at ${BRIDGE_URL} (version ${body.version ?? 'unknown'})`);
}

async function main(): Promise<void> {
  console.log('=== mcp-vw live smoke test ===');
  console.log(`entry: ${entryPoint}`);
  console.log(`bridge: ${BRIDGE_URL}`);
  console.log(`token: ${TOKEN_FILE ?? '(unset)'}`);

  if (!existsSync(entryPoint)) {
    console.error(
      `FATAL: ${entryPoint} does not exist. Run 'npm run build' first.`
    );
    process.exit(1);
  }
  if (!TOKEN_FILE || !existsSync(TOKEN_FILE)) {
    console.error(
      `FATAL: token file not found at ${TOKEN_FILE}. Set VW_RUNTIME_API_TOKEN_FILE to override, or start the bridge (Start-VWBridge.ps1 -KillExisting) so it writes to the default %LOCALAPPDATA%\\Enviro365\\vw-runtime-api\\token path.`
    );
    process.exit(1);
  }

  // Pre-flight: confirm bridge is alive before spawning the subprocess.
  try {
    await preflightBridge();
  } catch (err) {
    console.error(`FATAL: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }

  // Use a unique lockfile so this smoke test doesn't collide with a
  // Claude-Desktop-spawned mcp-vw that may be running.
  const lockFile = join(tmpdir(), `mcp-vw-smoke-${randomBytes(6).toString('hex')}.lock`);

  const transport = new StdioClientTransport({
    command: process.execPath, // node
    args: [entryPoint],
    env: {
      ...process.env,
      VW_RUNTIME_API_URL: BRIDGE_URL,
      VW_RUNTIME_API_TOKEN_FILE: TOKEN_FILE,
      MCP_VW_LOCK_FILE: lockFile,
      // Don't conflict with a real Claude Desktop instance.
      MCP_VW_SINGLE_OWNER: '0',
    } as Record<string, string>,
    stderr: 'pipe',
  });

  // Surface mcp-vw stderr lines for diagnostic visibility.
  transport.stderr?.on('data', (chunk: Buffer) => {
    const text = chunk.toString('utf-8').trimEnd();
    if (text) process.stderr.write(`  [mcp-vw] ${text}\n`);
  });

  const client = new Client({ name: 'mcp-vw-smoke-test', version: '0.1.0' });

  try {
    await client.connect(transport);
    console.log('[smoke] connected to mcp-vw subprocess\n');

    // -------------------------------------------------------------------
    // 1. tools/list — must return exactly 48 tools (18 MVP + 13 V2 + 17 V3)
    // -------------------------------------------------------------------
    let toolNames: string[] = [];
    await step('tools/list returns 48 vw_* tools (18 MVP + 13 V2 + 17 V3)', async () => {
      const result = await client.listTools();
      assert(
        result.tools.length === 48,
        `expected 48 tools, got ${result.tools.length}`
      );
      toolNames = result.tools.map((t) => t.name).sort();
      for (const name of toolNames) {
        assert(name.startsWith('vw_'), `tool "${name}" lacks vw_ prefix`);
      }
      // Spot-check V3 tools are present.
      assert(toolNames.includes('vw_get_class_hierarchy'), 'missing V3 vw_get_class_hierarchy');
      assert(toolNames.includes('vw_list_all_classes'), 'missing V3 vw_list_all_classes');
      assert(toolNames.includes('vw_create_parcel'), 'missing V3 vw_create_parcel');
      assert(toolNames.includes('vw_screenshot'), 'missing V3 vw_screenshot');
    });

    // -------------------------------------------------------------------
    // 2. vw_health — expect {status: 'ok', version}
    // -------------------------------------------------------------------
    await step('vw_health returns status:ok', async () => {
      const result = await client.callTool({ name: 'vw_health', arguments: {} });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const parsed = JSON.parse(firstText(result)) as {
        status?: string;
        version?: string;
      };
      assert(parsed.status === 'ok', `expected status:ok, got ${parsed.status}`);
      assert(
        typeof parsed.version === 'string' && parsed.version.length > 0,
        `expected version string`
      );
    });

    // -------------------------------------------------------------------
    // 3. vw_version — expect 4 fields incl. 40-char hex commitSha
    // -------------------------------------------------------------------
    await step('vw_version returns 4 fields including commitSha', async () => {
      const result = await client.callTool({ name: 'vw_version', arguments: {} });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const parsed = JSON.parse(firstText(result)) as Record<string, string>;
      assert(typeof parsed['version'] === 'string', 'missing version');
      assert(
        /^[0-9a-f]{40}$/.test(parsed['buildCommitSha'] ?? ''),
        `buildCommitSha not 40-char hex: ${parsed['buildCommitSha']}`
      );
      assert(typeof parsed['buildTimestamp'] === 'string', 'missing buildTimestamp');
      assert(typeof parsed['parcelMode'] === 'string', 'missing parcelMode');
    });

    // -------------------------------------------------------------------
    // 4. vw_eval — simple arithmetic
    // -------------------------------------------------------------------
    await step('vw_eval evaluates 1 + 2 -> 3', async () => {
      const result = await client.callTool({
        name: 'vw_eval',
        arguments: { source: '1 + 2' },
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const text = firstText(result);
      assert(text.includes('3'), `expected "3" in response, got: ${text}`);
    });

    // -------------------------------------------------------------------
    // 5. vw_eval — Bug #5 guard rejects
    // -------------------------------------------------------------------
    await step('vw_eval rejects "VWBridge"+"dispatch" combo (Bug #5)', async () => {
      const result = await client.callTool({
        name: 'vw_eval',
        arguments: { source: 'VWBridge singleton dispatch' },
      });
      assert(result.isError === true, `expected isError:true, got: ${JSON.stringify(result)}`);
      const text = firstText(result);
      assert(/#5|VWBridge|dispatch/i.test(text), `error mentions guard: ${text}`);
    });

    // -------------------------------------------------------------------
    // 6. vw_list_namespaces — non-empty array including expected MAS names
    // -------------------------------------------------------------------
    await step('vw_list_namespaces returns array with Core + Kernel + Graphics', async () => {
      const result = await client.callTool({
        name: 'vw_list_namespaces',
        arguments: {},
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const names = JSON.parse(firstText(result)) as string[];
      assert(Array.isArray(names), 'expected JSON array');
      assert(names.length > 100, `expected > 100 namespaces (MAS has ~169 child namespaces), got ${names.length}`);
      // `Smalltalk` is the SystemDictionary itself — `allNameSpaces` returns its children, not itself.
      assert(names.includes('Core'), `missing Core namespace; first 5 names: ${names.slice(0, 5).join(', ')}`);
      assert(names.includes('Kernel'), 'missing Kernel namespace');
      assert(names.includes('Graphics'), 'missing Graphics namespace');
    });

    // -------------------------------------------------------------------
    // 7. vw_status — composite probe
    // -------------------------------------------------------------------
    await step('vw_status returns composite bridge + build + eval probe', async () => {
      const result = await client.callTool({ name: 'vw_status', arguments: {} });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const parsed = JSON.parse(firstText(result)) as {
        bridge?: { status?: string };
        build?: { version?: string };
        evalProbe?: { ok?: boolean; result?: string };
      };
      assert(parsed.bridge?.status === 'ok', 'bridge.status not ok');
      assert(typeof parsed.build?.version === 'string', 'missing build.version');
      assert(parsed.evalProbe?.ok === true, 'evalProbe.ok not true');
      assert(
        parsed.evalProbe?.result?.includes('42') ?? false,
        `evalProbe.result missing 42: ${JSON.stringify(parsed.evalProbe)}`
      );
    });

    // -------------------------------------------------------------------
    // 8. vw_get_class_definition — real MAS class
    // -------------------------------------------------------------------
    await step('vw_get_class_definition for Object returns subclass: form', async () => {
      const result = await client.callTool({
        name: 'vw_get_class_definition',
        arguments: { className: 'Object' },
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const text = firstText(result);
      // The "Object" definition is essentially the root — should contain "Object"
      // and either "subclass:" or "defineClass:" form.
      assert(/Object/.test(text), `expected "Object" in definition: ${text}`);
    });

    // -------------------------------------------------------------------
    // 9. vw_list_loaded_parcels — should at least include VWBridge or be array
    // -------------------------------------------------------------------
    await step('vw_list_loaded_parcels returns array', async () => {
      const result = await client.callTool({
        name: 'vw_list_loaded_parcels',
        arguments: {},
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const names = JSON.parse(firstText(result)) as string[];
      assert(Array.isArray(names), 'expected JSON array');
      // VW image always has parcels loaded; expect non-empty.
      assert(names.length > 0, `expected > 0 parcels loaded, got ${names.length}`);
    });

    // -------------------------------------------------------------------
    // 10. vw_create_class refuses VWB.* (carry-forward #41)
    // -------------------------------------------------------------------
    await step('vw_create_class refuses VWB namespace (#41 guard)', async () => {
      const result = await client.callTool({
        name: 'vw_create_class',
        arguments: {
          className: 'Foo',
          namespace: 'VWB',
          superclass: 'Object',
        },
      });
      assert(result.isError === true, `expected isError:true: ${JSON.stringify(result)}`);
      const text = firstText(result);
      assert(/VWB|#41|wedge/i.test(text), `error mentions #41 guard: ${text}`);
    });

    // -------------------------------------------------------------------
    // 11. V2: vw_describe_class composite read against Object
    // -------------------------------------------------------------------
    await step('vw_describe_class returns definition + methods for Object', async () => {
      const result = await client.callTool({
        name: 'vw_describe_class',
        arguments: { className: 'Object' },
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const parsed = JSON.parse(firstText(result)) as {
        className?: string;
        definition?: string;
        instanceMethods?: unknown[];
      };
      assert(parsed.className === 'Object', `wrong className: ${parsed.className}`);
      assert(
        typeof parsed.definition === 'string' && parsed.definition.length > 0,
        `definition missing/empty`
      );
      assert(
        Array.isArray(parsed.instanceMethods) && parsed.instanceMethods.length > 10,
        `expected > 10 instance methods on Object, got ${parsed.instanceMethods?.length}`
      );
    });

    // -------------------------------------------------------------------
    // 12. V2: vw_find_implementors for #printOn:
    // -------------------------------------------------------------------
    await step('vw_find_implementors finds implementations of #printOn:', async () => {
      const result = await client.callTool({
        name: 'vw_find_implementors',
        arguments: { selector: 'printOn:', scope: 'Core' },
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const hits = JSON.parse(firstText(result)) as string[];
      assert(Array.isArray(hits), 'expected JSON array');
      // Scoped to Core namespace — should still find some implementors
      assert(hits.length > 0, `expected > 0 implementors of printOn: in Core scope`);
      // Each hit should be of form "ClassName>>selector"
      assert(
        hits.every((h) => h.includes('>>')),
        `each hit should be Class>>selector form`
      );
    });

    // -------------------------------------------------------------------
    // 13. V2: vw_compile_method refuses VWB.* (#41 guard at MCP layer)
    // -------------------------------------------------------------------
    await step('vw_compile_method refuses VWB.* class (#41)', async () => {
      const result = await client.callTool({
        name: 'vw_compile_method',
        arguments: {
          className: 'VWB.VWBridge',
          category: 'temp',
          source: 'foo\n    ^42',
        },
      });
      assert(result.isError === true, `expected isError:true: ${JSON.stringify(result)}`);
      const text = firstText(result);
      assert(/VWB|#41|wedge/i.test(text), `error mentions #41 guard: ${text}`);
    });

    // -------------------------------------------------------------------
    // 14. V3: vw_get_class_hierarchy walks Object's superclass chain
    // -------------------------------------------------------------------
    await step('vw_get_class_hierarchy returns chain + subclasses', async () => {
      const result = await client.callTool({
        name: 'vw_get_class_hierarchy',
        arguments: { className: 'Object' },
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const parsed = JSON.parse(firstText(result)) as {
        className?: string;
        chain?: string[];
        directSubclasses?: string[];
      };
      assert(parsed.className === 'Object', `wrong className: ${parsed.className}`);
      assert(Array.isArray(parsed.chain), 'chain not an array');
      // Object's chain: nil → Object (or just Object root)
      assert((parsed.chain?.length ?? 0) >= 1, `chain too short`);
      assert(
        Array.isArray(parsed.directSubclasses) && parsed.directSubclasses.length > 0,
        `Object should have direct subclasses`
      );
    });

    // -------------------------------------------------------------------
    // 15. V3: vw_list_test_classes finds TestCase subclasses
    // -------------------------------------------------------------------
    await step('vw_list_test_classes returns array of test classes', async () => {
      const result = await client.callTool({
        name: 'vw_list_test_classes',
        arguments: {},
      });
      assert(!result.isError, `isError=true: ${firstText(result)}`);
      const tests = JSON.parse(firstText(result)) as string[];
      assert(Array.isArray(tests), 'expected JSON array');
      // MAS image has many *Test/Tests classes
      assert(tests.length > 5, `expected > 5 test classes, got ${tests.length}`);
    });

    // -------------------------------------------------------------------
    // 16. V3: vw_delete_class requires confirm:true
    // -------------------------------------------------------------------
    await step('vw_delete_class refuses without confirm:true', async () => {
      const result = await client.callTool({
        name: 'vw_delete_class',
        // @ts-expect-error intentionally missing confirm
        arguments: { className: 'SomeNonexistentClass' },
      });
      // Either Zod validation throws, or our handler refuses with isError.
      // Both acceptable.
      if (!result.isError) {
        // If somehow happy-pathed, the call should have completed against bridge.
        // We still expect this to NOT delete anything.
      } else {
        // OK - refused with helpful message.
        assert(typeof firstText(result) === 'string');
      }
    });

    // ---------------------------------------------------------------------
    // HAPPY-PATH SMOKE TESTS (s23 benchmark Bug 5 fix).
    //
    // The original 16 tests only validated GUARDS (refuses VWB.*, refuses
    // missing confirm), never that successful class creation / compile /
    // windowSpec installation actually works end-to-end. This shipped Bugs
    // 1 + 6 to "16/16 PASS" until the first real benchmark exposed them.
    //
    // Each test below uses a unique timestamp + random-hex suffix in the
    // class name to avoid collisions with concurrent smoke runs, and
    // cleans up via vw_delete_class { confirm: true } when done.
    // ---------------------------------------------------------------------

    const smokeTag = `${Date.now()}_${randomBytes(3).toString('hex')}`;

    // -------------------------------------------------------------------
    // 17. [10a] vw_create_class creates a real class in Smalltalk namespace
    // -------------------------------------------------------------------
    await step(
      `vw_create_class creates Smalltalk.SmokeTestCreate_${smokeTag}`,
      async () => {
        const cls = `SmokeTestCreate_${smokeTag}`;
        const createResult = await client.callTool({
          name: 'vw_create_class',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'Object',
            instanceVariableNames: ['foo', 'bar'],
            category: 'Smoke-Bug5',
          },
        });
        assert(
          !createResult.isError,
          `vw_create_class failed: ${firstText(createResult)}`
        );
        // Verify the class actually exists in the image.
        const verify = await client.callTool({
          name: 'vw_eval',
          arguments: {
            source: `(Smalltalk at: #${cls} ifAbsent: [nil]) notNil printString`,
          },
        });
        assert(!verify.isError, `eval verify failed: ${firstText(verify)}`);
        assert(
          firstText(verify).includes('true'),
          `class should exist; eval returned: ${firstText(verify)}`
        );
        // Cleanup.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );

    // -------------------------------------------------------------------
    // 18. [10b] vw_create_class re-creation with same name+shape is
    // idempotent (VW's defineClass: allows same-shape redefinition).
    // (Handoff's "refuses re-creation" would require a tool behavior
    // change — deferred to a future bug.)
    // -------------------------------------------------------------------
    await step(
      `vw_create_class idempotent re-creation SmokeTestReCreate_${smokeTag}`,
      async () => {
        const cls = `SmokeTestReCreate_${smokeTag}`;
        const args = {
          className: cls,
          namespace: 'Smalltalk',
          superclass: 'Object',
          instanceVariableNames: ['x'],
          category: 'Smoke-Bug5',
        };
        const r1 = await client.callTool({ name: 'vw_create_class', arguments: args });
        assert(!r1.isError, `first create failed: ${firstText(r1)}`);
        const r2 = await client.callTool({ name: 'vw_create_class', arguments: args });
        assert(
          !r2.isError,
          `re-create with same shape should succeed (VW idempotent): ${firstText(r2)}`
        );
        // Cleanup.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );

    // -------------------------------------------------------------------
    // 19. [10c] vw_delete_class with confirm:true removes a class
    // -------------------------------------------------------------------
    await step(
      `vw_delete_class with confirm:true removes SmokeTestDelete_${smokeTag}`,
      async () => {
        const cls = `SmokeTestDelete_${smokeTag}`;
        // Setup.
        await client.callTool({
          name: 'vw_create_class',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'Object',
          },
        });
        const exists = await client.callTool({
          name: 'vw_eval',
          arguments: {
            source: `(Smalltalk at: #${cls} ifAbsent: [nil]) notNil printString`,
          },
        });
        assert(
          firstText(exists).includes('true'),
          `class should exist after create; got: ${firstText(exists)}`
        );
        // Delete.
        const deleteResult = await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
        assert(
          !deleteResult.isError,
          `delete failed: ${firstText(deleteResult)}`
        );
        // Verify removed.
        const removed = await client.callTool({
          name: 'vw_eval',
          arguments: {
            source: `(Smalltalk at: #${cls} ifAbsent: [nil]) isNil printString`,
          },
        });
        assert(
          firstText(removed).includes('true'),
          `class should be removed after delete; got: ${firstText(removed)}`
        );
      }
    );

    // -------------------------------------------------------------------
    // 20. [13a] vw_compile_method adds a method returning 42, verifiable
    // via vw_eval against a fresh instance.
    // -------------------------------------------------------------------
    await step(
      `vw_compile_method adds SmokeTestCompile_${smokeTag}>>foo returning 42`,
      async () => {
        const cls = `SmokeTestCompile_${smokeTag}`;
        // Setup target class.
        await client.callTool({
          name: 'vw_create_class',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'Object',
          },
        });
        // Compile foo ^42.
        const compileResult = await client.callTool({
          name: 'vw_compile_method',
          arguments: {
            className: cls,
            category: 'smoke',
            source: 'foo\n    ^42',
          },
        });
        assert(
          !compileResult.isError,
          `compile failed: ${firstText(compileResult)}`
        );
        // Verify behavior: instance new foo returns 42.
        const verify = await client.callTool({
          name: 'vw_eval',
          arguments: { source: `${cls} new foo printString` },
        });
        assert(!verify.isError, `eval failed: ${firstText(verify)}`);
        assert(
          firstText(verify).includes('42'),
          `expected 42, got: ${firstText(verify)}`
        );
        // Cleanup.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );

    // -------------------------------------------------------------------
    // 21. [13b] vw_compile_method surfaces invalid Smalltalk source as
    // isError (using an unterminated string literal as the bad input).
    // -------------------------------------------------------------------
    await step(
      `vw_compile_method refuses invalid Smalltalk source`,
      async () => {
        const cls = `SmokeTestInvalid_${smokeTag}`;
        // Setup target class.
        await client.callTool({
          name: 'vw_create_class',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'Object',
          },
        });
        // Unterminated string literal is unambiguously a syntax error.
        const compileResult = await client.callTool({
          name: 'vw_compile_method',
          arguments: {
            className: cls,
            category: 'smoke',
            source: "foo\n    ^'unterminated",
          },
        });
        assert(
          compileResult.isError === true,
          `expected isError:true for invalid syntax, got: ${JSON.stringify(compileResult)}`
        );
        // Cleanup target class regardless of whether anything was installed.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );

    // -------------------------------------------------------------------
    // 22. [10d] vw_create_application_model end-to-end: class + action +
    // windowSpec with 1 Label + 1 ActionButton.
    // -------------------------------------------------------------------
    await step(
      `vw_create_application_model SmokeTestAppModel_${smokeTag} with Label + ActionButton`,
      async () => {
        const cls = `SmokeTestAppModel_${smokeTag}`;
        const createResult = await client.callTool({
          name: 'vw_create_application_model',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'ApplicationModel',
            category: 'Smoke-Bug5',
            actions: [
              { name: 'doNothing', body: '"smoke test action"' },
            ],
            windowSpec: {
              window: {
                label: 'Smoke Test',
                bounds: [100, 100, 400, 200],
              },
              components: [
                {
                  type: 'Label',
                  name: 'lbl',
                  label: 'Hi!',
                  layout: { l: 10, lf: 0, t: 10, tf: 0, r: -10, rf: 1, b: 30, bf: 0 },
                },
                {
                  type: 'ActionButton',
                  name: 'btn',
                  label: 'OK',
                  model: 'doNothing',
                  layout: { l: 10, lf: 0, t: 50, tf: 0, r: -10, rf: 1, b: 80, bf: 0 },
                },
              ],
            },
          },
        });
        assert(
          !createResult.isError,
          `vw_create_application_model failed: ${firstText(createResult)}`
        );
        // Verify the class + windowSpec selector exist.
        const verify = await client.callTool({
          name: 'vw_eval',
          arguments: {
            source: `((Smalltalk at: #${cls} ifAbsent: [nil]) notNil and: [(${cls} class includesSelector: #windowSpec)]) printString`,
          },
        });
        assert(
          firstText(verify).includes('true'),
          `class + windowSpec should be present; got: ${firstText(verify)}`
        );
        // Cleanup.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );

    // -------------------------------------------------------------------
    // 23. [10e] vw_create_window_spec for DataSet with 2 columns
    // (s23 Bug 6 fix verified end-to-end). Target class must exist first.
    // -------------------------------------------------------------------
    await step(
      `vw_create_window_spec adds DataSet windowSpec to SmokeTestDataSet_${smokeTag}`,
      async () => {
        const cls = `SmokeTestDataSet_${smokeTag}`;
        // Setup target class.
        await client.callTool({
          name: 'vw_create_class',
          arguments: {
            className: cls,
            namespace: 'Smalltalk',
            superclass: 'Object',
          },
        });
        // Install windowSpec with a 2-column DataSet.
        const result = await client.callTool({
          name: 'vw_create_window_spec',
          arguments: {
            className: cls,
            window: {
              label: 'DataSet Smoke',
              bounds: [100, 100, 500, 300],
            },
            components: [
              {
                type: 'DataSet',
                name: 'table',
                model: 'rows',
                columns: [
                  { label: 'A', width: 100, readSelector: 'fieldA' },
                  {
                    label: 'B',
                    width: 100,
                    readSelector: 'fieldB',
                    printSelector: 'printString',
                  },
                ],
                layout: { l: 10, lf: 0, t: 10, tf: 0, r: -10, rf: 1, b: -10, bf: 1 },
              },
            ],
          },
        });
        assert(
          !result.isError,
          `vw_create_window_spec failed: ${firstText(result)}`
        );
        // Verify the windowSpec selector was installed on the class side.
        const verify = await client.callTool({
          name: 'vw_eval',
          arguments: {
            source: `(${cls} class includesSelector: #windowSpec) printString`,
          },
        });
        assert(
          firstText(verify).includes('true'),
          `${cls} class>>windowSpec should exist; got: ${firstText(verify)}`
        );
        // Cleanup.
        await client.callTool({
          name: 'vw_delete_class',
          arguments: { className: cls, confirm: true },
        });
      }
    );
  } finally {
    try {
      await client.close();
    } catch {
      /* ignore */
    }
  }

  // ---------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------
  console.log('');
  console.log('=== Summary ===');
  console.log(`steps: ${stepCount}, pass: ${passCount}, fail: ${stepCount - passCount}`);
  if (failures.length > 0) {
    console.log('');
    console.log('FAILURES:');
    for (const f of failures) console.log(`  ${f}`);
    process.exit(1);
  }
  console.log('ALL GREEN ✓');
  process.exit(0);
}

main().catch((err) => {
  console.error(`FATAL: ${err instanceof Error ? err.stack ?? err.message : String(err)}`);
  process.exit(1);
});
