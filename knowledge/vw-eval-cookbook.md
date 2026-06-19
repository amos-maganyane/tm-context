# `/eval` cookbook

`POST /eval` (v0.8.3+) evaluates arbitrary Smalltalk on the bridge's serve-process. Eliminates the workspace-file-in cycle for every introspection task.

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

```smalltalk
| target |
target := ScheduledControllers scheduledControllers detect: [:c |
    [c model class == SimpleDialog] on: Error do: [:ex | false]
] ifNone: [nil].
target isNil
    ifTrue: ['no live modal']
    ifFalse: ['live modal id=', target model identityHash printString]
```

### Dismiss the live SimpleDialog modal

```smalltalk
| target |
target := ScheduledControllers scheduledControllers detect: [:c |
    [c model class == SimpleDialog] on: Error do: [:ex | false]
] ifNone: [nil].
target ~~ nil ifTrue: [
    target model cancel value: true.        "record outcome: cancel/No"
    target closeAndUnschedule.              "the only method that reliably wakes the wedged loop"
    'dismissed']
```

For Yes/OK, use `target model accept value: true` instead.

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
    select: [:k | k asString includesString: 'confirm']) printString
```

**Note:** use `includesString:` for substring contains-check. `indexOfSubCollection:` returns position (NOT a bool) and may not exist on all VW Dictionary subtypes.

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

### Test a hypothesis without state changes

`/eval` doesn't auto-commit anything (no GS transaction touched). All experiments are safe to run.

## Writing /eval scripts: gotchas

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
