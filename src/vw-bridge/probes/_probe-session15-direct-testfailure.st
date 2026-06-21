"Session-15 direct experiment: does on: Core.Exception do: catch TestFailure raised directly (no SUnit involvement)?"
| outcome1 outcome2 testFailureClass |
testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].

"Test 1: raise TestFailure new signal:, catch via on: Core.Exception do:"
outcome1 := 'UNKNOWN'.
[testFailureClass new signal: 'direct raise']
    on: Core.Exception
    do: [:ex | outcome1 := 'CAUGHT: ', ex class name asString].

"Test 2: raise TestFailure new signal:, catch via on: Core.Error do: (per session-12 claim)"
outcome2 := 'UNKNOWN'.
[testFailureClass new signal: 'direct raise']
    on: Core.Error
    do: [:ex | outcome2 := 'CAUGHT: ', ex class name asString].

"Combine and report"
'TestFailure-class=', testFailureClass printString,
' | superclass=', testFailureClass superclass name,
' | exception-catch=', outcome1,
' | error-catch=', outcome2
