"Session-16 v2 - re-file-in VWBridge-Test.st post-fix.
Lesson from v1 probe: on: Core.Exception do: catches benign EndOfStreamNotification
that the chunk parser raises at EOF, short-circuiting file-in before all chunks compile.
Fix: resume Notifications so file-in completes; only treat Error as failure.
Literal check uses string-grep for 'startingAt:' since the new compiled selector is
#indexOfSubCollection:startingAt: (ONE combined symbol), not separate #startingAt:."
| s nl sampleSelectors fileinStatus |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step 1: file-in. Resume Notifications (e.g., EndOfStreamNotification at EOF)
 so they do not unwind file-in mid-stream. Real Errors still propagate / get caught."
fileinStatus := 'unknown'.
[[fileinStatus := 'starting'.
  'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn.
  fileinStatus := 'ok']
    on: Core.Notification
    do: [:ex | ex resume]]
    on: Core.Error
    do: [:ex | fileinStatus := 'ERROR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)'])].
s nextPutAll: 'fileIn: '; nextPutAll: fileinStatus; nextPutAll: nl.

"Step 2: verify literals across 3 prior-erroring methods. New compiled methods
 should contain selector #indexOfSubCollection:startingAt: (one combined symbol).
 Check via printString grep for the substring 'startingAt:'."
s nextPutAll: '=== literals check (looking for startingAt: substring) ==='; nextPutAll: nl.
sampleSelectors := #(#testHealthReturnsStatusOK #testEvalEvaluatesArithmetic #testWindowsRequiresAuth #testHealthReturnsCurrentVersion #testEvalReturnsErrorForBadCode #testHealthDoesNotRequireAuth #testWindowsAcceptsValidAuth).
sampleSelectors do: [:sel |
    | meth litsStr has |
    meth := VWB.VWBridgeTest compiledMethodAt: sel ifAbsent: [nil].
    s nextPutAll: sel asString; nextPutAll: ': '.
    meth isNil
        ifTrue: [s nextPutAll: '(method missing)']
        ifFalse: [
            litsStr := meth literals printString.
            has := (litsStr indexOfSubCollection: 'startingAt:' startingAt: 1) > 0.
            s nextPutAll: 'has #startingAt:= '; nextPutAll: has printString.
            s nextPutAll: ' literals='; nextPutAll: litsStr].
    s nextPutAll: nl].

s contents
