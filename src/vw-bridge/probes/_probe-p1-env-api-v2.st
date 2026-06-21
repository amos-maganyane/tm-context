"Probe P1 (revised) - find the env-read API in this VW image. The OS.OperatingSystem class is absent so the standard VW selector doesn't resolve. Try several candidate access patterns and list relevant bindings in the OS namespace."
| s nl found |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. Confirm OS namespace exists and inventory env-related bindings."
s nextPutAll: '-- OS namespace presence --'; nextPutAll: nl.
found := Smalltalk at: #OS ifAbsent: [nil].
s nextPutAll: 'OS = '; nextPutAll: found printString; nextPutAll: nl.
found isNil ifFalse: [
    s nextPutAll: 'OS class = '; nextPutAll: found class name; nextPutAll: nl.
    s nextPutAll: 'OS keys size = '; nextPutAll: found keys size printString; nextPutAll: nl].

"2. List OS bindings whose name suggests OS / process / environment access."
s nextPutAll: nl; nextPutAll: '-- OS bindings matching env/process/system/platform/shell --'; nextPutAll: nl.
found isNil ifFalse: [
    | matches |
    matches := OrderedCollection new.
    found keys asArray do: [:k |
        ((k asString indexOfSubCollection: 'nv' startingAt: 1) > 0 or: [
        (k asString indexOfSubCollection: 'rocess' startingAt: 1) > 0 or: [
        (k asString indexOfSubCollection: 'ystem' startingAt: 1) > 0 or: [
        (k asString indexOfSubCollection: 'latform' startingAt: 1) > 0 or: [
        (k asString indexOfSubCollection: 'hell' startingAt: 1) > 0 or: [
        (k asString indexOfSubCollection: 'OS' startingAt: 1) > 0]]]]])
            ifTrue: [matches add: k asString]].
    matches asSortedCollection asArray do: [:k | s nextPutAll: '  OS.'; nextPutAll: k; nextPutAll: nl]].

"3. Confirm known-good binding from session-13 (OS.ExternalProcess) resolves."
s nextPutAll: nl; nextPutAll: '-- known-good binding from session-13 --'; nextPutAll: nl.
s nextPutAll: 'OS.ExternalProcess = '.
[s nextPutAll: OS.ExternalProcess name; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl].

"4. Try alternate paths for env access."
s nextPutAll: nl; nextPutAll: '-- candidate access patterns --'; nextPutAll: nl.

"4a. Smalltalk environment (some VW images)."
s nextPutAll: '4a. Smalltalk environment: '.
[s nextPutAll: Smalltalk environment class name; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl].

"4b. ObjectMemory environment (some images)."
s nextPutAll: '4b. ObjectMemory respondsTo: #environment = '.
s nextPutAll: (ObjectMemory class canUnderstand: #environment) printString; nextPutAll: nl.

"4c. OS.PlatformShell or similar singleton path."
s nextPutAll: '4c. OS keys starting with Platform/Shell/OS: '; nextPutAll: nl.
found isNil ifFalse: [
    #('PlatformShell' 'PlatformShellAccessor' 'OperatingSystemAccessor' 'WindowsPlatform' 'UnixPlatform' 'Win32Constants' 'OSProcessAccessor' 'PlatformConstants' 'PlatformFunctions') do: [:n |
        s nextPutAll: '    OS.'; nextPutAll: n; nextPutAll: ' = '.
        s nextPutAll: (found at: n asSymbol ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]].

"4d. ExternalProcess class-side env support."
s nextPutAll: '4d. OS.ExternalProcess class respondsTo: #env helpers'; nextPutAll: nl.
#(#getEnv: #environment #environmentVariableNamed: #getenv: #env: #getEnvironment) do: [:sel |
    s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (OS.ExternalProcess class canUnderstand: sel) printString; nextPutAll: nl].

"4e. Probe Smalltalk class-side env selectors."
s nextPutAll: '4e. Smalltalk class respondsTo: #env helpers'; nextPutAll: nl.
#(#getenv: #getEnv: #env: #environment #environmentVariableValueOf:) do: [:sel |
    s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (Smalltalk class canUnderstand: sel) printString; nextPutAll: nl].

s contents