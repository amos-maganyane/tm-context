"Session-16 - re-file-in VWBridge-ScreenshotTest.st with fixed helpers, then
re-run ScreenshotTest gate via direct-invoke pattern with Core.Notification resume."
| s nl fileinStatus cls selectors results passCount errorCount failCount |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step 1: file-in. Resume Notifications (per session-16 finding)."
fileinStatus := 'unknown'.
[[fileinStatus := 'starting'.
  'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-ScreenshotTest.st' asFilename fileIn.
  fileinStatus := 'ok']
    on: Core.Notification
    do: [:ex | ex resume]]
    on: Core.Error
    do: [:ex | fileinStatus := 'ERROR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)'])].
s nextPutAll: 'fileIn: '; nextPutAll: fileinStatus; nextPutAll: nl.

"Step 2: re-run ScreenshotTest gate via direct-invoke (with Notification resume)"
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

s nextPutAll: '=== VWBridgeScreenshotTest gate v2 (' , selectors size printString , ' selectors): ' ,
    passCount printString , ' pass, ' , failCount printString , ' fail, ' , errorCount printString , ' error ==='; nextPutAll: nl.
results do: [:r | s nextPutAll: r; nextPutAll: nl].
s contents
