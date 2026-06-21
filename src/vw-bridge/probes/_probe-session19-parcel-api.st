"Probe session-19 step 1: Kernel.Parcel build/save API surface.
Non-destructive enumeration of class-side + instance-side selectors related to parcel creation/serialization."
| s nl patterns matchPred classSels instSels createMethod |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
patterns := #('create' 'save' 'parcelOut' 'fileOut' 'build' 'write' 'snapshot').
matchPred := [:sel |
    (patterns detect: [:pat | (sel asString indexOfSubCollection: pat startingAt: 1) > 0]
        ifNone: [nil]) notNil].
classSels := (Kernel.Parcel class selectors asArray) asSortedCollection asArray.
instSels := (Kernel.Parcel selectors asArray) asSortedCollection asArray.
s nextPutAll: '=== class-side selectors matching create|save|parcelOut|fileOut|build|write|snapshot ==='; nextPutAll: nl.
classSels do: [:sel |
    (matchPred value: sel) ifTrue: [s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl]].
s nextPutAll: '=== instance-side selectors matching same patterns ==='; nextPutAll: nl.
instSels do: [:sel |
    (matchPred value: sel) ifTrue: [s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl]].
s nextPutAll: '=== createParcelNamed: behavioral fingerprint ==='; nextPutAll: nl.
createMethod := Kernel.Parcel class compiledMethodAt: #createParcelNamed: ifAbsent: [nil].
createMethod isNil 
    ifTrue: [s nextPutAll: '  ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  numArgs='; nextPutAll: createMethod numArgs printString; nextPutAll: nl.
        s nextPutAll: '  numTemps='; nextPutAll: createMethod numTemps printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: createMethod messages asSortedCollection asArray printString; nextPutAll: nl.
        s nextPutAll: '  literals='; nextPutAll: createMethod literals printString; nextPutAll: nl].
s contents
