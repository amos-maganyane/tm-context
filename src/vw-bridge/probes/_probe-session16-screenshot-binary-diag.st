"Session-16 - diagnose ScreenshotTest binary error.
Hypothesis: WriteStream on: ByteArray works (binary), httpBinaryResponse returns
ByteArray correctly, but the TEST HELPER statusLineOf: fails on ByteArray
(uses indexOf: Character cr which returns 0 on ByteArray), then returns the
whole ByteArray, then test's description: concats String with ByteArray
raising 'Strings only store Characters'."
| s nl ws bytesResp resp statusLine concatErr indexResult bodyResult |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step 1: confirm WriteStream on: ByteArray is binary-safe"
s nextPutAll: '=== Step 1: WriteStream on: ByteArray ==='; nextPutAll: nl.
ws := Core.WriteStream on: (Core.ByteArray new: 32).
[ws nextPut: 16r89. ws nextPutAll: #[16r50 16r4e].
 s nextPutAll: 'OK contents='; nextPutAll: ws contents printString; nextPutAll: nl]
    on: Core.Exception do: [:ex |
        s nextPutAll: 'ERR '; nextPutAll: ex class name asString; nextPutAll: ' | '; nextPutAll: (ex messageText ifNil: ['(no msg)']); nextPutAll: nl].

"Step 2: invoke handleScreenshotBody: directly and inspect resp"
s nextPutAll: '=== Step 2: handleScreenshotBody: with fake override ==='; nextPutAll: nl.
[| tc |
 tc := VWB.VWBridgeScreenshotTest new.
 tc setUp.
 [tc withScreenshotCaptureOverride: [:spec :rect | tc fakeSuccessResultWithBytes: tc fakePngBytesIncludingNullsAndHighBytes width: 1 height: 1]
    do: [resp := tc screenshotResponseFor: '{\"target\":{\"type\":\"screen\"},\"format\":\"png\"}']]
    ensure: [[tc tearDown] on: Core.Exception do: [:e | nil]]]
    on: Core.Notification do: [:ex | ex resume].
s nextPutAll: 'resp class= '; nextPutAll: resp class name asString; nextPutAll: nl.
s nextPutAll: 'resp size= '; nextPutAll: resp size printString; nextPutAll: nl.
s nextPutAll: 'resp first 50 bytes= '; nextPutAll: (resp copyFrom: 1 to: (50 min: resp size)) printString; nextPutAll: nl.

"Step 3: try indexOf: Core.Character cr on the ByteArray resp"
s nextPutAll: '=== Step 3: indexOf: Character cr on ByteArray ==='; nextPutAll: nl.
indexResult := [resp indexOf: Core.Character cr] on: Core.Exception do: [:ex | 'ERR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)'])].
s nextPutAll: 'indexOf: Character cr -> '; nextPutAll: indexResult printString; nextPutAll: nl.
"Compare: try indexOf: Integer 13 (cr value)"
s nextPutAll: 'indexOf: 13 -> '; nextPutAll: (resp indexOf: 13) printString; nextPutAll: nl.

"Step 4: try the statusLineOf: helper on the ByteArray"
s nextPutAll: '=== Step 4: statusLineOf: on ByteArray ==='; nextPutAll: nl.
[| tc |
 tc := VWB.VWBridgeScreenshotTest new.
 statusLine := tc statusLineOf: resp.
 s nextPutAll: 'statusLine class= '; nextPutAll: statusLine class name asString; nextPutAll: nl.
 s nextPutAll: 'statusLine size= '; nextPutAll: statusLine size printString; nextPutAll: nl.
 s nextPutAll: 'statusLine (first 50)= '; nextPutAll: (statusLine copyFrom: 1 to: (50 min: statusLine size)) printString; nextPutAll: nl]
    on: Core.Exception do: [:ex |
        s nextPutAll: 'statusLineOf ERR '; nextPutAll: ex class name asString; nextPutAll: ' | '; nextPutAll: (ex messageText ifNil: ['(no msg)']); nextPutAll: nl].

"Step 5: reproduce the concat that fails (String , ByteArray)"
s nextPutAll: '=== Step 5: String , ByteArray concat ==='; nextPutAll: nl.
concatErr := ['prefix: ' , resp. 'OK concat'] on: Core.Exception do: [:ex |
    'ERR: ' , ex class name asString , ' | ' , (ex messageText ifNil: ['(no msg)'])].
s nextPutAll: concatErr; nextPutAll: nl.

s contents
