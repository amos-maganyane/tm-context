!VWBridge methodsFor: 'screenshot handler'!

captureScreenshotViaSubprocess: aSpec rect: aRect
	"v0.9.1 Step 17 session-13 fix: Production screen-capture via PowerShell
	 plus System.Drawing subprocess (per Oracle F3 verdict - Path B). Uses
	 OS.ExternalProcess execute:arguments:do:errorStreamDo: one-shot pattern
	 - NOT bare proc wait (session-12 attempted bare wait which returned
	 immediately with exit=259 STILL_ACTIVE because bare proc wait does not
	 actually wait synchronously in this VW image - new carry-forward
	 constraint number four). The one-shot drains stdout via the do block
	 during subprocess lifetime which makes wait synchronize correctly
	 (verified session-13 probe elapsed 2514ms for ~2.5s capture).

	 outStream binary is essential. Without binary flip the stream returns
	 TwoByteString with codepage-decoded characters that corrupt PNG bytes
	 (verified session-13 probe: byte 137 PNG magic became 235 without flip).

	 - aSpec: validated request dict (targetType, format, maxBytes, timeoutMs)
	 - aRect: nil for screen target; window snapshot dict for window target

	 Returns outcome Dictionary matching screenshotCaptureOverride shape so
	 handleScreenshotBody: routes both paths identically.
	   success keys: ok=true, pngBytes=ByteArray, width=Int, height=Int
	   failure keys: ok=false, status=Int, error=String, message=String

	 v1: synchronous wait (no timeoutMs enforcement); subprocess typically
	 completes in 2-3s for full virtual screen. Timeout enforcement via
	 separate fork plus terminate is a deferred improvement."
	| helperPath argList pngBytes stderrBuf invokeError extent result |
	helperPath := self screenshotHelperScriptPath.
	argList := Core.OrderedCollection new.
	argList add: '-ExecutionPolicy'; add: 'Bypass'.
	argList add: '-File'; add: helperPath.
	aRect isNil
		ifTrue: [
			"screen target - PS helper computes from SystemInformation VirtualScreen"
			argList add: '-Mode'; add: 'screen']
		ifFalse: [
			"window target - use the resolved rect from windowsSnapshotForWait shape"
			| x y w h |
			x := (aRect at: 'originX') asInteger.
			y := (aRect at: 'originY') asInteger.
			w := ((aRect at: 'cornerX') asInteger - x) max: 1.
			h := ((aRect at: 'cornerY') asInteger - y) max: 1.
			argList add: '-Mode'; add: 'window'.
			argList add: '-X'; add: x printString.
			argList add: '-Y'; add: y printString.
			argList add: '-W'; add: w printString.
			argList add: '-H'; add: h printString].
	pngBytes := nil.
	stderrBuf := WriteStream on: String new.
	invokeError := nil.
	[OS.ExternalProcess
		execute: 'powershell.exe'
		arguments: argList asArray
		do: [:outStream |
			outStream binary.
			pngBytes := [outStream upToEnd]
				on: self errorClass do: [:ex | ByteArray new]]
		errorStreamDo: [:errStream |
			[stderrBuf nextPutAll: errStream upToEnd asString]
				on: self errorClass do: [:ex | nil]]]
		on: self errorClass do: [:ex |
			invokeError := 'powershell launch or run failed - ' , ex description].
	invokeError notNil ifTrue: [
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: invokeError , '; stderr=' , stderrBuf contents].
	(pngBytes isNil or: [pngBytes isEmpty]) ifTrue: [
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: 'subprocess returned 0 bytes; stderr=' , stderrBuf contents].
	"Defensive normalization - binary flip should already yield ByteArray"
	(pngBytes isKindOf: ByteArray) ifFalse: [pngBytes := pngBytes asByteArray].
	extent := self pngExtentFromBytes: pngBytes.
	result := Core.Dictionary new.
	result at: 'ok' put: true.
	result at: 'pngBytes' put: pngBytes.
	result at: 'width' put: (extent at: 1).
	result at: 'height' put: (extent at: 2).
	^result! !
