"Session-16 - re-file-in VWBridge-Test.st post-indexOfSubCollection fix + verify literals.
Expect: file-in returns gracefully, testHealthReturnsStatusOK literals now contain #startingAt:."
| fileInResult m lits hasStartingAt sampleSelectors check |
fileInResult := [
    'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn.
    'ok']
    on: Core.Exception
    do: [:ex | 'fileIn ERR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)'])].

m := VWB.VWBridgeTest compiledMethodAt: #testHealthReturnsStatusOK ifAbsent: [nil].
lits := m isNil ifTrue: ['method missing'] ifFalse: [m literals printString].
hasStartingAt := m isNil ifTrue: [false] ifFalse: [m literals anySatisfy: [:l | l = #startingAt:]].

"Spot-check 3 previously-erroring methods for #startingAt: in their literals"
sampleSelectors := #(#testHealthReturnsStatusOK #testEvalEvaluatesArithmetic #testWindowsRequiresAuth).
check := Core.OrderedCollection new.
sampleSelectors do: [:sel |
    | meth |
    meth := VWB.VWBridgeTest compiledMethodAt: sel ifAbsent: [nil].
    check add: sel asString , ' #startingAt: ' ,
        (meth isNil
            ifTrue: ['(method missing)']
            ifFalse: [(meth literals anySatisfy: [:l | l = #startingAt:]) printString])].

'fileIn=' , fileInResult , ' testHealthHasStartingAt=' , hasStartingAt printString
    , ' literals=' , lits
    , ' check=' , check asArray printString
