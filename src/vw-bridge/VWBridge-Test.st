"=== VWBridgeTest - SUnit tests for the v0.8.8+ bridge dispatcher ==="
"Filed-in alongside VWBridge.st via:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn

 ============================================================================
 *** HOW TO RUN THESE TESTS ***
 ============================================================================
 PREFER A VW WORKSPACE for green results:

   [WORKSPACE - GREEN]
   VWBridgeTest suite run printString
   ((VWBridgeTest selector: #testHealthReturnsCurrentVersion) run) printString

   [HTTP /eval - ALL RED (each test returns 400 recursive_dispatch, v0.8.8+)]
   POST http://127.0.0.1:9876/eval  with body  'VWBridgeTest suite run'
   --> tests fail clean, listener stays alive (was image-killing pre-v0.8.8)

 Why: these tests dispatch against VWBridge singleton synchronously. When
 they're invoked from /eval, that runs on the bridge's own serve process,
 and the recursive bridge dispatch: from within a serve-process handler
 hits the v0.8.8 per-process re-entry guard and returns 400. Pre-v0.8.8 it
 wedged the listener and required a vwnt.exe restart. See
 knowledge/vw-bridge-known-issues.md Bug #5 for the full writeup,
 implementation, and verification evidence.
 ============================================================================

 Design notes:
 - Tests dispatch directly against VWBridge singleton (no HTTP listener
   round-trip required), so they run on the in-image SUnit process and are
   independent of network state or port availability.
 - setUp grabs the live token from the singleton, so tests stay valid
   across bridge restarts (file-in writes a new token, tests pick it up
   automatically).
 - Each test asserts against the raw HTTP response string returned by
   dispatch:headers:body: (status line + headers + body)."

Smalltalk.VWB defineClass: #VWBridgeTest
	superclass: #{TestCase}
	indexedType: #none
	private: false
	instanceVariableNames: 'bridge authHeaders'
	classInstanceVariableNames: ''
	imports: ''
	category: 'VWBridge-Tests'!

!VWB.VWBridgeTest methodsFor: 'fixture'!

setUp
	"Capture singleton + build authorized headers for the current token."
	bridge := VWBridge singleton.
	authHeaders := Core.Dictionary new.
	authHeaders at: 'Authorization' put: 'Bearer ' , bridge token!

dispatch: requestLine
	"Helper: dispatch authorized, no body."
	^bridge dispatch: requestLine headers: authHeaders body: ''!

dispatch: requestLine headers: hdrs
	"Helper: dispatch with caller-controlled headers (for auth-edge tests)."
	^bridge dispatch: requestLine headers: hdrs body: ''!

dispatch: requestLine body: aBody
	"Helper: dispatch authorized with a body."
	^bridge dispatch: requestLine headers: authHeaders body: aBody!

statusLineOf: aResponse
	"First line of the HTTP response (before first CR)."
	| idx |
	idx := aResponse indexOf: Core.Character cr.
	^idx > 0 ifTrue: [aResponse copyFrom: 1 to: idx - 1] ifFalse: [aResponse]!

bodyOf: aResponse
	"Everything after the headers/body separator (CR LF CR LF).
	 Uses 2-arg indexOfSubCollection:startingAt: because the 1-arg form errors
	 on some receiver contexts in this image (session-8 carry-forward constraint)."
	| crlf sep idx |
	crlf := String with: Core.Character cr with: Core.Character lf.
	sep := crlf , crlf.
	idx := aResponse indexOfSubCollection: sep startingAt: 1.
	^idx > 0
		ifTrue: [aResponse copyFrom: idx + sep size to: aResponse size]
		ifFalse: ['']! !

!VWB.VWBridgeTest methodsFor: 'tests - health'!

testHealthReturnsStatusOK
	"GET /health -> HTTP 200."
	| resp |
	resp := self dispatch: 'GET /health HTTP/1.1'.
	self assert: (resp indexOfSubCollection: 'HTTP/1.1 200 OK') > 0
		description: 'Health should return 200 OK. Status: ' , (self statusLineOf: resp)!

testHealthReturnsCurrentVersion
	"Locks the bridge version against /health output.
	 UPDATE the version literal in this test when bumping the bridge."
	| body |
	body := self bodyOf: (self dispatch: 'GET /health HTTP/1.1').
	self assert: (body indexOfSubCollection: '"status":"ok"') > 0
		description: 'Health body missing status=ok. Body: ' , body.
	self assert: (body indexOfSubCollection: '"version":"0.9.1"') > 0
		description: 'Health body missing version=0.9.1. Body: ' , body!

testHealthDoesNotRequireAuth
	"Health is intentionally auth-exempt for liveness probes."
	| resp |
	resp := self dispatch: 'GET /health HTTP/1.1' headers: Core.Dictionary new.
	self assert: (resp indexOfSubCollection: 'HTTP/1.1 200 OK') > 0
		description: 'Health should be auth-exempt. Status: ' , (self statusLineOf: resp)! !

!VWB.VWBridgeTest methodsFor: 'tests - auth'!

testWindowsRequiresAuth
	"Protected endpoints must reject requests without a valid Bearer token."
	| resp |
	resp := self dispatch: 'GET /windows HTTP/1.1' headers: Core.Dictionary new.
	self assert: (resp indexOfSubCollection: '401') > 0
		description: 'Unauthenticated /windows should return 401. Status: ' , (self statusLineOf: resp)!

testWindowsAcceptsValidAuth
	"With a valid Bearer token, /windows returns 200."
	| resp |
	resp := self dispatch: 'GET /windows HTTP/1.1'.
	self assert: (resp indexOfSubCollection: 'HTTP/1.1 200 OK') > 0
		description: '/windows with valid token should be 200. Status: ' , (self statusLineOf: resp)! !

!VWB.VWBridgeTest methodsFor: 'tests - eval'!

testEvalEvaluatesArithmetic
	"POST /eval evaluates Smalltalk and returns the printString of the result."
	| body |
	body := self bodyOf: (self dispatch: 'POST /eval HTTP/1.1' body: '2 + 3').
	self assert: (body indexOfSubCollection: '"ok":true') > 0
		description: 'eval response should be ok. Body: ' , body.
	self assert: (body indexOfSubCollection: '"5"') > 0
		description: 'eval (2+3) should yield 5. Body: ' , body!

testEvalReturnsErrorForBadCode
	"Unparseable Smalltalk surfaces a structured error, not a crash."
	| body |
	body := self bodyOf: (self dispatch: 'POST /eval HTTP/1.1' body: 'this is not smalltalk &&').
	self assert: ((body indexOfSubCollection: 'eval_failed') > 0
		or: [(body indexOfSubCollection: '"ok":false') > 0])
		description: 'Bad eval should surface a structured error. Body: ' , body! !

!VWB.VWBridgeTest methodsFor: 'tests - bug 2'!

testBug2DialogConfirmYesReturnsTrue
	"v0.8.12 fix: bridge-dismissed Dialog confirm: Yes must return true.
	 Was nil pre-v0.8.12 (Bug #2 Symptom A). Forks Dialog confirm: at user
	 priority, lets modal open, calls handler directly (avoids Bug #5
	 recursive dispatch), polls for fork completion, asserts captured return."
	| proc deadline ret |
	Root.Smalltalk at: #TEST_BUG2_YES_RET put: 'pending'.
	proc := [Root.Smalltalk at: #TEST_BUG2_YES_RET
		put: (Dialog confirm: 'TEST Bug#2 Yes - bridge dismiss')]
		forkAt: Processor userSchedulingPriority.
	(Delay forMilliseconds: 500) wait.
	bridge doRespondDialog: 'Yes'.
	deadline := Time millisecondClockValue + 5000.
	[(Root.Smalltalk at: #TEST_BUG2_YES_RET) = 'pending'
		and: [Time millisecondClockValue < deadline]]
		whileTrue: [(Delay forMilliseconds: 100) wait].
	ret := Root.Smalltalk at: #TEST_BUG2_YES_RET.
	self assert: ret == true description: 'Expected true, got: ' , ret printString!

testBug2DialogConfirmNoReturnsFalse
	"v0.8.12 fix: bridge-dismissed Dialog confirm: No must return false.
	 Both Yes and No bridge dismissals return nil from the framework
	 (Q3 in session-7 pre-probes). Override synthesizes accept/cancel."
	| proc deadline ret |
	Root.Smalltalk at: #TEST_BUG2_NO_RET put: 'pending'.
	proc := [Root.Smalltalk at: #TEST_BUG2_NO_RET
		put: (Dialog confirm: 'TEST Bug#2 No - bridge dismiss')]
		forkAt: Processor userSchedulingPriority.
	(Delay forMilliseconds: 500) wait.
	bridge doRespondDialog: 'No'.
	deadline := Time millisecondClockValue + 5000.
	[(Root.Smalltalk at: #TEST_BUG2_NO_RET) = 'pending'
		and: [Time millisecondClockValue < deadline]]
		whileTrue: [(Delay forMilliseconds: 100) wait].
	ret := Root.Smalltalk at: #TEST_BUG2_NO_RET.
	self assert: ret == false description: 'Expected false, got: ' , ret printString! !

!VWB.VWBridgeTest methodsFor: 'tests - logging'!

testLogWritesNDJSONToFile
	"v0.8.13: bridge log: writes a JSON-line to vw-bridge.log containing
	 ts, level, and msg fields. Marker uniqueness via millisecondClockValue
	 ensures we find OUR write, not some pre-existing line."
	| marker contents |
	marker := 'TEST_LOG_NDJSON_' , Time millisecondClockValue printString.
	bridge log: marker.
	contents := [bridge logFilePath asFilename readStream upToEnd]
		on: Error do: [:ex | ''].
	self assert: (contents indexOfSubCollection: marker startingAt: 1) > 0
		description: 'Marker not in log file. Tail: ' ,
			(contents copyFrom: ((contents size - 200) max: 1) to: contents size).
	self assert: (contents indexOfSubCollection: '"level":"info"' startingAt: 1) > 0
		description: 'Log file missing level:info field'.
	self assert: (contents indexOfSubCollection: '"ts":' startingAt: 1) > 0
		description: 'Log file missing ts field'.
	self assert: (contents indexOfSubCollection: '"msg":' startingAt: 1) > 0
		description: 'Log file missing msg field'!

testLogLevelDistinction
	"v0.8.13: logWarn: and logError: produce lines with distinguishable
	 level field values."
	| ts markerI markerW markerE contents |
	ts := Time millisecondClockValue printString.
	markerI := 'LEVEL_INFO_' , ts.
	markerW := 'LEVEL_WARN_' , ts.
	markerE := 'LEVEL_ERROR_' , ts.
	bridge log: markerI.
	bridge logWarn: markerW.
	bridge logError: markerE.
	contents := [bridge logFilePath asFilename readStream upToEnd]
		on: Error do: [:ex | ''].
	self assert: (contents indexOfSubCollection: markerI startingAt: 1) > 0
		description: 'Info marker missing'.
	self assert: (contents indexOfSubCollection: markerW startingAt: 1) > 0
		description: 'Warn marker missing'.
	self assert: (contents indexOfSubCollection: markerE startingAt: 1) > 0
		description: 'Error marker missing'.
	self assert: (contents indexOfSubCollection: '"level":"warn"' startingAt: 1) > 0
		description: 'Warn level field missing'.
	self assert: (contents indexOfSubCollection: '"level":"error"' startingAt: 1) > 0
		description: 'Error level field missing'!

testLogJsonLineWellFormed
	"v0.8.13: each NDJSON line starts with a JSON object header and ends
	 with a closing brace + LF. Sanity check that we are not emitting
	 truncated or malformed entries."
	| marker contents |
	marker := 'JSON_FORM_' , Time millisecondClockValue printString.
	bridge log: marker.
	contents := [bridge logFilePath asFilename readStream upToEnd]
		on: Error do: [:ex | ''].
	self assert: (contents indexOfSubCollection: marker startingAt: 1) > 0
		description: 'Marker missing in well-formed JSON test'.
	self assert: (contents indexOfSubCollection: '{"ts":' startingAt: 1) > 0
		description: 'No JSON object header found in log'.
	self assert: (contents lastIndexOf: $}) > 0
		description: 'Log file missing closing brace'! !

!VWB.VWBridgeTest methodsFor: 'tests - purge wedged'!

testPurgeWedgedDialogProcessesReturnsNonNegativeInteger
	"v0.8.11 purgeWedgedDialogProcesses contract: returns Integer >= 0.
	 Safe to call on an image with no wedged processes (returns 0).
	 Defensive design swallows all errors and returns 0 on Process class
	 missing, GC'd procs, partially-walked contexts, etc."
	| count |
	count := bridge purgeWedgedDialogProcesses.
	self assert: (count isKindOf: Core.Integer)
		description: 'purgeWedgedDialogProcesses should return Integer, got: ' , count class name asString.
	self assert: count >= 0
		description: 'purgeWedgedDialogProcesses should return non-negative count, got: ' , count printString!

testPurgeWedgedDialogProcessesIdempotentOnCleanImage
	"v0.8.11: repeated calls converge to 0. First call may return >0 if
	 pre-existing wedges exist from earlier session activity; second call
	 must be 0 because the first call already unwedged everything purgeable."
	| firstCount secondCount |
	firstCount := bridge purgeWedgedDialogProcesses.
	"brief settle in case the first purge spawned any cleanup forks"
	(Delay forMilliseconds: 100) wait.
	secondCount := bridge purgeWedgedDialogProcesses.
	self assert: secondCount = 0
		description: 'idempotency violated: first=' , firstCount printString ,
			' second=' , secondCount printString , ' (expected second=0)'!

testPurgeWedgedDialogProcessesUnwedgesActiveModalFork
	"Targeted v0.8.11 behavior test: forks Dialog confirm:, force-closes
	 its modal window to wedge the modal loop (Semaphore stays unsignaled
	 because closeAndUnschedule doesn't push a Destroy event), then directly
	 invokes purge - NOT through doRespondDialog: - to isolate purge's
	 effect. Asserts purge counts >= 1 AND that the fork unwedges cleanly
	 (Dialog confirm: returns true via the v0.8.12 SimpleDialog override
	 since we set accept value: true before close)."
	| proc deadline globalKey count modalCtrl ret |
	globalKey := #TEST_PURGE_TARGET_RET.
	Root.Smalltalk at: globalKey put: 'pending'.
	proc := [Root.Smalltalk at: globalKey
		put: (Dialog confirm: 'TEST purgeWedgedDialogProcesses target')]
		forkAt: Processor userSchedulingPriority.
	(Delay forMilliseconds: 500) wait.
	"Locate the modal directly (avoid bridge dispatch:) and force-close it.
	 closeAndUnschedule leaves the fork wedged on a Semaphore wait."
	modalCtrl := ScheduledControllers scheduledControllers detect: [:c |
		[c model isKindOf: SimpleDialog] on: Error do: [:e | false]
	] ifNone: [nil].
	self assert: modalCtrl notNil description: 'modal did not open within 500ms'.
	modalCtrl model accept value: true.
	modalCtrl closeAndUnschedule.
	"Directly invoke purge - must report at least 1 (our fork)."
	count := bridge purgeWedgedDialogProcesses.
	self assert: count >= 1
		description: 'purge should unwedge >= 1 process, got: ' , count printString.
	"Fork should now unwind. Dialog confirm: returns true via the v0.8.12
	 SimpleDialog>>choose:labels:values:default:for: override (accept=true)."
	deadline := Time millisecondClockValue + 5000.
	[(Root.Smalltalk at: globalKey) = 'pending'
		and: [Time millisecondClockValue < deadline]]
		whileTrue: [(Delay forMilliseconds: 100) wait].
	ret := Root.Smalltalk at: globalKey.
	self assert: ret == true
		description: 'fork did not unwedge to true; result: ' , ret printString! !

"Stage 2 cleanup: remove old top-level Root.Smalltalk.VWBridgeTest if present (idempotent - defensive guard ensures we only touch the OLD top-level class, never the new VWB.VWBridgeTest)"
[(Smalltalk at: #VWBridgeTest ifAbsent: [nil]) ifNotNil: [:cls | (cls environment == Root.Smalltalk) ifTrue: [cls removeFromSystem]]] on: Core.Error do: [:ex | nil]!

!VWB.VWBridgeTest methodsFor: 'config'!

testVwBridgeHomeOverrideTakesPriority
	"v0.9.2 Phase P P1: vwBridgeHomeOverride: takes priority over the
	 VW_BRIDGE_HOME env var. Cleared in ensure: block to keep the test
	 hermetic from the next test."
	[VWBridge vwBridgeHomeOverride: 'C:\test\override-wins'.
	 self assert: VWBridge vwBridgeHome = 'C:\test\override-wins'
		description: 'vwBridgeHome should return override when set']
		ensure: [VWBridge clearVwBridgeHomeOverride]!

testClearVwBridgeHomeOverrideRestoresEnvLookup
	"v0.9.2 Phase P P1: clearVwBridgeHomeOverride drops the override and
	 vwBridgeHome falls back to the env-var lookup path. Verified by
	 setting a clearly-fake value, clearing it, and asserting that
	 vwBridgeHome no longer returns the fake value (it returns the env
	 var, OR raises if env var is unset - both pass the deny: check)."
	| afterClear |
	[VWBridge vwBridgeHomeOverride: 'C:\test\should-be-cleared'.
	 self assert: VWBridge vwBridgeHome = 'C:\test\should-be-cleared'
		description: 'sanity check: override should be active'.
	 VWBridge clearVwBridgeHomeOverride.
	 afterClear := [VWBridge vwBridgeHome] on: Error do: [:ex | nil].
	 self deny: afterClear = 'C:\test\should-be-cleared'
		description: 'after clear, vwBridgeHome should not return the cleared override value']
		ensure: [VWBridge clearVwBridgeHomeOverride]!

testTokenFilePathDerivesFromVwBridgeHome
	"v0.9.2 Phase P P1: tokenFilePath returns vwBridgeHome with .token
	 appended via backslash. Hermetic via override seam."
	[VWBridge vwBridgeHomeOverride: 'C:\test\install'.
	 self assert: VWBridge tokenFilePath = 'C:\test\install\.token'
		description: 'tokenFilePath should be vwBridgeHome , backslash , .token']
		ensure: [VWBridge clearVwBridgeHomeOverride]!

testLogFilePathDerivesFromVwBridgeHome
	"v0.9.2 Phase P P1: logFilePath returns vwBridgeHome with vw-bridge.log
	 appended via backslash. Both class-side and instance-side return the
	 same path, confirming instance delegation works."
	[VWBridge vwBridgeHomeOverride: 'C:\test\install'.
	 self assert: VWBridge logFilePath = 'C:\test\install\vw-bridge.log'
		description: 'class-side logFilePath should be vwBridgeHome , backslash , vw-bridge.log'.
	 self assert: VWBridge singleton logFilePath = 'C:\test\install\vw-bridge.log'
		description: 'instance-side logFilePath should delegate to class-side']
		ensure: [VWBridge clearVwBridgeHomeOverride]!

testScreenshotHelperScriptPathDerivesFromVwBridgeHome
	"v0.9.2 Phase P P3: screenshotHelperScriptPath returns vwBridgeHome
	 with scripts/screenshot-helper.ps1 appended via backslash. Both
	 class-side and instance-side return the same path. P3 relocated the
	 helper from repo-root scripts/ to vwBridgeHome/scripts/ so a single
	 env var pins the entire install."
	[VWBridge vwBridgeHomeOverride: 'C:\test\install'.
	 self assert: VWBridge screenshotHelperScriptPath = 'C:\test\install\scripts\screenshot-helper.ps1'
		description: 'class-side screenshotHelperScriptPath should derive from override path'.
	 self assert: VWBridge singleton screenshotHelperScriptPath = 'C:\test\install\scripts\screenshot-helper.ps1'
		description: 'instance-side screenshotHelperScriptPath should delegate to class-side']
		ensure: [VWBridge clearVwBridgeHomeOverride]! !
