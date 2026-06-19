# Smalltalk / VW Gotchas

Specific things that have bitten us in this codebase. None of these are obvious from a generic Smalltalk reference.

## VW chunk format (`.st` file-in)

### Chunk terminators are `!` characters

A chunk = one Smalltalk expression. Each chunk MUST end with `!`. The parser splits on `!`, evaluates each chunk.

### Top-of-file docstring needs explicit `"!`

```smalltalk
"=== my header docstring ==="
"More docstring text spanning
 multiple lines."!     ← THIS '!' is essential
```

Without the trailing `!`, the chunk parser keeps consuming until the NEXT `!` it finds — which will be inside `!ClassName methodsFor: 'category'!`, mangling everything downstream.

**Symptom:** file-in error like `Nothing more expected ->methodName:` on what looks like a perfectly valid method.

### Method category blocks

```smalltalk
!VWBridge methodsFor: 'networking'!

firstMethod
    ^42!                       ← single ! ends this method's chunk

secondMethod
    ^99! !                     ← double ! ends both the method AND the category
```

The LAST method in a category needs `! !` (space-separated). Intermediates just `!`. The second `!` closes out the `methodsFor:` chunk.

### Verifying chunk format before file-in

Bracket-balance and terminator checks via PowerShell:
```powershell
$content = Get-Content -LiteralPath myfile.st -Raw
"open [: $(([regex]::Matches($content, '\[')).Count) close ]: $(([regex]::Matches($content, '\]')).Count)"
"open (: $(([regex]::Matches($content, '\(')).Count) close ): $(([regex]::Matches($content, '\)')).Count)"
$content -split "`n" | Select-String -Pattern '!\s*$'   # all chunk-terminator lines
```

## Character literals

### `$'` (single-quote char literal) is unreliable in chunk file-ins

The VW chunk parser sometimes mis-parses `$'` (the character literal for `'`). Use the explicit alternative:

```smalltalk
(Core.Character value: 39)     ← always works
$'                              ← may break chunk file-in
```

This bit us when implementing `extractLabelText:` in `VWBridge-phaseB.st` — we needed to find quoted segments in a printString.

### Other escape-prone characters

The chunk parser is generally OK with most ASCII, but for safety in `.st` files use `Core.Character value: <ascii>`:
- LF: `Core.Character value: 10`
- CR: `Core.Character value: 13`
- Tab: `Core.Character value: 9`
- Space: `Core.Character value: 32`
- Single quote: `Core.Character value: 39`

## Namespace qualification (GBS image)

This image is GBS (GemBuilder for Smalltalk) on VW. Kernel class names are ambiguous and MUST be qualified.

### Always qualify

```smalltalk
Core.String              "← string"
Core.Symbol
Core.Character
Core.Integer
Core.OrderedCollection
Core.Dictionary
Core.IdentitySet
Core.Array
Core.Error
Core.Exception
Core.Time
Core.Delay
Core.Semaphore
Core.WriteStream
Core.ReadStream

Root.Smalltalk           "the master namespace registry"
```

### Look up via global registry (safest)

```smalltalk
self globalNamed: #ClassName

"or directly:"
Root.Smalltalk at: #ClassName ifAbsent: [nil]
```

This avoids hard dependencies on namespace shape — works regardless of which namespace the class lives in.

### Why `Core.Smalltalk` is wrong

`Core.Smalltalk` is the Core namespace DICTIONARY itself, not the master class registry. Iterating `allClasses` on it gives only Core's classes (or errors). Use `Root.Smalltalk` for cross-namespace lookups.

## Protocol surprises

### `valuesDo:` doesn't exist on all Dictionary-like classes

Some VW Dictionary subtypes (notably `WealthPublishedPundleVersionsTool`'s namedComponents in this image — class reported as `Dictionary` but doesn't respond to `valuesDo:`) crash with MNU.

**Defensive iteration pattern:**
```smalltalk
(coll respondsTo: #valuesDo:)
    ifTrue: [coll valuesDo: aBlock]
    ifFalse: [
        (coll respondsTo: #do:) ifTrue: [
            coll do: aBlock]]
```

`do:` on a Dictionary iterates VALUES (same as `valuesDo:`) in standard Smalltalk, so this is a safe fallback. The bridge's `resolveAspect:` was patched for this in v0.8.4.

### `indexOfSubCollection:` returns position, NOT a boolean

```smalltalk
'hello world' indexOfSubCollection: 'world'       → 7
'hello world' indexOfSubCollection: 'xyz'         → 0
```

Use `> 0` to convert to boolean. Many Smalltalks have `indexOfSubCollection:startingAt:` instead (with explicit start index).

### `includesString:` is the contains-check selector in VW

```smalltalk
'hello world' includesString: 'world'    → true
```

NOT `includesSubString:` (doesn't exist), NOT `findString:` (also missing). Use `includesString:`.

### `Symbol asString` returns ByteString (subclass of String)

```smalltalk
#confirm: class                  → Symbol
#confirm: asString class         → ByteString
(#confirm: asString) isString    → true
```

But Symbol IS-A String already, so `aSymbol respondsTo: #aStringMethod` is usually true. If you get MNU on a Symbol where String works, the parent class chain may not be what you think.

### `(SomeClass class compiledMethodAt: #foo)` for class-side method lookup

To get the CompiledMethod for a class-side method:
```smalltalk
Dialog class compiledMethodAt: #confirm:        ← class-side
Dialog compiledMethodAt: #confirm:              ← would look on the instance side (would fail for Dialog which has no instance methods)
```

For method source (when sources file isn't linked):
```smalltalk
(Dialog class compiledMethodAt: #confirm:) asSourceCodeDocument string
```

NOT `sourceString` (doesn't exist on CompiledMethod here), NOT `getSource` (returns nil if sources file is misconfigured).

### Text/ComposedText text extraction

```smalltalk
aComposedText asString    ← raw text, works for String/Text/ComposedText
aComposedText string      ← may include print-quotes
aComposedText text        ← wrapped form "Text for 'X'"
aComposedText printString ← description, not the text itself
aComposedText displayString ← also a description, NOT the text
```

`asString` is the universal safe extractor.

## Process / threading model

### Block-local temps are per-activation

```smalltalk
[true] whileTrue: [
    | client |
    client := nextClient.
    [stuff with: client] forkAt: 4]    "each fork captures THIS iteration's client correctly"
```

Each invocation of the whileTrue block is a new activation with a fresh `client` binding. Forks inside the block capture their iteration's binding. This is different from JavaScript pre-`let` where `var` in a loop is shared.

### `ValueHolder>>value:` notifies dependents on the SETTING process

```smalltalk
holder value: true   "fires #changed on this process, NOT on observer processes"
```

If a different process is waiting in `[holder value] whileFalse: [yield]`, it won't notice immediately — it'll see the change on its NEXT yield. If it's not yielding (e.g. blocked in a nested event loop), it may never notice.

This is why dismissing VW modals from a foreign process by setting ValueHolders alone doesn't work reliably. See [`vw-dialogs.md`](./vw-dialogs.md).

### `Processor activeProcess yield` doesn't always release control

Equal-priority processes don't preempt in standard Smalltalk — they cooperate via yield. The "yield" is a hint to the scheduler. If no other process is ready, control returns immediately to the yielding process.

### Process termination doesn't always clean up

`aProcess terminate` stops execution but may leave:
- Sockets in TIME_WAIT
- Domain objects in inconsistent state
- ValueHolders mid-notify
- Mouse capture not released

When in doubt, bridge restart (file-in all `.st` files) is more reliable than process terminate.

## Exception handling

### `Core.Error` catches most but not all

```smalltalk
[risky] on: Core.Error do: [:ex | ...]
```

Catches `Error` and subclasses. Does NOT catch:
- `Notification` (informational)
- `Halt` (debugger triggers)
- Some compiler/parser errors that signal as `Exception` directly

For genuinely "catch all", use `Core.Exception`:
```smalltalk
[risky] on: Core.Exception do: [:ex | ...]
```

But this catches Halt too, which can hide debugger entry points.

### Error reporting in `/eval` responses

The bridge's `/eval` handler catches via `self errorClass` (= `Core.Error`). Some errors escape — they bubble to `serve:`'s outer catch and return HTTP 500 with `{"error":"internal","message":"..."}`. If you see internal errors, the eval'd expression raised something outside `Core.Error` (often a parser/compiler issue).

## See also

- [`vw-eval-cookbook.md`](./vw-eval-cookbook.md) — the recipes that work around these gotchas
- [`vw-dialogs.md`](./vw-dialogs.md) — concrete example (the dialog dismissal saga) of process/notification mechanics in action
- Bridge code files in `../src/vw-bridge/*.st` — see how production patches handle these (chunk format, namespace qualifiers, defensive iteration)
