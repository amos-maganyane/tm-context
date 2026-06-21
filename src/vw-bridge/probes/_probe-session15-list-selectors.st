| s nl sels |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
sels := VWB.VWBridgeTest testSelectors asSortedCollection asArray.
s nextPutAll: 'VWBridgeTest.testSelectors ('; nextPutAll: sels size printString; nextPutAll: '):'; nextPutAll: nl.
sels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
s contents
