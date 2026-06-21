/**
 * codegen/parcel.ts — vw_create_parcel (V3 HEAVYWEIGHT).
 *
 * Build a binary .pcl parcel from a class list + optional namespaces + optional
 * extension methods. Wraps the canonical Smalltalk pattern proven session-19
 * (Phase P P6):
 *
 *   1. Save Cursor>>showWhile: method (carry-forward #35)
 *   2. Install Cursor pass-through patch (`^aBlock value`)
 *   3. Build parcel: createParcelNamed: + addNameSpace: + addEntiretyOfClass:
 *      + addSelector:class: + parcelOutOn:withSource:hideOnLoad:republish:backup:
 *   4. Cleanup via removeParcelNamed: wrapped with Notification-resume (#38)
 *   5. Restore Cursor method via methodDictionary swap (NOT recompile — sources stripped)
 *   6. Wrap everything in ensure: so restore runs even on error
 *
 * Carry-forward constraints honored:
 *   - #35 Cursor>>showWhile: wedge — monkey-patch + restore
 *   - #36 createParcelNamed: returns EMPTY (content added explicitly)
 *   - #37 parcelOutOn:withSource: takes Filename (NOT boolean)
 *   - #38 removeParcelNamed: raises Notification → must resume
 *   - #41 compile on VWB.* wedges → refuse VWB.* class targets
 *   - #42 ensure: referencing VWB after parcelOutOn: raises "no binding" → we
 *         don't reference VWB classes in the ensure block
 *
 * Per architecture.md §5.3 (tool 48) + §6.7.
 */

import { z } from 'zod';
import type { BridgeClientLike } from '../bridge.js';
import { text, errorResult, safeHandler, type ToolResult } from '../util.js';
import {
  isValidClassIdentifier,
  isValidNamespaceIdentifier,
  isValidSelector,
  quoteSmalltalkString,
} from '../smalltalk.js';
import type { ToolDef } from '../tools/types.js';

// -----------------------------------------------------------------------------
// Input schema
// -----------------------------------------------------------------------------

const extensionSchema = z.object({
  className: z.string().min(1).max(200),
  selector: z.string().min(1).max(200),
  isMeta: z.boolean().optional(),
});

const createParcelSchema = {
  name: z
    .string()
    .min(1)
    .max(200)
    .describe('Parcel name (e.g. "MyApp"). Will produce <outputDir>/<name>.pcl + .pst.'),
  outputDir: z
    .string()
    .min(1)
    .max(2_000)
    .describe('Output directory for the .pcl + .pst files. Use forward slashes or escaped backslashes for Windows.'),
  namespaces: z
    .array(z.string().min(1).max(100))
    .optional()
    .describe('Namespace identifiers to include via addNameSpace:. The parcel auto-creates these on load if absent.'),
  classes: z
    .array(z.string().min(1).max(200))
    .describe('Fully-qualified class identifiers to include via addEntiretyOfClass:. Each class + ALL its methods.'),
  extensions: z
    .array(extensionSchema)
    .optional()
    .describe('Extension methods to add via addSelector:class: (e.g. category-prefixed *VWBridge-Patches methods).'),
  hideOnLoad: z
    .boolean()
    .optional()
    .describe('Whether to hide the parcel on load (post-load UI suppression). Default false.'),
};

// -----------------------------------------------------------------------------
// Tool factory
// -----------------------------------------------------------------------------

const TOOL_DESCRIPTION =
  'HEAVYWEIGHT: build a binary .pcl parcel from a typed JSON spec. ' +
  'Internally wraps the canonical Phase P P6 pattern: Cursor>>showWhile: monkey-patch (carry-forward #35) + createParcelNamed: + addEntiretyOfClass: + parcelOutOn:withSource:hideOnLoad:republish:backup: + removeParcelNamed: Notification-resume (#38) + Cursor methodDictionary restore. ' +
  'AI passes {name, outputDir, namespaces, classes, extensions, hideOnLoad}; tool emits a single composite Smalltalk script + dispatches via /eval. ' +
  'REFUSED for any VWB.* class target (carry-forward #41 — would wedge the bridge mid-build).';

function refusesVWB(name: string): boolean {
  return name === 'VWB' || name.startsWith('VWB.');
}

export function makeCreateParcelTool(
  bridge: BridgeClientLike
): ToolDef<typeof createParcelSchema> {
  return {
    name: 'vw_create_parcel',
    description: TOOL_DESCRIPTION,
    inputSchema: createParcelSchema,
    handler: safeHandler(async (input): Promise<ToolResult> => {
      // ---------------------------------------------------------------------
      // Validation
      // ---------------------------------------------------------------------
      if (!/^[A-Za-z][A-Za-z0-9_-]*$/.test(input.name)) {
        return errorResult(
          `vw_create_parcel: invalid parcel name "${input.name}". Must match /^[A-Za-z][A-Za-z0-9_-]*$/.`
        );
      }
      if (input.outputDir.trim().length === 0) {
        return errorResult('vw_create_parcel: outputDir is empty.');
      }

      const namespaces = input.namespaces ?? [];
      for (const ns of namespaces) {
        if (!isValidNamespaceIdentifier(ns)) {
          return errorResult(`vw_create_parcel: invalid namespace identifier "${ns}".`);
        }
        if (ns === 'VWB') {
          return errorResult(
            `vw_create_parcel refuses VWB namespace target (carry-forward #41).`
          );
        }
      }

      for (const cls of input.classes) {
        if (!isValidClassIdentifier(cls)) {
          return errorResult(`vw_create_parcel: invalid class identifier "${cls}".`);
        }
        if (refusesVWB(cls)) {
          return errorResult(
            `vw_create_parcel refuses VWB.* class target "${cls}" (carry-forward #41 — would wedge the bridge mid-build).`
          );
        }
      }

      const extensions = input.extensions ?? [];
      for (const ext of extensions) {
        if (!isValidClassIdentifier(ext.className)) {
          return errorResult(
            `vw_create_parcel: invalid extension className "${ext.className}".`
          );
        }
        if (refusesVWB(ext.className)) {
          return errorResult(
            `vw_create_parcel refuses VWB.* extension class "${ext.className}" (carry-forward #41).`
          );
        }
        if (!isValidSelector(ext.selector)) {
          return errorResult(
            `vw_create_parcel: invalid extension selector "${ext.selector}".`
          );
        }
      }

      // ---------------------------------------------------------------------
      // Emit composite Smalltalk script
      // ---------------------------------------------------------------------
      const namespaceLines = namespaces
        .map((ns) => `    parcel addNameSpace: ${ns}.`)
        .join('\n');
      const classLines = input.classes
        .map((c) => `    parcel addEntiretyOfClass: ${c}.`)
        .join('\n');
      const extensionLines = extensions
        .map((e) => {
          const receiver = e.isMeta === true ? `${e.className} class` : e.className;
          return `    parcel addSelector: #${e.selector} class: ${receiver}.`;
        })
        .join('\n');

      // Normalize output path: prefer forward slashes; embed in Smalltalk string literal.
      const pclPath = `${input.outputDir.replace(/[\\/]+$/, '')}/${input.name}.pcl`;
      const pstPath = `${input.outputDir.replace(/[\\/]+$/, '')}/${input.name}.pst`;
      const hideOnLoad = input.hideOnLoad === true ? 'true' : 'false';

      const probe = `| parcel oldShowWhile pclFile pstFile patchInstalled |
oldShowWhile := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value'
        classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true]
        on: Core.Notification do: [:n | n resume].

    patchInstalled ifTrue: [
        parcel := Kernel.Parcel createParcelNamed: ${quoteSmalltalkString(input.name)}.
${namespaceLines}
${classLines}
${extensionLines}
        pclFile := ${quoteSmalltalkString(pclPath)} asFilename.
        pstFile := ${quoteSmalltalkString(pstPath)} asFilename.
        parcel
            parcelOutOn: pclFile
            withSource: pstFile
            hideOnLoad: ${hideOnLoad}
            republish: false
            backup: false.
        [Kernel.Parcel removeParcelNamed: ${quoteSmalltalkString(input.name)}]
            on: Core.Notification do: [:n | n resume]]
] ensure: [
    "Restore Cursor method via methodDictionary swap (sources stripped — can't recompile)."
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: oldShowWhile]
].
'OK ' , ${quoteSmalltalkString(pclPath)} , ' + ' , ${quoteSmalltalkString(pstPath)}`;

      const evalResult = await bridge.postEval(probe);
      if (!evalResult.ok) {
        return errorResult(
          `vw_create_parcel: VW eval failed building "${input.name}": ${evalResult.error ?? '(no error)'}\n\nEmitted Smalltalk:\n${probe}`
        );
      }

      return {
        content: [
          text(
            `Built parcel "${input.name}". Result: ${evalResult.result ?? '(no result)'}. ` +
              `Files: ${pclPath} + ${pstPath}. ` +
              `Components: ${namespaces.length} namespace${namespaces.length === 1 ? '' : 's'}, ` +
              `${input.classes.length} class${input.classes.length === 1 ? '' : 'es'}, ` +
              `${extensions.length} extension${extensions.length === 1 ? '' : 's'}.`
          ),
        ],
      };
    }),
  };
}
