| s nl matches actionMatches osKeys ba ws ec |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Path B probe: subprocess + binary streams (READ-ONLY) ==='; nextPutAll: nl.

"--- A. Class hunt for subprocess/pipe/external-process candidates ---"
matches := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | | kn |
        kn := k asString.
        (((((((((kn indexOfSubCollection: 'Subprocess' startingAt: 1) > 0)
            or: [(kn indexOfSubCollection: 'ChildProcess' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'ExternalProcess' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'PipeableProc' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'CommandShell' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'WinProcess' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'OSProcess' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'SystemCommand' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'StreamPipe' startingAt: 1) > 0]])
        do: [:k | matches add: ns name , '.' , k asString]].
s nextPutAll: nl; nextPutAll: '--- Subprocess-related class candidates ('; nextPutAll: matches size printString; nextPutAll: ') ---'; nextPutAll: nl.
(matches asSortedCollection) do: [:n | s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

"--- B. OS namespace contents (full enumeration) ---"
s nextPutAll: nl; nextPutAll: '--- OS namespace keys ---'; nextPutAll: nl.
osKeys := [(OS keys asArray collect: [:k | k asString]) asSortedCollection]
    on: Error do: [:e | s nextPutAll: 'ERR OS namespace: ' , e messageText; nextPutAll: nl. #()].
s nextPutAll: 'count='; nextPutAll: osKeys size printString; nextPutAll: nl.
osKeys do: [:k | s nextPutAll: '  '; nextPutAll: k; nextPutAll: nl].

"--- C. Class-side action selectors in OS|Core|Kernel namespaces ---"
actionMatches := OrderedCollection new.
#(#OS #Core #Kernel) do: [:nsSym |
    | ns |
    ns := Smalltalk at: nsSym ifAbsent: [nil].
    ns notNil ifTrue: [
        ns keys do: [:k | | cls |
            cls := ns at: k ifAbsent: [nil].
            (cls notNil and: [cls isKindOf: Behavior]) ifTrue: [
                cls class selectors do: [:sel | | sn |
                    sn := sel asString.
                    (#('command:' 'command:arguments:' 'run:' 'exec:' 'system:' 'spawn:' 'popen:' 'execute:' 'shell:' 'startUp:')
                        includes: sn)
                        ifTrue: [actionMatches add: cls name asString , ' class>>' , sel asString]]]]]].
s nextPutAll: nl; nextPutAll: '--- Class-side action selectors in OS|Core|Kernel (';
  nextPutAll: actionMatches size printString; nextPutAll: ') ---'; nextPutAll: nl.
(actionMatches asSortedCollection) do: [:n | s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

"--- D. ByteArray WriteStream binary sanity test ---"
s nextPutAll: nl; nextPutAll: '--- Binary WriteStream test (ByteArray) ---'; nextPutAll: nl.
ba := ByteArray new: 16.
s nextPutAll: 'ba class='; nextPutAll: ba class name; nextPutAll: nl.
ws := [WriteStream on: ba]
    on: Error do: [:e |
        s nextPutAll: 'WS-on-bytearray ERR: ' , e messageText printString; nextPutAll: nl.
        nil].
ws notNil ifTrue: [
    s nextPutAll: 'ws class='; nextPutAll: ws class name; nextPutAll: nl.
    [ws nextPut: 16r89; nextPut: 16r50; nextPut: 16r4e; nextPut: 16r47; nextPut: 16r0d; nextPut: 16r0a; nextPut: 16r1a; nextPut: 16r0a]
        on: Error do: [:e | s nextPutAll: 'nextPut ERR: ' , e messageText printString; nextPutAll: nl].
    s nextPutAll: 'After 8 nextPut (PNG magic), ws contents class='; nextPutAll: ws contents class name; nextPutAll: nl.
    s nextPutAll: 'contents size='; nextPutAll: ws contents size printString; nextPutAll: nl.
    s nextPutAll: 'contents bytes (printString)='; nextPutAll: ws contents printString; nextPutAll: nl].

"--- E. Stream subclass tree (look for binary stream classes) ---"
s nextPutAll: nl; nextPutAll: '--- WriteStream allSubclasses ---'; nextPutAll: nl.
(WriteStream allSubclasses collect: [:c | c name asString]) asSortedCollection do: [:n |
    s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

"--- F. ExternalConnection / Socket classes (alternative to subprocess pipes) ---"
s nextPutAll: nl; nextPutAll: '--- ExternalConnection check ---'; nextPutAll: nl.
ec := Smalltalk at: #ExternalConnection ifAbsent: [nil].
ec isNil ifTrue: [s nextPutAll: 'ExternalConnection ABSENT (top-level)'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: 'ExternalConnection present, class.selectors count='; 
          nextPutAll: ec class selectors size printString; nextPutAll: nl].

s contents
