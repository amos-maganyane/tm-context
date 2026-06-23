# VW Runtime API Project — AI Agent Operating Rules

You are working on an HTTP bridge into a live **VisualWorks 9.3.1** image (MAS / Momentum Wealth deployment, `storedev64.im`). Bridge runs at `http://127.0.0.1:9876`. All work is empirical — probe before commit, real-usage verify before declaring done.

This file is the **stable operating discipline**. Per-session state (current version, token, commits ahead, vwnt.exe PID) lives in the resume prompt + latest [`knowledge/HANDOFF-*.md`](knowledge/).

---

## Critical references (READ FIRST when context is missing)

- **[`knowledge/vw-image-api-contract.md`](knowledge/vw-image-api-contract.md)** — canonical reference for this image's API surface. 23+ carry-forward constraints: what's absent/customized, SUnit semantics, chunk file-in scope, GemBuilder namespace collisions, env-var API, subprocess invocation, etc. **Always read before writing a new probe.** Update when a new image quirk surfaces.
- **[`plan/STRATEGIC-ASSESSMENT-*.md`](plan/)** — current Phase deliverable table + critical path.
- **[`plan/ROADMAP-QUALITY-FIRST.md`](plan/ROADMAP-QUALITY-FIRST.md)** — the seven quality disciplines below.
- **Latest [`knowledge/HANDOFF-*.md`](knowledge/)** — current session EOD state (bridge version, token, commits ahead, vwnt.exe PID, pending tasks).

---

## Operational discipline

### Quality-first, NOT timeline-first

Seven disciplines apply to every deliverable. A phase that can't meet its quality gate gets reshaped, not rushed.

1. **TDD red→green→refactor** — every behavior change has a failing test first
2. **Real-usage verification gate** — drive the actual workflow end-to-end before declaring done
3. **Atomic commits + explicit auth** — one logical change per commit; ASK + WAIT for OK before EACH commit batch
4. **Docs match reality** — capture carry-forward constraints in `vw-image-api-contract.md` ASAP; don't let docs drift
5. **Smallest correct change wins** — no premature abstraction; bugfix ≠ refactor
6. **Probe before commit** — cheap `/eval` probe before any structural change
7. **Oracle consult for architecture-shaped decisions** — multi-system tradeoffs, unfamiliar patterns

### Commit cadence (NON-NEGOTIABLE)

- **NEVER commit, amend, or push without explicit user authorization**
- ASK with planned commit subject(s) + WAIT for OK before each commit batch
- Atomic commits: one logical change per commit (e.g., fix + docs + probes = 3 commits, not 1)
- Conventional messages: subject ≤72 chars (`type(scope): description`), terse body, evidence in handoff doc
- Push only when explicitly authorized (typically deferred to next session start)

### AI drives `/eval` file-ins (user-established session-15)

- `/eval`-based file-ins are AI agent work, NOT user paste
- Workspace paste is **ONLY** for cold-start when bridge is dead (no `/eval` available)
- After bringing the bridge back via Workspace cold-start, AI takes over for ALL subsequent work

### `/eval` pre-flight rule (session-15)

While bridge is up, **verify any Smalltalk syntax via `/eval` BEFORE handing to user for Workspace paste**. Catches syntax errors, Workspace-vs-/eval namespace ambiguity, MNU on speculative API names. Cheap (~1 sec). Saves a paste-error round-trip.

### NO MAS application code modification — EVER

- Bridge adapts to MAS as-shipped
- Tests adapt to MAS as-shipped
- All bridge code lives under `src/vw-bridge/`
- VW-class extensions go through `VWBridge-Patches.st` with `*PackageName` category prefix

---

## Phase 0 verification (start of every session)

After reading anchor docs:

1. `curl.exe -s http://127.0.0.1:9876/health` — expect `{"status":"ok","version":"X.Y.Z"}` (current version per latest handoff)
2. Read `%LOCALAPPDATA%\Enviro365\vw-runtime-api\token` — should match last EOD value if no vwnt.exe restart
3. `wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git log --oneline origin/main..main` — confirm expected commits ahead
4. `wsl ... git status --short` — confirm expected untracked files only
5. `/eval` probe to verify bridge class identity: `VWB.VWBridge environment name` → `'VWB'`; `Smalltalk at: #VWBridge ifAbsent: [nil]` → `nil`
6. `Get-Process -Name vwnt` — confirm vwnt.exe PID matches last EOD OR file-in needed for new process

### If vwnt.exe restarted OR bridge is down — Phase P P5 wrapper handles everything

AI drives the recovery (do NOT punt to user paste — Phase P P5 SHIPPED session-18):

1. Run the wrapper:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass `
     -File "$env:VW_RUNTIME_API_HOME\scripts\Start-VWBridge.ps1" -KillExisting
   ```

   Or invoke [`Start-VWBridge.bat`](src/vw-bridge/scripts/Start-VWBridge.bat) directly. Handles: preflight (env var + file existence + `load.st` no `!`), kill any existing vwnt.exe, generate chunk (load.st body + `\r\n!\r\n`), launch `vwnt.exe storedev64.im -filein <generated>`, poll `/health` up to 90s, verify `token` rotated, toggle `Smalltalk.Dialog useNativeDialogs: false` via `/eval`.
2. Re-read `%LOCALAPPDATA%\Enviro365\vw-runtime-api\token` after wrapper exits 0 (token rotates on every launch).
3. `VW_RUNTIME_API_HOME` env var auto-resolved at Process / User / Machine scopes (set session-15, persistent across launches; wrapper handles fresh-terminal launches where parent process didn't inherit it).

Typical cycle: ~9 seconds end-to-end. Verified through 5-cycle quality gate session-18 (mean 9.11s, all green). The wrapper is idempotent without `-KillExisting`: if bridge is already up, it exits 0 silently. Drop `-KillExisting` to make the call safe to retry.

### Cold-start emergency fallback (wrapper buggy)

If `Start-VWBridge.ps1` fails (rare — passed 5-cycle quality gate session-18 + smoke test):

1. Paste [`src/vw-bridge/load.st`](src/vw-bridge/load.st) body into VW Workspace + Do It. Smalltalk for Workspace MUST use `Core.*` qualification per `vw-image-api-contract.md` constraint #18 — load.st already does.
2. `load.st` orchestrates: env-var resolve → 5-file file-in → `VWB.VWBridge start` → `token` write.
3. Re-toggle `Smalltalk.Dialog useNativeDialogs: false` via `/eval` after bridge UP (wrapper does this automatically; manual fallback requires explicit toggle).

Pre-Phase P P5 (session-17 and earlier) this was the primary cold-start path. Phase P P5 (SHIPPED session-18) made it the emergency fallback only. Note the Dialog selectors are asymmetric: setter is `useNativeDialogs:` (keyword); getter is `usesNativeDialogs` (extra 's') — see `vw-image-api-contract.md` constraint #32.

---

## Tool conventions

### HTTP `/eval` to the bridge

```powershell
curl.exe -s -X POST http://127.0.0.1:9876/eval `
  -H "Authorization: Bearer <token>" `
  -H "Content-Type: text/plain" `
  --data-binary "@C:\path\to\probe.st"
```

- Use `curl.exe` — **NEVER** PowerShell `Invoke-RestMethod` (auto-formats arrays, breaks JSON)
- Use `--data-binary "@file"` — **NEVER** `--data "$body"` (PowerShell mangles embedded quotes)
- Read token from `%LOCALAPPDATA%\Enviro365\vw-runtime-api\token` (rotates on `VWB.VWBridge start`)

### Long Smalltalk probes

Write to `src/vw-bridge/probes/_probe-*.st` then send via `--data-binary @path`. Avoids PowerShell quote-escape hell. Probes committed alongside the feature work they support.

### Multi-line commit messages

Write to `C:\Users\AMMAGA~1\AppData\Local\Temp\2\opencode\msg-*.txt` then `git commit -F /mnt/c/...`. Avoids WSL bash parsing nested quotes + parens.

### Git via WSL

```
wsl --cd /mnt/c/Users/ammaganyane/tm/tm-context git <command>
```

### Force-kill vwnt.exe (when Task Manager fails)

```powershell
Stop-Process -Id <PID> -Force
```

Works even when `Get-Process` reports `Responding=True` but process ignores WM_CLOSE.

---

## Smalltalk syntax pitfalls in this image

Full image-API quirks (absent APIs, surprising behavior, namespace organization) live in [`knowledge/vw-image-api-contract.md`](knowledge/vw-image-api-contract.md). These are the syntax-level pitfalls that bite repeatedly:

### Declare ALL temps at top of method/block

Mid-block temps `| x |` partway through a script are INVALID. Declare all temps at the TOP of a method (or top of a block right after `:arg |`).

### Parenthesize chained keyword messages

`expr or: [a] or: [b]` parses as `#or:or:` keyword. Use `(expr or: [a]) or: [b]`.

Same trap: `stream nextPutAll: X on: Error do: Z` parses as `#nextPutAll:on:do:` single keyword. Wrap `on:do:` subexpression in parens.

### Fully-qualify cross-namespace refs in chunk file-in

Chunk file-in compiles in Smalltalk namespace context, NOT the class's environment. Bare cross-namespace refs resolve to nil. **Always qualify:**

```smalltalk
bridge := VWB.VWBridge singleton.   "✓"
bridge := VWBridge singleton.        "✗ resolves to nil → MNU at runtime"
```

### Workspace paste needs `Core.*` qualification

GemBuilder-imported namespaces (`GemStone.Gbs.ServerClasses.WriteStreamLegacy`, `GemStoneClasses.Globals.String`) collide with VW stock class names. Workspace pops disambiguation; `/eval` doesn't. **Smalltalk for human Workspace paste MUST use:**

```smalltalk
Core.WriteStream / Core.String / Core.Character / Core.OrderedCollection
```

### Avoid Stage 1 substring guard

`/eval` body containing **BOTH** `'dispatch'` AND `'VWBridge'` substrings is rejected by the bridge. Use `'router'` (or rephrase) in probe comments to avoid the trigger.

### Avoid `!` in `"..."` comments

Chunk parser splits at `!` even inside multi-line comments. Rewrite `!` out (`!=` → `not equal to`, `!exists` → `does not exist`). ~90 min debug cost if hit.

### Block arities

- `value` / `value:` / `value:value:` / `value:value:value:` (up to 3 args native)
- 4+ args: `valueWithArguments: anArray`

### Array construction

- `Array with:with:with:with:` (max 4 via `with:` chain)
- 5+ elements: `OrderedCollection new add:; add:; ...; asArray`

---

## Direct-invoke gate pattern (CANONICAL `/eval` SUnit runner)

Proven safe across 20 test selectors session-15 — no bridge wedge, no debugger pop. **Use this for ALL SUnit gate runs via `/eval`.**

```smalltalk
| tc testFailureClass |
testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
tc := cls new.
[[tc setUp.
  tc perform: aSelector]
    on: Core.Exception
    do: [:ex |
        (testFailureClass notNil and: [ex isKindOf: testFailureClass])
            ifTrue: ["FAIL: assertion - record + continue"]
            ifFalse: ["ERR: exception - record + continue"]]]
    ensure: [[tc tearDown] on: Core.Exception do: [:ex | nil]]
```

Bypasses SUnit's `runCase` which has the debugger-popping path (session-12 constraint #2). Direct invocation lets exceptions bubble to the outer handler cleanly. `on: Core.Exception do:` catches MNU, Error, AND TestFailure at the language level.

### NEVER use these (will wedge bridge 10-15 min)

- `cls suite run` — MAS-customized `TestCase>>testClasses` walks the entire image's tests (hundreds of `GemStoneClasses.*Tests.*`)
- `cls buildSuite` — calls `testClasses` (same root cause)
- `(cls selector: sel) run` via `/eval` if test has actual assertion failures — SUnit's `runCase` pops VW debugger

### Per-class scope alternative (NO testClasses walk)

```smalltalk
result := cls buildSuiteFromLocalSelectors run.
```

OR build a custom selective suite:

```smalltalk
| suite |
suite := TestSuite new.
#(#testFoo #testBar) do: [:sel | suite addTest: (cls selector: sel)].
suite run printString
```

### TestFailure API (correct form in this image)

- `TestFailure signal` (UNARY class-side, inherited from Exception) — ✓ raises cleanly
- `TestFailure signal: 'msg'` (keyword) — ✗ MNU (keyword form ABSENT)
- `TestFailure new` — creates instance but doesn't raise; combine with `signal` if needed

---

## Memory MCP (knowledge graph)

The `memory` MCP server gives a persistent knowledge graph across sessions. Use it as the source of truth for prior-session context that isn't in handoff docs.

### At session start

Run `memory_search_nodes` for relevant query terms (e.g., `session`, `VWBridge`, `Phase-P`, `ammaganyane`, `Direct-invoke-gate-pattern`, `Latent-test-bug-*`) to absorb stored context. The graph captures user preferences, project state, technical discoveries, latent bug catalog, milestones.

### During session

- Add observations to existing entities when new facts surface
- Create new entities for genuinely new concepts (a new bug class, a new technique, a new session)
- Use active-voice relations (`discovers`, `affects`, `delivers`, `validates`)
- One fact per observation string (atomic)
- Reuse existing entity names rather than creating duplicates

### Key entity types in this graph

| Type | Purpose | Examples |
|---|---|---|
| `user` | Preferences + behaviors | `ammaganyane` |
| `project` | Top-level project state | `tm-context-vw-bridge` |
| `smalltalk-class` | Key in-image classes | `VWB.VWBridge` |
| `runtime-environment` | Image + tooling | `VW-image-storedev64` |
| `session` | One per work session (key events) | `Session-N-YYYY-MM-DD` |
| `code-bug` | Discovered latent bugs | `Latent-test-bug-indexOfSubCollection` |
| `technique` | Proven patterns | `Direct-invoke-gate-pattern` |
| `milestone` | Phase progress | `Phase-P-progress` |

---

## Style

- Selectors: intention-revealing keyword messages, standard Smalltalk casing (`calculatePremiumFor:on:`), no abbreviations
- Methods small and single-purpose; guard clauses over nested ifs
- Match conventions observed in neighboring code over any generic rule
- Class comments via class-side `comment` method (or chunk header)
