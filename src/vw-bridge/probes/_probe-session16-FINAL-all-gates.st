"Session-16 FINAL - consolidated all-3-gates sweep with v2 direct-invoke pattern.
Direct-invoke + Core.Notification resume (SUnit runCase parity). Single /eval call,
single consolidated result. Evidence for commit batch."
| s nl runGate |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

runGate := [:cls |
    | selectors results passCount errorCount failCount |
    selectors := cls testSelectors asSortedCollection asArray.
    results := Core.OrderedCollection new.
    passCount := 0. errorCount := 0. failCount := 0.
    selectors do: [:sel |
        | tc outcome startMs elapsedMs testFailureClass |
        testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
        tc := cls new.
        outcome := 'UNKNOWN'.
        startMs := Core.Time millisecondClockValue.
        [[[tc setUp.
           tc perform: sel.
           elapsedMs := Core.Time millisecondClockValue - startMs.
           outcome := 'PASS'. passCount := passCount + 1]
             on: Core.Notification
             do: [:nex | nex resume]]
            on: Core.Exception
            do: [:ex |
                elapsedMs := Core.Time millisecondClockValue - startMs.
                (testFailureClass notNil and: [ex isKindOf: testFailureClass])
                    ifTrue: [outcome := 'FAIL: ' , (ex messageText ifNil: ['(no msg)']). failCount := failCount + 1]
                    ifFalse: [outcome := 'ERR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)']). errorCount := errorCount + 1]]]
            ensure: [
                [tc tearDown] on: Core.Exception do: [:ex | nil]].
        results add: sel asString , ' (' , elapsedMs printString , 'ms): ' , outcome].
    s nextPutAll: '=== ', cls name asString, ' gate (' , selectors size printString , '): ' ,
        passCount printString , ' pass, ' , failCount printString , ' fail, ' , errorCount printString , ' error ==='; nextPutAll: nl.
    results do: [:r | s nextPutAll: r; nextPutAll: nl].
    s nextPutAll: nl].

"Run all 3 gates in sequence"
runGate value: VWB.VWBridgeWaitTest.
runGate value: VWB.VWBridgeTest.
runGate value: VWB.VWBridgeScreenshotTest.

s contents
