---
title: VW Image API Contract — MAS storedev64 image
purpose: Probe-derived reference for the live VisualWorks image at C:\visualworks931\image\storedev64.im. Read BEFORE writing new /eval probes or assuming standard VW API surface.
last_verified: 2026-06-20 (session-9, after parcel-autoload drill)
source_sessions: 3, 6, 7, 8, 9
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
| `Dialog useNativeDialogs: false` | Resets on every `vwnt.exe` restart | Re-toggle via `/eval` after every image launch |

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
