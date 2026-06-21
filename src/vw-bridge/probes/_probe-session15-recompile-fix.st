| s nl m beforeBinding afterBinding result |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"1. What does the current resolved binding point at?"
m := VWB.VWBridgeTest compiledMethodAt: #setUp ifAbsent: [nil].
beforeBinding := m literals first.
s nextPutAll: 'before.binding='; nextPutAll: beforeBinding printString; nextPutAll: nl.
s nextPutAll: 'before.binding.value='; nextPutAll: beforeBinding value printString; nextPutAll: nl.

"2. Try recompile - does the new compile resolve against the class's environment (VWB)?"
[VWB.VWBridgeTest recompile: #setUp.
 m := VWB.VWBridgeTest compiledMethodAt: #setUp ifAbsent: [nil].
 afterBinding := m literals first.
 s nextPutAll: 'after.recompile.binding='; nextPutAll: afterBinding printString; nextPutAll: nl.
 s nextPutAll: 'after.recompile.binding.value='; nextPutAll: afterBinding value printString; nextPutAll: nl]
    on: Core.Exception
    do: [:ex | s nextPutAll: 'recompile EX: '; nextPutAll: ex class name asString; nextPutAll: ' - '; nextPutAll: (ex messageText ifNil: ['(nil)']); nextPutAll: nl].

"3. If recompile worked, retry the smoke test"
[result := (VWB.VWBridgeTest selector: #testVwBridgeHomeOverrideTakesPriority) run.
 s nextPutAll: 'retry.result='; nextPutAll: result printString; nextPutAll: nl]
    on: Core.Exception
    do: [:ex | s nextPutAll: 'retry EX: '; nextPutAll: ex class name asString; nextPutAll: ' - '; nextPutAll: (ex messageText ifNil: ['(nil)']); nextPutAll: nl].

s contents
