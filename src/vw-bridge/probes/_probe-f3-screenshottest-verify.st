| s nl cls testSelectors oneResult |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== VWBridgeScreenshotTest verification ==='; nextPutAll: nl.

"Section A: class loaded?"
cls := Smalltalk at: #VWBridgeScreenshotTest ifAbsent: [nil].
cls isNil
    ifTrue: [s nextPutAll: 'CLASS ABSENT!'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: 'class.name='; nextPutAll: cls name asString; nextPutAll: nl.
        s nextPutAll: 'class.superclass='; nextPutAll: cls superclass name asString; nextPutAll: nl.
        s nextPutAll: 'class.category='; nextPutAll: cls category printString; nextPutAll: nl.
        s nextPutAll: 'class.selectors count='; nextPutAll: cls selectors size printString; nextPutAll: nl.

        "Section B: list test selectors"
        testSelectors := (cls selectors asArray select: [:sel |
            (sel asString indexOfSubCollection: 'test' startingAt: 1) = 1]) asSortedCollection.
        s nextPutAll: nl; nextPutAll: 'test selectors ('; nextPutAll: testSelectors size printString; nextPutAll: '):'; nextPutAll: nl.
        testSelectors do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

        "Section C: list helper selectors"
        s nextPutAll: nl; nextPutAll: 'helper selectors (non-test):'; nextPutAll: nl.
        ((cls selectors asArray reject: [:sel |
            (sel asString indexOfSubCollection: 'test' startingAt: 1) = 1]) asSortedCollection) do: [:sel |
            s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

        "Section D: run ONE test (smallest one) and capture result"
        s nextPutAll: nl; nextPutAll: '--- Run ONE test: testScreenshotRejectsBadRequest ---'; nextPutAll: nl.
        oneResult := [(cls selector: #testScreenshotRejectsBadRequest) run]
            on: Error do: [:e | 'ERROR: ' , e class name asString , ' - ' , e messageText printString].
        s nextPutAll: 'result.class='; nextPutAll: oneResult class name; nextPutAll: nl.
        s nextPutAll: 'result.printString='; nextPutAll: oneResult printString; nextPutAll: nl].

s contents
