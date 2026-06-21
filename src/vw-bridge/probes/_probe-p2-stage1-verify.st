"Stage 1 verification - confirm class categories + SimpleDialog method category updated after Stage 1 file-in batch."
| s nl m org |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. Class categories - should all be the new VWBridge-Core / VWBridge-Tests values."
s nextPutAll: '-- Class categories --'; nextPutAll: nl.
s nextPutAll: '  VWBridge: '; nextPutAll: VWBridge category printString; nextPutAll: nl.
s nextPutAll: '  VWBridgeTest: '; nextPutAll: VWBridgeTest category printString; nextPutAll: nl.
s nextPutAll: '  VWBridgeWaitTest: '; nextPutAll: VWBridgeWaitTest category printString; nextPutAll: nl.
s nextPutAll: '  VWBridgeScreenshotTest: '; nextPutAll: VWBridgeScreenshotTest category printString; nextPutAll: nl.

"2. SimpleDialog method existence."
s nextPutAll: nl; nextPutAll: '-- SimpleDialog patch method --'; nextPutAll: nl.
m := SimpleDialog compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
s nextPutAll: '  method exists: '; nextPutAll: m notNil printString; nextPutAll: nl.

"3. SimpleDialog method category via class organization (CompiledMethod has no #category in this image)."
s nextPutAll: '  category via organization: '.
[org := SimpleDialog organization.
 s nextPutAll: (org categoryOfElement: #choose:labels:values:default:for:) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR ' , e messageText; nextPutAll: nl].

"4. All categories on SimpleDialog - look for *VWBridge-Patches category."
s nextPutAll: nl; nextPutAll: '-- All SimpleDialog categories --'; nextPutAll: nl.
[org := SimpleDialog organization.
 org categories asSortedCollection asArray do: [:c |
    ((c asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0 or: [(c asString indexOfSubCollection: 'mas-bug' startingAt: 1) > 0 or: [(c asString indexOfSubCollection: '*' startingAt: 1) > 0]])
        ifTrue: [s nextPutAll: '  '; nextPutAll: c asString; nextPutAll: nl]]]
    on: Error do: [:e | s nextPutAll: 'org ERR ' , e messageText; nextPutAll: nl].

"5. Parcel introspection - is there a VWBridge-Patches parcel/package now?"
s nextPutAll: nl; nextPutAll: '-- Parcel introspection --'; nextPutAll: nl.
[s nextPutAll: '  parcelNamed VWBridge-Patches: '; nextPutAll: (Kernel.Parcel parcelNamed: 'VWBridge-Patches') printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  parcel lookup ERR'; nextPutAll: nl].

s contents