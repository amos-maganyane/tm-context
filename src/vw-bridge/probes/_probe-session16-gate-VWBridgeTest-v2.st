"Session-16 v2 - VWBridgeTest gate runner with Notification-resume parity for SUnit runCase.
Session-15 v1 template caught Notifications as ERR; SUnit's standard runCase actually
auto-resumes Notifications (Notification != Error in this image), letting test bodies
continue past benign signals like Namespace>>at:put: creating a new binding.
This v2 probe resumes Notifications explicitly, mirroring runCase semantics while still
catching real Errors + TestFailures."
| s nl cls selectors results passCount errorCount failCount |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
cls := VWB.VWBridgeTest.
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

s nextPutAll: '=== VWBridgeTest gate v2 (' , selectors size printString , ' selectors): ' ,
    passCount printString , ' pass, ' , failCount printString , ' fail, ' , errorCount printString , ' error ==='; nextPutAll: nl.
results do: [:r | s nextPutAll: r; nextPutAll: nl].
s contents
