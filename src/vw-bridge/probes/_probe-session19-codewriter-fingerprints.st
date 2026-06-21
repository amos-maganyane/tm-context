"Probe session-19 step 16: fingerprint CodeWriter's parcel-write methods to find headless-safe variant.

CodeWriter has 3 likely write entry points:
  - parcelInto: (1-arg) - simplest
  - writeToParcelFileNamed: (1-arg) - simpler than full 6-arg version
  - writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup: (6-arg) - full

Check each for #showWhile: presence (the wedge culprit) + their delegation chain."
| s nl m sels |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

sels := #(
    #new
    #initialize
    #initializeRegistry
    #codeComponent:
    #parcelInto:
    #writeToParcelFileNamed:
    #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:
    #storeDefinitionsAndComments
).

sels do: [:sel |
    | isClassSide |
    isClassSide := sel = #new.
    m := isClassSide
        ifTrue: [CodeWriter class compiledMethodAt: sel ifAbsent: [nil]]
        ifFalse: [CodeWriter compiledMethodAt: sel ifAbsent: [nil]].
    s nextPutAll: '=== CodeWriter'.
    isClassSide ifTrue: [s nextPutAll: ' class'].
    s nextPutAll: '>>'; nextPutAll: sel asString; nextPutAll: ' ==='; nextPutAll: nl.
    m isNil
        ifTrue: [s nextPutAll: '  ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
            s nextPutAll: '  numTemps='; nextPutAll: m numTemps printString; nextPutAll: nl.
            s nextPutAll: '  showWhile?='; nextPutAll: (m messages includes: #showWhile:) printString; nextPutAll: nl.
            s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl]].

s contents
