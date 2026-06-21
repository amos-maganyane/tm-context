| s nl bridge tokenMatch dialogState topVWBridge vwbKeys |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
s nextPutAll: 'phase0-env-name='; nextPutAll: VWB.VWBridge environment name printString; nextPutAll: nl.
topVWBridge := Smalltalk at: #VWBridge ifAbsent: [nil].
s nextPutAll: 'phase0-toplevel-vwb-class='; nextPutAll: topVWBridge printString; nextPutAll: nl.
vwbKeys := VWB keys asArray.
s nextPutAll: 'phase0-vwb-keys-size='; nextPutAll: vwbKeys size printString; nextPutAll: nl.
s nextPutAll: 'phase0-vwb-keys='; nextPutAll: (vwbKeys asSortedCollection asArray) printString; nextPutAll: nl.
bridge := VWB.VWBridge singleton.
s nextPutAll: 'phase0-singleton-port='; nextPutAll: bridge port printString; nextPutAll: nl.
tokenMatch := bridge token = '3959506095072-199161'.
s nextPutAll: 'phase0-token-matches-handoff='; nextPutAll: tokenMatch printString; nextPutAll: nl.
dialogState := Smalltalk.Dialog usesNativeDialogs.
s nextPutAll: 'phase0-uses-native-dialogs='; nextPutAll: dialogState printString; nextPutAll: nl.
s contents
