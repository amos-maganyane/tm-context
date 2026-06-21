"Session-16 v2 - narrow down WHERE Notification fires in testBug2DialogConfirmYesReturnsTrue.
Step-isolates: literals of dialog test, setUp alone, first line inline, forkAt: line inline."
| s nl tc m litsStr |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step A: confirm testBug2DialogConfirmYesReturnsTrue exists + show its literals"
s nextPutAll: '=== A: dialog test literals ==='; nextPutAll: nl.
m := VWB.VWBridgeTest compiledMethodAt: #testBug2DialogConfirmYesReturnsTrue ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: 'METHOD ABSENT'; nextPutAll: nl]
    ifFalse: [
        litsStr := m literals printString.
        s nextPutAll: 'literals='; nextPutAll: litsStr; nextPutAll: nl;
          nextPutAll: 'numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl;
          nextPutAll: 'numTemps='; nextPutAll: m numTemps printString; nextPutAll: nl].

"Step B: run setUp ALONE (no perform:) and capture any Notification"
s nextPutAll: '=== B: setUp alone ==='; nextPutAll: nl.
tc := VWB.VWBridgeTest new.
[[tc setUp.
  s nextPutAll: 'setUp OK'; nextPutAll: nl]
    on: Core.Exception
    do: [:e |
        s nextPutAll: 'setUp CAUGHT: ', e class name asString, ' | ', (e messageText ifNil: ['(nil)']); nextPutAll: nl]]
    ensure: [
        [tc tearDown] on: Core.Exception do: [:e | nil]].

"Step C: run setUp + the first line of the test manually"
s nextPutAll: '=== C: setUp + Smalltalk at:put: ==='; nextPutAll: nl.
tc := VWB.VWBridgeTest new.
[[tc setUp.
  Root.Smalltalk at: #TEST_BUG2_YES_RET put: 'pending'.
  s nextPutAll: 'lines AB OK, TEST_BUG2_YES_RET=', (Root.Smalltalk at: #TEST_BUG2_YES_RET) printString; nextPutAll: nl]
    on: Core.Exception
    do: [:e |
        s nextPutAll: 'CAUGHT: ', e class name asString, ' | ', (e messageText ifNil: ['(nil)']); nextPutAll: nl]]
    ensure: [
        [tc tearDown] on: Core.Exception do: [:e | nil]].

"Step D: run setUp + first line + forkAt: alone (no Delay, no doRespondDialog)"
s nextPutAll: '=== D: setUp + at:put: + forkAt: ==='; nextPutAll: nl.
tc := VWB.VWBridgeTest new.
[[tc setUp.
  Root.Smalltalk at: #TEST_BUG2_YES_RET put: 'pending'.
  [Root.Smalltalk at: #TEST_BUG2_YES_RET put: 'fork-done']
    forkAt: Processor userSchedulingPriority.
  s nextPutAll: 'forkAt OK (no Dialog called)'; nextPutAll: nl]
    on: Core.Exception
    do: [:e |
        s nextPutAll: 'CAUGHT: ', e class name asString, ' | ', (e messageText ifNil: ['(nil)']); nextPutAll: nl]]
    ensure: [
        [tc tearDown] on: Core.Exception do: [:e | nil]].

s contents
