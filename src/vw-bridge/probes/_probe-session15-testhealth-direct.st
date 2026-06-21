"Session-15 experiment: direct-invoke testHealthReturnsStatusOK to see actual exception class + check TestFailure catch"
| tc result startMs elapsedMs testFailureClass |
testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
tc := VWB.VWBridgeTest new.
result := 'UNKNOWN'.
[tc setUp.
 startMs := Core.Time millisecondClockValue.
 [tc perform: #testHealthReturnsStatusOK.
  elapsedMs := Core.Time millisecondClockValue - startMs.
  result := 'METHOD_OK | elapsedMs=', elapsedMs printString]
    on: Core.Exception
    do: [:ex |
        elapsedMs := Core.Time millisecondClockValue - startMs.
        result := 'CAUGHT_EX: ', ex class name asString,
                  ' | TestFailure-cls=', (testFailureClass ifNil: ['nil'] ifNotNil: [testFailureClass name]),
                  ' | isKindOf:TestFailure=', (testFailureClass isNil ifTrue: ['cls-nil'] ifFalse: [(ex isKindOf: testFailureClass) printString]),
                  ' | msg=', (ex messageText ifNil: ['(nil)']),
                  ' | elapsedMs=', elapsedMs printString]]
    ensure: [tc tearDown].
result
