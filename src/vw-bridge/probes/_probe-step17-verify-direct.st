"Verify Step 17 fix - invoke handleScreenshotBody: with no override.
 Expected: response is a ByteArray (NOT a String 500-error), size in the
 800KB range, HTTP status line 200 OK, Content-Type image/png header
 present, body bytes start with PNG magic 137 80 78 71 13 10 26 10.

 Comment hygiene: zero exclamation marks. No router substring."

| s nl bridge respBytes respSize hdrStr hdrEnd bodyStart firstPngBytes pngMagicOk |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Verify Step 17 fix: handleScreenshotBody: with no override ==='; nextPutAll: nl.

bridge := VWBridge singleton.
s nextPutAll: 'bridge class = '; nextPutAll: bridge class name; nextPutAll: nl.
s nextPutAll: 'screenshotCaptureOverride nil? = ';
	nextPutAll: ((bridge instVarNamed: 'screenshotCaptureOverride') isNil) printString;
	nextPutAll: nl.

"--- Invoke production capture path ---"
respBytes := nil.
[respBytes := bridge handleScreenshotBody: '{"target":{"type":"screen"},"format":"png"}']
	on: Error do: [:e | 
		respBytes := 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].

s nextPutAll: nl; nextPutAll: '--- Response inspection ---'; nextPutAll: nl.
s nextPutAll: 'resp class = '; nextPutAll: respBytes class name; nextPutAll: nl.
respSize := [respBytes size] on: Error do: [:e | -1].
s nextPutAll: 'resp size = '; nextPutAll: respSize printString; nextPutAll: nl.

"--- Decode header section as String for status line + Content-Type inspection ---"
(respBytes isKindOf: ByteArray) ifTrue: [
	"Find header/body boundary: CRLFCRLF = 13 10 13 10"
	hdrEnd := 0.
	1 to: ((respBytes size - 3) min: 4096) do: [:i |
		(hdrEnd = 0
			and: [(respBytes at: i) = 13
			and: [(respBytes at: i + 1) = 10
			and: [(respBytes at: i + 2) = 13
			and: [(respBytes at: i + 3) = 10]]]])
				ifTrue: [hdrEnd := i + 3]].
	s nextPutAll: 'hdrEnd = '; nextPutAll: hdrEnd printString; nextPutAll: nl.
	hdrEnd > 0 ifTrue: [
		hdrStr := WriteStream on: String new.
		1 to: hdrEnd do: [:i | hdrStr nextPut: (Core.Character value: (respBytes at: i))].
		s nextPutAll: 'header section = '; nextPutAll: hdrStr contents printString; nextPutAll: nl.
		"--- Inspect first 16 bytes of body (should be PNG magic plus IHDR start) ---"
		bodyStart := hdrEnd + 1.
		((respBytes size - bodyStart) >= 16) ifTrue: [
			firstPngBytes := (bodyStart to: bodyStart + 15) collect: [:i | respBytes at: i].
			s nextPutAll: 'body first 16 = '; nextPutAll: firstPngBytes printString; nextPutAll: nl.
			pngMagicOk := (firstPngBytes first: 8) asArray = #(137 80 78 71 13 10 26 10).
			s nextPutAll: 'PNG magic OK = '; nextPutAll: pngMagicOk printString; nextPutAll: nl.
			s nextPutAll: 'body size = '; nextPutAll: (respBytes size - hdrEnd) printString; nextPutAll: nl]]].

(respBytes isKindOf: String) ifTrue: [
	"Failure case - String response is the JSON error envelope"
	s nextPutAll: 'STRING response (failure path): '; nextPutAll: respBytes; nextPutAll: nl].

s contents
