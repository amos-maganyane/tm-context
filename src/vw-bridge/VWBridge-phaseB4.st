"=== VW Widget Bridge Phase B+1 v0.8.5 -- correct /dialogs + /dialogs/respond ==="
"PREREQ:  VWBridge.st (v0.5), VWBridge-phaseA.st (v0.7), VWBridge-phaseB.st
          (v0.8.1), VWBridge-phaseB1.st (v0.8.2), VWBridge-phaseB2.st (v0.8.3),
          VWBridge-phaseB3.st (v0.8.4) must already be filed in.
          File this LAST. Restarts the bridge and rewrites .token.

 CHANGES: Three fixes rooted in v0.8.4 end-to-end test findings:

 (1) doListDialogs - now filters via scheduledControllers (live windows
     only) instead of SimpleDialog allInstances. v0.8.4 incorrectly
     reported stale (non-modal) SimpleDialog instances as 'dialogs',
     causing /dialogs/respond to target the wrong instance.

 (2) describeDialog: - handles ComposedText labels via #asString. The
     displayMessageString aspect's spec.label is a ComposedText, not a
     String. v0.8.4 tried widget.model.value which errored. v0.8.5
     extracts via spec.label asString (works for Text, ComposedText, and
     plain String alike).

 (3) doRespondDialog: - REWRITTEN. v0.8.4 routed through the /click
     dispatch path but the wedged modal loop never noticed the action
     fire. v0.8.5 directly:
       a. finds the live SimpleDialog ScheduledController
       b. sets model.accept value:true (Yes/OK) or model.cancel value:true
          (No/Cancel) to record the outcome
       c. calls target closeAndUnschedule to force window-close (bypasses
          the wedged modal loop entirely; modal exit happens when its
          loop next iterates - typically immediate via the OS close event)

 BUMPS /health version to 0.8.5.

 CASCADE-MODAL PATTERN: confirmation actions in MAS often pop a SECOND
 modal after dismissal of the first (e.g. clicking No on 'search may
 take a while' triggers a 'Search cancelled' notification with an OK
 button). The caller orchestrates: call /dialogs/respond, then /dialogs
 again, respond again, until /dialogs returns empty.

 NAMESPACE: Root.Smalltalk and Core.* qualified per the GBS image gotcha."!

!VWBridge methodsFor: 'dialogs'!

doListDialogs
	"v0.8.5: enumerate SimpleDialog instances that are LIVE (i.e. in
	 scheduledControllers - have an open window). Filters out stale
	 allInstances and the dialogSupplier singleton automatically since
	 those aren't in scheduledControllers."
	| err dialogs response sdClass mgr |
	err := self errorClass.
	sdClass := self globalNamed: #SimpleDialog.
	sdClass == nil ifTrue: [
		^'{"ok":false,"error":"no_simple_dialog_class","dialogs":[]}'].
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [
		^'{"ok":false,"error":"no_scheduled_controllers","dialogs":[]}'].
	dialogs := Core.OrderedCollection new.
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		([ctrl model class == sdClass] on: err do: [:ex | false]) ifTrue: [
			dialogs add: (self describeDialog: ctrl model)]].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'dialogs' put: dialogs.
	^self jsonFor: response!

describeDialog: aSimpleDialog
	"v0.8.5: extract message text from ComposedText/Text/String via #asString.
	 Returns Dictionary {id, message, buttons:[labels]}."
	| d err builder comps msg btnLabels msgWidget |
	err := self errorClass.
	d := Core.Dictionary new.
	d at: 'id' put: ([aSimpleDialog identityHash printString] on: err do: [:ex | nil]).
	builder := [aSimpleDialog builder] on: err do: [:ex | nil].
	msg := nil.
	btnLabels := Core.OrderedCollection new.
	builder ~~ nil ifTrue: [
		comps := [builder namedComponents] on: err do: [:ex | nil].
		comps ~~ nil ifTrue: [
			"Message text - spec.label may be String, Text, or ComposedText
			 (all respond to asString, returning the raw text)."
			msgWidget := [comps at: #displayMessageString ifAbsent: [nil]] on: err do: [:ex | nil].
			msgWidget ~~ nil ifTrue: [
				msg := [msgWidget spec label asString] on: err do: [:ex | nil]].
			"Button labels - iterate ActionButtonSpec widgets defensively."
			(comps respondsTo: #valuesDo:)
				ifTrue: [
					comps valuesDo: [:w |
						([w spec class name asString = 'ActionButtonSpec'] on: err do: [:ex | false])
							ifTrue: [
								btnLabels add: ([w spec label asString] on: err do: [:ex | nil])]]]
				ifFalse: [
					(comps respondsTo: #do:) ifTrue: [
						comps do: [:w |
							([w spec class name asString = 'ActionButtonSpec'] on: err do: [:ex | false])
								ifTrue: [
									btnLabels add: ([w spec label asString] on: err do: [:ex | nil])]]]]]].
	d at: 'message' put: msg.
	d at: 'buttons' put: btnLabels asArray.
	^d!

doRespondDialog: choice
	"v0.8.5: REWRITTEN. Runs on UI process (via onUIDo).
	 Finds the live SimpleDialog ScheduledController, records the outcome
	 via accept/cancel ValueHolders, then closeAndUnschedule.
	 closeAndUnschedule bypasses the wedged modal loop - the loop notices
	 the window-gone signal on its next iteration (typically immediate
	 because the OS-close event wakes it up)."
	| err choiceStr sdClass mgr target wantsAccept wantsCancel |
	err := self errorClass.
	sdClass := self globalNamed: #SimpleDialog.
	sdClass == nil ifTrue: [
		^'{"ok":false,"error":"no_simple_dialog_class"}'].
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [
		^'{"ok":false,"error":"no_scheduled_controllers"}'].
	target := [mgr scheduledControllers detect: [:c |
		[c model class == sdClass] on: err do: [:ex | false]
	] ifNone: [nil]] on: err do: [:ex | nil].
	target == nil ifTrue: [
		^'{"ok":false,"error":"no_live_dialog","hint":"Dialog useNativeDialogs may still be true - use POST /eval to toggle off"}'].
	choiceStr := choice asString.
	wantsAccept := (choiceStr = 'Yes') or: [(choiceStr = 'OK') or: [choiceStr = 'Accept']].
	wantsCancel := (choiceStr = 'No') or: [(choiceStr = 'Cancel') or: [choiceStr = 'Decline']].
	"Record outcome on the model's accept/cancel ValueHolders."
	wantsAccept ifTrue: [
		[target model accept value: true] on: err do: [:ex | nil]].
	wantsCancel ifTrue: [
		[target model cancel value: true] on: err do: [:ex | nil]].
	"Force close at the controller level - this wakes the modal loop."
	[target closeAndUnschedule] on: err do: [:ex |
		^'{"ok":false,"error":"close_failed","message":' , (self safeJsonFor: ex description) , '}'].
	^'{"ok":true,"choice":' , (self safeJsonFor: choiceStr) ,
		',"method":"closeAndUnschedule","recordedAccept":' , wantsAccept printString ,
		',"recordedCancel":' , wantsCancel printString , '}'! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"v0.8.5: REPLACES v0.8.4. Only change is /health version bump.
	 All routes preserved."
	| parts method path queryString authResp |
	authResp := self authError: requestLine headers: headers.
	authResp ~~ nil ifTrue: [^authResp].
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"bad_request"}'].
	method := parts at: 1.
	path := parts at: 2.
	queryString := ''.
	(path includes: $?) ifTrue: [
		| qi |
		qi := path indexOf: $?.
		queryString := path copyFrom: qi + 1 to: path size.
		path := path copyFrom: 1 to: qi - 1].
	method = 'GET' ifTrue: [
		path = '/health' ifTrue: [
			^self httpResponse: 200 type: 'application/json'
				body: '{"status":"ok","version":"0.8.5"}'].
		path = '/windows' ifTrue: [^self handleWindows].
		path = '/windows/tree' ifTrue: [^self handleTree].
		path = '/value' ifTrue: [^self handleGetValueQuery: queryString].
		path = '/menu' ifTrue: [^self handleMenuQuery: queryString].
		path = '/dialogs' ifTrue: [^self handleDialogsQuery].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'POST' ifTrue: [
		path = '/click' ifTrue: [^self handleClickBody: bodyString].
		path = '/type'  ifTrue: [^self handleTypeBody: bodyString].
		path = '/menu/click' ifTrue: [^self handleMenuClickBody: bodyString].
		path = '/eval' ifTrue: [^self handleEvalBody: bodyString].
		path = '/dialogs/respond' ifTrue: [^self handleDialogsRespondBody: bodyString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'PUT' ifTrue: [
		path = '/value' ifTrue: [^self handlePutValueQuery: queryString body: bodyString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'OPTIONS' ifTrue: [
		^self httpResponse: 200 type: 'text/plain' body: ''].
	^self httpResponse: 405 type: 'application/json'
		body: '{"error":"method_not_allowed","method":"' , method , '"}'! !

"=== Restart the bridge and rewrite .token for agent pickup ==="
| f tokenPath |
VWBridge stop.
VWBridge start.
tokenPath := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\.token'.
f := [tokenPath asFilename writeStream] on: Core.Error do: [:ex | nil].
f == nil
	ifTrue: [Transcript cr; show: 'WARN: could not write .token file (', tokenPath, ') - copy token manually from Transcript'; cr]
	ifFalse: [
		[f lineEndTransparent] on: Core.Error do: [:ex | nil].
		f nextPutAll: VWBridge singleton token.
		f close.
		Transcript cr; show: 'Token written to .token: '; show: VWBridge singleton token; cr]!
