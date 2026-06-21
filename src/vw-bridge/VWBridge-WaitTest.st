"=== VWBridgeWaitTest - SUnit tests for the v0.9.0+ /wait endpoint ==="
"Filed-in alongside VWBridge.st via:
   'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-WaitTest.st' asFilename fileIn

 ============================================================================
 *** HOW TO RUN THESE TESTS ***
 ============================================================================
 These tests INVOKE handleWait: DIRECTLY on the bridge singleton, bypassing
 the HTTP dispatcher entirely. This means:
   - They are SAFE to run via POST /eval (the Bug #5 re-entry guard is not
     triggered because handleWait: is called directly, not through
     bridge dispatch:).
   - They also work from a VW Workspace identically.

   [WORKSPACE / HTTP - both GREEN once handleWait: is implemented in B3.1]
   VWBridgeWaitTest suite run printString
   ((VWBridgeTest selector: #testWaitRejectsMissingKind) run) printString

 The 25 tests are designed RED first (B2.5-B2.9) - they will all fail with
 'handleWait: not implemented yet' until B3.1 lands. As each B3.x predicate
 evaluator is implemented, the matching 5-test block goes GREEN.
 ============================================================================

 Design notes:
 - Tests invoke handleWait: directly (no recursive HTTP dispatch).
 - setUp grabs the live singleton + builds auth headers.
 - tearDown calls bridge clearWaitOverrides to restore production behavior.
 - Fake clock + scripted snapshot helpers in 'fixture' category allow
   sub-second timeout/race tests without real Delays.
 - The fake clock auto-advances on every waitForMilliseconds: call by the
   same number of ms that the bridge requested - so a test running with
   timeoutMs=300 + intervalMs=100 will exit the loop after ~3 fake polls.
 - All scripted snapshots are OrderedCollections of dialog/window Dictionaries
   matching the shape that windowSummaries / describeDialog: would produce."

Smalltalk.VWB defineClass: #VWBridgeWaitTest
	superclass: #{TestCase}
	indexedType: #none
	private: false
	instanceVariableNames: 'bridge authHeaders'
	classInstanceVariableNames: ''
	imports: ''
	category: 'VWBridge-Tests'!

!VWB.VWBridgeWaitTest methodsFor: 'fixture'!

setUp
	"Capture singleton + build authorized headers for the current token."
	bridge := VWB.VWBridge singleton.
	authHeaders := Core.Dictionary new.
	authHeaders at: 'Authorization' put: 'Bearer ' , bridge token!

tearDown
	"Clear wait test seams to restore production behavior."
	bridge clearWaitOverrides!

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
	idx := aResponse indexOfSubCollection: sep startingAt: 1.
	^idx > 0
		ifTrue: [aResponse copyFrom: idx + sep size to: aResponse size]
		ifFalse: ['']!

waitResponseFor: aBodyString
	"Invoke handleWait: directly on the bridge singleton. Bypasses HTTP
	 router to avoid Bug #5 re-entry guard - safe to run via /eval.
	 Fails the calling test cleanly via assert:description: if handler not
	 implemented yet (RED until B3.1 lands; transitions to GREEN/expected-fail
	 once handleWait: exists)."
	(bridge respondsTo: #handleWait:) 
		ifFalse: [self assert: false 
			description: 'handleWait: not implemented yet (RED until B3.1 lands)'].
	^bridge handleWait: aBodyString!

bodyContains: aSubstring in: aResponse
	"Predicate: does the response body contain the substring?"
	^(aResponse indexOfSubCollection: aSubstring startingAt: 1) > 0!

windowSnapshotWith: aClassName title: aTitle
	"Build a single window-snapshot Dictionary (same shape as windowSummaries entries)."
	| d |
	d := Core.Dictionary new.
	d at: 'id' put: 'win-test'.
	d at: 'appClass' put: aClassName.
	d at: 'title' put: aTitle.
	d at: 'viewClass' put: 'ScheduledWindow'.
	d at: 'bounds' put: '0 @ 0 corner: 100 @ 100'.
	^d!

windowSnapshotWith: aClassName title: aTitle id: anId
	"Build a window-snapshot Dictionary with explicit id."
	| d |
	d := Core.Dictionary new.
	d at: 'id' put: anId.
	d at: 'appClass' put: aClassName.
	d at: 'title' put: aTitle.
	d at: 'viewClass' put: 'ScheduledWindow'.
	d at: 'bounds' put: '0 @ 0 corner: 100 @ 100'.
	^d!

dialogSnapshotWith: aMessage
	"Build a single dialog-snapshot Dictionary (same shape as describeDialog: entries)."
	| d |
	d := Core.Dictionary new.
	d at: 'id' put: '12345'.
	d at: 'class' put: 'SimpleDialog'.
	d at: 'message' put: aMessage.
	d at: 'buttons' put: (OrderedCollection with: 'OK').
	^d!

withFakeClockAndScriptedWindows: snapshotSeq do: aBlock
	"Set up fake clock (auto-advances on sleep) + scripted window snapshots.
	 Runs aBlock then clears overrides via tearDown.
	 snapshotSeq is an Array/OrderedCollection of OrderedCollection snapshots,
	 e.g. #( #() #() (winDict winDict) ) - 3 polls, first 2 empty then 2 windows."
	bridge clockOverride: 0.
	bridge sleepOverride: [:ms | bridge clockOverride: bridge waitClockMilliseconds + ms].
	bridge scriptedWindowSnapshots: snapshotSeq asOrderedCollection.
	^aBlock value!

withFakeClockAndScriptedDialogs: snapshotSeq do: aBlock
	"Set up fake clock + scripted dialog snapshots."
	bridge clockOverride: 0.
	bridge sleepOverride: [:ms | bridge clockOverride: bridge waitClockMilliseconds + ms].
	bridge scriptedDialogSnapshots: snapshotSeq asOrderedCollection.
	^aBlock value!

withFakeClockOnly: aBlock
	"Set up fake clock alone (for shared validation tests - no UI scripting needed)."
	bridge clockOverride: 0.
	bridge sleepOverride: [:ms | bridge clockOverride: bridge waitClockMilliseconds + ms].
	^aBlock value! !

!VWB.VWBridgeWaitTest methodsFor: 'tests - shared validation'!

testWaitRejectsMissingKind
	"POST /wait with empty body - expect 400 bad-request."
	| resp |
	resp := self waitResponseFor: '{}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Expected 400 for missing kind. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: 'bad-request' in: resp)
		description: 'Body should reference bad-request error'!

testWaitRejectsUnsupportedKindEvalTruthy
	"eval-truthy is explicitly excluded - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"eval-truthy"}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'eval-truthy must be rejected. Got: ' , (self statusLineOf: resp)!

testWaitRejectsCompoundPredicate
	"Compound predicates (kind=all or kind=any) excluded from MVP - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"all","predicates":[]}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Compound predicates must be rejected. Got: ' , (self statusLineOf: resp)!

testWaitRejectsInvalidTimeoutBounds
	"timeoutMs=0 is out of bounds [1, 60000] - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"window-appears","timeoutMs":0,"match":{"appClass":"X"}}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'timeoutMs=0 must be rejected. Got: ' , (self statusLineOf: resp)!

testWaitUsesDefaults
	"Omitting timeoutMs + intervalMs should use defaults 5000 + 100.
	 With empty scripted snapshots, this means ~50 polls then 408 timeout."
	| resp |
	self withFakeClockAndScriptedWindows: #() do: [
		resp := self waitResponseFor: '{"kind":"window-appears","match":{"appClass":"NoMatch"}}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 timeout after default 5000ms. Got: ' , (self statusLineOf: resp)! !

!VWB.VWBridgeWaitTest methodsFor: 'tests - window-appears'!

testWindowAppearsImmediateSuccess
	"First scripted snapshot has matching window - expect 200, polls=1."
	| resp snap |
	snap := self windowSnapshotWith: 'TestApp' title: 'Test Window'.
	self withFakeClockAndScriptedWindows: (Array with: (OrderedCollection with: snap)) do: [
		resp := self waitResponseFor: '{"kind":"window-appears","match":{"appClass":"TestApp"}}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 immediate match. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"satisfied":true' in: resp)
		description: 'Body should include satisfied:true'!

testWindowAppearsDelayedSuccess
	"First 2 snapshots empty, 3rd matches - expect 200, polls=3."
	| resp matchSnap snapSeq |
	matchSnap := self windowSnapshotWith: 'TestApp' title: 'Test'.
	snapSeq := Array 
		with: OrderedCollection new
		with: OrderedCollection new
		with: (OrderedCollection with: matchSnap).
	self withFakeClockAndScriptedWindows: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"window-appears","timeoutMs":1000,"intervalMs":100,"match":{"appClass":"TestApp"}}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 delayed match. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"polls":3' in: resp)
		description: 'Expected polls=3. Got: ' , (self bodyOf: resp)!

testWindowAppearsTimeout
	"No scripted snapshot matches before deadline - expect 408."
	| resp |
	self withFakeClockAndScriptedWindows: #() do: [
		resp := self waitResponseFor: '{"kind":"window-appears","timeoutMs":300,"intervalMs":100,"match":{"appClass":"NoMatch"}}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 timeout. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"error":"timeout"' in: resp)
		description: 'Body should reference timeout error'!

testWindowAppearsMalformedMissingMatch
	"Missing match field - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"window-appears"}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Missing match must be rejected. Got: ' , (self statusLineOf: resp)!

testWindowAppearsMultipleMatchesDeterministic
	"Snapshot has 3 matching windows - expect 200 with matchCount:3, deterministic first matched."
	| resp m1 m2 m3 |
	m1 := self windowSnapshotWith: 'TestApp' title: 'First' id: 'win-1'.
	m2 := self windowSnapshotWith: 'TestApp' title: 'Second' id: 'win-2'.
	m3 := self windowSnapshotWith: 'TestApp' title: 'Third' id: 'win-3'.
	self withFakeClockAndScriptedWindows: 
		(Array with: (OrderedCollection with: m1 with: m2 with: m3)) do: [
			resp := self waitResponseFor: '{"kind":"window-appears","match":{"appClass":"TestApp"}}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 multi-match. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"matchCount":3' in: resp)
		description: 'Expected matchCount=3. Got body: ' , (self bodyOf: resp).
	self assert: (self bodyContains: 'win-1' in: resp)
		description: 'First matched should be win-1 (deterministic order)'! !

!VWB.VWBridgeWaitTest methodsFor: 'tests - dialog-appears'!

testDialogAppearsImmediateSuccess
	"First scripted dialog snapshot contains substring match - expect 200."
	| resp snap |
	snap := self dialogSnapshotWith: 'Do you want to save changes?'.
	self withFakeClockAndScriptedDialogs: (Array with: (OrderedCollection with: snap)) do: [
		resp := self waitResponseFor: '{"kind":"dialog-appears","messageContains":"save changes"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 immediate dialog match. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"satisfied":true' in: resp)
		description: 'Body should include satisfied:true'!

testDialogAppearsDelayedSuccess
	"Dialog appears after several polls - expect 200, polls=3."
	| resp matchSnap snapSeq |
	matchSnap := self dialogSnapshotWith: 'Continue?'.
	snapSeq := Array 
		with: OrderedCollection new
		with: OrderedCollection new
		with: (OrderedCollection with: matchSnap).
	self withFakeClockAndScriptedDialogs: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"dialog-appears","timeoutMs":1000,"intervalMs":100,"messageContains":"Continue"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 delayed dialog. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"polls":3' in: resp)
		description: 'Expected polls=3'!

testDialogAppearsTimeout
	"No dialog matches before deadline - expect 408."
	| resp |
	self withFakeClockAndScriptedDialogs: #() do: [
		resp := self waitResponseFor: '{"kind":"dialog-appears","timeoutMs":300,"intervalMs":100,"messageContains":"NeverShows"}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 timeout. Got: ' , (self statusLineOf: resp)!

testDialogAppearsMalformedMissingMessageContains
	"Missing messageContains - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"dialog-appears"}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Missing messageContains must be rejected. Got: ' , (self statusLineOf: resp)!

testDialogAppearsSubstringMatchMultiline
	"Substring match should work on multi-line message text (uses 2-arg
	 indexOfSubCollection:startingAt: per image API constraint)."
	| resp snap multiline |
	multiline := 'Line one of message' , (String with: Core.Character lf) ,
	             'Line two with the keyword we seek' , (String with: Core.Character lf) ,
	             'Line three trailing'.
	snap := self dialogSnapshotWith: multiline.
	self withFakeClockAndScriptedDialogs: (Array with: (OrderedCollection with: snap)) do: [
		resp := self waitResponseFor: '{"kind":"dialog-appears","messageContains":"keyword we seek"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 multi-line match. Got: ' , (self statusLineOf: resp)! !

!VWB.VWBridgeWaitTest methodsFor: 'tests - window-closes'!

testWindowClosesAlreadyClosed
	"First snapshot doesnt contain windowId - succeed immediately."
	| resp |
	self withFakeClockAndScriptedWindows: 
		(Array with: OrderedCollection new) do: [
			resp := self waitResponseFor: '{"kind":"window-closes","windowId":"win-42"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 already-closed. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"alreadySatisfied":true' in: resp)
		description: 'Body should mark alreadySatisfied:true'!

testWindowClosesDelayedClose
	"First 2 snapshots contain windowId, 3rd doesnt - expect 200, polls=3."
	| resp present snapSeq |
	present := self windowSnapshotWith: 'TestApp' title: 'Test' id: 'win-42'.
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: OrderedCollection new.
	self withFakeClockAndScriptedWindows: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"window-closes","timeoutMs":1000,"intervalMs":100,"windowId":"win-42"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 delayed close. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"polls":3' in: resp)
		description: 'Expected polls=3'!

testWindowClosesTimeout
	"Window present in all snapshots - expect 408."
	| resp present snapSeq |
	present := self windowSnapshotWith: 'TestApp' title: 'Test' id: 'win-42'.
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present).
	self withFakeClockAndScriptedWindows: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"window-closes","timeoutMs":300,"intervalMs":100,"windowId":"win-42"}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 timeout. Got: ' , (self statusLineOf: resp)!

testWindowClosesMalformedMissingTarget
	"Neither windowId nor match provided - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"window-closes"}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Missing target must be rejected. Got: ' , (self statusLineOf: resp)!

testWindowClosesBoundaryRace
	"Fake clock reaches deadline on same iteration that final snapshot
	 removes the window. The final-check after the loop should catch it
	 and return 200, NOT 408."
	| resp present snapSeq |
	present := self windowSnapshotWith: 'TestApp' title: 'Test' id: 'win-42'.
	"timeoutMs=300, intervalMs=100 => 3 polls then deadline. Provide 4 snapshots
	 (3 with window present, 4th empty for the final check)."
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: OrderedCollection new.
	self withFakeClockAndScriptedWindows: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"window-closes","timeoutMs":300,"intervalMs":100,"windowId":"win-42"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Boundary race: final check should win, expect 200 not 408. Got: ' , (self statusLineOf: resp)! !

!VWB.VWBridgeWaitTest methodsFor: 'tests - dialog-closes'!

testDialogClosesAlreadyClosed
	"First snapshot has no matching dialog - succeed immediately."
	| resp |
	self withFakeClockAndScriptedDialogs: 
		(Array with: OrderedCollection new) do: [
			resp := self waitResponseFor: '{"kind":"dialog-closes","messageContains":"Continue?"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 already-closed. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"alreadySatisfied":true' in: resp)
		description: 'Body should mark alreadySatisfied:true'!

testDialogClosesDelayedClose
	"Dialog present in first 2 snapshots, absent in 3rd - expect 200, polls=3."
	| resp present snapSeq |
	present := self dialogSnapshotWith: 'Continue?'.
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: OrderedCollection new.
	self withFakeClockAndScriptedDialogs: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"dialog-closes","timeoutMs":1000,"intervalMs":100,"messageContains":"Continue"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Expected 200 delayed close. Got: ' , (self statusLineOf: resp).
	self assert: (self bodyContains: '"polls":3' in: resp)
		description: 'Expected polls=3'!

testDialogClosesTimeout
	"Dialog present in all snapshots - expect 408."
	| resp present snapSeq |
	present := self dialogSnapshotWith: 'StillOpen?'.
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present).
	self withFakeClockAndScriptedDialogs: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"dialog-closes","timeoutMs":300,"intervalMs":100,"messageContains":"StillOpen"}'].
	self assert: (self bodyContains: 'HTTP/1.1 408' in: resp)
		description: 'Expected 408 timeout. Got: ' , (self statusLineOf: resp)!

testDialogClosesMalformedMissingTarget
	"Missing messageContains - expect 400."
	| resp |
	resp := self waitResponseFor: '{"kind":"dialog-closes"}'.
	self assert: (self bodyContains: 'HTTP/1.1 400' in: resp)
		description: 'Missing messageContains must be rejected. Got: ' , (self statusLineOf: resp)!

testDialogClosesBoundaryRace
	"Fake clock reaches deadline on same iteration that final snapshot
	 removes the dialog. Final-check should win and return 200."
	| resp present snapSeq |
	present := self dialogSnapshotWith: 'StillOpen?'.
	snapSeq := Array 
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: (OrderedCollection with: present)
		with: OrderedCollection new.
	self withFakeClockAndScriptedDialogs: snapSeq do: [
		resp := self waitResponseFor: '{"kind":"dialog-closes","timeoutMs":300,"intervalMs":100,"messageContains":"StillOpen"}'].
	self assert: (self bodyContains: 'HTTP/1.1 200' in: resp)
		description: 'Boundary race: final check should win, expect 200 not 408. Got: ' , (self statusLineOf: resp)! !

"Stage 2 cleanup: remove old top-level Root.Smalltalk.VWBridgeWaitTest if present (idempotent - defensive guard ensures we only touch the OLD top-level class, never the new VWB.VWBridgeWaitTest)"
[(Smalltalk at: #VWBridgeWaitTest ifAbsent: [nil]) ifNotNil: [:cls | (cls environment == Root.Smalltalk) ifTrue: [cls removeFromSystem]]] on: Core.Error do: [:ex | nil]!
