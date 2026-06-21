"=== VWBridgeScreenshotTest - SUnit tests for the v0.9.1+ /screenshot endpoint ==="
"Filed-in alongside VWBridge.st via:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-ScreenshotTest.st' asFilename fileIn

 ============================================================================
 *** HOW TO RUN THESE TESTS ***
 ============================================================================
 These tests INVOKE handleScreenshotBody: DIRECTLY on the bridge singleton,
 bypassing the HTTP router entirely. This means:
   - They are SAFE to run via POST /eval (the Bug #5 re-entry guard is not
     triggered because handleScreenshotBody: is called directly, not through
     bridge route layer).
   - They also work from a VW Workspace identically.

   [WORKSPACE / HTTP - both GREEN once handleScreenshotBody: is implemented in session-12]
   VWBridgeScreenshotTest suite run printString
   ((VWBridgeScreenshotTest selector: #testScreenshotFakeCaptureSuccessReturns200WithPngBytes) run) printString

 The 10 tests are designed RED first (session-11 TDD scaffold) - they will
 all fail with 'screenshot endpoint not implemented yet (RED until session-12
 lands)' until the handler + test seams are added.

 Implementation order (per Oracle F3, bg_3e72b537):
   1. Request validation (parseAndValidateScreenshotRequest:)
   2. Binary response builder (httpBinaryResponse:type:body: returning ByteArray)
   3. Fake capture success path (screenshotCaptureOverride seam)
   4. maxBytes -> 413 screenshot-too-large
   5. Window target zero matches -> 404 screenshot-window-not-found
   6. Window target multiple matches -> 409 screenshot-window-ambiguous
   7. Fake timeout outcome -> 408 screenshot-timeout
   8. Fake capture failure -> 500 screenshot-capture-failed
   9. (Later) live PowerShell smoke tests via OS.ExternalProcess
 ============================================================================

 Design notes:
 - Tests invoke handleScreenshotBody: directly (no HTTP layer round-trip).
 - setUp grabs the live singleton + builds authorized headers (parallel to
   VWBridgeWaitTest / VWBridgeTest pattern).
 - tearDown calls bridge clearScreenshotOverrides defensively (guarded by
   respondsTo: check so tearDown works even when seam not yet implemented).
 - ensureScreenshotImplemented helper checks all required methods exist
   before each test, providing a uniform RED message instead of confusing
   doesNotUnderstand errors.
 - Fake PNG bytes include null (0x00) AND high (0xFF, 0x89, etc.) byte
   values to lock binary safety from test #4 onward (per Oracle's guidance
   on test seam refinement).
 - Test seam dictionary shape (per Oracle):
     success: { ok=true, pngBytes=ByteArray, width=Integer, height=Integer }
     failure: { ok=false, status=Integer, error=String, message=String }
 - scriptedWindowsForScreenshot is INTENTIONALLY SEPARATE from
   scriptedWindowSnapshots so /wait and /screenshot tests do not interfere.
 - Test method count: 10 (8 per Oracle's TDD order + 2 validation sub-cases
   for format/maxBytes specifics)."

Smalltalk.VWB defineClass: #VWBridgeScreenshotTest
	superclass: #{TestCase}
	indexedType: #none
	private: false
	instanceVariableNames: 'bridge authHeaders'
	classInstanceVariableNames: ''
	imports: ''
	category: 'VWBridge-Tests'!

!VWB.VWBridgeScreenshotTest methodsFor: 'fixture'!

setUp
	"Capture singleton + build authorized headers for the current token."
	bridge := VWB.VWBridge singleton.
	authHeaders := Core.Dictionary new.
	authHeaders at: 'Authorization' put: 'Bearer ' , bridge token!

tearDown
	"Clear screenshot test seams to restore production behavior.
	 Defensive: works even if seams not yet implemented (RED state)."
	(bridge respondsTo: #clearScreenshotOverrides)
		ifTrue: [bridge clearScreenshotOverrides]!

ensureScreenshotImplemented
	"Verify the screenshot endpoint + seams are implemented. Provides a
	 uniform RED message until session-12 implementation lands, instead of
	 cryptic doesNotUnderstand errors. Tests should call this first."
	| missing |
	missing := OrderedCollection new.
	(bridge respondsTo: #handleScreenshotBody:) ifFalse: [missing add: 'handleScreenshotBody:'].
	(bridge respondsTo: #screenshotCaptureOverride:) ifFalse: [missing add: 'screenshotCaptureOverride:'].
	(bridge respondsTo: #scriptedWindowsForScreenshot:) ifFalse: [missing add: 'scriptedWindowsForScreenshot:'].
	(bridge respondsTo: #clearScreenshotOverrides) ifFalse: [missing add: 'clearScreenshotOverrides'].
	missing isEmpty ifFalse: [
		self assert: false
			description: 'screenshot endpoint not implemented yet (RED until session-12 lands). Missing: ' , missing printString]!

screenshotResponseFor: aBodyString
	"Invoke handleScreenshotBody: directly on the bridge singleton. Bypasses
	 HTTP router to avoid Bug #5 re-entry guard - safe to run via /eval.
	 Calls ensureScreenshotImplemented first so callers get a clean RED
	 message rather than DNU."
	self ensureScreenshotImplemented.
	^bridge handleScreenshotBody: aBodyString!

statusLineOf: aResponse
	"First line of the HTTP response (before first CR).
	 Works for both String and ByteArray responses (treats high bytes as
	 character codes; status line is always ASCII)."
	| idx |
	idx := aResponse indexOf: Core.Character cr.
	idx = 0 ifTrue: [
		"Try LF as fallback - PowerShell helper might emit LF-only"
		idx := aResponse indexOf: Core.Character lf].
	^idx > 0 ifTrue: [aResponse copyFrom: 1 to: idx - 1] ifFalse: [aResponse]!

bodyOf: aResponse
	"Everything after the headers/body separator (CR LF CR LF).
	 Uses 2-arg indexOfSubCollection:startingAt: per image API contract."
	| crlf sep idx |
	crlf := String with: Core.Character cr with: Core.Character lf.
	sep := crlf , crlf.
	idx := aResponse indexOfSubCollection: sep startingAt: 1.
	^idx > 0
		ifTrue: [aResponse copyFrom: idx + sep size to: aResponse size]
		ifFalse: ['']!

bodyContains: aSubstring in: aResponse
	"Predicate: does the response contain the substring? Uses 2-arg
	 indexOfSubCollection: per image API contract. Works on String and
	 ByteArray responses (byte-comparison)."
	^(aResponse indexOfSubCollection: aSubstring startingAt: 1) > 0!

headerContains: aSubstring in: aResponse
	"Check if a substring appears in the header section only (before body
	 separator). Useful for asserting Content-Type without false positives
	 from body content."
	| crlf sep idx headerSection |
	crlf := String with: Core.Character cr with: Core.Character lf.
	sep := crlf , crlf.
	idx := aResponse indexOfSubCollection: sep startingAt: 1.
	headerSection := idx > 0
		ifTrue: [aResponse copyFrom: 1 to: idx - 1]
		ifFalse: [aResponse].
	^(headerSection indexOfSubCollection: aSubstring startingAt: 1) > 0! !

!VWB.VWBridgeScreenshotTest methodsFor: 'fixture - helpers'!

fakePngBytesIncludingNullsAndHighBytes
	"Returns a small ByteArray containing PNG magic + null bytes + high
	 bytes. Lockstep with Oracle's guidance to lock binary safety from
	 the first capture test - not ASCII-only."
	^#[16r89 16r50 16r4e 16r47 16r0d 16r0a 16r1a 16r0a
	   16r00 16r00 16r00 16r0d 16r49 16r48 16r44 16r52
	   16rff 16rfe 16r00 16r01 16r80 16r7f]!

fakeOversizedPngBytesOfSize: aByteCount
	"Returns a ByteArray of the requested size, filled with PNG-magic-like
	 bytes (no real PNG validity needed - just binary content to assert
	 size-cap rejection)."
	| ws |
	ws := WriteStream on: (ByteArray new: aByteCount).
	aByteCount timesRepeat: [ws nextPut: 16r89].
	^ws contents!

fakeSuccessResultWithBytes: aByteArray width: w height: h
	"Build the dictionary shape Oracle specified for screenshotCaptureOverride
	 success outcomes."
	| d |
	d := Core.Dictionary new.
	d at: 'ok' put: true.
	d at: 'pngBytes' put: aByteArray.
	d at: 'width' put: w.
	d at: 'height' put: h.
	^d!

fakeFailureResultStatus: aStatusCode error: anErrorCode message: aMessage
	"Build the dictionary shape Oracle specified for screenshotCaptureOverride
	 failure outcomes."
	| d |
	d := Core.Dictionary new.
	d at: 'ok' put: false.
	d at: 'status' put: aStatusCode.
	d at: 'error' put: anErrorCode.
	d at: 'message' put: aMessage.
	^d!

windowRectSnapshotAppClass: aClassName titleContains: aTitle origin: anOriginString corner: aCornerString
	"Build a single window-snapshot Dictionary matching the shape
	 scriptedWindowsForScreenshot expects. Includes geometry needed for
	 captureScreenshot to compute the screen rectangle. Origin and corner
	 are strings like '805@281' / '1758@1121'."
	| d |
	d := Core.Dictionary new.
	d at: 'id' put: 'screenshot-test-win'.
	d at: 'appClass' put: aClassName.
	d at: 'title' put: aTitle.
	d at: 'viewClass' put: 'ScheduledWindow'.
	d at: 'bounds' put: anOriginString , ' corner: ' , aCornerString.
	d at: 'originX' put: ((anOriginString tokensBasedOn: $@) first asNumber).
	d at: 'originY' put: ((anOriginString tokensBasedOn: $@) last asNumber).
	d at: 'cornerX' put: ((aCornerString tokensBasedOn: $@) first asNumber).
	d at: 'cornerY' put: ((aCornerString tokensBasedOn: $@) last asNumber).
	^d!

windowRectSnapshotAppClass: aClassName titleContains: aTitle id: anId
	"Build a window snapshot with explicit id (for multi-match disambiguation tests)."
	| d |
	d := self windowRectSnapshotAppClass: aClassName titleContains: aTitle origin: '0@0' corner: '100@100'.
	d at: 'id' put: anId.
	^d!

withScreenshotCaptureOverride: aBlock do: aTestBlock
	"Set screenshotCaptureOverride, run the test block, rely on tearDown
	 to clear. aBlock receives (spec, rect) and returns a result dictionary
	 per Oracle's shape."
	bridge screenshotCaptureOverride: aBlock.
	^aTestBlock value!

withScriptedScreenshotWindows: aWindowCollection do: aTestBlock
	"Set scriptedWindowsForScreenshot to a fixed snapshot, run the test
	 block. aWindowCollection is an OrderedCollection of window-snapshot
	 dictionaries."
	bridge scriptedWindowsForScreenshot: aWindowCollection asOrderedCollection.
	^aTestBlock value! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - validation'!

testScreenshotRejectsBadRequest
	"POST /screenshot with empty body - expect 400 bad-request."
	| resp |
	resp := self screenshotResponseFor: '{}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Expected 400 for empty body. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'invalid-screenshot-request' in: resp)
		description: 'Body should reference invalid-screenshot-request error'!

testScreenshotRejectsUnsupportedFormat
	"format='jpg' rejected (PNG-only v1) - expect 415."
	| resp |
	resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"jpg"}'.
	self assert: (self bodyContains: 'HTTP/1.1 415' in: resp)
		description: 'format=jpg should return 415. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-unsupported-format' in: resp)
		description: 'Body should reference screenshot-unsupported-format error'!

testScreenshotRejectsInvalidMaxBytes
	"maxBytes=0 (or negative or > 16777216) - expect 400."
	| resp |
	resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png","maxBytes":0}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'maxBytes=0 must be rejected. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'maxBytes' in: resp)
		description: 'Body should reference maxBytes in the error'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - binary response'!

testScreenshotBinaryResponseBuilderRoundTripsPngBytes
	"Binary safety lock. Fake capture returns bytes including null (0x00)
	 AND high (0xFF, 0x89) values. Response must preserve every byte
	 exactly - no Latin1 mangling, no truncation at first null."
	| resp fakeBytes |
	fakeBytes := self fakePngBytesIncludingNullsAndHighBytes.
	self withScreenshotCaptureOverride: [:spec :rect |
		self fakeSuccessResultWithBytes: fakeBytes width: 1 height: 1]
		do: [
			resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 for fake success. Got: ' , (self statusLineOf: resp).
	self assert: (self headerContains: 'Content-Type: image/png' in: resp)
		description: 'Response must declare Content-Type: image/png'.
	"The body bytes must equal fakeBytes exactly - byte for byte."
	self assert: (self bodyOf: resp) size = fakeBytes size
		description: 'Body size should equal fake bytes size. Body size: ' , (self bodyOf: resp) size printString , ', expected: ' , fakeBytes size printString.
	self assert: (self bodyOf: resp) = fakeBytes
		description: 'Body bytes must round-trip identically (binary safety)'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - capture success'!

testScreenshotFakeCaptureSuccessReturns200WithPngBytes
	"Happy path with default request. Override returns fake success.
	 Asserts 200 + image/png + extent headers + body bytes."
	| resp fakeBytes |
	fakeBytes := self fakePngBytesIncludingNullsAndHighBytes.
	self withScreenshotCaptureOverride: [:spec :rect |
		self fakeSuccessResultWithBytes: fakeBytes width: 1920 height: 1080]
		do: [
			resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 OK. Got: ' , (self statusLineOf: resp).
	self assert: (self headerContains: 'image/png' in: resp)
		description: 'Content-Type must be image/png'.
	self assert: (self headerContains: 'X-VWBridge-Screenshot-Width: 1920' in: resp)
		description: 'Width header must reflect captured dimension'.
	self assert: (self headerContains: 'X-VWBridge-Screenshot-Height: 1080' in: resp)
		description: 'Height header must reflect captured dimension'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - size cap'!

testScreenshotMaxBytesExceededReturns413
	"Override returns oversize bytes (200 bytes when maxBytes=100).
	 Bridge must detect and reject with 413 - NOT silently truncate, NOT
	 auto-downscale (per F1 spec)."
	| resp oversizedBytes |
	oversizedBytes := self fakeOversizedPngBytesOfSize: 200.
	self withScreenshotCaptureOverride: [:spec :rect |
		self fakeSuccessResultWithBytes: oversizedBytes width: 1 height: 1]
		do: [
			resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png","maxBytes":100}'].
	self assert: (self bodyContains: 'HTTP/1.1 413' in: resp)
		description: 'Expected 413 for oversized body. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-too-large' in: resp)
		description: 'Body should reference screenshot-too-large error'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - window targeting'!

testScreenshotWindowTargetZeroMatchesReturns404
	"target=window with appClass that does not match any scripted window -
	 expect 404 BEFORE invoking capture override (window resolution first)."
	| resp captureCalled |
	captureCalled := false.
	self withScriptedScreenshotWindows: OrderedCollection new do: [
		self withScreenshotCaptureOverride: [:spec :rect | captureCalled := true. self fakeSuccessResultWithBytes: #[16r89] width: 1 height: 1]
			do: [
				resp := self screenshotResponseFor: '{"target":{"type":"window","appClass":"NoSuchApp"},"format":"png"}']].
	self assert: (self bodyContains: 'HTTP/1.1 404' in: resp)
		description: 'Expected 404 for zero-match window. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-window-not-found' in: resp)
		description: 'Body should reference screenshot-window-not-found error'.
	self assert: captureCalled = false
		description: 'Capture override must NOT be called when window resolution fails'!

testScreenshotWindowTargetMultipleMatchesReturns409
	"target=window with appClass matching 2 scripted windows - expect 409
	 ambiguous BEFORE invoking capture (per F1 - first-match-wins is flaky)."
	| resp w1 w2 captureCalled |
	captureCalled := false.
	w1 := self windowRectSnapshotAppClass: 'TestApp' titleContains: 'First' id: 'win-1'.
	w2 := self windowRectSnapshotAppClass: 'TestApp' titleContains: 'Second' id: 'win-2'.
	self withScriptedScreenshotWindows: (OrderedCollection with: w1 with: w2) do: [
		self withScreenshotCaptureOverride: [:spec :rect | captureCalled := true. self fakeSuccessResultWithBytes: #[16r89] width: 1 height: 1]
			do: [
				resp := self screenshotResponseFor: '{"target":{"type":"window","appClass":"TestApp"},"format":"png"}']].
	self assert: (self bodyContains: 'HTTP/1.1 409' in: resp)
		description: 'Expected 409 for ambiguous window. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-window-ambiguous' in: resp)
		description: 'Body should reference screenshot-window-ambiguous error'.
	self assert: captureCalled = false
		description: 'Capture override must NOT be called when window ambiguous'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - timeout'!

testScreenshotFakeTimeoutReturns408
	"Override returns a timeout failure outcome - bridge should map status
	 408 to HTTP 408 response with screenshot-timeout error."
	| resp |
	self withScreenshotCaptureOverride: [:spec :rect |
		self fakeFailureResultStatus: 408 error: 'screenshot-timeout' message: 'subprocess exceeded timeoutMs']
		do: [
			resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png","timeoutMs":1000}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 for timeout outcome. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-timeout' in: resp)
		description: 'Body should reference screenshot-timeout error'! !

!VWB.VWBridgeScreenshotTest methodsFor: 'tests - capture failure'!

testScreenshotFakeCaptureFailureReturns500
	"Override returns a generic capture failure outcome - bridge should
	 map to 500 with screenshot-capture-failed error."
	| resp |
	self withScreenshotCaptureOverride: [:spec :rect |
		self fakeFailureResultStatus: 500 error: 'screenshot-capture-failed' message: 'subprocess exited non-zero']
		do: [
			resp := self screenshotResponseFor: '{"target":{"type":"screen"},"format":"png"}'].
	self assert: (self bodyContains: 'HTTP/1.1 500' in: resp)
		description: 'Expected 500 for capture failure. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'screenshot-capture-failed' in: resp)
		description: 'Body should reference screenshot-capture-failed error'! !

"Stage 2 cleanup: remove old top-level Root.Smalltalk.VWBridgeScreenshotTest if present (idempotent - defensive guard ensures we only touch the OLD top-level class, never the new VWB.VWBridgeScreenshotTest)"
[(Smalltalk at: #VWBridgeScreenshotTest ifAbsent: [nil]) ifNotNil: [:cls | (cls environment == Root.Smalltalk) ifTrue: [cls removeFromSystem]]] on: Core.Error do: [:ex | nil]!
