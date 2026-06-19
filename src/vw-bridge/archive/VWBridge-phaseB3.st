"=== VW Widget Bridge Phase B+1 v0.8.4 -- /dialogs + /dialogs/respond + valuesDo: fix ==="
"PREREQ:  VWBridge.st (v0.5), VWBridge-phaseA.st (v0.7), VWBridge-phaseB.st
          (v0.8.1), VWBridge-phaseB1.st (v0.8.2), VWBridge-phaseB2.st (v0.8.3)
          must already be filed in. File this LAST. Restarts the bridge and
          rewrites .token.

 CHANGES: Three things, all rooted in this session's Phase B+1.B/C findings:

 (1) BUG FIX in resolveAspect: -- v0.7's valuesDo: iteration crashes with
     'Message not understood: #valuesDo:' on some VW Dictionary subtypes
     (notably WealthPublishedPundleVersionsTool's namedComponents). This
     blocks /click on ANY window when the problematic window comes first
     in scheduledControllers iteration. Fix: protect valuesDo: with
     respondsTo: check, fall back to do: (which on a Dictionary iterates
     values too).

 (2) NEW ENDPOINT GET /dialogs -- enumerate live SimpleDialog modals.
     Requires Dialog useNativeDialogs: false (otherwise the modal is a
     Win32 native dialog invisible to VW introspection).
     Response: {""ok"":true, ""dialogs"":[{""id"":""<hash>"",
                ""message"":""<displayMessageString value>"",
                ""buttons"":[""<labels>...""]}]}
     If native dialogs are still on, returns ""dialogs"":[] - dialog is
     up but VW can't see it.

 (3) NEW ENDPOINT POST /dialogs/respond -- click a button on the live modal.
     Body: {""choice"":""Yes""|""No""|""OK""|""Cancel""|""<aspect>""}
     Maps friendly names to button aspects (Yes->YesButton, etc.).
     Reuses the (now-fixed) /click dispatch path. Returns the same shape
     as /click: {""ok"":true,""aspect"":""...""...} or error.

 BUMPS /health version to 0.8.4.
 Re-defines dispatch:headers:body: to register the new routes.

 USAGE PATTERN (the full automation):
   1. Dialog useNativeDialogs: false   (via POST /eval, once per session)
   2. POST /click findID                (search action - opens confirm modal)
   3. (immediately) POST /dialogs/respond {""choice"":""No""}
                                        (dismisses modal, click action returns)

 NAMESPACE: Root.Smalltalk and Core.* qualified per the GBS image gotcha."!

!VWBridge methodsFor: 'interaction'!

resolveAspect: aspectName inWindowMatching: titleSubstring
	"v0.8.4: REPLACES v0.7's version. Adds defensive iteration over
	 namedComponents - some VW Dictionary subtypes don't respond to
	 valuesDo: and crashed the original. Falls back to do: (which on
	 a Dictionary iterates values too) or skips if neither works.
	 Locate {appModel, widgetWrapper} by aspect name.
	 titleSubstring nil = any window.
	 Returns Core.Array {app. wrapper. errorJSON}.
	 Must be called on the UI process."
	| mgr err found |
	err := self errorClass.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [
		^Core.Array with: nil with: nil with: '{"error":"no_scheduled_controllers"}'].
	found := nil.
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| app builder comps title titleOK wrapper aspectSym |
		found == nil ifTrue: [
			app := [ctrl model] on: err do: [:ex | nil].
			(app == nil or: [([app builder] on: err do: [:ex | nil]) == nil]) ifTrue: [
				app := [ctrl view application] on: err do: [:ex | nil]].
			builder := app == nil ifTrue: [nil] ifFalse: [[app builder] on: err do: [:ex | nil]].
			builder ~~ nil ifTrue: [
				title := [ctrl view label asString] on: err do: [:ex | ''].
				titleOK := titleSubstring == nil
					or: [(title indexOfSubCollection: titleSubstring startingAt: 1) > 0].
				titleOK ifTrue: [
					comps := [builder namedComponents] on: err do: [:ex | nil].
					comps ~~ nil ifTrue: [
						aspectSym := [aspectName asSymbol] on: err do: [:ex | nil].
						aspectSym ~~ nil ifTrue: [
							wrapper := [comps at: aspectSym ifAbsent: [nil]] on: err do: [:ex | nil]].
						wrapper == nil ifTrue: [
							wrapper := [comps at: aspectName ifAbsent: [nil]] on: err do: [:ex | nil]].
						wrapper == nil ifTrue: [
							"v0.8.4 defensive iteration"
							(comps respondsTo: #valuesDo:)
								ifTrue: [
									comps valuesDo: [:w |
										wrapper == nil ifTrue: [
											([w spec label asString = aspectName] on: err do: [:ex | false])
												ifTrue: [wrapper := w]]]]
								ifFalse: [
									(comps respondsTo: #do:) ifTrue: [
										comps do: [:w |
											wrapper == nil ifTrue: [
												([w spec label asString = aspectName] on: err do: [:ex | false])
													ifTrue: [wrapper := w]]]]]].
						wrapper ~~ nil ifTrue: [
							found := Core.Array with: app with: wrapper with: nil]]]]]].
	found ~~ nil ifTrue: [^found].
	^Core.Array with: nil with: nil
		with: '{"error":"widget_not_found","aspect":"' , aspectName , '"}'! !

!VWBridge methodsFor: 'dialogs'!

handleDialogsQuery
	"GET /dialogs - enumerate live SimpleDialog modals.
	 Returns 200 with {ok:true, dialogs:[...]}. Empty array if no live
	 modal OR if Dialog usesNativeDialogs is still true (native dialogs
	 are invisible to VW introspection)."
	| outcome |
	outcome := self onUIDo: [self doListDialogs].
	outcome == nil ifTrue: [outcome := '{"ok":false,"error":"ui_timeout","dialogs":[]}'].
	^self httpResponse: 200 type: 'application/json' body: outcome!

doListDialogs
	"Runs on UI process (via onUIDo). Returns JSON string.
	 Filters Dialog dialogSupplier singleton out of allInstances - we only
	 want live modals."
	| err supplier dialogs response sdClass |
	err := self errorClass.
	sdClass := self globalNamed: #SimpleDialog.
	sdClass == nil ifTrue: [
		^'{"ok":false,"error":"no_simple_dialog_class","dialogs":[]}'].
	supplier := [Dialog dialogSupplier] on: err do: [:ex | nil].
	dialogs := Core.OrderedCollection new.
	([sdClass allInstances] on: err do: [:ex | #()]) do: [:s |
		s == supplier ifFalse: [
			dialogs add: (self describeDialog: s)]].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'dialogs' put: dialogs.
	^self jsonFor: response!

describeDialog: aSimpleDialog
	"Build a Dictionary describing one live SimpleDialog: id, message text,
	 and button labels (extracted from ActionButtonSpec widgets in
	 namedComponents)."
	| d err builder comps msg btnLabels |
	err := self errorClass.
	d := Core.Dictionary new.
	d at: 'id' put: ([aSimpleDialog identityHash printString] on: err do: [:ex | nil]).
	builder := [aSimpleDialog builder] on: err do: [:ex | nil].
	msg := nil.
	btnLabels := Core.OrderedCollection new.
	builder ~~ nil ifTrue: [
		comps := [builder namedComponents] on: err do: [:ex | nil].
		comps ~~ nil ifTrue: [
			"Message text via displayMessageString aspect"
			| msgWidget |
			msgWidget := [comps at: #displayMessageString ifAbsent: [nil]] on: err do: [:ex | nil].
			msgWidget ~~ nil ifTrue: [
				msg := [msgWidget widget model value asString] on: err do: [:ex | nil]].
			"Button labels - same defensive iteration as resolveAspect:"
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

handleDialogsRespondBody: bodyString
	"POST /dialogs/respond - dispatch a button click on the live modal.
	 Body: {""choice"":""Yes""|""No""|""OK""|""Cancel""|""<aspect>""}
	 Maps friendly names to standard button aspects, or uses the choice
	 as the aspect name directly if not in the friendly-name map.
	 Reuses the (v0.8.4-fixed) /click dispatch path under the hood."
	| dict choice outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	choice := dict at: 'choice' ifAbsent: [nil].
	choice == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_choice","need":"choice: Yes|No|OK|Cancel|<aspect>"}'].
	outcome := self onUIDo: [self doRespondDialog: choice].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^((outcome indexOfSubCollection: '"ok":true' startingAt: 1) > 0)
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doRespondDialog: choice
	"Runs on UI process (via onUIDo). Returns JSON string.
	 Maps choice to button aspect (Yes->YesButton, No->NoButton,
	 OK->OkButton, Cancel->CancelButton), then dispatches via doClick:.
	 Other choice strings are passed through as the aspect name as-is."
	| aspectName err sdClass supplier live |
	err := self errorClass.
	sdClass := self globalNamed: #SimpleDialog.
	sdClass == nil ifTrue: [
		^'{"ok":false,"error":"no_simple_dialog_class"}'].
	supplier := [Dialog dialogSupplier] on: err do: [:ex | nil].
	live := [sdClass allInstances reject: [:s | s == supplier]] on: err do: [:ex | #()].
	live isEmpty ifTrue: [
		^'{"ok":false,"error":"no_live_dialog","hint":"Dialog useNativeDialogs may still be true - check via /eval"}'].
	"Map friendly choice names to button aspects."
	aspectName := choice asString.
	aspectName = 'Yes'    ifTrue: [aspectName := 'YesButton'].
	aspectName = 'No'     ifTrue: [aspectName := 'NoButton'].
	aspectName = 'OK'     ifTrue: [aspectName := 'OkButton'].
	aspectName = 'Cancel' ifTrue: [aspectName := 'CancelButton'].
	"Dispatch through the existing click path - resolveAspect: will find
	 the button in the SimpleDialog's namedComponents."
	^self doClick: aspectName inWindow: nil! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"v0.8.4: REPLACES v0.8.3. Adds GET /dialogs and POST /dialogs/respond.
	 Bumps /health version to 0.8.4."
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
				body: '{"status":"ok","version":"0.8.4"}'].
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
