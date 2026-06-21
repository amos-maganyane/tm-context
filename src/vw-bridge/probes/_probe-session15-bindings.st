| s nl m setUpMethod testMethod |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"VWBridgeTest>>setUp literals"
setUpMethod := VWB.VWBridgeTest compiledMethodAt: #setUp ifAbsent: [nil].
s nextPutAll: 'setUp.literals='; nextPutAll: setUpMethod literals printString; nextPutAll: nl.
s nextPutAll: 'setUp.messages='; nextPutAll: setUpMethod messages asArray printString; nextPutAll: nl.

"VWBridgeTest>>testVwBridgeHomeOverrideTakesPriority literals"
testMethod := VWB.VWBridgeTest compiledMethodAt: #testVwBridgeHomeOverrideTakesPriority ifAbsent: [nil].
s nextPutAll: 'test.literals='; nextPutAll: testMethod literals printString; nextPutAll: nl.

"Compare: a method on VWB.VWBridge itself (e.g., #singleton) for sanity"
m := VWB.VWBridge class compiledMethodAt: #singleton ifAbsent: [nil].
m ifNotNil: [s nextPutAll: 'VWBridge.class>>singleton.literals='; nextPutAll: m literals printString; nextPutAll: nl].

"Verify VWB.VWBridge is reachable"
s nextPutAll: 'VWB.at.VWBridge='; nextPutAll: (VWB at: #VWBridge ifAbsent: [nil]) printString; nextPutAll: nl.
s nextPutAll: 'Smalltalk.at.VWBridge='; nextPutAll: (Smalltalk at: #VWBridge ifAbsent: [nil]) printString; nextPutAll: nl.

"What's VWBridgeTest's environment?"
s nextPutAll: 'VWBridgeTest.env='; nextPutAll: VWB.VWBridgeTest environment name; nextPutAll: nl.
s nextPutAll: 'VWBridgeTest.env.contains.VWBridge='; nextPutAll: (VWB.VWBridgeTest environment includesKey: #VWBridge) printString; nextPutAll: nl.

s contents
