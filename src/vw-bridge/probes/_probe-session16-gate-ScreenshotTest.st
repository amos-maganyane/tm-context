"Session-16 full /eval gate runner for VWB.VWBridgeScreenshotTest via direct-invoke pattern (bypasses SUnit runCase debugger-popping per session-15 proof)"
"Each selector runs in isolation: new instance, setUp, perform:, capture exception, tearDown"
"Watch for Windows CopyFromScreen environmental issue (not bridge regression) per session-15 handoff"
| s nl cls selectors results passCount errorCount failCount |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
cls := VWB.VWBridgeScreenshotTest.
selectors := cls testSelectors asSortedCollection asArray.
results := Core.OrderedCollection new.
passCount := 0. errorCount := 0. failCount := 0.

selectors do: [:sel |
    | tc outcome startMs elapsedMs testFailureClass |
    testFailureClass := Smalltalk at: #TestFailure ifAbsent: [nil].
    tc := cls new.
    outcome := 'UNKNOWN'.
    startMs := Core.Time millisecondClockValue.
    [[tc setUp.
      tc perform: sel.
      elapsedMs := Core.Time millisecondClockValue - startMs.
      outcome := 'PASS'. passCount := passCount + 1]
        on: Core.Exception
        do: [:ex |
            elapsedMs := Core.Time millisecondClockValue - startMs.
            (testFailureClass notNil and: [ex isKindOf: testFailureClass])
                ifTrue: [outcome := 'FAIL: ' , (ex messageText ifNil: ['(no msg)']). failCount := failCount + 1]
                ifFalse: [outcome := 'ERR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)']). errorCount := errorCount + 1]]]
        ensure: [
            [tc tearDown] on: Core.Exception do: [:ex | nil]].
    results add: sel asString , ' (' , elapsedMs printString , 'ms): ' , outcome].

s nextPutAll: '=== VWBridgeScreenshotTest gate (', selectors size printString, ' selectors): ',
    passCount printString, ' pass, ', failCount printString, ' fail, ', errorCount printString, ' error ==='; nextPutAll: nl.
results do: [:r | s nextPutAll: r; nextPutAll: nl].
s contents
