"Probe session-19 step 23: post-P6-gate final state verification.
Mirrors session-18 post-cycle-5 deep state probe. Confirms parcel-loaded bridge
matches semantic expectations of FileIn-mode bridge: VWB identity, override, dialog state."
| s nl bridge tokenMatch dialogState topVWBridge vwbKeys overrideCat |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
s nextPutAll: '=== Phase P P6 post-gate state ==='; nextPutAll: nl.
s nextPutAll: 'env-name='; nextPutAll: VWB.VWBridge environment name printString; nextPutAll: nl.
topVWBridge := Smalltalk at: #VWBridge ifAbsent: [nil].
s nextPutAll: 'toplevel-VWBridge='; nextPutAll: topVWBridge printString; nextPutAll: nl.
vwbKeys := VWB keys asSortedCollection asArray.
s nextPutAll: 'vwb-keys-size='; nextPutAll: vwbKeys size printString; nextPutAll: nl.
s nextPutAll: 'vwb-keys='; nextPutAll: vwbKeys printString; nextPutAll: nl.
bridge := VWB.VWBridge singleton.
s nextPutAll: 'singleton-port='; nextPutAll: bridge port printString; nextPutAll: nl.
tokenMatch := bridge token = '3959511089808-65801'.
s nextPutAll: 'token-matches-cycle5='; nextPutAll: tokenMatch printString; nextPutAll: nl.
overrideCat := (Smalltalk.SimpleDialog includesSelector: #choose:labels:values:default:for:) 
    ifTrue: [Smalltalk.SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:]
    ifFalse: [#absent].
s nextPutAll: 'simpledialog-override-category='; nextPutAll: overrideCat printString; nextPutAll: nl.
dialogState := Smalltalk.Dialog usesNativeDialogs.
s nextPutAll: 'uses-native-dialogs='; nextPutAll: dialogState printString; nextPutAll: nl.
s contents
