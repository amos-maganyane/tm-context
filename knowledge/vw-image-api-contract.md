---
title: VW Image API Contract — MAS storedev64 image
purpose: Probe-derived reference for the live VisualWorks image at C:\visualworks931\image\storedev64.im. Read BEFORE writing new /eval probes or assuming standard VW API surface.
last_verified: 2026-06-22 (session-24 EOD, after PR P0 trio merged + pushed: Bug 1 vw_create_class rewrite to canonical Cincom VW `defineClass:` 8-kw form (67ec8d2) + Bug 6 `DataSet` widget as 14th component type in vw_create_window_spec (3267fcc) + Bug 5 7 happy-path smoke tests covering all 4 codegen tools (d83ff09); 305/305 vitest + 23/23 smoke test green; zero bridge restarts; image clean with s23 stretch's MCPBenchReviewWindow regression fixture preserved at originY=229)
source_sessions: 3, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 24
---

# VW Image API Contract — MAS `storedev64.im`

This image is **NOT stock VisualWorks**. It is a heavily customized MAS (Old Mutual Wealth) deployment of VW 9.3.1 with sources stripped, conventional startup hooks absent, and several core selectors missing or renamed. Every entry below has been verified by direct `/eval` probe or external observation.

If a selector you assume exists isn't listed here, **probe before using it.** Probe-derived recovery is far cheaper than chasing `Message not understood` errors through fork chains.

---

## Image identity (verified 2026-06-20 session-9)

| Property | Value |
|---|---|
| Executable | `C:\visualworks931\bin\win64\vwnt.exe` |
| Image file | `C:\visualworks931\image\storedev64.im` (~188 MB) |
| Changes file | `C:\visualworks931\image\storedev64.cha` (~117 MB) |
| Working directory | `C:\visualworks931\image\` |
| Sources file | `C:\visualworks931\image\visual.sou` (~20 MB) — **stripped** (`getSource` returns `nil`) |
| Launch command | `vwnt.exe storedev64.im` (no startup script argument observed in current process) |
| Parent process | `explorer.exe` (manual launch) |
| VW version | 9.3.1 (64-bit on Windows) |
| MAS version | `!MAS NR V436.47` (from `version.topaz`) |
| Bridge endpoint | `http://127.0.0.1:9876` (when running; v0.8.13 as of session-9) |
| Bridge token | rotates every `VWBridge start`; read from `src/vw-bridge/.token` |

---

## Quick lookup — does X work in this image?

| Question | Answer | Use |
|---|---|---|
| Get image file path | ✗ `Smalltalk imageFileName` / ✓ `ObjectMemory imageName` | `ObjectMemory imageName` |
| Get current directory | ✓ | `Filename defaultDirectory` |
| Read OS env var by name | ✗ `OS.OperatingSystem` (absent in this image) / ✓ `OS.CEnvironment userEnvironment at: 'X' ifAbsent: [...]` (fail-loud, DEPRECATED session-15 → use `OSSystemSupport getVariable: 'X'`) / ✓ `OS.CEnvironment getenv: 'X'` (returns `''` on missing — GOTCHA) | see [Environment variables](#environment-variables-session-14) |
| Build output strings | ✗ `String streamContents:` / ✓ `WriteStream on: String new` | always use the WriteStream form |
| Emit a newline in a stream | ✗ `Core.Character lf asString` (returns `'Core.Character lf'`) / ✓ `String with: Core.Character lf` | bind once at probe top: `nl := String with: Core.Character lf` |
| Find substring index | ✗ 1-arg `indexOfSubCollection:` / ✓ `indexOfSubCollection: aSub startingAt: 1` | always 2-arg form |
| Check substring presence | ✗ `includesSubString:` / ✓ `(s indexOfSubCollection: sub startingAt: 1) > 0` | predicate via index check |
| String find char from index | ✗ `indexOf:startingAt:` / ✓ `nextIndexOf:from:to:` | with explicit bounds |
| Current time, absolute | ✗ `DateAndTime now` / ✓ `Timestamp now printString` (e.g. `'20 June 2026 18:25:05.429'`) | for log timestamps |
| Current time, monotonic | ✓ `Core.Time millisecondClockValue` | for uniqueness markers, latencies |
| Char as 1-char string | ✗ `aChar asString` (returns `printString`) / ✓ `String with: aChar` | always |
| Iterate selectors | ✗ `selectorsDo:` / ✓ `selectors do:` | two words |
| Class registry lookup | ✗ `SystemNavigation` (absent) / ✓ manual walk via `Smalltalk allClasses` / `messages` introspection | see Probe patterns |
| Class lookup, top-level | `Smalltalk includesKey: #Foo` — **returns false for namespaced classes** | use `Smalltalk allNameSpaces` walk |
| Class lookup, namespaced | `Kernel.Parcel`, `Tools.ParcelManager`, etc. — direct binding works | see Namespace organization |
| Class lookup, defensive | `Smalltalk at: #Foo ifAbsent: [nil]` (top-level only) or `Kernel at: #Foo ifAbsent: [nil]` | match the namespace |
| Predicate "is this a collection?" | ✗ `isCollection` (not generic) / ✓ `respondsTo: #do:` | duck-type instead |
| Predicate "can class do X?" | `instance class canUnderstand: #sel` (CLASS-SIDE on metaclass: `cls class canUnderstand: #sel`) | mind class vs metaclass |
| List `instVarNames` | CLASS-SIDE only: `model class instVarNames` | not instance-side |
| Append to a file | ✗ `Filename>>appendingWriteStream` / ✓ `readWriteStream` + `setToEnd` | `writeStream` ALWAYS truncates, even with `setToEnd` after |
| Get all processes | ✓ `Process allInstances` (~200-300 procs) / ✗ `Processor allProcesses` | use `allInstances` |
| Source code of method | ✗ `getSource` returns `nil` (sources stripped) | use `CompiledMethod>>messages`, `>>literals`, `>>numArgs`, `>>numTemps` for behavioral fingerprint |
| Image-boot hooks | ✗ `Smalltalk addToStartUpList:` / ✗ `SessionManager instance` (returns `nil`!) | see Startup hook landscape |
| Auto-load parcels at boot | ✗ no auto-load wired in this image | manual `Kernel.Parcel loadParcelFrom: 'path\to\X.pcl' asFilename` — needs external trigger. **NOT** `ensureLoadedParcel:` (cache-only). See [Discovery + Load API quirks](#discovery--load-api-quirks-session-11--phase-f3-trap). |
| Character literal in chunk file-in | ✗ `$'` is unreliable | `(Core.Character value: 39)` |
| Global namespace for `Smalltalk`, `Core`, etc. | qualified prefix sometimes required | `Root.Smalltalk`, `Core.String`, `Core.Character`, `Core.Error`, `Core.Array`, `Core.Integer`, `Core.OrderedCollection`, `Core.Dictionary` |

---

## Namespace organization (where classes live)

Top-level `Smalltalk includesKey: #X` returns `false` for any class that lives in a non-`Smalltalk` namespace. **This was the session-9 trap that almost mis-killed Phase D-parcel.** Walk `Smalltalk allNameSpaces` to find a class whose location you don't know.

Image has **312 namespaces** total. The most commonly-needed ones:

| Class / lookup | Namespace | Notes |
|---|---|---|
| `Parcel` | `Kernel.Parcel` | NOT top-level. 86 class-side + 224 instance-side selectors. |
| `ParcelLoadedChange`, `ParcelSavedChange`, `ParcelMissingError`, `ParcelError`, `ParcelAlreadyLoadedError`, `ParcelContainsAlreadyLoadedComponentsError` | `Kernel.*` | Parcel-load announcement classes |
| `ParcelManager`, `ParcelDirectory`, `ParcelListTool`, `ParcelLoadedTool`, `ParcelManagerTool` (+13 more) | `Tools.*` | UI/management; 17 classes total |
| `ParcelFileViewer` | `FileTools.ParcelFileViewer` | |
| `ParcelPropertiesInspector` | `UI.ParcelPropertiesInspector` | |
| `RuntimePackager` | (it IS a namespace itself, not a class!) | Contains 37 `Runtime*` classes for building VW deployment images |
| `RuntimeStartupController` | `RuntimePackager.RuntimeStartupController` | Misleading name — class-side selectors `#()`, instance-side `#(#saveFinalImage)`. Not a startup mechanism. |
| `Smalltalk`, `Core`, `Kernel`, `Tools`, `UI`, `Graphics`, `OS`, `Net`, `Database` | top-level | The standard VW namespaces. |
| `Root` | top-level | Root namespace; `Root.Smalltalk` works. |
| MAS business classes (`PartySearchView`, `Portfolio*`, `Contract*`, `Fee*`, `Risk*`, `Pip*`, `PP*`) | top-level | All MAS application code is at top-level. Hundreds of namespaces starting with `Pip*`, `PP*`, `Risk*`, `Wealth*`, etc. |
| `String`, `Character`, `Integer`, `Array`, `OrderedCollection`, `Dictionary`, `Error` | use `Core.*` prefix in `/eval` probes if globals fail to resolve | Bare `String` usually works; namespace-qualify if not. |
| `NameSpace`, `Class`, `Metaclass`, `CodeComponent` | top-level | Core meta-classes. |

To enumerate where ANY class symbol lives:

```smalltalk
"Walk all namespaces for any binding starting with 'Foo':"
| matches |
matches := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray
        select: [:k | (k asString indexOfSubCollection: 'Foo' startingAt: 1) > 0])
        do: [:k | matches add: (ns name , '.' , k asString)]].
matches asArray
```

---

## APIs ABSENT (don't reach for these)

Each entry: what it would do in stock VW → why it's absent here → alternative.

### Image / boot

| Absent | Standard purpose | Alternative |
|---|---|---|
| `Smalltalk addToStartUpList:` | Register class for image-startup callback | Not available — see Startup hook landscape |
| `Smalltalk startUpList` | Inspect startup list | Same — none exists |
| `Smalltalk imageStartUp` | Trigger startup sequence | Same |
| `SessionManager instance` (returns `nil`!) | Get the active session manager for adding startup actions | Not initialized in this image — no instance to add to |
| `Smalltalk imageFileName` / `imageName` / `currentImageName` / `currentImageFilename` | Get image path | ✓ `ObjectMemory imageName` |
| `ObjectMemory currentImageFilename` | Same as above | ✓ `ObjectMemory imageName` |

### Strings / collections

| Absent | Standard purpose | Alternative |
|---|---|---|
| `String streamContents:` | Construct string via stream | `WriteStream on: String new` + `s contents` |
| `String includesSubString:` | Boolean substring check | `(s indexOfSubCollection: sub startingAt: 1) > 0` |
| `String indexOfSubCollection:` (1-arg) | Find substring index from start | `indexOfSubCollection: sub startingAt: 1` (2-arg form) — the 1-arg signature errors on some receivers |
| `String indexOf:startingAt:` | Find char from index | `nextIndexOf:from:to:` |
| Generic `isCollection` | Type predicate | `respondsTo: #do:` |
| `selectorsDo:` on a class | Iterate selectors with a block | `selectors do:` |

### Time

| Absent | Standard purpose | Alternative |
|---|---|---|
| `DateAndTime now` / `DateAndTime` class | ISO 8601-ish timestamp | `Timestamp now printString` — format `'D MMMM YYYY HH:MM:SS.mmm'` |
| ISO 8601 formatting | — | Not directly; format manually from `Timestamp` parts |

### Reflection / navigation

| Absent | Standard purpose | Alternative |
|---|---|---|
| `SystemNavigation` class | Senders/implementors search | Manual walks: `Smalltalk allClasses do: [:c \| c selectors do: [:s \| (c compiledMethodAt: s ifAbsent: [nil]) ifNotNil: [:m \| (m messages includes: target) ifTrue: [...]]]]` |
| `CompiledMethod>>getSource` returns `nil` | Source text | Use `>>messages`, `>>literals`, `>>numArgs`, `>>numTemps` for behavioral fingerprint |
| `Processor allProcesses` | All scheduler procs | `Process allInstances` (~200-300 procs in normal state) |

### File system

| Absent | Standard purpose | Alternative |
|---|---|---|
| `Filename>>appendingWriteStream` (on `NTFSFilename`) | Append-mode write stream | `readWriteStream` + `setToEnd`. `writeStream` ALWAYS truncates, even with `setToEnd` AFTER. |

---

## APIs PRESENT with surprising behavior

| API | Surprise | Workaround |
|---|---|---|
| `Character>>asString` | Returns `printString` (e.g. `'Core.Character lf'`), NOT a 1-char string | Use `String with: aChar` for a 1-char string |
| `Filename>>writeStream` | TRUNCATES every time (even with `setToEnd` afterward) | Use `readWriteStream` + `setToEnd` for append; `writeStream` only for create-or-truncate |
| `Kernel.Parcel class>>findAndLoadParcels` | **Pops an interactive UI dialog** (via `incrementalSearchDialogForParcelsIn:`) | For programmatic / headless load: `ensureLoadedParcel: 'Name' withVersion: nil` (or `:forPundle:`) |
| `Kernel.Parcel class>>incrementallySearchForParcelsInCache` | UI-driven (`#window`, `#firstLabel:`, fork via `#userBackgroundPriority`) | Same as above; bypass to `ensureLoadedParcel:withVersion:` |
| Chunk-format file-in | **Comment-only chunks are REJECTED** by the parser. Every chunk needs an executable expression. | Add a no-op expression at end of comment-only chunks, OR use `"..."` comments only inside method bodies (which are inside an executable chunk). |
| Multi-line `"..."` comments | Terminate at the **first inner `"`**. Outer comment then mis-parses. | Use bracket markers `[...]` instead of `"..."` for example tags inside outer comments. See [Bug #6 fix in session-8](./HANDOFF-2026-06-20-session8.md). |
| `"..."` comments containing `!` (session-12) | Chunk parser splits at `!` **even inside multi-line comments** → "Unmatched comment quote". | Rewrite `!` out of comments. `!=` → `not equal to` / `non-zero`; `!exists` → `does not exist`. |
| `Dialog useNativeDialogs: false` | Resets on every `vwnt.exe` restart | Re-toggle via `/eval` after every image launch |
| `OS.ExternalProcess>>wait` (bare pattern: `new` + `startProcess:arguments:` + `wait`) (session-12) | Returns immediately WITHOUT waiting. `exitStatus` returns 259 (Windows STILL_ACTIVE). `isExited` returns the proc itself, NOT a Boolean. `isActive` never flips false even after subprocess completes. | Use `execute:arguments:do:errorStreamDo:` one-shot instead — see [Subprocess invocation](#subprocess-invocation-session-13) section. |
| `OS.ExternalProcess` one-shot `do:` block stream (`StandardIOStream`) (session-13) | Character-mode by default. `upToEnd` returns `TwoByteString` with codepage-decoded chars (PNG magic 0x89 → 0xEB). | Send `outStream binary` BEFORE any read. Then `upToEnd` returns `ByteArray` byte-faithful. |
| `ExternalReadAppendStream>>nextPutAll: aByteArray` (session-13) | Raises `Error 'Strings only store Characters'` — the socket stream from `SocketAccessor>>readAppendStream` is character-mode by default. | Flip to binary: `(response isKindOf: ByteArray) ifTrue: [stream binary]` then `nextPutAll:` succeeds. `nextPut:` byte-loop also works. |

---

## Probe patterns that WORK in this image

### Boilerplate for any new probe

```smalltalk
| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
"... build s up ..."
s contents
```

### Defensive class lookup

```smalltalk
| cls |
cls := Smalltalk at: #Foo ifAbsent: [nil].
cls isNil
    ifTrue: ['ABSENT']
    ifFalse: [cls name , ' present, super=' , cls superclass name]
```

For a namespaced class:

```smalltalk
Kernel.Parcel  "direct binding works"
Tools.ParcelManager
"OR defensively:"
Kernel at: #Parcel ifAbsent: [nil]
```

### Cross-namespace symbol scan

```smalltalk
"Find every binding starting with 'Parcel' across all 312 namespaces:"
| matches |
matches := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | (k asString indexOfSubCollection: 'Parcel' startingAt: 1) > 0])
        do: [:k | matches add: (ns name , '.' , k asString)]].
matches asArray
```

### Behavioral fingerprint of a method (sources stripped)

```smalltalk
| m |
m := SomeClass class compiledMethodAt: #someSelector ifAbsent: [nil].
m isNil ifTrue: ['ABSENT'] ifFalse: [
    Array
        with: m numArgs
        with: m numTemps
        with: m messages asSortedCollection asArray
        with: m literals]
```

### Sender scan (targeted; full scan is 10k+ classes)

```smalltalk
| senders scope |
senders := OrderedCollection new.
scope := OrderedCollection new.
"Pick namespaces relevant to the question:"
Kernel classes do: [:c | scope add: c].
Tools classes do: [:c | scope add: c].
RuntimePackager classes do: [:c | scope add: c].
scope := scope asSet asArray.
scope do: [:cls |
    cls selectors do: [:sel | | m |
        m := cls compiledMethodAt: sel ifAbsent: [nil].
        (m notNil and: [m messages includes: #targetSelector])
            ifTrue: [senders add: cls name , '>>' , sel asString]].
    cls class selectors do: [:sel | | m |
        m := cls class compiledMethodAt: sel ifAbsent: [nil].
        (m notNil and: [m messages includes: #targetSelector])
            ifTrue: [senders add: cls name , ' class>>' , sel asString]]].
senders asArray
```

### Trying multiple selector candidates with error recovery

```smalltalk
| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
#(#imageFileName #imageName #currentImageName) do: [:sel |
    [s nextPutAll: '  Smalltalk '; nextPutAll: sel asString; nextPutAll: '='; 
      nextPutAll: (Smalltalk perform: sel) printString; nextPutAll: nl]
        on: Error do: [:e | s nextPutAll: '  Smalltalk '; nextPutAll: sel asString; nextPutAll: ' ERR'; nextPutAll: nl]].
s contents
```

### Outside-the-image info (PowerShell)

```powershell
# Process info incl command line
Get-WmiObject Win32_Process -Filter "ProcessId=<pid>" | Select-Object CommandLine, ParentProcessId

# Find files quickly
Get-ChildItem -LiteralPath "C:\visualworks931\image" -Filter "*.st"

# Bridge call via curl.exe (NEVER Invoke-RestMethod — it auto-formats arrays)
curl.exe -s -X POST http://127.0.0.1:9876/eval `
  -H "Authorization: Bearer <token>" `
  -H "Content-Type: text/plain" `
  --data-binary "@C:\path\to\probe.st"
```

---

## Probe anti-patterns (don't do)

| Anti-pattern | Why it fails | Correct |
|---|---|---|
| `Smalltalk includesKey: #Parcel` | `Parcel` lives in `Kernel`, not top-level `Smalltalk` | Walk `Smalltalk allNameSpaces` or query `Kernel includesKey: #Parcel` |
| `String streamContents: [:s \| ...]` | Selector absent | `WriteStream on: String new` + manual `s contents` at end |
| `Core.Character lf asString` for a newline | Returns `'Core.Character lf'` literal string | `String with: Core.Character lf` |
| `aResponse indexOfSubCollection: sep` (1-arg) | Errors on some receiver contexts | 2-arg form: `:startingAt: 1` |
| `cls selectorsDo: [:s \| ...]` | Selector absent | `cls selectors do: [:s \| ...]` |
| `Smalltalk imageFileName` | Selector absent on `Smalltalk` | `ObjectMemory imageName` |
| `SystemNavigation senders: #foo` | `SystemNavigation` absent | Manual walk over `Smalltalk allClasses` (or targeted scope) |
| `Processor allProcesses` | Selector absent | `Process allInstances` |
| `Invoke-RestMethod` from PowerShell against bridge | Auto-formats arrays into PowerShell tables, breaks JSON | `curl.exe -s` + `--data-binary @file` |
| PowerShell `-Body` with literal JSON inline | Quote-hell across multiple layers | `--data-binary "@path/to/file.json"` |
| `cls selectors size > 0 ifTrue:` to test class exists | `cls` might be `nil` from `ifAbsent:` and `nil selectors` errors | Explicit `isNil ifTrue: [...] ifFalse: [...]` |
| `(VWBridgeTest selector: #foo) run` via `/eval` (session-12) | Assertion failures route to **VW debugger UI which blocks the serve-process indefinitely**. `on: Error do:` does NOT catch `TestFailure`. | Invoke production methods DIRECTLY via `/eval` (e.g. `bridge handleScreenshotBody: '{...}'`) and inspect the response. For full SUnit suite, use a VW Workspace. |
| `aByteArray indexOfSubCollection: aString startingAt: 1` (session-12) | Returns 0 (not found) — ByteArray holds Integers, String holds Characters; types mismatch. | Convert ByteArray header section to String first via `WriteStream on: String new` + `nextPut: (Core.Character value: byte)` loop, THEN substring-search the String. |
| PowerShell `>` redirection for binary stdout (session-12) | Applies Out-File semantics with default text encoding (UTF-16 LE with BOM), even when the subprocess writes raw bytes via `[Console]::OpenStandardOutput().Write`. Mangles binary. | Use `.NET Process API` (`ProcessStartInfo` + `BaseStream.CopyTo`) OR `cmd /c "..." > file` (cmd redirection is byte-faithful). NOT PowerShell `>`. |

---

## Subprocess invocation (session-13)

The only working synchronous-wait + binary-stdout pattern in this image is `OS.ExternalProcess>>execute:arguments:do:errorStreamDo:` one-shot with `outStream binary` flip. Bare `proc wait` is broken (session-12 constraint #4 — returns immediately with exit=259 STILL_ACTIVE).

```smalltalk
| pngBytes stderrText |
pngBytes := nil.
stderrText := ''.
OS.ExternalProcess
    execute: 'powershell.exe'
    arguments: #('-ExecutionPolicy' 'Bypass' '-File' 'C:\path\helper.ps1')
    do: [:outStream |
        outStream binary.
        pngBytes := outStream upToEnd]
    errorStreamDo: [:errStream |
        stderrText := errStream upToEnd asString].
"pngBytes is now a ByteArray, byte-faithful."
```

Why it works:

1. The one-shot drains stdout via the `do:` block during the subprocess lifetime, which makes the internal `wait` synchronize correctly (verified session-13 probe: elapsed 2514ms for ~2.5s capture, vs the bare `wait` returning 0ms).
2. `outStream binary` flips the `StandardIOStream` from char mode (codepage-decodes bytes) to binary mode (raw bytes). Without it: PNG magic 0x89 → 0xEB via codepage.
3. Class-side `execute:...` just instantiates via `new` and delegates to the instance-side method — same semantics.

For writing binary responses out a socket (e.g. `/screenshot` PNG), the analog applies to `ExternalReadAppendStream`:

```smalltalk
(response isKindOf: ByteArray) ifTrue: [stream binary].
stream nextPutAll: response.
```

Without the `binary` flip, `nextPutAll: aByteArray` raises `Error 'Strings only store Characters'`. See [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st) `serve:` L430 for the production usage.

PowerShell helper scripts that emit binary stdout MUST use `[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)` — NOT `Write-Output` / `Write-Host` (text mangling). When invoked via `OS.ExternalProcess` the OS-level anonymous pipe carries bytes; the VW char-mode stream wrapper is what corrupts them without the `binary` flip.

---

## Environment variables (session-14)

The standard VW class `OS.OperatingSystem` is ABSENT in this image. OS env-var access lives on `OS.CEnvironment` (a `Dictionary` subclass; `userEnvironment` returns a populated `CEnvironment` of ~47 entries on Windows).

### Canonical read by name (fail-loud)

```smalltalk
| home |
home := OS.CEnvironment userEnvironment
    at: 'VW_BRIDGE_HOME'
    ifAbsent: [self error: 'VW_BRIDGE_HOME not set'].
```

- `OS.CEnvironment userEnvironment` returns the live OS env as a `CEnvironment` instance.
- Identity-stable: two consecutive calls return `==` instances. Mutations propagate across reads.
- `at:ifAbsent:` distinguishes missing-key from empty-string-value — cleanest fail-loud pattern.

### Shortcut read (GOTCHA: returns empty string on missing)

```smalltalk
OS.CEnvironment getenv: 'VW_BRIDGE_HOME'                 "returns '' if not set, NOT nil"
OS.CEnvironment caseInsensitiveGetenv: 'userprofile'     "case-insensitive variant"
```

⚠ `getenv:` returns `''` (empty string) when the var is missing, NOT nil and does NOT raise. The naive predicate `(OS.CEnvironment getenv: 'X') isNil` is always false → unreliable for "is this set?" checks. Use `userEnvironment at:ifAbsent:` for fail-loud, or `(getenv: 'X') isEmpty` if you accept the missing-vs-empty conflation.

### Test-time mutation

```smalltalk
"Set:"
OS.CEnvironment userEnvironmentAt: 'VW_BRIDGE_HOME' put: 'C:\test\value'.

"Remove:"
OS.CEnvironment userEnvironment removeKey: 'VW_BRIDGE_HOME' ifAbsent: [nil].
```

- Mutations are visible to BOTH `getenv:` and `userEnvironment at:` reads (consistent).
- Mutations persist for the `vwnt.exe` process lifetime. ALWAYS restore in `tearDown` / `ensure:` block.
- For hermetic tests prefer a class-side override seam (e.g. `Class>>fooOverride: aValue` / `clearFooOverride`) over OS env mutation — the seam is local to the class and never risks leaking state between tests.

### Misleading APIs (do NOT use for OS env vars)

| Selector | Actually returns | Use for OS env vars? |
|---|---|---|
| `OS.ExternalProcess environment` | `Smalltalk.OS` NameSpace (117 keys) | ❌ No — Smalltalk symbol scope |
| `ObjectMemory environment` | `Smalltalk.Kernel` NameSpace | ❌ No — Smalltalk symbol scope |
| `Smalltalk environment` | a NameSpace | ❌ No — Smalltalk symbol scope |

All three return Smalltalk namespaces (compile-time symbol scopes), not OS environment variables. The shared selector name is a misnomer specific to this image's API surface.

### Production usage in this codebase

`VWBridge class>>vwBridgeHome` (added session-14 Phase P P1, see [`src/vw-bridge/VWBridge.st`](../src/vw-bridge/VWBridge.st)) uses the canonical fail-loud read with a class-side override seam for tests:

```smalltalk
vwBridgeHome
    vwBridgeHomeOverride isNil ifFalse: [^vwBridgeHomeOverride].
    ^OS.CEnvironment userEnvironment
        at: 'VW_BRIDGE_HOME'
        ifAbsent: [self error: 'VW_BRIDGE_HOME env var is not set...']
```

Tests inject via `VWB.VWBridge vwBridgeHomeOverride: 'C:\test\path'` and clear via `VWB.VWBridge clearVwBridgeHomeOverride` inside `ensure:` blocks. No OS env mutation in test setUp/tearDown — keeps the suite hermetic from process-wide env state.

### Deprecation warning (session-15)

This image's VW emits `CEnvironment class>>#userEnvironment is deprecated. To set an environment variable use OSSystemSupport>>#setVariable:value: (or #getVariable: to read an environment variable).` on every call. The warning fires 4× during VWB.VWBridge startup (logFilePath, tokenFilePath, etc.). Functional but noisy.

Future cleanup: switch reads to `OSSystemSupport getVariable: 'VW_BRIDGE_HOME'` and writes to `OSSystemSupport setVariable:value:`. Probe semantics first (missing-key behavior may differ from `CEnvironment userEnvironment at:ifAbsent:`).

---

## Chunk file-in compile scope (session-15)

`'path' asFilename fileIn` compiles methods in **Smalltalk's namespace context, NOT the class's own environment**. Even when the chunk header is `!VWB.MyClass methodsFor: 'cat'!` (fully-qualified), bare class references inside the method bodies resolve against Smalltalk's namespace chain, not VWB's.

**Empirical evidence (session-15 P2 Stage 2 regression):**

- `VWB.VWBridgeTest>>setUp` had `bridge := VWBridge singleton.` (bare reference)
- After file-in, `(VWB.VWBridgeTest compiledMethodAt: #setUp) literals first` returned `(ResolvedDeferredBinding key: #VWBridge)`
- `binding value` returned `nil` because `Smalltalk.VWBridge` had been removed in Stage 2
- All test methods erroring with `MessageNotUnderstood: #singleton` on nil receiver
- Latent bug shipped to `origin/main` in commit `d86274b` (session-14 Stage 2) — suite was never run end-to-end so the bug wasn't caught until session-15

**Fix pattern: always fully-qualify cross-namespace class references in chunks**

```smalltalk
bridge := VWB.VWBridge singleton.   "✓ resolves to actual class"
bridge := VWBridge singleton.        "✗ resolves to nil if not in Smalltalk"
```

Affects: any chunk file-in that crosses namespace boundaries. Doesn't affect:

- Methods compiled in a Browser (different compile context — class's own environment is used)
- `self`-based references inside a class's own methods
- Fully-qualified literals (`#{VWB.VWBridge}` form, or `VWB.VWBridge` direct)
- Symbol-based lookups (`Smalltalk at: #VWBridge`)

**Session-14's claim "Bare VWBridge inside VWB-scoped methods resolves via namespace lookup" was empirically wrong** for chunk file-in scope. The claim may hold for Browser-compiled methods, but those aren't our path.

---

## SUnit semantics in this image (session-15)

This image's `TestCase` has MAS customizations that break stock SUnit assumptions. Trap-rich; read before using any `suite`/`run` invocation.

### `TestCase class>>testClasses` is MAS-customized

Returns `^ServerTestCase testClasses , ClientTestCase testClasses` — the entire union of GemStone+VW server-side and client-side test class trees (hundreds of `GemStoneClasses.*Tests.*` classes). Calling `cls suite` for ANY subclass of `TestCase` aggregates the WHOLE image's tests.

Verified via:

```smalltalk
(TestCase class compiledMethodAt: #testClasses) literals
"=> #(#{Smalltalk.ServerTestCase} #testClasses #{Smalltalk.ClientTestCase})"
```

**Consequence**: `cls suite run` walks the full MAS test tree (~thousands of selectors). On any assertion failure, the bridge wedges 10-15 min (compounding session-12 constraint #2). This is what walked the runaway in session-15.

### Per-class scope: `buildSuiteFromLocalSelectors`

Build a per-class TestSuite using ONLY the class's local `test*` selectors (no `testClasses` walk):

```smalltalk
result := VWB.VWBridgeTest buildSuiteFromLocalSelectors run.
```

Bypasses `suite` → `buildSuite` → `testClasses` walk entirely. Returns a `TestResult` with one entry per local test selector.

### Selective TestSuite (subset of selectors)

```smalltalk
| suite |
suite := TestSuite new.
#(#testFoo #testBar) do: [:sel | suite addTest: (cls selector: sel)].
suite run printString
```

Useful for running just the hermetic (non-dispatching) tests via `/eval` to avoid the per-process re-entry guard.

### Exception handling

- **`on: Core.Exception do:` catches `MessageNotUnderstood` and `Core.Error` subclasses** when wrapping `(cls selector: sel) run` — no debugger pop, no bridge wedge (session-15 verified empirically).
- **Whether `on: Core.Exception do:` catches `TestFailure`** (assertion-failed exception) is UNKNOWN as of session-15 — was deferred to avoid bridge wedge risk during diagnosis.
- Per session-12 constraint #2: SUnit assertion failures via `/eval` pop the VW debugger blocking the serve-process. The constraint applies specifically to `TestFailure`; MNU and other errors are caught by SUnit's internal handler and recorded in the `TestResult`'s `errors` collection.

### `TestResult` access patterns

```smalltalk
result := suite run.
result runCount.        "Integer - total tests"
result passedCount.     "Integer"
result failureCount.    "Integer"
result errorCount.      "Integer"
result failures.        "Collection of failed TestCase instances"
result errors.          "Collection of errored TestCase instances"
"Each TestCase has #selector — but NOT the exception object directly"
result printString.     "e.g., '20 run, 18 passed, 1 failed, 1 error'"
```

To get the actual exception text for a failed/errored test, invoke the test method via `tc perform: aSelector` wrapped in `on: Core.Exception do:` (bypasses SUnit's internal handler).

---

## Workspace vs /eval namespace resolution (session-15)

VW Workspace and `/eval` use DIFFERENT namespace resolution paths.

- **`/eval`** runs in the bridge serve-process's namespace context. Bare `WriteStream`, `String`, etc. resolve to the stock VW Core classes unambiguously.
- **Workspace** runs in a stricter context that flags ambiguity. This image has GemBuilder-imported namespaces (`GemStone.Gbs.ServerClasses.WriteStreamLegacy`, `GemStoneClasses.Globals.String`, `GemStoneClasses.WealthGlobalsTests.StringTest`, etc.) that collide with stock VW class names. Workspace pops an "Ambiguous class or variable" disambiguation dialog OR auto-picks the wrong candidate (e.g., `WriteStream` → `GemStone.Gbs.ServerClasses.WriteStreamLegacy`).

**Fix**: any Smalltalk code given to a human for Workspace paste MUST fully-qualify standard classes:

```smalltalk
| s nl |
s := Core.WriteStream on: Core.String new.       "✓ unambiguous"
nl := Core.String with: Core.Character lf.        "✓ unambiguous"
"... NOT bare WriteStream / String / Character ..."
```

This is in addition to qualifying cross-namespace references like `VWB.VWBridge`.

**Pre-flight rule for code given to a human**: while the bridge is up, verify Smalltalk syntax via `/eval` BEFORE handing it to the user for Workspace paste. The /eval pre-flight catches:

- Syntax errors (parser rejects)
- Class-resolution errors that work in /eval but fail in Workspace (require Core.* prefix)
- MNU errors on speculative API names

The pre-flight is cheap (~1 sec) and saves the human a paste-error round-trip.

---

## Phase P P2 Stage 3 — `load.st` / `unload.st` orchestrators (session-17)

`VWBridge.st` no longer auto-starts on file-in — the auto-start chunk was removed in session-17. The file is now **parcel-ready** (files in without side-effects) which is the prerequisite for P6 parcel build. Two external orchestrators replace the previous auto-start behavior.

### [`src/vw-bridge/load.st`](../src/vw-bridge/load.st) — external load orchestrator

Do-it expression block (NOT chunk-formatted) for `/eval` POST or VW Workspace Do It. Behavior:

1. Resolves `VW_BRIDGE_HOME` from OS env via `OS.CEnvironment userEnvironment at:ifAbsent:` — fails loud per constraint #8.
2. Defensively stops + removes any leaked top-level `Root.Smalltalk.VWBridge` (Stage 2 migration vestige cleanup).
3. Files in 5 source files in dependency order:
   - `VWBridge.st` (Core — defines VWB namespace + VWBridge class)
   - `VWBridge-Patches.st` (SimpleDialog override — Bug #2 fix)
   - `VWBridge-Test.st`, `VWBridge-WaitTest.st`, `VWBridge-ScreenshotTest.st`
4. Calls `VWB.VWBridge start` (rotates token, creates listener process).
5. Writes new `.token` to `VWB.VWBridge tokenFilePath` (derived from `VW_BRIDGE_HOME`) for agent pickup.

`fileIn` raises `EndOfStreamNotification` at EOF (constraint #24) — `load.st` leaves the `fileIn` UNWRAPPED so the notification auto-resumes at the top-level handler.

### [`src/vw-bridge/unload.st`](../src/vw-bridge/unload.st) — external unload orchestrator

Do-it expression block. Inverse of `load.st` — removes ALL VWBridge footprint from the image:

1. Captures `tokenPath` BEFORE the class is gone (defensive: any error → nil).
2. Stops bridge listener via dynamic `Smalltalk at: #VWB` lookup.
3. Deletes `.token` file.
4. Removes `SimpleDialog>>choose:labels:values:default:for:` override (`removeSelector:` is naturally defensive on absent — verified session-17 probe).
5. Removes 4 VWB classes in reverse-dependency order: `VWBridgeScreenshotTest`, `VWBridgeWaitTest`, `VWBridgeTest`, `VWBridge`.
6. Removes empty VWB namespace (only if `keys isEmpty` — defensive against leaked residual classes).

All steps wrapped with `on: Core.Error do: [:ex | log]` for belt-and-suspenders. After unload, the image is **byte-equivalent to pre-load state**: `Smalltalk at: #VWB` returns `nil`, `Kernel.Parcel classParcelMap` has zero VWB-prefixed keys, `SimpleDialog includesSelector: #choose:labels:values:default:for:` returns false.

### Quality-gate test technique — in-place unload+load+verify via single `/eval` call

The `/eval` handler runs on a **forked process** from the listener. When `unload` kills the listener mid-call (`process terminate` + `listener close`), the handler process keeps running (different process tree). The handler can then file-in + `start` a NEW listener and respond via the still-open accepted client socket.

This enables in-place quality-gate testing WITHOUT requiring Workspace cold-start. Pattern:

```smalltalk
"Single /eval body that:
 1. snapshots pre-state (uses VWB.VWBridge - exists at compile + execution)
 2. runs unload body inline (kills listener; handler survives)
 3. snapshots post-unload state (Smalltalk at: #VWB returns nil; Kernel.Parcel
    classParcelMap-VWB-keys empty; SimpleDialog override removed; .token gone)
 4. runs load body inline using DYNAMIC class lookups for the start step:
        newCls := (Smalltalk at: #VWB ifAbsent: [nil])
                      ifNotNil: [:ns | ns at: #VWBridge ifAbsent: [nil]].
        newCls ifNotNil: [:c | c start]
    (avoids stale compile-time binding to the OLD class object that unload removed)
 5. snapshots post-load state - all 4 classes back, override re-installed, bridge UP
 6. asserts 6 quality-gate predicates all true"
```

Verified session-17: **2 consecutive in-place cycles passed all 6 gate checks** (idempotency proven). Handler survived 3 listener-recycle events. Tokens rotated 3× during testing: `3959501518637-726009` → `3959501660889-966286` → `3959501833089-730222` → `3959501869549-282335` (each `start` calls `generateToken`).

The UNLOAD section uses direct `VWB.VWBridge` refs — works because the class exists at compile time AND empirically also survives the unload-then-redefine via the same compiled body (VW's `ResolvedDeferredBinding` for qualified `Namespace.Class` refs re-resolves on each use through the namespace lookup chain). Dynamic `Smalltalk at: #VWB` lookup in the LOAD section is belt-and-suspenders for self-modifying code paths — never wrong, occasionally necessary.

### Cold-start exception now uses `load.st` instead of `VWBridge.st`

Per AGENTS.md cold-start exception, the FIRST file-in when bridge is dead requires VW Workspace paste (no `/eval` available). Pre-session-17 this was `VWBridge.st` (which auto-started). Post-session-17 this is `load.st` (which orchestrates the 5 file-ins + `start` + `.token` write). **Session-18 SHIPPED Phase P P5** — [`Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) + [`Start-VWBridge.bat`](../src/vw-bridge/scripts/Start-VWBridge.bat) wrap `vwnt.exe -filein <generated-chunk>` so the Workspace paste step is no longer the primary cold-start path; it lives on as the emergency fallback only.

---

## Phase P P5 — `Start-VWBridge.ps1` wrapper via `vwnt.exe -filein` (session-18)

`vwnt.exe -filein <chunk-file>` is the officially-documented VW image-level command-line switch for filing in Smalltalk source at image startup (AppDevGuide.pdf p36, verified against `C:\visualworks931\doc\AppDevGuide.pdf` shipping with this exact install). Verified empirically through a 5-cycle quality gate session-18: every cycle ~9.1s end-to-end, all green.

### Image-level switches available in this MAS image

`Core.ImageConfigurationSystem` (top-level, env=Core; one instance) gates which image-level switches are honored. Probed session-18:

| Flag instVar | Value in MAS | Gates switch |
|---|---|---|
| `allowFilein` | **true** | `-filein` |
| `allowExpressions` | **true** | `-doit`, `-evaluate` |
| `allowParcelLoading` | **true** | `-pcl`, `-cnf`, `-psp` (good for P6 parcel load) |
| `allowSettings` | false | `-settings` |
| `useDefaultConfigFile` | false | auto-load of default config |
| `allowDevelopment` | false | dev-mode features |

The 12 class-side selectors on `ImageConfigurationSystem` are the 6 accessor/mutator pairs above. `allowSettings=false` means `-settings <xml>` is silently rejected even though the switch parser sees it. `allowFilein=true` confirms the MAS deployment did NOT lock down `-filein`.

`Core.CommandLineInterest` is also present (15 class-side, 16 instance-side selectors) — the pragma/event mechanism documented on AppDevGuide.pdf p469. Zero active subscribers in this image.

Documented image-level switches (from AppDevGuide.pdf p35-36, p449, p481):

| Switch | Documented behavior | Status in MAS | Source |
|---|---|---|---|
| `-listOptions` | Lists all image-level switches in this image | available (requires Headless) | p35 |
| `-pcl parcelFile [parcelFile...]` | Load parcel(s) at startup | allowed | p36 |
| `-cnf configFile [configFile...]` | Load parcels named in config file | allowed | p36 |
| `-psp dir1 dir2 ...` | Set parcel search path | allowed (with -pcl) | p36 |
| `-filein fileNames` | File in Smalltalk source (*.st) | **allowed** | **p36** |
| `-settings fileNames` | Load XML settings | BLOCKED (allowSettings=false) | p36 |
| `-doit stringArgs` | Evaluate expression(s); image continues running | allowed | p36 |
| `-evaluate stringArg` | Evaluate single expr, print result, exit | allowed | p36 |
| `-err errorFile` | Set error log path | Runtime-Packager-only (silent no-op here, see #34) | p481 |
| `-notifier notifierClass` | Set unhandled-exception notifier | Runtime-Packager-only | p481 |
| `-transcript aFileName` | Redirect Transcript output to file | not probed | p36 |
| `-headless` | Run headless | not probed | p527 |
| `-terminate-on-error` | Save headfull on error | not probed | p449 |
| `-no-terminate-on-error` | Inverse | not probed | p449 |
| `-nohlstrc` | Skip startup file | not probed | p449 |

Generic command syntax (p35): `<oe> [oe-switches] <image-name> [image-switches]`. Image name MUST precede image switches. Working examples (p214-215):

```
..\bin\win\vwnt.exe visual.im -pcl UIPainter
..\bin\win\vwnt.exe visual.im -cnf HotDraw.txt
..\bin\win\vwnt.exe visual.im -psp ..\goodies\other\HotDraw -cnf HotDraw.txt
```

### Chunk-wrap design (`Start-VWBridge.ps1`)

[`load.st`](../src/vw-bridge/load.st) is a do-it expression block (NOT chunk-formatted). `-filein` reads chunk-format files (chunks separated by `!`). To bridge the format gap, the wrapper writes a single-chunk wrapped file to `$VW_BRIDGE_HOME/.generated/load-startup.st`:

```
<load.st body bytes (4133 bytes, LF-only)>
\r\n
!
\r\n
```

Total 4138 bytes ASCII (no BOM — chunk parser is byte-oriented and rejects UTF-8 BOM). Trailing `\r\n!\r\n` makes the body one complete chunk. Top-level `^` inside the chunk is **silently consumed** when read via `'path' asFilename fileIn` (verified session-18 probe D) — `load.st`'s closing `^'[load.st] OK token=...'` works fine; chunk file-in semantics match `/eval` semantics for the top-level method-return.

**Preflight assertion**: `load.st` must contain ZERO `!` characters. The wrapper byte-scans `load.st` before each launch and exits code 4 if any `!` found (otherwise the chunk-wrap would split into two chunks at the first `!` and break startup).

### Launch invocation

```powershell
Start-Process -FilePath 'C:\visualworks931\bin\win64\vwnt.exe' `
              -ArgumentList @(
                  'C:\visualworks931\image\storedev64.im',
                  '-filein', $generatedChunk,
                  '-err', $errFile
              ) `
              -WorkingDirectory 'C:\visualworks931\image'
```

Working directory must be the image dir (per session-9: that's where the `.cha` changes file is locked). Image name precedes switches. `-err` is Runtime-Packager-only (constraint #34) — silently no-op in this image, but harmless on the command line and the wrapper handles missing err-file gracefully.

### Wrapper preflight + idempotency + verification

The PS1 script (~260 lines) implements the 8 failure modes Oracle flagged session-17 plus 2 found session-18:

1. `VW_BRIDGE_HOME` missing → resolved at Process / User / Machine env scopes; exit 2 if all empty
2. `vwnt.exe` / `storedev64.im` / `load.st` missing → exit 3
3. `load.st` contains `!` → exit 4 (preflight byte-scan)
4. Existing `vwnt.exe` running + `-KillExisting` flag → kill cleanly, wait 2s for port 9876 to clear
5. Already-running bridge (default) → idempotent exit 0 with `/health` echo
6. `vwnt.exe` exits before `/health` 200 → tail err file, exit 5
7. `/health` doesn't respond within timeout (default 90s) → exit 5
8. `.token` doesn't rotate (load.st step 5 failed) → exit 6
9. Post-launch `Smalltalk.Dialog useNativeDialogs: false` toggle via `/eval` (Bug #2 fix gate)
10. Asymmetric Dialog getter/setter (see constraint #32) — verification uses the setter side

Default behavior: idempotent. Re-running the wrapper while bridge is up returns 0 silently. `-KillExisting` flag is the explicit destructive opt-in for quality-gate cycling.

### Quality gate (session-18, Oracle's 5-cycle spec)

5 consecutive cold-start cycles passed:

| Cycle | Elapsed | PID transition | Token tail | All verifications |
|---|---|---|---|---|
| 1 (dry-run) | 9.54s | 6236 → 1980 | -282335 → -257889 | ✓ |
| 2 | 8.60s | 1980 → 5000 | -257889 → -564079 | ✓ |
| 3 | 8.65s | 5000 → 8784 | -564079 → -163522 | ✓ |
| 4 | 9.64s | 8784 → 5776 | -163522 → -199161 | ✓ |
| 5 | 9.14s | 5776 → 8584 | -199161 → -199161 (token-suffix repeat — see below) | ✓ |

Mean 9.11s end-to-end. /health 200 in 3 polls (1500ms) every cycle. VWB.VWBridge identity invariants (env=#VWB, top-level=nil, 4 classes, SimpleDialog override, `usesNativeDialogs`=false) preserved through every cycle.

**Token-tail repeat (cycle 4 → cycle 5)**: both ended `-199161`. Token is `<timestamp>-<random>` shape; high (timestamp) part advanced cleanly each cycle, low (random) part happens to repeat. As-a-whole tokens still distinct (cycle 4 `3959506086034-199161` vs cycle 5 `3959506095072-199161`). Not a regression but worth flagging — may warrant future probe of token-random entropy.

### Cold-start path table (post-session-19)

| Scenario | Path |
|---|---|
| Default cold-start (FileIn) | [`Start-VWBridge.bat`](../src/vw-bridge/scripts/Start-VWBridge.bat) or `Start-VWBridge.ps1 -Mode FileIn` (or just `.ps1` directly) |
| Parcel cold-start (P6 production) | `Start-VWBridge.ps1 -Mode Parcel` — loads `parcels/VWBridge.pcl` + post-load start-script |
| Quality-gate cycling | `Start-VWBridge.ps1 -KillExisting` (FileIn or `-Mode Parcel`) |
| Wrapper buggy / emergency fallback | VW Workspace paste of [`load.st`](../src/vw-bridge/load.st) body (AGENTS.md cold-start exception persists for recovery only) |
| Reload while bridge UP | POST `load.st` content as `/eval` body (idempotent) |
| In-image quality-gate test | In-place unload+load+verify single-/eval-call pattern (session-17 technique, still useful for fast iteration without process restart) |
| Headless build of new .pcl | Cursor>>showWhile: monkey-patch + canonical `Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:` (session-19 ship — see [Phase P P6 section](#phase-p-p6--vwbridgepcl-binary-parcel--start-vwbridgeps1--mode-parcel-session-19)) |

---

## Phase P P6 — VWBridge.pcl binary parcel + Start-VWBridge.ps1 -Mode Parcel (session-19)

Phase P P6 SHIPPED session-19 after extensive empirical investigation (24 probes + Oracle consult + research). The canonical VW API for headless binary parcel build (`Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:`) wraps its actual write in `Cursor wait showWhile: [block]` — a UI progress notifier that wedges headless bridge listeners. AppDevGuide.pdf documents parcel build ONLY through UI (Runtime Packager / System Browser); StoreCI-Building (community CI tool) implements its own `ParcelWriter` class to fill this gap but is ABSENT in this MAS image.

**Resolution**: temporary `Cursor>>showWhile:` monkey-patch + restore via `methodDictionary` swap, with canonical `parcelOutOn:` for the actual build. Verified headless-safe and 5-cycle quality-gate green.

### The Cursor>>showWhile: wedge + monkey-patch resolution

`Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:` messages list includes `#showWhile:` `#wait` `#normal` — `Cursor wait showWhile: [block]` wraps the actual write. In headless mode (no display server), the cursor change attempt blocks indefinitely. `Smalltalk.Dialog useNativeDialogs: false` (Bug #2 fix) does NOT prevent it — the call doesn't route through `SimpleDialog`.

The pass-through patch:

```smalltalk
| oldMethod patchInstalled |
oldMethod := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true]
        on: Core.Notification do: [:n | n resume].
    patchInstalled ifTrue: [
        "... call parcelOutOn: or any other UI-wrapped API ..."
    ]
] ensure: [
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: oldMethod]].
```

Restore via `methodDictionary at:put:` (not `recompile`) because sources are stripped — the saved `oldMethod` is a `CompiledMethod` object that can be re-installed by direct dictionary mutation. The `ensure:` block guards against permanent system change if the build path errors.

### parcelOutOn: invocation quirks

`parcel parcelOutOn: pclFilename withSource: pstFilename hideOnLoad: false republish: false backup: false` — the keyword names are MISLEADING:

- `withSource:` — **a Filename for the .pst source companion (NOT a boolean)**. Passing `nil`/`false`/a Stream raises `MessageNotUnderstood: #asLogicalFileSpecification` because the method internally calls `withSource asLogicalFileSpecification`. Even when source is "hidden", pass a real `.pst` path (Oracle warned). The wrapper writes the .pst file as a side-effect.
- `hideOnLoad:` — boolean (3rd positional). Controls whether the parcel is "hidden on load" (post-load UI visibility, not source-hiding).
- `republish:` — boolean (4th positional). For Store integration. `false` for standalone build.
- `backup:` — boolean (5th positional). Whether to keep prior version. `false` for clean build.

`hideSource:` (4-th boolean arg) lives in the 6-arg writer-level `CodeWriter>>writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:` that `parcelOutOn:` delegates to via `prepareCodeWriter:`. The parcel-level call signature uses different keyword names.

### Parcel content-add API (createParcelNamed: returns EMPTY)

`Kernel.Parcel class>>createParcelNamed: 'Name'` registers an EMPTY Parcel (summary = `'Text for an Empty Parcel'`, `definedThings = IdentitySet()`). Content MUST be added explicitly via instance-side selectors before `parcelOutOn:`:

| Selector | Purpose |
|---|---|
| `addNameSpace:` | Add a namespace to the parcel (parcel auto-creates it on load if not present) |
| `addNameSpace:attributes:` | Same with metadata |
| `addEntiretyOfClass:` | Add a class + all its instance/class methods + comment |
| `addEntiretyOfClasses:` | Same for an Array of classes |
| `addClass:` | Add class definition only (no methods) |
| `addClassAndAllSelectors:` | Add class + selectors (subtly different from addEntirety) |
| `addSelector:class:` | Add an extension method to a class (for *-categorized methods like `*VWBridge-Patches mas-bug2-fix`). The class arg is the **instance side** for instance methods; pass `SomeClass class` for class-side. |
| `addBinding:in:` / `addName:in:` / `addNames:in:` | Add namespace bindings |
| `addObject:` / `addObject:named:` | Add Smalltalk-serialized objects |

After `parcelOutOn:` succeeds, ALWAYS call `[Kernel.Parcel removeParcelNamed: name] on: Core.Notification do: [:n | n resume]` to clean up the registry (raises a benign `'Notification - '` per constraint #38).

### VWBridge.pcl content (session-19 production build)

```smalltalk
parcel := Kernel.Parcel createParcelNamed: 'VWBridge'.
parcel addNameSpace: VWB.
parcel addEntiretyOfClass: VWB.VWBridge.
parcel addSelector: #choose:labels:values:default:for: class: SimpleDialog.
parcel
    parcelOutOn: '<VW_BRIDGE_HOME>/parcels/VWBridge.pcl' asFilename
    withSource: '<VW_BRIDGE_HOME>/parcels/VWBridge.pst' asFilename
    hideOnLoad: false
    republish: false
    backup: false.
```

Output: 52,478-byte `.pcl` + 128,285-byte `.pst` companion. Binary header bytes match stock VW parcel format (`00 11 00 00 00 D0 00 00 00 01 1D` + ASCII `Smalltalk Binary Storage File` + length-prefixed parcel-name + length-prefixed version-string `'no version'`).

VWBridge-Tests.pcl (intended VWB.VWBridgeTest + VWB.VWBridgeWaitTest + VWB.VWBridgeScreenshotTest) **DEFERRED** — the build wedged the bridge mid-`parcelOutOn:` with 3 test classes (Cursor monkey-patch held but some OTHER UI/dependency path tripped). Not on production critical path; future iteration if dev/QA distribution shape needs it.

### .pst companion file dependency

The `.pcl` embeds a reference to its `.pst` source companion. `Kernel.Parcel loadParcelFrom: pclFilename` looks for `pcl.pst` alongside the `.pcl`. If absent, VW pops a confirmation dialog: `'Failed to find source file <Name>.pst. Ok to load without target source?'` — which **wedges image startup in headless mode** (no display server to receive the click).

Two fixes:

1. **Ship `.pst` alongside `.pcl`** (current session-19 approach) — commit both binary files to git. Stock VW does this (UIPainter.pst 1.6 MB lives alongside UIPainter.pcl 670 KB).
2. **Rebuild with `hideOnLoad: true`** (clean alternative, deferred) — suppress source dependency at load. Trades a tiny build difference for ~128 KB less in distribution.

### Wrapper -Mode FileIn|Parcel switch (Start-VWBridge.ps1)

[`scripts/Start-VWBridge.ps1`](../src/vw-bridge/scripts/Start-VWBridge.ps1) gained a `-Mode` parameter session-19:

- `-Mode FileIn` (default, P5 path) — chunk-wrap `load.st` (5-file file-in + start + token-write) + `vwnt.exe -filein <generated-chunk>`
- `-Mode Parcel` — chunk-wrap [`parcel-start.st`](../src/vw-bridge/parcel-start.st) (post-parcel-load: start + token-write) + `vwnt.exe -pcl <parcel> -filein <generated-chunk>`

Switch ordering: `-pcl <parcel> -filein <chunk>` (parcel BEFORE filein). AppDevGuide.pdf p470 documents left-to-right command-line processing — `-pcl` parses first (loads the parcel, adds namespace+classes), then `-filein` (executes the post-load start script which depends on the loaded classes).

### Quality gate (session-19, Oracle's 5-cycle spec, all Parcel mode)

5 consecutive cold-start cycles passed:

| Cycle | Elapsed | PID transition | Token tail | All verifications |
|---|---|---|---|---|
| 1 (dry-run, manual) | ~5s | 2232 → 3632 | `…-564079` → `…-65801` | ✓ |
| 2 | 9.01s | 3632 → 8872 | `…-65801` → `…-65801` | ✓ |
| 3 | 8.25s | 8872 → 7960 | `…-65801` → `…-65801` | ✓ |
| 4 | 8.16s | 7960 → 5864 | `…-65801` → `…-65801` | ✓ |
| 5 | 8.32s | 5864 → 7532 | `…-65801` → `…-65801` | ✓ |

**Mean 8.43s for cycles 2-5** — slightly FASTER than P5's 9.11s (less work in parcel-start.st vs load.st). `/health` 200 in 3 polls (1500ms) every cycle. `useNativeDialogs: false` re-armed every cycle. All 5 PIDs distinct. Same token-suffix-repeat oddity as session-18 (cycles 2-5 all ended `-65801`; tokens as wholes still distinct due to advancing timestamp portion).

**Post-cycle-5 deep state probe** confirmed lean production install: env=#VWB, top-level=nil, **1 class in VWB (only `#VWBridge` — no Test classes loaded)**, port 9876, SimpleDialog override category EXACT match `'*VWBridge-Patches mas-bug2-fix'`, `usesNativeDialogs=false`. **Parcel mode delivers a strictly leaner image than FileIn mode** (which loads all 4 classes via file-in of the 5 source files).

### Carry-forward constraints emitted by P6 work (35-40)

See the constraint summary at the end of this doc:
- **35** Cursor>>showWhile: is the headless wedge culprit for parcelOutOn: (not Smalltalk.Dialog)
- **36** Kernel.Parcel>>createParcelNamed: returns EMPTY parcel; content added explicitly
- **37** parcelOutOn:withSource: is a Filename arg (not a boolean as the keyword suggests)
- **38** Kernel.Parcel class>>removeParcelNamed: raises Notification (must resume)
- **39** CodeWriter is the binary write engine (Smalltalk.CodeWriter, env=#Kernel, top-level)
- **40** Parcel write embeds .pst path reference; ship .pst alongside .pcl OR use hideOnLoad:true

---

## Phase P P7+P8 — INSTALL.md + GET /version endpoint (session-20)

Phase P COMPLETE session-20 with two paired ships: (P7) `INSTALL.md` at repo root documenting both FileIn and Parcel install paths for an onboarding developer; (P8) `GET /version` endpoint returning bridge release version + cold-start git HEAD SHA + cold-start UTC timestamp + active install mode. Bridge bumped v0.9.1 → v0.10.0. `scripts/Build-Parcel.ps1` shipped as the reproducible parcel rebuild pipeline.

### /version endpoint shape

```
GET /version
→ 200 OK application/json
  {"version":"0.10.0","buildCommitSha":"<40-char git SHA>","buildTimestamp":"<ISO-8601 UTC>","parcelMode":"FileIn|Parcel"}
```

Auth-exempt — like `/health`, no token required. Suitable for liveness/version checks from monitoring, CI, container healthchecks, SDK version-pinning.

Fields:

| Field | Source | Semantics |
|---|---|---|
| `version` | `VWB.VWBridge class>>version` literal in source | Bridge release version. Bump per release. |
| `buildCommitSha` | Class ivar `buildCommitSha`, set by Start-VWBridge.ps1 at cold-start | Git HEAD when **this bridge instance** was launched — NOT when the parcel was originally built. Defaults to `'unknown'` if no wrapper involvement. |
| `buildTimestamp` | Class ivar `buildTimestamp`, set by wrapper at cold-start | ISO-8601 UTC of the same launch event. |
| `parcelMode` | Class ivar `parcelMode`, set by wrapper at cold-start | `'FileIn'` or `'Parcel'` — which install path is active. |

For parcel-build provenance (when was the .pcl actually compiled into binary), check `git log` on `parcels/VWBridge.pcl`. The wrapper-injected fields reflect cold-start, not parcel-build, because attempting to bake build metadata into the parcel as compiled-literal class-side methods wedges the bridge — see [Why metadata is NOT baked into the parcel](#why-metadata-is-not-baked-into-the-parcel-session-20).

### Class-side accessors + setters (VWB.VWBridge class>>'config')

Added to [`VWBridge.st`](../src/vw-bridge/VWBridge.st) class-side `'config'` category:

```smalltalk
version
    ^'0.10.0'

buildCommitSha
    ^buildCommitSha isNil ifTrue: ['unknown'] ifFalse: [buildCommitSha]

buildCommitSha: aString
    buildCommitSha := aString

buildTimestamp
    ^buildTimestamp isNil ifTrue: ['unknown'] ifFalse: [buildTimestamp]

buildTimestamp: aString
    buildTimestamp := aString

parcelMode
    ^parcelMode isNil ifTrue: ['unknown'] ifFalse: [parcelMode]

parcelMode: aString
    parcelMode := aString
```

Three new class instance variables (`buildCommitSha`, `buildTimestamp`, `parcelMode`) added to `classInstanceVariableNames`. The setters mutate the ivars; the getters read them with `'unknown'` fallback. The new parcel includes all 7 methods via `addEntiretyOfClass:` so Parcel-mode cold-start has the setters available for wrapper injection.

### Start-VWBridge.ps1 region (10) — build-info inject (both modes)

The wrapper now does a second `/eval` POST after the `useNativeDialogs:` toggle:

```powershell
$buildCommitSha = Get-GitHeadSha $bridgeHome              # walks up to find .git/HEAD
$buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$infoBody = "VWB.VWBridge buildCommitSha: '$buildCommitSha'. " +
            "VWB.VWBridge buildTimestamp: '$buildTimestamp'. " +
            "VWB.VWBridge parcelMode: '$Mode'. ^'build-info-set'"
curl.exe -s -X POST http://127.0.0.1:9876/eval ...
```

`Get-GitHeadSha` is a pure-PowerShell helper (no `git` CLI dependency — git isn't on PowerShell's PATH on this workstation, only via WSL): walks up from `$bridgeHome` to find the `.git` directory, reads `HEAD`, follows `ref:` to `.git/refs/heads/<branch>` or falls back to `packed-refs`. Returns `'unknown'` on any failure.

Both modes run identical inject — no Mode-specific branch. Acceptable trade-off: Parcel-mode `/version` reflects cold-start moment (not parcel-build moment), but for traceability `git log parcels/VWBridge.pcl` gives the actual parcel-build commit.

### scripts/Build-Parcel.ps1 — reproducible parcel rebuild

[`scripts/Build-Parcel.ps1`](../src/vw-bridge/scripts/Build-Parcel.ps1) drives a headless parcel build via `/eval`:

1. Preflight: bridge UP + `VW_BRIDGE_HOME` + `.token` readable
2. Captures git HEAD SHA + UTC timestamp **for build-context logging only** (NOT baked into parcel content)
3. Clears prior `.generated/parcels/VWBridge.pcl` + `.pst` (so we know the build wrote fresh ones)
4. POSTs the verbatim session-19 parcel-build pattern: `Cursor>>showWhile:` monkey-patch (carry-forward #35) + `Kernel.Parcel createParcelNamed: 'VWBridge'` + `addNameSpace: VWB` + `addEntiretyOfClass: VWB.VWBridge` + `addSelector: #choose:labels:values:default:for: class: SimpleDialog` + `parcelOutOn:withSource:hideOnLoad:republish:backup:` + `removeParcelNamed:` cleanup (constraint #38)
5. Verifies output artifacts exist
6. Copies `.pcl` + `.pst` from `.generated/parcels/` to `parcels/` (the shipped distribution location)

Build succeeded session-20 first try with verbatim session-19 pattern (no compile-time modifications to VWB.VWBridge class — see why below). Produced `VWBridge.pcl` 53,305 bytes + `VWBridge.pst` 130,811 bytes — slightly larger than session-19's 52,478 + 128,285 to accommodate the 7 new methods.

### Why metadata is NOT baked into the parcel (session-20)

The "obvious" approach for `/version` was: compile literal-returning class-side methods (`buildCommitSha ^'<sha>'`, `buildTimestamp ^'<ts>'`) into VWB.VWBridge class BEFORE `addEntiretyOfClass:`, so the parcel ships them as baked-in literals. Session-20 attempted this and it wedged the bridge mid-build, twice.

Two related discoveries surfaced during the attempt:

1. **`compile:` on VWB.VWBridge class via /eval wedges the bridge listener** (new constraint #41). Even with the Cursor>>showWhile: monkey-patch installed FIRST, calling `VWB.VWBridge class compile: 'source' classified: 'cat'` triggers a wedge somewhere. Root cause: compile: fires VW change announcements (ChangeAdded / MethodAdded) that fan out to UI listeners, at least one of which routes through a wedging path other than `Cursor wait showWhile:` (which the Cursor patch covers). A single isolated compile: call sometimes works; a more involved probe (compile + parcelOutOn: + ensure: cleanup) reliably wedges.

2. **ensure: block referencing VWB.VWBridge AFTER `parcelOutOn:` + `removeParcelNamed:` raises "no binding"** (new constraint #42). When the ensure block runs `VWB.VWBridge class methodDictionary at: #buildCommitSha put: oldShaMethod` after the parcel build completes, the Compiler reports `"The identifier VWB.VWBridge has no binding"` even though the class IS still bound at runtime (verified by subsequent probes). Some Compiler / namespace state is corrupted during parcel manipulation that affects subsequent expression-compile binding resolution in the same /eval body.

Both findings are likely manifestations of the same root cause (parcel-build perturbs the change/announcement system + Compiler binding cache). They are recorded as separate constraints because they manifest at different points.

**Design implication**: the simpler design (wrapper /eval-injects values at cold-start in both modes via setters on the class) sidesteps both wedges entirely. Build-Parcel.ps1 ships just the class definitions + methods — no compile-time customization. The `git log parcels/VWBridge.pcl` provides traceability when needed.

### Quality gate (session-20, 5-cycle Parcel mode)

5 consecutive cold-start cycles via `Start-VWBridge.ps1 -Mode Parcel -KillExisting`:

| Cycle | Elapsed | PID transition | Token (full) | /version |
|---|---|---|---|---|
| 1 (dry-run, manual) | ~9s | 8944 → 3316 | `…-12438` → `…-808187` | ✓ |
| 2 | 9.18s | 3316 → 6140 | `…-808187` → `…-808187` | ✓ |
| 3 | 9.78s | 6140 → 7336 | `…-808187` → `…-808187` | ✓ |
| 4 | 9.02s | 7336 → 3868 | `…-808187` → `…-808187` | ✓ |
| 5 | 8.66s | 3868 → 7588 | `…-808187` → `…-808187` | ✓ |

**Mean 9.16s for cycles 2-5** — slightly slower than session-19's 8.43s, attributable to the extra `/eval` round-trip for build-info inject. All 5 PIDs distinct, all 5 tokens distinct as wholes (timestamp portion advances cleanly; random portion `-808187` repeats in 4 of 5 cycles — same pattern as sessions 18 and 19, confirming the token-entropy carry-forward observation for `generateToken`'s random source). `/version` returned valid 4-field JSON with `buildTimestamp` advancing each cycle (`17:06:55Z` → `17:07:05Z` → `17:07:14Z` → `17:07:23Z`), confirming wrapper injection runs every cycle.

### Wrapper recovery validation (session-20)

The wrapper handled **5 unplanned bridge recoveries** during session-20 debugging (compile-wedge investigation):

| # | Trigger | Recovery time |
|---|---|---|
| 1 | Cursor monkey-patch + parcelOutOn: + ensure-block "no binding" | ~9s FileIn |
| 2 | HALF 1 isolation probe (compile: on VWB.VWBridge, no patch) | ~9s FileIn |
| 3 | Ensure-block referencing VWB.VWBridge post-build | ~9s FileIn |
| 4 | Successful build, then state probe wedged | ~9s FileIn |
| 5 | Parcel-mode validation cycle 1 (intentional, not a recovery) | ~9s Parcel |

Wrapper recovered cleanly every time. The P5 wrapper is now stress-tested under 9 (s19) + 5 (s20) = 14 unplanned/cycling launches across two sessions. **Empirical confidence HIGH.**

### Carry-forward constraints emitted by P7+P8 work (41-42)

See the constraint summary at the end of this doc:
- **41** `compile:` on VWB.VWBridge wedges the bridge even with Cursor monkey-patch installed
- **42** ensure: block referencing VWB.VWBridge after parcelOutOn: + removeParcelNamed: raises "no binding"

---

## Startup hook landscape (heart of Phase D evidence)

This image **does NOT auto-execute Smalltalk code at boot through any standard VW mechanism.**

### What's missing

| Standard VW startup mechanism | Status in this image |
|---|---|
| `Smalltalk addToStartUpList: Foo` | `addToStartUpList:` selector absent on `Smalltalk class` |
| `Smalltalk startUpList` | Absent |
| `Smalltalk imageStartUp` | Absent |
| `SessionManager instance addStartupAction: [...]` | `SessionManager instance` returns `nil`; `SessionManager` class itself has only 2 class-side selectors: `#instance #makeConnectors` |
| Class-side `#startUp:` callbacks | **Zero** implementors in the image (only `#startUp` (no colon) on 2 classes: `FSGsDemoHandler`, `Subsystem` — neither fires automatically) |
| `ObjectMemory class` startup registration | No startup-related selectors |
| `RuntimePackager.RuntimeStartupController` | Misnamed — class-side selectors `#()`, instance-side only `#saveFinalImage`. Used by RuntimePackager UI for "save final image" workflow, NOT for image boot. |

### Parcel auto-load

| Question | Verdict | Evidence |
|---|---|---|
| Is parcel mechanism present? | YES (fully) | `Kernel.Parcel` 86 class-side + 224 instance-side selectors; 103 stock `.pcl` files in `C:\visualworks931\parcels\`; 36-entry `searchPathModel` ValueHolder pointing at `$(VISUALWORKS)\parcels` etc. |
| Does any code auto-call `findAndLoadParcels` at boot? | NO | Sender scan across 585 classes / 15812 methods (Kernel + Tools + RuntimePackager + `*Startup*` / `*Boot*` named): only sender is `VisualLauncher>>menuItemLoadParcelByName` (UI menu action) |
| Does lazy/on-demand parcel load exist? | YES | `GeneralBindingReference>>valueIfUndefinedLoadFrom:` triggers `ensureLoadedParcel:withVersion:` when an undefined binding is referenced |
| Does pragma-driven parcel load exist? | YES (parser-driven) | `Parser>>choosePragmaFor:startingAt:` calls `loadParcelByName:` for declared pragma deps |

### Evidence that external scripting feeds this image

- `WealthWS-startup.st` (26 bytes, dated 2006) at `C:\visualworks931\image\` contains literally `GemStoneInterface startup.` — proves the convention of small startup scripts exists somewhere in the deployment pipeline. Not auto-fed at image boot in current launch sequence.
- `iferror.topaz` + `version.topaz` near the image (both touched today 2026-06-20 13:23:40) — `.topaz` is the GemStone/VW command-line REPL, used by external CI/deployment pipelines to feed scripts into the image.
- `deploy.gs` (~36 MB) and `testCases.gs` (~18 MB) in the same dir — large GemStone source scripts loaded by the deployment process.
- Current `vwnt.exe` (PID 5624) was launched with command line `"C:\visualworks931\bin\win64\vwnt.exe" "C:\visualworks931\image\storedev64.im"` from `explorer.exe` (manual launch) — **no startup script argument was passed**.

### Practical implication for auto-start

Any auto-start mechanism for the VWBridge has to come from **outside the image**:

1. **D-external (pure)** — wrapper script (PowerShell / batch / Topaz) launches `vwnt.exe` and feeds in `[bridgeStart] 'C:\...\VWBridge.st' asFilename fileIn. VWBridge start.` via Topaz stdin or via a `-doit` style command-line arg if VW supports one (unverified).
2. **D-snapshot** — file-in the bridge in a Workspace, then `ObjectMemory snapshotAs:thenQuit:` to capture the loaded code into a fresh `.im`. The bridge listener fork does NOT survive snapshot, so the snapshot still needs SOMETHING to restart the listener — and there's no in-image hook to do it. Same external trigger problem.
3. **D-parcel** — build a `VWBridge.pcl` with a `postLoad:` block that calls `VWBridge start`, place it in `C:\visualworks931\parcels\`. **But** since `findAndLoadParcels` is not auto-called, the parcel won't load unless something external triggers `Kernel.Parcel findAndLoadParcels` (or `ensureLoadedParcel:withVersion:`) on the running image. So this is **D-parcel + external trigger**, not a pure self-bootstrapping parcel.

**All three paths converge on needing an external trigger.** The pure-D-parcel "drop it in the path and forget" pattern is not available in this image without an additional hook. Phase D's design decision narrows to: which external trigger mechanism (CLI arg / Topaz stdin / external watcher) is least brittle, AND whether the in-image code is shipped as a parcel for hygiene vs as a raw `.st` file-in.

---

## Parcel infrastructure (session-9 discovery)

### Class: `Kernel.Parcel`

- Superclass: `CodeComponent`
- Class-side: **86 selectors**. Key ones grouped by purpose:
  - **Build/save:** `createParcelNamed:`
  - **Discover:** `findParcelNamed:`, `parcelNamed:`, `parcelNames`, `parcels`
  - **Load (programmatic, headless):** `ensureLoadedParcel:withVersion:`, `ensureLoadedParcel:withVersion:for:`, `ensureLoadedParcel:withVersion:forPundle:`, `ensureLoadedParcel:withVersion:for:with:`, `ensureLoadedParcel:withVersion:forPundle:with:`, `loadParcelByName:`, `loadParcelFrom:`, `loadParcelCachedFrom:`, `loadParcelFor:`
  - **Load (interactive — pops UI dialog):** `findAndLoadParcels`, `findAndLoadParcelsInCache`, `incrementallySearchForParcelsInCache`
  - **Unload:** `unloadParcel:logged:`, `unloadParcelNamed:`, `unloadParcelByNameFor:`
  - **Search path:** `searchPathModel` (returns ValueHolder on OrderedCollection of `PortableFilename`)
  - **Class→parcel mapping:** `classParcelMap`, `parcelsForClass:`, `parcelsForBinding:`
  - **Callback trigger:** `triggerParcelLoaded:` (broadcasts announcement)
- Instance-side: **224 selectors**. The ones that matter for callbacks / auto-start:
  - `postLoad:` — INSTANCE method that holds the post-load block (set when building the parcel; fires when the parcel loads)
  - `postUnloadBlock` — analogous for unload
  - `doComponentLoadedActions` — orchestrates load callbacks
  - `runClassExtensionPostLoadMethods` — runs `#initializeAfterLoad` on extended classes
  - `isLoaded`, `isDirty`, `version`, `versionString`, `bundleName`, `summary`
  - `fileOutOn:`, `parcelOutOn:withSource:hideOnLoad:republish:backup:` — parcel serialization

### Callback mechanism (NOT `parcelInitialize`)

`#parcelInitialize` has **0 implementors** in this image (verified by full-image scan). The callback model is:

1. **`Parcel>>postLoad:` block** — set at parcel-build time; fires when parcel loads.
2. **`Kernel.ParcelLoadedChange`** — `Announcement` subclass (of `ComponentLoadedChange`). Has `#fileIn`, `#filename`, `#component:`, `#parameters`, `#systemVersion:`, `#version`. Listeners subscribe via the standard Announcement framework for cross-cutting reactions.
3. **`Kernel.ParcelSavedChange`** — analogous for save events.
4. **`Parcel>>runClassExtensionPostLoadMethods`** — calls `#initializeAfterLoad` on any class the parcel extends. The 5 stock implementors (`Application`, `Class`, `ClassDescription`, `Metaclass`, `AbsentClassImporterMetaclass`) are the system's own bookkeeping.

### Discovery + Load API quirks (session-11 — Phase F3 trap)

`Kernel.Parcel`'s headless load APIs are NOT filesystem-aware on demand. The name-cache is only populated for currently-loaded parcels — there is NO on-demand scan of the search path.

| Selector | Behavior | Use |
|---|---|---|
| `parcels` | Returns `List` of currently-LOADED `Parcel` instances. | Inspect what's in image. |
| `parcelNames` | Returns `List` of names — **LOADED-only** (identity-equal to `parcels collect: #name`). Does NOT scan filesystem. | **NOT** a discovery API. Use `Get-ChildItem` on `C:\visualworks931\parcels\` etc. for filesystem-side discovery. |
| `findParcelNamed: aString` | Returns `Parcel` instance if LOADED, `nil` otherwise. | Test "is this name loaded?" — not "does this .pcl exist on disk?" |
| `parcelNamed: aString` | Same as `findParcelNamed:` — LOADED-only lookup. | Same. |
| `ensureLoadedParcel: aString withVersion: nilOrVer` | If name is in cache (== LOADED), no-op. If NOT in cache, raises **`ParcelMissingError`** (empty message text) — does NOT search the filesystem for `aString.pcl`. | Only useful for re-asserting a name is loaded. **NOT** the headless load-by-name API one would expect. |
| `loadParcelFrom: aFilename` | **THIS is the headless load bypass.** Accepts explicit `Filename`, reads .pcl directly, returns the `Parcel` instance. Bypasses the name cache. | The actual "load a .pcl headless" API. Use `'C:\path\to\Thing.pcl' asFilename` as argument. |
| `unloadParcelNamed: aString` | Returns `true` on success. Reversible cleanup for test-loads. | Always pair test-loads with this for clean state. |

**Practical recipe** for headless test-load + cleanup:

```smalltalk
| loaded |
loaded := Kernel.Parcel loadParcelFrom: 'C:\visualworks931\preview\64-bit\Thing.pcl' asFilename.
"... do work ..."
Kernel.Parcel unloadParcelNamed: 'Thing'.
```

**`Parcel` instance introspection surface is NARROW** (most expected selectors are absent in this build):

| Works | Errors with `MessageNotUnderstood` |
|---|---|
| `name`, `version`, `versionString`, `summary`, `comment`, `bundleName`, `isLoaded`, `isDirty`, `postLoad:`, `postUnloadBlock`, `definedClasses`, `definedBindings`, `extendedClasses`, `extensionMethods`, `hasExtensions`, `classesAndSelectorsDo:`, `definedNameSpaces`, `definedObjects` | `file`, `fileName`, `prerequisites`, `components`, `codeComponents`, `classes`, `classDefinitions`, `extensions`, `classExtensions`, `bindings`, `releaseInformation`, `parameters`, `hidden`, `date`, `fullName` |

For inspecting what a parcel contributed, use `definedClasses` + `extendedClasses` + `extensionMethods` (instance side).

### NAMING TRAP — `ImageWriter.pcl` is NOT a pixel encoder (session-11 Phase F3)

`C:\visualworks931\preview\64-bit\ImageWriter.pcl` is the **VW VM-snapshot (.im file) converter**, NOT a pixel image (PNG/JPEG/BMP) encoder. Defined classes: `VirtualImage`, `McCartneyImage`, `VirtualImageBytes`, `SixtyFourBitVirtualImage`, `HugeArray`. Parcel comment: *"image conversion framework which can read virtual image files and write them out... convert 32-bit virtual images to 64-bit virtual images."* The term "image" here means "memory snapshot of the running VM," not bitmap pixels.

**Confirmed via session-11 image-wide hunt** across all 312 namespaces / 10,216 bindings: there is **NO** pixel-image-encoder class (`*ImageWriter*`, `*ImageEncoder*`, `*BitmapWriter*`, `*BMPWriter*`, `*TIFF*`, `*WebP*` all count=0). `Graphics.ImageReader` hierarchy has 5 readers and zero writer peer. `LibJPEG-turbo` (loaded) is decode-only despite the upstream library supporting encode. `Graphics.PNGImageReader` has 41 instance methods, all decode/filter/chunk-process; zero write methods.

If you need pixel-image encoding (PNG/JPEG/etc.) in this image: it is NOT in any stock VW pundle. Path forward is OS-level subprocess (PowerShell System.Drawing) or hand-rolled Smalltalk encoder using loaded `Compression-ZLib` / `HashesBase` primitives. See [`../plan/PLAN-PHASE-F-SCREENSHOT.md`](../plan/PLAN-PHASE-F-SCREENSHOT.md) Q1 section.

### Search path (verified)

`Kernel.Parcel searchPathModel value` returns an OrderedCollection of 36 `PortableFilename` entries, all anchored on `$(VISUALWORKS)` env var:

```
$(VISUALWORKS)\parcels          ← canonical drop point (103 stock .pcls live here)
$(VISUALWORKS)\advanced
$(VISUALWORKS)\database
$(VISUALWORKS)\dllcc
$(VISUALWORKS)\xtreams
$(VISUALWORKS)\dst
$(VISUALWORKS)\wavedev
$(VISUALWORKS)\waveserver
$(VISUALWORKS)\web
$(VISUALWORKS)\security
$(VISUALWORKS)\net
$(VISUALWORKS)\com
$(VISUALWORKS)\store
$(VISUALWORKS)\opentalk
$(VISUALWORKS)\webservices
$(VISUALWORKS)\seaside
$(VISUALWORKS)\packaging
$(VISUALWORKS)\icc
$(VISUALWORKS)\glorp
$(VISUALWORKS)\DotNETConnect
$(VISUALWORKS)\pdp
$(VISUALWORKS)\japanese
$(VISUALWORKS)\contributed
$(VISUALWORKS)\contributed\*    ← glob: any subdirectory
$(VISUALWORKS)\compat
$(VISUALWORKS)\contributed\*\*  ← glob: two-deep
$(VISUALWORKS)\examples
.                                ← current working directory!
$(VISUALWORKS)\preview\*
$(VISUALWORKS)\preview\*\*
$(VISUALWORKS)\obsolete
$(VISUALWORKS)\obsolete\*
$(VISUALWORKS)\launchpad
$(VISUALWORKS)\www
$(VISUALWORKS)\distributed
```

For our bridge, the cleanest drop point is `C:\visualworks931\parcels\VWBridge.pcl`. The `.` entry means a parcel in the working dir (`C:\visualworks931\image\`) would also be found.

### Related Parcel classes (across namespaces)

- **`Kernel.*` (7 classes):** `Parcel`, `ParcelLoadedChange`, `ParcelSavedChange`, `ParcelMissingError`, `ParcelError`, `ParcelAlreadyLoadedError`, `ParcelContainsAlreadyLoadedComponentsError`
- **`Tools.*` (17 classes):** management/UI — `ParcelManager`, `ParcelPrereqCollector`, `ParcelPropertiesTool`, `ParcelDirectory`, `ParcelListTool`, `ParcelLoadedTool`, `ParcelGroup`, `ParcelPrereqItem`, `ParcelSelectionTool`, `ParcelFileItem`, `ParcelDirectoriesTool`, `ParcelInImageItem`, `ParcelFavoritesTool`, `ParcelManagerTool`, `ParcelPrereqReference`, `ParcelCommentTool`, `ParcelPrereqTreeTool`
- **`FileTools.*` (1):** `ParcelFileViewer`
- **`UI.*` (1):** `ParcelPropertiesInspector`

### `RuntimePackager` namespace (separate but adjacent — VW deployment image builder)

- **NOT for parcels** — for building stripped runtime/deployment `.im` files
- Contains 37 `Runtime*` classes including `RuntimeManager`, `RuntimeManagerStripper`, `RuntimeFullDumper`, `RuntimeHeadlessExample`, `VersionForPackaging`, `RuntimeBuilderAppModel`
- `RuntimeStartupController` (despite its name) is a UI controller for the "save final image" workflow — NOT a boot-time startup mechanism
- Relevant if/when we build a true deployment image; not relevant for current Phase D auto-start question

---

## File system layout (verified 2026-06-20)

### `C:\visualworks931\image\` (working directory, on parcel search path as `.`)

Recently touched files (current MAS deployment):

| File | Size | Last modified | Purpose |
|---|---|---|---|
| `storedev64.im` | ~188 MB | 6/18/2026 | The image we're running |
| `storedev64.cha` | ~117 MB | 6/20/2026 | Changes file (grows during session) |
| `deploy.gs` | ~36 MB | 6/20/2026 | GemStone deployment script |
| `testCases.gs` | ~18 MB | 6/20/2026 | Test Mentor test cases |
| `iferror.topaz` | 24 B | 6/20/2026 | Topaz error-handler: `iferror\nstack\nexit 3` |
| `version.topaz` | 17 B | 6/20/2026 | Version marker: `!MAS NR V436.47` |
| `WealthWS-startup.st` | 26 B | 2/6/2006 | Old startup snippet: `GemStoneInterface startup.` |
| `CstMessengerSupport.pcl` | 18 KB | 7/11/2024 | Application parcel |
| `GbsRuntime.pcl` | 1.1 MB | 7/11/2024 | GemBuilder for Smalltalk runtime parcel |
| `GbsTools.pcl` | 697 KB | 7/11/2024 | GemBuilder tooling parcel |
| `Res115807.pcl`, `Res116028.pcl`, `Res116124.pcl`, `Res116156.pcl` | ~3-10 KB each | 2023-2024 | Resource patches |
| `WealthSystem.bat` | 398 B | 7/9/2019 | Old launch script (references `c:\visualworks8`, not 931 — likely stale) |

### `C:\visualworks931\parcels\` (canonical parcel drop point)

Contains 103 stock VW parcels (`.pcl` files) — the standard VW distribution. Examples: `ANSICompatibility.pcl`, `BOSS.pcl`, `Browser-*.pcl` family (20+ files), `Compression-Zip.pcl`, `Database.pcl`, etc.

This is where a custom `VWBridge.pcl` would naturally live.

### `C:\visualworks931\bin\win64\VisualWorks.ini`

Maps version codes (`94 128`, `93 129`, etc.) to executable paths. Points at `D:\` paths (look like internal Cincom dev paths — probably installed-as-template config, not actively used by current MAS deployment).

---

## Carry-forward constraints summary (one-line per item)

- **Token** rotates on every `VWBridge start`; re-read from `src/vw-bridge/.token` after every reload.
- **Bridge file-in via Workspace** (when bridge is DOWN): `'path' asFilename fileIn.` — NOT Launcher → File Browser → File In.
- **Bridge file-in via /eval** (when bridge is UP, v0.8.8+): PowerShell + `curl.exe` with `--data-binary @file`. Token rotates afterward — re-read.
- **`/eval` runs on bridge serve process**, NOT UI process. `mgr activeControllerProcess` returns `nil` during modals; `onUIDo:` falls back to direct execution.
- **NEVER call `VWBridge singleton dispatch:` from inside `/eval`** — v0.8.8+ has Stage 1 substring + Stage 2 per-process re-entry guard.
- **`windowTitle` is CASE-SENSITIVE** substring match.
- **OFF-LIMITS widgets** without explicit user OK: `commitWidget`, `loginRpcWidget`, `removeWidget`. MAS menu leaves with mutation verbs need OK before any `/menu/click`.
- **Bug #2** (FIXED v0.8.12): `SimpleDialog>>choose:labels:values:default:for:` override in [`VWBridge.st`](../src/vw-bridge/VWBridge.st) L1700-1751 forces the broadcast Yes/No path through cooperatively.
- **Bug #6** (FIXED v0.8.13 session-8): `[...]` instead of `"..."` for example tags inside outer comments in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st).
- **`bodyOf:` 1-arg `indexOfSubCollection:` issue** (FIXED v0.8.13+session-9 A1): swapped to 2-arg form.
- **`!` in `"..."` comments breaks chunk parser** (session-12): rewrite `!` characters out of comments (`!=` → `not equal to`, etc.). Cost ~90 min debug if hit.
- **SUnit assertion failures via `/eval` pop VW debugger** (session-12): use direct production-method invocation + response inspection instead. Full SUnit runs go through VW Workspace.
- **`aByteArray indexOfSubCollection: aString`** returns 0 (session-12): ByteArray-Integer vs String-Character type mismatch. Convert ByteArray → String character-by-character first for substring checks on binary responses.
- **Bare `OS.ExternalProcess>>wait` does NOT actually wait** (session-12 problem; session-13 FIX): use `execute:arguments:do:errorStreamDo:` one-shot pattern + `outStream binary` flip — see [Subprocess invocation](#subprocess-invocation-session-13) section.
- **PowerShell `>` redirection mangles binary stdout** (session-12): UTF-16 LE Out-File semantics even when subprocess writes raw bytes. Use .NET Process API OR `cmd /c "..." > file` for byte-faithful redirection.
- **`ExternalReadAppendStream nextPutAll: aByteArray`** requires `binary` flip (session-13): raises "Strings only store Characters" otherwise. For socket-write of binary responses (e.g. /screenshot PNG): `(response isKindOf: ByteArray) ifTrue: [stream binary]` before `nextPutAll:`.
- **OS env vars** via `OS.CEnvironment userEnvironment at:ifAbsent:` for fail-loud (session-14): `OS.OperatingSystem` ABSENT in this image; `getenv:` returns `''` on missing (gotcha — naive `isNil` check breaks); `OS.ExternalProcess environment` / `ObjectMemory environment` / `Smalltalk environment` return Smalltalk NameSpace not env vars (misnomer). `userEnvironment` is DEPRECATED (session-15) in favor of `OSSystemSupport getVariable:` / `setVariable:value:` — fires 4× per bridge startup. See [Environment variables](#environment-variables-session-14) section.
- **Chunk file-in compile scope is Smalltalk, NOT the class's environment** (session-15): bare class references in chunk-filed methods resolve against Smalltalk's namespace chain, not the receiving class's own environment. Cross-namespace refs MUST be fully-qualified (`VWB.VWBridge` not `VWBridge`). Session-14 claim "bare VWBridge in VWB-scoped methods resolves via namespace lookup" was empirically wrong — latent bug shipped in `d86274b` Stage 2 commit, caught session-15. See [Chunk file-in compile scope](#chunk-file-in-compile-scope-session-15).
- **`TestCase class>>testClasses` is MAS-customized** to walk `ServerTestCase` + `ClientTestCase` (session-15): `cls suite` for ANY `TestCase` subclass aggregates the whole image's tests (hundreds of `GemStoneClasses.*Tests.*` classes). Use `cls buildSuiteFromLocalSelectors run` for per-class scope, or `TestSuite new addTest:` for selective subsets. See [SUnit semantics](#sunit-semantics-in-this-image-session-15).
- **`on: Core.Exception do:` catches `MessageNotUnderstood` and `Core.Error`** safely via /eval (session-15): no debugger pop, no bridge wedge. Whether it catches `TestFailure` (assertion-failed exception) is UNKNOWN — session-12 constraint #2 still holds for actual assertion failures.
- **Workspace requires `Core.*` qualification** for stock class names (session-15): GemBuilder-imported namespaces (`GemStone.Gbs.ServerClasses.WriteStreamLegacy`, `GemStoneClasses.Globals.String`, etc.) collide with VW core classes. /eval resolves bare names against the bridge serve-process's scope; Workspace pops disambiguation OR auto-picks the wrong candidate. Smalltalk handed to a human for Workspace paste MUST use `Core.String`, `Core.WriteStream`, `Core.Character`, etc.
- **/eval pre-flight rule** (session-15): while the bridge is up, verify any Smalltalk syntax via /eval BEFORE handing to a human for Workspace paste. Catches syntax errors, Workspace-vs-/eval ambiguity, and MNU on speculative API names. Cheap (~1 sec) — saves the human a paste-error round-trip.
- **`'path' asFilename fileIn` raises `EndOfStreamNotification` at EOF** (session-16): naive `[...] on: Core.Exception do:` wrapping CATCHES this benign notification and ABORTS file-in mid-stream (chunks compiled before the notification stay; chunks after are skipped — symptom: re-file-in appears to "complete" but newly-edited methods retain old bytecode). Either let the notification propagate (default = auto-resume at top level via bridge's outer handler) or explicitly `[...] on: Core.Notification do: [:ex | ex resume]` around the file-in to allow continuation. Session-15's `_probe-session15-refilein.st` worked because it had NO error wrapping; session-16's first refilein probe failed because it caught the notification.
- **Direct-invoke SUnit gate pattern must resume `Core.Notification` for SUnit `runCase` parity** (session-16): SUnit's standard `runCase` auto-resumes Notifications, so tests that legitimately signal benign Notifications PASS via Workspace but ERR via /eval if the direct-invoke probe doesn't wrap the test body with `[...] on: Core.Notification do: [:ex | ex resume]`. Updated template: `[[tc setUp. tc perform: sel] on: Core.Notification do: [:nex | nex resume]] on: Core.Exception do: [:ex | ...]`. Without this, 3 dialog tests in VWBridgeTest erred with `Notification | Notification - ` even though they pass via Workspace.
- **`Namespace>>at:put:` raises `Notification` on creating a NEW binding** (session-16): adding a previously-absent key to `Root.Smalltalk` (or any Namespace) signals an unnamed `Notification` (class=`Notification`, messageText=`'Notification - '`). Reassigning an existing key does NOT raise. In Workspace, auto-resumed silently; in /eval, propagates unless caught. Test design pitfall: 3 dialog tests in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) use `Root.Smalltalk at: #TEST_BUG2_*_RET put: 'pending'` as a cross-process fork-result channel — works once the binding exists, raises on each fresh image / namespace cleanup. Fix at gate probe level (Notification-resume) rather than test code, mirroring runCase semantics.
- **ByteArray-aware test helpers needed for binary responses** (session-16): when test response can be ByteArray (e.g., from `httpBinaryResponse:` for /screenshot), helpers must detect `aResponse isKindOf: Core.ByteArray` and switch lookups accordingly: `indexOf: Core.Character cr` → `indexOf: 13` (Integer); `indexOfSubCollection: 'crlf-crlf' (String)` → `indexOfSubCollection: #[13 10 13 10] (ByteArray)`; `aSubstring (String)` → `aSubstring asByteArray`. `aByteArray asString` and `aString asByteArray` are both native in this image (byte ↔ codepoint by value). Production `httpBinaryResponse:` was already correct — only [`VWBridge-ScreenshotTest.st`](../src/vw-bridge/VWBridge-ScreenshotTest.st) helpers (`statusLineOf:`, `bodyOf:`, `bodyContains:in:`, `headerContains:in:`) needed the dual-mode logic. Symptom: `description: 'Got: ' , (self statusLineOf: resp)` raises `Strings only store Characters` when statusLineOf: returns the entire ByteArray (fallback path) and String,ByteArray concat copies Integer elements into Character slots.
- **HTTP /eval inherent limit: bridge-dispatching tests fail with Bug #5 recursive_dispatch** (session-16 confirmed): 7 VWBridgeTest selectors that call `bridge dispatch:` from /eval hit the v0.8.8+ per-process re-entry guard and return HTTP 400 with `{"error":"recursive_dispatch","depth":2,"hint":...}`. These tests are designed to pass via VW Workspace (different process). The /eval gate measures hermetic + non-dispatching test correctness; **48/48 unblocked PASS + 7 known-blocked is the maximum achievable via /eval direct-invoke**. Documented in [`VWBridge-Test.st`](../src/vw-bridge/VWBridge-Test.st) L14-25 file header as `[HTTP /eval - ALL RED]`. Per-class /eval-PASS counts: WaitTest 25/25, VWBridgeTest 13/13 unblocked (10 hermetic + 3 dialog-with-Notification-resume), ScreenshotTest 10/10.
- **`load.st` / `unload.st` external orchestrators (session-17 Stage 3)**: `VWBridge.st` no longer auto-starts. [`src/vw-bridge/load.st`](../src/vw-bridge/load.st) orchestrates env-var resolve + 5-file file-in + `VWB.VWBridge start` + `.token` write; [`src/vw-bridge/unload.st`](../src/vw-bridge/unload.st) is the inverse defensive cleanup (capture tokenPath → stop bridge → delete .token → remove SimpleDialog override → remove 4 VWB classes reverse-dep → remove empty VWB namespace). Cold-start exception now goes through `load.st` (was `VWBridge.st`). Parcel-readiness prerequisite for P6 satisfied. See [Phase P P2 Stage 3](#phase-p-p2-stage-3--loadst--unloadst-orchestrators-session-17) section.
- **In-place unload+load+verify via single `/eval` call (session-17)**: The `/eval` handler runs on a forked process and SURVIVES listener termination — can re-create the bridge inline within the same `/eval` body. Pattern: pre-snapshot → unload body (kills listener) → post-unload snapshot → load body (use dynamic `Smalltalk at: #VWB` lookups for the start step to avoid stale compile-time bindings) → post-load snapshot → assert 6 gate predicates. Saves the Workspace cold-start round-trip for quality-gate testing. Idempotency proven via 2 consecutive cycles in session-17 (token rotated 3×, bridge survived 3 listener-recycle events without wedge).
- **`removeSelector:` is naturally defensive on absent selector** (session-17 verified): `Object removeSelector: #absent` returns without raising; same for `SimpleDialog removeSelector: #absent`. The defensive `on: Core.Error do: [:ex | nil]` wrap is belt-and-suspenders but not strictly required for `removeSelector:`. Combined with constraints #12 (`class removeFromSystem`) + #13 (`NameSpace removeFromSystem` on empty namespace) and `tokenPath asFilename delete` defensive guard, the unload.st sequence is fully idempotent across multiple invocations.
- **`Smalltalk.Dialog` has asymmetric setter/getter for native-dialogs flag** (session-18): setter is `useNativeDialogs:` (keyword, 1-arg) — what AGENTS.md cold-start step 3 references and what the Phase P P5 wrapper calls post-launch. Getter is `usesNativeDialogs` (unary, with an EXTRA 's' in 'uses', returns Boolean). The expected symmetric getter `useNativeDialogs` (no extra 's') does NOT exist and raises `MessageNotUnderstood` on probe. Verification probes must use the asymmetric form: `(Dialog class canUnderstand: #useNativeDialogs:)` for setter presence, `Dialog usesNativeDialogs` for current value.
- **`vwnt.exe -filein <chunk-file>` switch + `ImageConfigurationSystem` allow-flag state** (session-18 SHIPPED Phase P P5): `-filein` documented verbatim on `C:\visualworks931\doc\AppDevGuide.pdf` p36 + verified through 5-cycle quality gate (mean 9.11s per cycle, /health 200 in 1500ms). Behavior: takes one or more `.st` chunk files; image continues running after file-in (unlike `-evaluate` which exits). Generic syntax: `<oe> [oe-switches] <image-name> [image-switches]` — image name MUST precede switches. `Core.ImageConfigurationSystem` gates which image-level switches are honored per allow-flag (probe F session-18): allowFilein=true, allowExpressions=true, allowParcelLoading=true (good for P6 -pcl), allowSettings=false, allowDevelopment=false, useDefaultConfigFile=false. Top-level `^` in chunk file-in is silently consumed (probe D session-18) — same as `/eval` for `'path' asFilename fileIn`. See [Phase P P5 section](#phase-p-p5--start-vwbridgeps1-wrapper-via-vwntexe--filein-session-18) for the wrapper design + switch table.
- **`-err errorFile` is Runtime-Packager-only** (session-18 surprise): per AppDevGuide.pdf p481, `-err` and `-notifier notifierClass` are listed under "Runtime Packager installs two additional command-line options". In non-RuntimePackager images (like ours), the switch is silently accepted but the error file is NEVER created. Phase P P5 wrapper passes `-err <errfile>` defensively but handles missing file gracefully. Means we have ZERO startup-side stderr visibility without an alternative redirect mechanism (e.g., piping via `Start-Process -RedirectStandardError`, which requires non-detached process spawning and is incompatible with our detached-launch design).
- **`Cursor>>showWhile:` is the headless wedge culprit for `parcelOutOn:`** (session-19 SHIPPED Phase P P6): `Kernel.Parcel>>parcelOutOn:withSource:hideOnLoad:republish:backup:` wraps its real binary write in `Cursor wait showWhile: [block]`. In headless mode the cursor change blocks indefinitely, wedging the bridge listener. `Smalltalk.Dialog useNativeDialogs: false` does NOT prevent it (this path doesn't go through SimpleDialog). Workaround: save `Cursor compiledMethodAt: #showWhile:`, install pass-through patch via `Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'`, call `parcelOutOn:`, restore via `Cursor methodDictionary at: #showWhile: put: oldMethod` inside an `ensure:` block. See [Phase P P6 section](#phase-p-p6--vwbridgepcl-binary-parcel--start-vwbridgeps1--mode-parcel-session-19). Reusable for any headless invocation of canonical VW APIs that wrap work in `Cursor wait showWhile:`.
- **`Kernel.Parcel class>>createParcelNamed:` returns an EMPTY parcel** (session-19): not auto-populated from class>>category matches. Summary = `'Text for an Empty Parcel'`, `definedThings = IdentitySet()`. Content MUST be added explicitly before `parcelOutOn:` via instance-side selectors: `addNameSpace:`, `addEntiretyOfClass:`, `addEntiretyOfClasses:`, `addClass:`, `addClassAndAllSelectors:`, `addSelector:class:` (extension method — class arg is instance side for instance methods), `addBinding:in:`, `addName:in:`, `addObject:`. After `parcelOutOn:` succeeds, cleanup with `[Kernel.Parcel removeParcelNamed: name] on: Core.Notification do: [:n | n resume]` to drop from `parcelList`.
- **`parcelOutOn:withSource:` second arg is a Filename, not a boolean** (session-19): the keyword name `withSource:` suggests `withSource: true/false` but actually means `withSource: <pstFilename>` — a `Filename` for the `.pst` source companion. Passing `nil`/`false`/a Stream raises `MessageNotUnderstood: #asLogicalFileSpecification` because the method internally calls `asLogicalFileSpecification` on the source arg. The 3rd positional `hideOnLoad:` IS the boolean (suppresses post-load UI dialog, not source-hiding). The 4-th boolean `hideSource:` lives in the lower-level 6-arg writer call `CodeWriter>>writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:`. The wrapping `parcelOutOn:` translates `withSource:` → `sourceFileNamed:` + always writes a `.pst` companion regardless of `hideOnLoad:`.
- **`Kernel.Parcel class>>removeParcelNamed:` raises Notification** (session-19): a benign `'Notification - '` fires during the removal. Naive `[...] on: Core.Exception do: [...]` catches it and ABORTS the removal — parcel stays in `parcelList`. Use the Notification-resume pattern matching constraint #25: `[Kernel.Parcel removeParcelNamed: name] on: Core.Notification do: [:n | n resume]`. Wrapped within a broader `ensure:` block for guaranteed cleanup-on-error.
- **`CodeWriter` is the binary parcel write engine** (session-19): top-level `Smalltalk.CodeWriter` (env=#Kernel, super=ObjectTracer, 6 class-side selectors, 123 inst-side selectors). Inst-side `writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:` is the actual binary-write entry point that `parcelOutOn:` delegates to via `prepareCodeWriter:`. None of CodeWriter's methods call `#showWhile:` directly — the UI wrapper is at the `parcelOutOn:` layer, NOT in the writer. Direct CodeWriter invocation is theoretically possible but requires reverse-engineering the ChangeSet + codeComponent setup that `parcelOutOn:` does (session-19 attempted and failed: MNU `#removeKey:ifAbsent:` on nil receiver because parcel wasn't registered in some ChangeSet/SourceFileManager dict). The Cursor monkey-patch (constraint #35) bypasses this complexity by enabling the canonical wrapper invocation.
- **Parcel write embeds `.pst` path reference; ship `.pst` alongside `.pcl`** (session-19 P6): `Kernel.Parcel loadParcelFrom: pclFilename` looks for `pcl.pst` source companion alongside the `.pcl`. If absent, VW pops `'Failed to find source file <Name>.pst. Ok to load without target source?'` confirmation dialog that wedges headless image startup. Two fixes: (a) commit `.pst` alongside `.pcl` in distribution (current P6 approach — stock VW does this, UIPainter.pst 1.6 MB lives alongside UIPainter.pcl 670 KB), or (b) rebuild parcel with `hideOnLoad: true` to suppress source dependency. VW binary parcel format: magic header `00 11 00 00 00 D0 00 00 00 01 1D` + ASCII `Smalltalk Binary Storage File` + length-prefixed parcel name + length-prefixed version string.
- **`compile:` on VWB.VWBridge class via /eval wedges the bridge listener** (session-20 P8 discovery): calling `VWB.VWBridge class compile: 'methodSource' classified: 'category'` from an `/eval` body wedges the bridge listener even with the `Cursor>>showWhile:` monkey-patch (constraint #35) installed first. Root cause: `compile:` fires VW change announcements (`ChangeAdded` / `MethodAdded`) that fan out to UI listeners, at least one of which routes through a wedging path other than `Cursor wait showWhile:`. A SINGLE isolated `compile:` call sometimes works; a more involved probe (compile + parcelOutOn: + ensure: cleanup) reliably wedges. **Design implication**: don't compile new methods on VWB.VWBridge mid-/eval. Phase P P8 (`/version` endpoint) abandoned the "bake build metadata as compiled literal class-side methods" approach in favor of class-side accessors + setters that `Start-VWBridge.ps1` /eval-injects at every cold-start in both FileIn and Parcel modes. /version metadata therefore reflects "what is currently running" rather than "when was the parcel built". See [Phase P P7+P8 section](#phase-p-p7p8--installmd--get-version-endpoint-session-20).
- **ensure: block referencing VWB.VWBridge after `parcelOutOn:` + `removeParcelNamed:` raises "no binding"** (session-20 P8): when an ensure block runs `VWB.VWBridge class methodDictionary at: #foo put: oldMethod` AFTER `parcelOutOn:withSource:hideOnLoad:republish:backup:` + `removeParcelNamed:` cleanup, the Compiler reports `"The identifier VWB.VWBridge has no binding"` — even though the class IS still bound at runtime (verified by subsequent probes from the same image). Some Compiler / namespace state is corrupted during parcel manipulation that affects subsequent expression-compile binding resolution within the same /eval body. Likely related to constraint #41 (compile triggers UI broadcasts + change-announcement system perturbation). Workaround: avoid referencing the class by fully-qualified name in post-parcel-build ensure: blocks. If you must, capture the class object into a temp variable BEFORE the parcel build and reference it via the temp. NOT investigated deeply — was a side-discovery during the abandoned bake-metadata path and not hit on the shipped P8 design.
- **Bridge /eval response collapses ASCII whitespace control chars to single space** (session-22 Phase M MVP discovery, constraint #43): when the bridge JSON-encodes the Smalltalk result string for the `result` field of `POST /eval`, every LF (0x0A), CR (0x0D), and TAB (0x09) byte in the response body is replaced with a single SPACE (0x20). Verified byte-by-byte against the live bridge: a probe emitting `'Core' + LF + 'Kernel' + LF + 'Tools' + LF + ...'` (via `WriteStream` + `nextPutAll: (String with: Core.Character lf)`) returns the JSON `"result":"'Core Kernel Tools ...'"` — bytes `32` between names rather than `\\n` escapes or raw `10`. TAB collapses identically (verified). Confirms the bridge does NOT JSON-escape whitespace control chars properly — it normalizes them to space at encode time. **Implication for `/eval` probes**: any WriteStream-built tabular/list output cannot use LF/CR/TAB as record/field separators. **Workaround at MCP layer** (mcp-vw v0.1.0): use `;` as record separator and `|` as field separator. Both characters survive JSON encoding intact, never appear inside Smalltalk identifiers/namespaces/selectors, and are the canonical separators in `src/mcp-vw/src/smalltalk.ts` (`RECORD_SEP` + `FIELD_SEP` exports). All MVP tools that emit lists (`vw_list_namespaces`, `vw_list_namespace_entries`, `vw_list_methods`, `vw_find_senders`, `vw_list_loaded_parcels`) use this pattern. `vw_get_class_definition` still gets multi-line text but the whitespace collapse is tolerable (definition stays single-line + readable). Future bridge work could fix this at the source by escaping `\n`/`\r`/`\t` in the JSON encoder, but the MCP-layer workaround is sufficient.
- **Legacy 6-kw `subclass:...:inDictionary:category:` selector is ABSENT** (session-24 PR P0 Bug 1 discovery, constraint #44): the selector `<Superclass> subclass:instanceVariableNames:classVariableNames:poolDictionaries:inDictionary:category:` does NOT exist in this image. Verified live: `ApplicationModel respondsTo: #subclass:instanceVariableNames:classVariableNames:poolDictionaries:inDictionary:category:` → `false`. Probably a GemStone/S idiom that confused the original mcp-vw emitter. The 5-kw `subclass:...:category:` form (no `inDictionary:`) DOES exist (`true`) but places the class in the superclass's namespace — no way to control placement. **The canonical Cincom VW form** for arbitrary-namespace class creation is the 8-kw `defineClass:` selector on a Namespace receiver: `Smalltalk.<NS> defineClass: #ClassName superclass: #{<Superclass>} indexedType: #none private: false instanceVariableNames: '...' classInstanceVariableNames: '' imports: '' category: '...'`. Empirically verified via `vw_get_class_definition Tools.UIPainter` returning this exact shape, and through Bug 1's live probe + golden full-string test. **Implication for codegen tools**: `vw_create_class`, `vw_create_application_model`, `vw_create_dialog`, and `vw_compile_class_definition` all use the 8-kw form now (post-67ec8d2). The schema preserves `classVariableNames` / `poolDictionaries` parameter fields for backwards compat but the handler rejects non-empty inputs with a migration hint (use `vw_compile_method` against the metaclass instead — `classVariableNames` and `poolDictionaries` are different concepts from `classInstanceVariableNames` + `imports` in the 8-kw form, so transparent translation isn't possible).
- **Bridge response timeout often signals a blocking modal dialog** (session-24 Bug 6 debugging, constraint #45 — USER-DISCOVERED): when an MCP tool call or raw `vw_eval` times out, the most common cause is a VW modal dialog (often `SimpleDialog` with empty title `" "`) blocking the bridge's UI-thread response. The dispatch process has forked the operation but the response can't return until the dialog is dismissed. **Diagnostic pattern**: (1) don't retry the timed-out call immediately — it'll wedge again; (2) check `vw_health` first (bridge will still respond — auth-exempt); (3) `vw_list_windows` and look for `SimpleDialog` `appClass` or empty-title entries; (4) dismiss via `vw_respond_dialog { buttonLabel: 'OK' }` OR close via raw `/eval` walking `ScheduledControllers scheduledControllers` and calling `closeAndUnschedule` on matches; (5) retry the original call. **Compounding risk** (also s24): a windowSpec that MNUs at paint time pops a debugger window PER RE-PAINT cycle. In one s24 probe this stacked 135 `GbxDebuggerClient` debuggers in the background before being noticed. Each debugger pop fans out UI announcements competing with bridge dispatch — high wedge risk if uncaught. **Pre-flight precaution for batch destructive ops** (e.g., smoke tests creating + deleting many classes): `Smalltalk.Dialog useNativeDialogs: false` before the batch — prevents VW's class-removal confirmation dialog from triggering this pattern. The Phase P P5 wrapper does this automatically on bridge launch; verify state via `Smalltalk.Dialog usesNativeDialogs printString` (note asymmetric getter per constraint #32).

---

## How to maintain this doc

- **When a new API surprise shows up in a probe**, add a row to "APIs ABSENT" or "APIs PRESENT with surprising behavior" with a one-line workaround.
- **When a new namespace lookup trips someone up**, add a row to "Namespace organization".
- **When the image is restarted to a different `.im`**, re-verify the Image identity table.
- **When a new bug is fixed**, add a one-line summary to "Carry-forward constraints" — point to the relevant handoff for archaeology.
- **Don't grow the narrative**. New facts go in tables. Tables stay scannable. If a topic needs more than 5 rows, split into its own section.

---

## See also

- [`HANDOFF-2026-06-20-session8.md`](./HANDOFF-2026-06-20-session8.md) — session-8 EOD: v0.8.13 logging + Wave 1 + initial auto-start blocker findings (some inferences corrected in session-9)
- [`HANDOFF-2026-06-20-session7.md`](./HANDOFF-2026-06-20-session7.md) — session-7 EOD: Bug #2 fix v0.8.12
- [`vw-bridge-known-issues.md`](./vw-bridge-known-issues.md) — bugs #1-#6 with status
- [`vw-party-search.md`](./vw-party-search.md) — PartySearchView usage guide (Bug #2 workaround marked optional v0.8.12+)
- [`../plan/ROADMAP-QUALITY-FIRST.md`](../plan/ROADMAP-QUALITY-FIRST.md) — Phase D auto-start architecture decisions depend on this doc's Startup hook landscape section
