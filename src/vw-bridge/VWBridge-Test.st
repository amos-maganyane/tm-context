"=== VWBridgeTest - SUnit tests for the v0.8.8+ bridge dispatcher ==="
"Filed-in alongside VWBridge.st via:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn

 ============================================================================
 *** HOW TO RUN THESE TESTS ***
 ============================================================================
 PREFER A VW WORKSPACE for green results:

   "WORKSPACE - GREEN"
   VWBridgeTest suite run printString
   ((VWBridgeTest selector: #testHealthReturnsCurrentVersion) run) printString

   ""HTTP /eval - ALL RED (each test returns 400 recursive_dispatch, v0.8.8+)""
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

Root.Smalltalk defineClass: #VWBridgeTest
	superclass: #{TestCase}
	indexedType: #none
	private: false
	instanceVariableNames: 'bridge authHeaders'
	classInstanceVariableNames: ''
	imports: ''
	category: 'VW-TestBridge-Tests'!

!VWBridgeTest methodsFor: 'fixture'!

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
	"Everything after the headers/body separator (CR LF CR LF)."
	| crlf sep idx |
	crlf := String with: Core.Character cr with: Core.Character lf.
	sep := crlf , crlf.
	idx := aResponse indexOfSubCollection: sep.
	^idx > 0
		ifTrue: [aResponse copyFrom: idx + sep size to: aResponse size]
		ifFalse: ['']! !

!VWBridgeTest methodsFor: 'tests - health'!

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
	self assert: (body indexOfSubCollection: '"version":"0.8.12"') > 0
		description: 'Health body missing version=0.8.12. Body: ' , body!

testHealthDoesNotRequireAuth
	"Health is intentionally auth-exempt for liveness probes."
	| resp |
	resp := self dispatch: 'GET /health HTTP/1.1' headers: Core.Dictionary new.
	self assert: (resp indexOfSubCollection: 'HTTP/1.1 200 OK') > 0
		description: 'Health should be auth-exempt. Status: ' , (self statusLineOf: resp)! !

!VWBridgeTest methodsFor: 'tests - auth'!

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

!VWBridgeTest methodsFor: 'tests - eval'!

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

!VWBridgeTest methodsFor: 'tests - bug 2'!

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
