# `/eval` cookbook

`POST /eval` (v0.8.3+) evaluates arbitrary Smalltalk on the bridge's serve-process. Eliminates the workspace-file-in cycle for every introspection task.

> **READ FIRST:** [`vw-image-api-contract.md`](./vw-image-api-contract.md) — the canonical probe-derived API contract for this MAS `storedev64` image. Documents which standard VW APIs are ABSENT (`String streamContents:`, `Smalltalk imageFileName`, `SystemNavigation`, `selectorsDo:`, `DateAndTime`, `String includesSubString:`, 1-arg `indexOfSubCollection:`, `String indexOf:startingAt:`, `Filename>>appendingWriteStream`, `Character>>asString` (returns printString), etc.) and which workarounds are correct. Most "why doesn't my probe compile" issues are documented there.

## Quick reference

**Request:**
```http
POST http://127.0.0.1:9876/eval
Authorization: Bearer <token>
Content-Type: text/plain

<Smalltalk source code>
```

**Response (success):**
```json
{"ok": true, "result": "<printString of result>"}
```

**Response (error):**
```json
{"error": "eval_failed", "message": "<exception description>"}
```

## PowerShell wrapper

```powershell
$tok = (Get-Content C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\.token).Trim()
$h = @{"Authorization" = "Bearer $tok"}

function Eval-Code($code) {
  try {
    (Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST `
      -Headers $h -Body $code -ContentType 'text/plain' -TimeoutSec 10).result
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      $stream = $resp.GetResponseStream(); $stream.Position = 0
      return (New-Object System.IO.StreamReader($stream)).ReadToEnd()
    }
    return "ERR: $($_.Exception.Message)"
  }
}

Eval-Code '1 + 2'
# → "3"
```

## Common recipes

### Method source via decompile

The VW image often has source-pointer issues (`getSource` returns nil), but the bytecode decompiler always works:

```smalltalk
(SomeClass compiledMethodAt: #aSelector) asSourceCodeDocument string
```

For class-side methods, use `SomeClass class`:

```smalltalk
(Dialog class compiledMethodAt: #confirm:) asSourceCodeDocument string
```

Output includes a "***This is decompiled code.***" disclaimer if source isn't linked, but the body is correct.

### Find a live SimpleDialog modal

Use `isKindOf:` (Bug #4 v0.8.6 fix) — `ExtendedSimpleDialog` and other subclasses are also dialogs:

```smalltalk
| target |
target := ScheduledControllers scheduledControllers detect: [:c |
    [c model isKindOf: SimpleDialog] on: Error do: [:ex | false]
] ifNone: [nil].
target isNil
    ifTrue: ['no live modal']
    ifFalse: ['live modal id=', target model identityHash printString,
              ' class=', target model class name asString]
```

### Dismiss the live SimpleDialog modal

```smalltalk
| target |
target := ScheduledControllers scheduledControllers detect: [:c |
    [c model isKindOf: SimpleDialog] on: Error do: [:ex | false]
] ifNone: [nil].
target ~~ nil ifTrue: [
    target model cancel value: true.        "record outcome: cancel/No"
    target closeAndUnschedule.              "dismiss the modal (OS-level close)"
    VWBridge singleton purgeWedgedDialogProcesses.  "v0.8.11+ unwedge the modal-loop fork"
    'dismissed']
```

For Yes/OK, use `target model accept value: true` instead. The v0.8.12 `SimpleDialog>>choose:labels:values:default:for:` override synthesizes the return value from `accept`/`cancel` ValueHolders after the force-close — so `Dialog confirm:` returns the correct boolean to its caller.

**Prefer `POST /dialogs/respond {"choice":"Yes"}`** when you can — the bridge's response handler does all three steps (set ValueHolder + closeAndUnschedule + purge) atomically.

### Toggle native dialogs

```smalltalk
Dialog useNativeDialogs: false.
Dialog usesNativeDialogs                   "→ false - confirms toggle"
```

### Enumerate scheduledControllers concisely

```smalltalk
ScheduledControllers scheduledControllers collect: [:c |
    'view=', ([c view class name asString] on: Error do: [:ex | '?']),
    ' model=', ([c model class name asString] on: Error do: [:ex | '?']),
    ' label=', ([c view label asString] on: Error do: [:ex | '?'])]
```

### List widget aspects of a window

```smalltalk
(ScheduledControllers scheduledControllers
    detect: [:c | (c view label asString includesString: 'Party Search')]
    ifNone: [nil]) model builder namedComponents keys printString
```

### Find class hierarchy

```smalltalk
(SimpleDialog allSuperclasses collect: [:c | c name]) printString
"→ 'OrderedCollection (#ApplicationModel #Model #Object)'"
```

### Find selectors matching a pattern

```smalltalk
"All class-side selectors on Dialog containing 'confirm'"
(Dialog class methodDictionary keys asSortedCollection
    select: [:k | (k asString indexOfSubCollection: 'confirm' startingAt: 1) > 0]) printString
```

**Note:** `String>>includesString:` does NOT exist in this image; the 1-arg `String>>indexOfSubCollection:` errors on some receiver contexts. Use the 2-arg `indexOfSubCollection:startingAt: 1` form returning a position, then compare `> 0` for substring presence. `selectorsDo:` is also absent — use `selectors do:` (two words).

### Process inspection

```smalltalk
"Count processes by name pattern"
(Process allInstances select: [:p |
    [p name asString = 'Party Search'] on: Error do: [:ex | false]]) size

"List all process names + states + priorities"
Process allInstances collect: [:p |
    ([p name asString] on: Error do: [:ex | '?']),
    ' state=', ([p state asString] on: Error do: [:ex | '?']),
    ' pri=', ([p priority printString] on: Error do: [:ex | '?'])]
```

### Find namespace globals defensively

```smalltalk
"Does class X exist? Returns nil or the class."
Root.Smalltalk at: #SomeClassName ifAbsent: [nil]

"Or check existence:"
(Root.Smalltalk includesKey: #SomeClassName) printString
```

### Extract text from ComposedText / Text / String

```smalltalk
"Works on String, Text, AND ComposedText"
someWidget spec label asString
```

DO NOT use `printString` or `displayString` — those give wrapped descriptions like `"ComposedText for 'X'"`.

### Look at process suspendedContext (where is it stuck?)

```smalltalk
| p |
p := Process allInstances detect: [:p | [p name asString = 'Party Search'] on: Error do: [:ex | false]].
p suspendedContext printString
"→ tells you the stack frame the process is stuck on"
```

### Walk a wedged process's stack to find a specific receiver

Session-6 / Bug #2 recipe — used to find the `ApplicationDialogController` and `WindowManager` receivers in a wedged modal-loop fork (which is exactly what `purgeWedgedDialogProcesses` does):

```smalltalk
"Walk a process's suspended stack. Returns Array of receiver class names
 (outermost frame first). Useful for understanding what nested call chain
 a fork is wedged inside."
| frames walk |
frames := OrderedCollection new.
walk := someProcess suspendedContext.
[walk ~~ nil and: [frames size < 40]] whileTrue: [
    | rc |
    rc := [walk receiver class name asString] on: Error do: [:ex | '?'].
    frames addFirst: rc.
    walk := [walk sender] on: Error do: [:ex | nil]].
frames asArray
```

To find a specific receiver class in the chain (e.g. WindowManager for `purgeDeadWindows`):

```smalltalk
| walk wm |
walk := someProcess suspendedContext.
wm := nil.
[walk ~~ nil and: [wm == nil]] whileTrue: [
    | rec |
    rec := [walk receiver] on: Error do: [:ex | nil].
    (rec notNil and: [[rec class name asString = 'WindowManager'] on: Error do: [:ex | false]])
        ifTrue: [wm := rec].
    walk := [walk sender] on: Error do: [:ex | nil]].
wm
```

### Compiled-method behavioral fingerprint (sources stripped)

`getSource` returns `nil` in this image (sources stripped). Use the bytecode introspection API instead:

```smalltalk
| m |
m := SomeClass class compiledMethodAt: #someSelector ifAbsent: [nil].
m isNil ifTrue: ['ABSENT'] ifFalse: [
    Array
        with: m numArgs           "argument count"
        with: m numTemps          "local temp count"
        with: m messages asSortedCollection asArray  "selectors this method sends"
        with: m literals]                            "string/symbol/array literals"
```

This avoids the Decompiler entirely (which has stripped pundles in this image). Good enough to confirm a method's identity, count arguments, see what other selectors it calls, and find embedded literals.

### Test a hypothesis without state changes

`/eval` doesn't auto-commit anything (no GS transaction touched). All experiments are safe to run.

## Writing /eval scripts: gotchas

> **Comprehensive list:** [`vw-image-api-contract.md`](./vw-image-api-contract.md) "Probe patterns / Probe anti-patterns" sections.

### Build output strings with WriteStream on: String new

`String streamContents:` does NOT exist in this image. Standard boilerplate for any multi-line probe:

```smalltalk
| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.   "Character>>asString returns printString, not a 1-char string"
"... build s up via s nextPutAll: '...'; nextPutAll: nl ..."
s contents
```

### Newline character in a string

`Core.Character lf asString` returns the literal text `'Core.Character lf'` (the printString), NOT a newline character. Always use `String with: Core.Character lf` to get a 1-char string.

### Use 2-arg `indexOfSubCollection: ... startingAt: 1`

The 1-arg `String>>indexOfSubCollection:` errors on some receiver contexts. Always use the 2-arg form:

```smalltalk
(s indexOfSubCollection: sub startingAt: 1) > 0   "substring present?"
```

### Walk all namespaces — do NOT trust top-level `Smalltalk includesKey:`

This image has 312 namespaces. Many classes (`Parcel`, `ParcelManager`, `ParcelFileViewer`, etc.) live in non-top-level namespaces (`Kernel.`, `Tools.`, `FileTools.`, `UI.`). `Smalltalk includesKey: #Parcel` returns false even though `Kernel.Parcel` is fully present. Use namespace walk:

```smalltalk
"Find every binding starting with 'Foo' across all 312 namespaces"
| matches |
matches := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | (k asString indexOfSubCollection: 'Foo' startingAt: 1) > 0])
        do: [:k | matches add: (ns name , '.' , k asString)]].
matches asArray
```

This was the session-9 trap that almost mis-killed Phase D-parcel (initial probe said "Parcel absent" — deeper walk found `Kernel.Parcel` with 86 class-side selectors).

### Use `Error` not `Core.Error` inside `/eval` body
The `/eval` body is compiled in the workspace namespace, where `Error` resolves to `Core.Error`. Either spelling works, but `Error` is shorter.

### Variable scoping in multi-statement bodies
Declare temps at the top:
```smalltalk
| a b c |
a := 1.
b := 2.
c := a + b.
c    "← the value of the last statement is the result"
```

### Return values
The result of the LAST statement is what gets `printString`ed. Use `^` to return early from blocks.

### Errors caught are reported as text
If your code does `[risky] on: Error do: [:ex | ex description]`, the error description becomes the result string. Useful for graceful failure reporting.

### Large results
Responses are returned as a single JSON string. Very large `printString` outputs (e.g. `Object allInstances printString`) may overwhelm `Invoke-RestMethod`. Slice your queries.

## See also

- [`vw-dialogs.md`](./vw-dialogs.md) — full background on dialog mechanics that drive these recipes
- [`vw-bridge-testing.md`](./vw-bridge-testing.md) — when to use `/eval` vs `/click`/`/value`/etc.
- [`smalltalk-gotchas.md`](./smalltalk-gotchas.md) — VW protocol surprises (`indexOfSubCollection:` not found, etc.)
- Bridge `/eval` implementation: [`VWBridge-phaseB2.st`](../src/vw-bridge/VWBridge-phaseB2.st)
