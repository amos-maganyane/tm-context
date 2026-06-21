"Phase 0 step 5 - bridge class identity verification (session-17 start)"
| s nl envName topLevelLookup vwbClasses |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

envName := VWB.VWBridge environment name printString.
topLevelLookup := (Smalltalk at: #VWBridge ifAbsent: [nil]) printString.
vwbClasses := (VWB classNames asSortedCollection asArray) printString.

s nextPutAll: 'VWB.VWBridge environment name = '; nextPutAll: envName; nextPutAll: nl.
s nextPutAll: 'Smalltalk at: #VWBridge ifAbsent: [nil] = '; nextPutAll: topLevelLookup; nextPutAll: nl.
s nextPutAll: 'VWB classNames = '; nextPutAll: vwbClasses; nextPutAll: nl.

s contents
