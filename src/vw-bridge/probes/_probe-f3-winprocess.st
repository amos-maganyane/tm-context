| s nl wp ep |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Path B deep probe: OS.WinProcess + OS.ExternalProcess API ==='; nextPutAll: nl.

"--- OS.WinProcess ---"
wp := OS at: #WinProcess ifAbsent: [nil].
wp isNil
    ifTrue: [s nextPutAll: 'OS.WinProcess ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: nl; nextPutAll: '--- OS.WinProcess CLASS-SIDE selectors ('; nextPutAll: wp class selectors size printString; nextPutAll: ') ---'; nextPutAll: nl.
        (wp class selectors asSortedCollection) do: [:sel | s nextPutAll: '  +'; nextPutAll: sel asString; nextPutAll: nl].
        s nextPutAll: nl; nextPutAll: '--- OS.WinProcess INSTANCE-SIDE selectors ('; nextPutAll: wp selectors size printString; nextPutAll: ') ---'; nextPutAll: nl.
        (wp selectors asSortedCollection) do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
        s nextPutAll: nl; nextPutAll: 'OS.WinProcess superclass='; nextPutAll: wp superclass name asString; nextPutAll: nl.
        s nextPutAll: 'allSuperclasses='; nextPutAll: (wp allSuperclasses collect: [:c | c name asString]) printString; nextPutAll: nl].

"--- OS.ExternalProcess ---"
ep := OS at: #ExternalProcess ifAbsent: [nil].
ep isNil
    ifTrue: [s nextPutAll: 'OS.ExternalProcess ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: nl; nextPutAll: '--- OS.ExternalProcess CLASS-SIDE selectors ('; nextPutAll: ep class selectors size printString; nextPutAll: ') ---'; nextPutAll: nl.
        (ep class selectors asSortedCollection) do: [:sel | s nextPutAll: '  +'; nextPutAll: sel asString; nextPutAll: nl].
        s nextPutAll: nl; nextPutAll: '--- OS.ExternalProcess INSTANCE-SIDE selectors ('; nextPutAll: ep selectors size printString; nextPutAll: ') ---'; nextPutAll: nl.
        (ep selectors asSortedCollection) do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
        s nextPutAll: nl; nextPutAll: 'OS.ExternalProcess superclass='; nextPutAll: ep superclass name asString; nextPutAll: nl.
        s nextPutAll: 'allSuperclasses='; nextPutAll: (ep allSuperclasses collect: [:c | c name asString]) printString; nextPutAll: nl].

s contents
