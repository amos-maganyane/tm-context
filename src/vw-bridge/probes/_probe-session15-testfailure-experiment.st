"Session-15 experiment: does on: Core.Exception do: catch SUnit TestFailure?"
"Picking testHealthReturnsStatusOK - WILL assert-fail via /eval (re-entry guard returns 400, test expects 200)"
"This is the empirical test for session-12 constraint #2 - we now know on: Core.Exception do: catches MNU/Error, unknown for TestFailure"
| tc result outcome startMs elapsedMs |
tc := VWB.VWBridgeTest selector: #testHealthReturnsStatusOK.
outcome := 'UNKNOWN'.
startMs := Core.Time millisecondClockValue.
[result := tc run.
 outcome := 'CLEAN_RESULT: ', result printString,
            ' | failureCount=', result failureCount printString,
            ' | errorCount=', result errorCount printString]
    on: Core.Exception
    do: [:ex |
        outcome := 'EXCEPTION_ESCAPED: ', ex class name asString,
                   ' | msg=', (ex messageText ifNil: ['(nil)'])].
elapsedMs := Core.Time millisecondClockValue - startMs.
outcome, ' | elapsedMs=', elapsedMs printString
