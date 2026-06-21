| s nl ns vwb top |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
ns := VWB.VWBridge environment name.
vwb := Smalltalk at: #VWB ifAbsent: [nil].
top := Smalltalk at: #VWBridge ifAbsent: [nil].
s nextPutAll: 'env-name='; nextPutAll: ns printString; nextPutAll: nl.
s nextPutAll: 'top-level-VWBridge='; nextPutAll: top printString; nextPutAll: nl.
s nextPutAll: 'VWB-keys-count='; nextPutAll: vwb keys size printString; nextPutAll: nl.
s nextPutAll: 'VWB-keys='; nextPutAll: (vwb keys asSortedCollection asArray collect: [:k | k asString]) printString; nextPutAll: nl.
s nextPutAll: 'singleton-class='; nextPutAll: VWB.VWBridge singleton class name; nextPutAll: nl.
s nextPutAll: 'singleton-env='; nextPutAll: VWB.VWBridge singleton class environment name; nextPutAll: nl.
s contents