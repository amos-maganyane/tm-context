"Session-16 v2 - diagnose ScreenshotTest binary error WITH CORRECT JSON.
v1 had backslash-escaped JSON quotes which Smalltalk treats as literal -
sent invalid JSON, got 400 instead of binary 200. v2 uses bare double-quotes
inside Smalltalk single-quoted string (no escaping needed)."
| s nl ws resp statusLineResult concatResult tc respClass respSize fakeBytes |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step 1: WriteStream on: ByteArray binary safety (sanity)"
s nextPutAll: '=== Step 1: WriteStream on: ByteArray ==='; nextPutAll: nl.
ws := Core.WriteStream on: (Core.ByteArray new: 32).
[ws nextPut: 16r89. ws nextPutAll: #[16r50 16r4e].
 s nextPutAll: 'OK contents='; nextPutAll: ws contents printString; nextPutAll: nl]
    on: Core.Exception do: [:ex |
        s nextPutAll: 'ERR '; nextPutAll: ex class name asString; nextPutAll: nl].

"Step 2: invoke handleScreenshotBody: with VALID JSON + capture override"
s nextPutAll: '=== Step 2: handleScreenshotBody: with valid JSON binary 200 path ==='; nextPutAll: nl.
resp := nil.
[[tc := VWB.VWBridgeScreenshotTest new.
  tc setUp.
  fakeBytes := tc fakePngBytesIncludingNullsAndHighBytes.
  [tc withScreenshotCaptureOverride: [:spec :rect | tc fakeSuccessResultWithBytes: fakeBytes width: 1920 height: 1080]
    do: [resp := tc screenshotResponseFor: '{"target":{"type":"screen"},"format":"png"}']]
    ensure: [[tc tearDown] on: Core.Exception do: [:e | nil]]]
    on: Core.Notification do: [:ex | ex resume]]
    on: Core.Error do: [:ex |
        s nextPutAll: 'Step 2 ERR '; nextPutAll: ex class name asString; nextPutAll: ' | '; nextPutAll: (ex messageText ifNil: ['(no msg)']); nextPutAll: nl].

respClass := resp isNil ifTrue: ['nil'] ifFalse: [resp class name asString].
respSize := resp isNil ifTrue: ['nil'] ifFalse: [resp size printString].
s nextPutAll: 'resp class='; nextPutAll: respClass; nextPutAll: nl.
s nextPutAll: 'resp size='; nextPutAll: respSize; nextPutAll: nl.
resp isNil ifFalse: [
    s nextPutAll: 'resp first 80='; nextPutAll: (resp copyFrom: 1 to: (80 min: resp size)) printString; nextPutAll: nl].

"Step 3: try indexOf: Character cr on resp (whatever class)"
s nextPutAll: '=== Step 3: indexOf: Character cr on resp ==='; nextPutAll: nl.
resp isNil ifFalse: [
    | idxChar idxInt |
    idxChar := [resp indexOf: Core.Character cr] on: Core.Exception do: [:ex | 'ERR:', ex class name asString].
    idxInt := [resp indexOf: 13] on: Core.Exception do: [:ex | 'ERR:', ex class name asString].
    s nextPutAll: 'indexOf: Character cr -> '; nextPutAll: idxChar printString; nextPutAll: nl.
    s nextPutAll: 'indexOf: 13 -> '; nextPutAll: idxInt printString; nextPutAll: nl].

"Step 4: try statusLineOf: on resp"
s nextPutAll: '=== Step 4: statusLineOf: on resp ==='; nextPutAll: nl.
resp isNil ifFalse: [
    statusLineResult := [| sl tc2 | tc2 := VWB.VWBridgeScreenshotTest new. sl := tc2 statusLineOf: resp. 'OK class=', sl class name asString, ' size=', sl size printString, ' value=', sl printString]
        on: Core.Exception do: [:ex | 'ERR ', ex class name asString, ' | ', (ex messageText ifNil: ['(no msg)'])].
    s nextPutAll: statusLineResult; nextPutAll: nl].

"Step 5: reproduce the String , resp concat (the actual test pattern)"
s nextPutAll: '=== Step 5: String , resp concat ==='; nextPutAll: nl.
resp isNil ifFalse: [
    concatResult := ['prefix: ', resp. 'OK concat'] on: Core.Exception do: [:ex |
        'ERR ', ex class name asString, ' | ', (ex messageText ifNil: ['(no msg)'])].
    s nextPutAll: concatResult; nextPutAll: nl].

"Step 6: reproduce String , (statusLineOf: resp) - the EXACT test pattern"
s nextPutAll: '=== Step 6: String , (statusLineOf: resp) ==='; nextPutAll: nl.
resp isNil ifFalse: [
    | actualPattern |
    actualPattern := [| tc3 sl | tc3 := VWB.VWBridgeScreenshotTest new. sl := tc3 statusLineOf: resp. 'prefix: ', sl. 'OK pattern'] on: Core.Exception do: [:ex |
        'ERR ', ex class name asString, ' | ', (ex messageText ifNil: ['(no msg)'])].
    s nextPutAll: actualPattern; nextPutAll: nl].

s contents
