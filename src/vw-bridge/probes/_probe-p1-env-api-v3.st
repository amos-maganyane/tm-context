"Probe P1 v3 - narrow to canonical env-read API. OS.CEnvironment is the named candidate. Also verify OS.ExternalProcess environment / ObjectMemory environment / at:put: setter for test-time mutation."
| s nl env |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. OS.CEnvironment shape - what kind of class and what does it offer."
s nextPutAll: '-- OS.CEnvironment --'; nextPutAll: nl.
s nextPutAll: 'superclass: '; nextPutAll: OS.CEnvironment superclass name; nextPutAll: nl.
s nextPutAll: 'class size: '; nextPutAll: OS.CEnvironment class selectors size printString; nextPutAll: nl.
s nextPutAll: 'inst size: '; nextPutAll: OS.CEnvironment selectors size printString; nextPutAll: nl.
s nextPutAll: 'class selectors: '; nextPutAll: (OS.CEnvironment class selectors asSortedCollection asArray printString); nextPutAll: nl.
s nextPutAll: 'inst selectors: '; nextPutAll: (OS.CEnvironment selectors asSortedCollection asArray printString); nextPutAll: nl.

"2. Try common class-side instance accessors."
s nextPutAll: nl; nextPutAll: '-- get a CEnvironment instance --'; nextPutAll: nl.
#(#current #default #new #singleton #instance) do: [:sel |
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: ' = '.
    [s nextPutAll: (OS.CEnvironment perform: sel) class name; nextPutAll: nl]
        on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl]].

"3. Class-side at: / at:ifAbsent: shortcut."
s nextPutAll: nl; nextPutAll: '-- direct CEnvironment class-side reads --'; nextPutAll: nl.
[s nextPutAll: 'class>>at: USERPROFILE = '.
 s nextPutAll: (OS.CEnvironment at: 'USERPROFILE' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl].

"4. Via OS.ExternalProcess environment."
[env := OS.ExternalProcess environment.
 s nextPutAll: 'OS.ExternalProcess environment class: '; nextPutAll: env class name; nextPutAll: nl.
 s nextPutAll: '  size: '; nextPutAll: env size printString; nextPutAll: nl.
 s nextPutAll: '  at: USERPROFILE = '; nextPutAll: (env at: 'USERPROFILE' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl.
 s nextPutAll: '  at: VW_BRIDGE_HOME = '; nextPutAll: (env at: 'VW_BRIDGE_HOME' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl.
 s nextPutAll: '  at: VISUALWORKS = '; nextPutAll: (env at: 'VISUALWORKS' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR ExtProc env '; nextPutAll: e messageText; nextPutAll: nl].

"5. Via ObjectMemory environment - what does that even return?"
[s nextPutAll: nl; nextPutAll: 'ObjectMemory environment class: '; nextPutAll: ObjectMemory environment class name; nextPutAll: nl.
 s nextPutAll: '  ObjectMemory environment printString: '; nextPutAll: ObjectMemory environment printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR OM env '; nextPutAll: e messageText; nextPutAll: nl].

"6. Mutation surface - for test-time env injection."
s nextPutAll: nl; nextPutAll: '-- env mutation --'; nextPutAll: nl.
[env := OS.ExternalProcess environment.
 s nextPutAll: 'env respondsTo: at:put: = '; nextPutAll: (env respondsTo: #at:put:) printString; nextPutAll: nl.
 s nextPutAll: 'env respondsTo: removeKey: = '; nextPutAll: (env respondsTo: #removeKey:) printString; nextPutAll: nl.
 s nextPutAll: 'env respondsTo: removeKey:ifAbsent: = '; nextPutAll: (env respondsTo: #removeKey:ifAbsent:) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl].

s contents