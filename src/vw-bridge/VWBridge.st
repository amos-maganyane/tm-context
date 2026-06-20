"=== VW Widget Bridge v0.8.12 -- single-file consolidation of the 7-patch chain ==="
"INSTALL: Launcher then File Browser then File In.  Token written to .token.
 Bridge runs on 127.0.0.1:9876.  See knowledge/CONSOLIDATION-NOTES.md for
 the endpoint list, design notes, validation procedure, and migration plan."

Root.Smalltalk defineClass: #VWBridge
	superclass: #{Core.Object}
	indexedType: #none
	private: false
	instanceVariableNames: 'port listener process token '
	classInstanceVariableNames: 'singleton dispatchDepthByProcess dispatchDepthMutex '
	imports: ''
	category: 'VW-TestBridge'!

!VWBridge class methodsFor: 'starting'!

start
	"Start the bridge on the default port."
	^self startOn: 9876!

startOn: aPort
	| inst |
	self stop.
	inst := self new.
	inst port: aPort.
	inst generateToken.
	inst startListener.
	singleton := inst.
	inst log: 'VWBridge starting on 127.0.0.1:' , aPort printString.
	inst log: 'VWBridge token: ' , inst token.
	inst log: 'Try: curl http://127.0.0.1:' , aPort printString , '/health'.
	^inst!

stop
	singleton == nil ifFalse: [
		singleton stopListener.
		singleton log: 'VWBridge stopped'.
		singleton := nil].!

singleton
	^singleton! !

!VWBridge class methodsFor: 'dispatch tracking'!

incrementDispatchDepthFor: aProcess
	"Bug #5 Stage 2: atomically increment + return the per-process
	 dispatch depth. Lazy-inits the mutex + dictionary on first call so
	 a fresh class redefinition doesn't need an explicit reset.
	 Uses IdentityDictionary keyed by Process so two different processes
	 dispatching concurrently never collide."
	| depth |
	dispatchDepthMutex == nil ifTrue: [
		dispatchDepthMutex := Core.Semaphore forMutualExclusion].
	dispatchDepthByProcess == nil ifTrue: [
		dispatchDepthByProcess := Core.IdentityDictionary new].
	dispatchDepthMutex critical: [
		depth := dispatchDepthByProcess at: aProcess ifAbsent: [0].
		depth := depth + 1.
		dispatchDepthByProcess at: aProcess put: depth].
	^depth!

decrementDispatchDepthFor: aProcess
	"Bug #5 Stage 2: atomic decrement. Removes the entry when depth
	 reaches 0 so the dictionary doesn't leak entries for short-lived
	 per-connection processes."
	(dispatchDepthMutex == nil or: [dispatchDepthByProcess == nil]) ifTrue: [^self].
	dispatchDepthMutex critical: [
		| depth |
		depth := dispatchDepthByProcess at: aProcess ifAbsent: [0].
		depth <= 1
			ifTrue: [dispatchDepthByProcess removeKey: aProcess ifAbsent: [nil]]
			ifFalse: [dispatchDepthByProcess at: aProcess put: depth - 1]]! !

!VWBridge methodsFor: 'accessing'!

port
	^port!

port: anInteger
	port := anInteger!

token
	^token! !

!VWBridge methodsFor: 'helpers'!

globalNamed: aSymbol
	"Resolve a global by searching the Smalltalk namespace, then key
	 sub-namespaces. Spelled Root.Smalltalk because unqualified names
	 are ambiguous in this image (GBS + VisualAge compatibility)."
	| v |
	v := Root.Smalltalk at: aSymbol ifAbsent: [nil].
	v == nil ifTrue: [
		#(Core Kernel OS UI Graphics Tools Net) do: [:nsName |
			v == nil ifTrue: [
				| ns |
				ns := Root.Smalltalk at: nsName ifAbsent: [nil].
				ns == nil ifFalse: [v := ns at: aSymbol ifAbsent: [nil]]]]].
	^v!

errorClass
	^Core.Error!

log: aString
	| t |
	t := self globalNamed: #Transcript.
	t == nil ifFalse: [t cr; show: aString]!

beginsWithIgnoreCase: aString prefix: aPrefix
	"Case-insensitive prefix match. Returns true if aString starts with aPrefix."
	| s p |
	aString == nil ifTrue: [^false].
	s := aString asString.
	p := aPrefix asString.
	s size < p size ifTrue: [^false].
	^(s copyFrom: 1 to: p size) asLowercase = p asLowercase! !

!VWBridge methodsFor: 'initialization'!

generateToken
	| ms |
	ms := [Core.Time millisecondClockValue] on: self errorClass do: [:ex | 0].
	token := ms printString , '-' , self identityHash printString!

startListener
	| prio |
	prio := [(self globalNamed: #Processor) userBackgroundPriority]
		on: self errorClass do: [:ex | 4].
	process := [self listenerLoop] forkAt: prio.
	[process name: 'VWBridge listener'] on: self errorClass do: [:ex | nil]!

stopListener
	process == nil ifFalse: [
		[process terminate] on: self errorClass do: [:ex | nil].
		process := nil].
	listener == nil ifFalse: [
		[listener close] on: self errorClass do: [:ex | nil].
		listener := nil]! !

!VWBridge methodsFor: 'networking'!

listenerLoop
	"Forks serve: per connection at userBackgroundPriority so a wedged
	 request doesn't block the listener. Each connection runs on its
	 own process; /health and other reads stay responsive even when
	 some serve: is wedged behind a modal."
	| prio |
	listener := self createListener.
	listener == nil ifTrue: [^self].
	prio := [(self globalNamed: #Processor) userBackgroundPriority]
		on: self errorClass do: [:ex | 4].
	[true] whileTrue: [
		| client |
		client := [listener accept] on: self errorClass do: [:ex | nil].
		client == nil
			ifTrue: [(Core.Delay forMilliseconds: 200) wait]
			ifFalse: [
				"Per-connection fork. serve: closes the connection on success;
				 the on:do: closes it on exception too."
				[[self serve: client] on: self errorClass do: [:ex |
					[client close] on: self errorClass do: [:e2 | nil]]]
					forkAt: prio]]!

createListener
	"Create a TCP server socket. Feature-detected via SocketAccessor."
	| sa s |
	sa := self globalNamed: #SocketAccessor.
	sa == nil ifTrue: [
		self log: 'VWBridge: SocketAccessor not found - cannot listen'.
		^nil].
	(sa class canUnderstand: #newTCPserverAtPort:)
		ifFalse: [
			self log: 'VWBridge: SocketAccessor class>>newTCPserverAtPort: missing - socket layer needs porting'.
			^nil].
	s := [sa newTCPserverAtPort: port] on: self errorClass do: [:ex |
		self log: 'VWBridge: cannot bind port ' , port printString , ': ' , ex description.
		nil].
	s == nil ifTrue: [^nil].
	[(s respondsTo: #listenFor:) ifTrue: [s listenFor: 5]] on: self errorClass do: [:ex | nil].
	self log: 'VWBridge: listening via SocketAccessor'.
	^s!

streamFor: aConnection
	(aConnection respondsTo: #readAppendStream) ifTrue: [
		^[aConnection readAppendStream] on: self errorClass do: [:ex | nil]].
	(aConnection respondsTo: #readWriteStream) ifTrue: [
		^[aConnection readWriteStream] on: self errorClass do: [:ex | nil]].
	^nil!

flushStream: aStream
	(aStream respondsTo: #commit) ifTrue: [
		[aStream commit] on: self errorClass do: [:ex | nil].
		^self].
	[aStream flush] on: self errorClass do: [:ex | nil]!

serve: aConnection
	"Full HTTP read (request line + headers + body) + auth + dispatch.
	 Called on a per-connection forked process from listenerLoop."
	| stream requestLine headers bodyLen bodyString response err |
	err := self errorClass.
	stream := self streamFor: aConnection.
	stream == nil ifTrue: [
		[aConnection close] on: err do: [:ex | nil].
		^self].
	"Disable line-end conversion: VW external streams otherwise rewrite
	 CR/LF on the wire, which corrupts HTTP framing."
	[stream lineEndTransparent] on: err do: [:ex | nil].
	requestLine := [self readRequestLineFrom: stream] on: err do: [:ex | ''].
	requestLine isEmpty ifTrue: [
		response := self httpResponse: 400 type: 'text/plain' body: 'Bad Request'.
		[stream nextPutAll: response] on: err do: [:ex | nil].
		self flushStream: stream.
		[stream close] on: err do: [:ex | nil].
		[aConnection close] on: err do: [:ex | nil].
		^self].
	headers := [self readHeadersFrom: stream] on: err do: [:ex | Core.Dictionary new].
	bodyString := ''.
	bodyLen := headers at: 'content-length' ifAbsent: [nil].
	bodyLen ~~ nil ifTrue: [
		| n |
		n := [bodyLen asNumber] on: err do: [:ex | 0].
		n > 0 ifTrue: [
			bodyString := [stream next: n] on: err do: [:ex | ''].
			bodyString == nil ifTrue: [bodyString := '']]].
	response := [self dispatch: requestLine headers: headers body: bodyString]
		on: err do: [:ex |
			self httpResponse: 500 type: 'application/json'
				body: '{"error":"internal","message":"' , ex description , '"}'].
	[stream nextPutAll: response] on: err do: [:ex | nil].
	self flushStream: stream.
	[stream close] on: err do: [:ex | nil].
	[aConnection close] on: err do: [:ex | nil]!

readRequestLineFrom: aStream
	| line |
	line := aStream upTo: (Core.Character value: 10).
	[line isEmpty not and: [line last asInteger = 13]] whileTrue: [
		line := line copyFrom: 1 to: line size - 1].
	^line!

readHeadersFrom: aStream
	"Read HTTP headers until blank line. Lowercased keys."
	| headers line colonPos key value err |
	err := self errorClass.
	headers := Core.Dictionary new.
	[true] whileTrue: [
		line := [aStream upTo: (Core.Character value: 10)] on: err do: [:ex | nil].
		line == nil ifTrue: [^headers].
		[line isEmpty not and: [line last asInteger = 13]] whileTrue: [
			line := line copyFrom: 1 to: line size - 1].
		line isEmpty ifTrue: [^headers].
		colonPos := line indexOf: $:.
		colonPos > 0 ifTrue: [
			key := (line copyFrom: 1 to: colonPos - 1) asLowercase.
			value := line copyFrom: colonPos + 1 to: line size.
			[value isEmpty not and: [value first = (Core.Character value: 32)]] whileTrue: [
				value := value copyFrom: 2 to: value size].
			headers at: key put: value]].
	^headers! !

!VWBridge methodsFor: 'auth'!

authError: requestLine headers: headers
	"Returns nil if auth passes (or path is exempt). Otherwise returns an HTTP
	 response string to short-circuit the dispatcher.
	 Exempt paths: /health, /favicon.ico."
	| parts path tokenHeader provided |
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"bad_request"}'].
	path := parts at: 2.
	(path includes: $?) ifTrue: [path := path copyFrom: 1 to: (path indexOf: $?) - 1].
	(path = '/health' or: [path = '/favicon.ico']) ifTrue: [^nil].
	tokenHeader := headers at: 'authorization' ifAbsent: [nil].
	tokenHeader == nil ifTrue: [
		^self httpResponse: 401 type: 'application/json'
			body: '{"error":"unauthorized","message":"Missing Authorization header"}'].
	(self beginsWithIgnoreCase: tokenHeader prefix: 'Bearer ') ifFalse: [
		^self httpResponse: 401 type: 'application/json'
			body: '{"error":"unauthorized","message":"Expected Bearer <token>"}'].
	provided := tokenHeader copyFrom: 8 to: tokenHeader size.
	provided = token ifFalse: [
		^self httpResponse: 401 type: 'application/json'
			body: '{"error":"unauthorized","message":"Invalid token"}'].
	^nil! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"Main dispatcher (v0.8.12). Wraps doDispatch:headers:body: with a
	 Bug #5 Stage 2 per-process re-entry guard - if /eval bodies
	 synchronously call back into dispatch: on the same process, we
	 detect the recursion via per-process depth counter and fail fast
	 with 400 instead of wedging the listener and the UI. Combined
	 with the Stage 1 substring check in handleEvalBody:, this contains
	 the foot-gun.
	 All routes:
	   GET  /health /windows /windows/tree /value /menu /dialogs
	   POST /click /type /menu/click /eval /dialogs/respond
	   PUT  /value
	   OPTIONS *"
	| proc depth err |
	err := self errorClass.
	proc := [(self globalNamed: #Processor) activeProcess] on: err do: [:ex | nil].
	proc == nil ifTrue: [
		^self doDispatch: requestLine headers: headers body: bodyString].
	depth := self class incrementDispatchDepthFor: proc.
	depth > 1 ifTrue: [
		"Re-entry from /eval (or any same-process caller). Refuse so the
		 listener and the UI don't wedge. The decrement here balances
		 the increment above; no ensure: block needed since we return."
		self class decrementDispatchDepthFor: proc.
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"recursive_dispatch","depth":' , depth printString ,
				',"hint":"/eval cannot re-enter VWBridge dispatch: - see Bug #5. Call handler methods directly (e.g. VWBridge singleton handleWindows) or run tests from a VW workspace."}'].
	^[self doDispatch: requestLine headers: headers body: bodyString]
		ensure: [self class decrementDispatchDepthFor: proc]!

doDispatch: requestLine headers: headers body: bodyString
	"Actual dispatch logic (v0.8.12). Called by dispatch:headers:body:
	 after the Bug #5 Stage 2 re-entry guard passes."
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
				body: '{"status":"ok","version":"0.8.12"}'].
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
		body: '{"error":"method_not_allowed","method":"' , method , '"}'!

dispatch: requestLine
	"Compatibility shim: single-arg dispatch routes through the 3-arg
	 dispatcher with empty headers/body. Kept so any old workspace
	 code that calls VWBridge singleton dispatch: 'GET /health HTTP/1.1'
	 still works (auth will of course reject it for non-/health paths)."
	^self dispatch: requestLine headers: Core.Dictionary new body: ''!

split: aString on: aCharacter
	| parts current |
	parts := Core.OrderedCollection new.
	current := Core.WriteStream on: Core.String new.
	aString do: [:ch |
		ch = aCharacter
			ifTrue: [
				current contents isEmpty ifFalse: [
					parts add: current contents.
					current := Core.WriteStream on: Core.String new]]
			ifFalse: [current nextPut: ch]].
	current contents isEmpty ifFalse: [parts add: current contents].
	^parts! !

!VWBridge methodsFor: 'handlers'!

handleWindows
	| list |
	list := self onUIDo: [self windowSummaries].
	list == nil ifTrue: [list := Core.OrderedCollection new].
	^self httpResponse: 200 type: 'application/json' body: (self jsonFor: list)!

handleTree
	| list |
	list := self onUIDo: [self windowTrees].
	list == nil ifTrue: [list := Core.OrderedCollection new].
	^self httpResponse: 200 type: 'application/json' body: (self jsonFor: list)! !

!VWBridge methodsFor: 'widget walking'!

windowSummaries
	| result mgr err |
	err := self errorClass.
	result := Core.OrderedCollection new.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^result].
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| d view app |
		d := Core.Dictionary new.
		view := [ctrl view] on: err do: [:ex | nil].
		app := self applicationFor: ctrl.
		d at: 'title' put: ([view label asString] on: err do: [:ex | nil]).
		d at: 'viewClass' put: (view == nil ifTrue: [nil] ifFalse: [view class name asString]).
		d at: 'appClass' put: (app == nil ifTrue: [nil] ifFalse: [app class name asString]).
		d at: 'bounds' put: ([view displayBox printString] on: err do: [:ex | nil]).
		result add: d].
	^result!

windowTrees
	| result mgr err |
	err := self errorClass.
	result := Core.OrderedCollection new.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^result].
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| d view app builder widgets |
		d := Core.Dictionary new.
		view := [ctrl view] on: err do: [:ex | nil].
		app := self applicationFor: ctrl.
		d at: 'title' put: ([view label asString] on: err do: [:ex | nil]).
		d at: 'appClass' put: (app == nil ifTrue: [nil] ifFalse: [app class name asString]).
		widgets := Core.OrderedCollection new.
		builder := app == nil ifTrue: [nil] ifFalse: [[app builder] on: err do: [:ex | nil]].
		builder == nil ifFalse: [
			| comps |
			comps := [builder namedComponents] on: err do: [:ex | nil].
			comps == nil ifFalse: [
				comps keysAndValuesDo: [:aspect :wrapper |
					widgets add: (self describeWidget: wrapper aspect: aspect)]]].
		d at: 'widgets' put: widgets.
		result add: d].
	^result!

applicationFor: aController
	"Prefer the controller model; fall back to the window application
	 when the model has no builder."
	| app view err |
	err := self errorClass.
	app := [aController model] on: err do: [:ex | nil].
	(app == nil or: [([app builder] on: err do: [:ex | nil]) == nil]) ifTrue: [
		view := [aController view] on: err do: [:ex | nil].
		view == nil ifFalse: [
			| alt |
			alt := [view application] on: err do: [:ex | nil].
			alt == nil ifFalse: [app := alt]]].
	^app!

describeWidget: aWrapper aspect: anAspect
	| d err |
	err := self errorClass.
	d := Core.Dictionary new.
	d at: 'aspect' put: ([anAspect asString] on: err do: [:ex | '?']).
	d at: 'label' put: ([aWrapper spec label asString] on: err do: [:ex | nil]).
	d at: 'specClass' put: ([aWrapper spec class name asString] on: err do: [:ex | nil]).
	d at: 'widgetClass' put: ([aWrapper widget class name asString] on: err do: [:ex | nil]).
	d at: 'value' put: ([aWrapper widget model value printString] on: err do: [:ex | nil]).
	^d! !

!VWBridge methodsFor: 'interaction'!

resolveAspect: aspectName inWindowMatching: titleSubstring
	"Locate {appModel, widgetWrapper} by aspect name.
	 titleSubstring nil = any window.
	 Returns Core.Array {app. wrapper. errorJSON}. Exactly one of
	 {wrapper, errorJSON} is non-nil.
	 Must be called on the UI process.

	 Defensive valuesDo: iteration: some VW Dictionary subtypes
	 (notably WealthPublishedPundleVersionsTool's namedComponents)
	 don't implement #valuesDo: and crash with MNU. Fall back to do:
	 (which on a Dictionary iterates values too) or skip if neither
	 works. This blocks /click on ANY window when the problematic
	 window happens to come first in scheduledControllers iteration."
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
		with: '{"error":"widget_not_found","aspect":"' , aspectName , '"}'!

handleClickBody: bodyString
	"POST /click -- invokes the widget's spec action on the application."
	| dict aspect winTitle outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	aspect := dict at: 'aspect' ifAbsent: [nil].
	aspect == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_aspect"}'].
	winTitle := dict at: 'windowTitle' ifAbsent: [dict at: 'window' ifAbsent: [nil]].
	outcome := self onUIDo: [self doClick: aspect inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doClick: aspect inWindow: winTitle
	"Runs on UI process. Returns a JSON string.

	 Image-specific click strategy (probe-confirmed):
	   spec action returns nil here, so  app perform: spec action  is a
	   dead end. Buttons in this image use a PluggableAdaptor whose
	   setter block invokes the configured action callback when value:
	   is sent. Sending  wrapper widget model value: true  fires the
	   click. The same approach naturally selects list rows / tabs
	   whose model is a ValueHolder driven by the widget.

	 v0.8.7 (Bug #1 fix): RadioButtonSpec is handled specially because
	 several radios commonly share a single ValueHolder (e.g.
	 PartySearchView's 7 searchCriteriaType radios all share
	 #searchCriteriaType). Setting value: true would corrupt that
	 shared holder with a literal boolean instead of the radio's
	 selection symbol. For radios we use  model value: spec select
	 which writes the correct Symbol (e.g. #contractNumber, #id).
	 The method field in the response distinguishes which path was
	 taken (model_value_true vs model_value_spec_select)."
	| r w err spec model oldVal result clickValue method radioCls |
	err := self errorClass.
	r := self resolveAspect: aspect inWindowMatching: winTitle.
	(r at: 3) ~~ nil ifTrue: [^r at: 3].
	w := r at: 2.
	model := [w widget model] on: err do: [:ex | nil].
	model == nil ifTrue: [
		^'{"error":"no_model","aspect":"' , aspect , '"}'].
	oldVal := [model value] on: err do: [:ex | nil].
	spec := [w spec] on: err do: [:ex | nil].
	radioCls := self globalNamed: #RadioButtonSpec.
	(spec ~~ nil and: [radioCls ~~ nil and: [spec isKindOf: radioCls]])
		ifTrue: [
			clickValue := [spec select] on: err do: [:ex | true].
			method := 'model_value_spec_select']
		ifFalse: [
			clickValue := true.
			method := 'model_value_true'].
	result := [model value: clickValue. nil] on: err do: [:ex |
		'{"error":"click_failed","message":"' , ex description , '"}'].
	^result == nil
		ifTrue: ['{"ok":true,"aspect":"' , aspect , '","method":"' , method , '","oldValue":' , (self safeJsonFor: oldVal printString) , ',"newValue":' , (self safeJsonFor: clickValue printString) , '}']
		ifFalse: [result]!

handleTypeBody: bodyString
	"POST /type -- sets the widget's ValueHolder value."
	| dict aspect winTitle val outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	aspect := dict at: 'aspect' ifAbsent: [nil].
	val := dict at: 'value' ifAbsent: [dict at: 'text' ifAbsent: [nil]].
	(aspect == nil or: [val == nil]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_params","need":"aspect and value"}'].
	winTitle := dict at: 'windowTitle' ifAbsent: [dict at: 'window' ifAbsent: [nil]].
	outcome := self onUIDo: [self doType: aspect value: val inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doType: aspect value: val inWindow: winTitle
	"Runs on UI process. Returns a JSON string."
	| r w err model result |
	err := self errorClass.
	r := self resolveAspect: aspect inWindowMatching: winTitle.
	(r at: 3) ~~ nil ifTrue: [^r at: 3].
	w := r at: 2.
	model := [w widget model] on: err do: [:ex | nil].
	model == nil ifTrue: [
		^'{"error":"no_model","aspect":"' , aspect , '"}'].
	result := [model value: val. nil] on: err do: [:ex |
		'{"error":"set_failed","message":"' , ex description , '"}'].
	^result == nil
		ifTrue: ['{"ok":true,"aspect":"' , aspect , '","value":' , (self safeJsonFor: val) , '}']
		ifFalse: [result]!

handleGetValueQuery: queryString
	"GET /value?aspect=X[&windowTitle=Y]"
	| aspect winTitle outcome |
	aspect := self queryParam: 'aspect' from: queryString.
	winTitle := self queryParam: 'windowTitle' from: queryString.
	aspect == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_aspect"}'].
	outcome := self onUIDo: [self doGetValue: aspect inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doGetValue: aspect inWindow: winTitle
	"Runs on UI process. Returns a JSON string."
	| r w err model val |
	err := self errorClass.
	r := self resolveAspect: aspect inWindowMatching: winTitle.
	(r at: 3) ~~ nil ifTrue: [^r at: 3].
	w := r at: 2.
	model := [w widget model] on: err do: [:ex | nil].
	model == nil ifTrue: [
		^'{"error":"no_model","aspect":"' , aspect , '"}'].
	val := [model value] on: err do: [:ex | nil].
	^'{"ok":true,"aspect":"' , aspect , '","value":' , (self safeJsonFor: val) , '}'!

handlePutValueQuery: queryString body: bodyString
	"PUT /value?aspect=X[&windowTitle=Y]  body: {""value"":...}
	 Alternative to POST /type. Reuses the type machinery."
	| aspect winTitle dict val outcome |
	aspect := self queryParam: 'aspect' from: queryString.
	winTitle := self queryParam: 'windowTitle' from: queryString.
	dict := self jsonParseFlat: bodyString.
	val := dict == nil ifTrue: [nil] ifFalse: [dict at: 'value' ifAbsent: [nil]].
	(aspect == nil or: [val == nil]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_params","need":"aspect (query) and value (body)"}'].
	outcome := self onUIDo: [self doType: aspect value: val inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^(outcome beginsWith: '{"ok":')
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

queryParam: paramName from: queryString
	"Extract a query parameter (case-insensitive name) from a URL query string.
	 Returns the URL-decoded value, or nil if missing."
	| pairs target |
	queryString isEmpty ifTrue: [^nil].
	target := paramName asLowercase.
	pairs := self split: queryString on: $&.
	pairs do: [:pair |
		| eq key value |
		eq := pair indexOf: $=.
		eq > 0 ifTrue: [
			key := (pair copyFrom: 1 to: eq - 1) asLowercase.
			key = target ifTrue: [
				value := pair copyFrom: eq + 1 to: pair size.
				^self urlDecode: value]]].
	^nil!

urlDecode: aString
	"Tiny URL decoder: + -> space, %HH -> char(HH)."
	| out i ch len err |
	err := self errorClass.
	out := Core.WriteStream on: Core.String new.
	i := 1.
	len := aString size.
	[i <= len] whileTrue: [
		ch := aString at: i.
		ch = $+
			ifTrue: [out nextPut: (Core.Character value: 32). i := i + 1]
			ifFalse: [
				(ch = $% and: [i + 2 <= len])
					ifTrue: [
						| hex byte |
						hex := aString copyFrom: i + 1 to: i + 2.
						byte := [Core.Integer readFrom: (Core.ReadStream on: hex) base: 16]
							on: err do: [:ex | 32].
						out nextPut: (Core.Character value: byte).
						i := i + 3]
					ifFalse: [
						out nextPut: ch.
						i := i + 1]]].
	^out contents! !

!VWBridge methodsFor: 'menu helpers'!

extractLabelText: anObject
	"Extract label text from a String or wrapper (LabelWithAccessor,
	 ComposedText, Text etc).
	 IMPORTANT: LabelWithAccessor inherits Object>>displayString which
	 returns printString - so displayString/text/string give us the
	 wrapper's full description, NOT the wrapped label. Diagnostic-
	 confirmed: lbl displayString returns 'LabelWithAccessor for
	 ''Party & Contract''' (the printString) - a String that passes
	 isString but is the wrong value.
	 Strategy: parse the printString FIRST (works for the standard
	 '... for ''X''' / '... ''X''' wrapper printString conventions),
	 fall back to accessor chain only if no quoted segment is found
	 (covers ComposedText/Text via #string, plain wrappers, and Symbols).
	 Uses (Core.Character value: 39) for the single-quote char because
	 $' is unreliable in chunk file-in.
	 v0.8.10 (Bug #4b full fix): replaced indexOf:startingAt: with
	 nextIndexOf:from:to: - this VW image does NOT implement
	 indexOf:startingAt: on String (probe-confirmed). The latent MNU
	 was never triggered in production because menu items in this image
	 have plain String labels (the printString PRIMARY path was only
	 hit during Bug #4b view-tree walk against LabelWithAccessor)."
	| err txt qch p1 p2 |
	err := self errorClass.
	anObject == nil ifTrue: [^''].
	anObject isString ifTrue: [^anObject].
	"PRIMARY: parse the printString for the first ''X'' quoted segment."
	txt := [anObject printString] on: err do: [:ex | ''].
	qch := Core.Character value: 39.
	p1 := txt indexOf: qch.
	p1 > 0 ifTrue: [
		p2 := [txt nextIndexOf: qch from: p1 + 1 to: txt size] on: err do: [:ex | 0].
		p2 > p1 ifTrue: [^txt copyFrom: p1 + 1 to: p2 - 1]].
	"FALLBACK: only if printString had no quoted segment.
	 result ~= txt guards against returning the same garbage. #string is
	 listed first because ComposedText answers its raw text to #string but
	 not to #displayString (which returns the class-name placeholder)."
	#(string displayString text) do: [:sel |
		(anObject respondsTo: sel) ifTrue: [
			| result |
			result := [anObject perform: sel] on: err do: [:ex | nil].
			(result ~~ nil and: [result isString and: [result ~= txt]])
				ifTrue: [^result]]].
	^txt!

menuItemsOf: aMenu
	"Return the items of a Menu, or nil if not enumerable.
	 VW Menu does NOT respond to #items (diagnostic-confirmed) - the
	 correct selector is #menuItems. Tries menuItems/items/components
	 in order so the helper survives future API drift."
	| err result |
	err := self errorClass.
	aMenu == nil ifTrue: [^nil].
	#(menuItems items components) do: [:sel |
		(aMenu respondsTo: sel) ifTrue: [
			result := [aMenu perform: sel] on: err do: [:ex | nil].
			result ~~ nil ifTrue: [^result]]].
	^nil!

submenuOf: aMenuItem
	"Return the submenu Menu of a MenuItem, or nil if none.
	 Tries submenu/subMenu/menu in order - submenu is the standard VW
	 accessor but kept tolerant for variant Menu item classes."
	| err result |
	err := self errorClass.
	aMenuItem == nil ifTrue: [^nil].
	#(submenu subMenu menu) do: [:sel |
		(aMenuItem respondsTo: sel) ifTrue: [
			result := [aMenuItem perform: sel] on: err do: [:ex | nil].
			result ~~ nil ifTrue: [^result]]].
	^nil!

get: aSelector or: ivarName from: anObject
	"Try the public accessor first; fall back to instVarNamed: if absent or
	 if the accessor returns nil. Defensive against VW class evolution."
	| err result |
	err := self errorClass.
	anObject == nil ifTrue: [^nil].
	(anObject respondsTo: aSelector) ifTrue: [
		result := [anObject perform: aSelector] on: err do: [:ex | nil].
		result ~~ nil ifTrue: [^result]].
	ivarName == nil ifTrue: [^nil].
	^[anObject instVarNamed: ivarName] on: err do: [:ex | nil]!

findMenuBarInWindowMatching: titleSubstring
	"Walk ScheduledControllers; return the menuBar of the first window
	 whose label contains titleSubstring. nil substring matches the first
	 window that has a menuBar. Must run on UI process."
	| mgr err matched |
	err := self errorClass.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^nil].
	matched := nil.
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| view title titleOK mb |
		matched == nil ifTrue: [
			view := [ctrl view] on: err do: [:ex | nil].
			view ~~ nil ifTrue: [
				title := [view label asString] on: err do: [:ex | ''].
				titleOK := titleSubstring == nil
					or: [(title indexOfSubCollection: titleSubstring startingAt: 1) > 0].
				titleOK ifTrue: [
					mb := (view respondsTo: #menuBar)
						ifTrue: [[view menuBar] on: err do: [:ex | nil]]
						ifFalse: [nil].
					mb ~~ nil ifTrue: [matched := mb]]]]].
	^matched! !

!VWBridge methodsFor: 'window tracking'!

controllerSet
	"Snapshot the currently-scheduled controllers as an IdentitySet.
	 Used by action endpoints to diff window changes before vs after
	 the action - so test runners know what windows the click opened
	 or closed without having to poll /windows separately."
	| mgr err set |
	err := self errorClass.
	set := Core.IdentitySet new.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^set].
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:c | set add: c].
	^set!

describeControllers: aCollection
	"Describe each controller as a Dictionary with title / appClass /
	 viewClass / bounds - same shape as /windows entries so callers can
	 reuse their parsing."
	| err result |
	err := self errorClass.
	result := Core.OrderedCollection new.
	aCollection do: [:ctrl |
		| d view app |
		d := Core.Dictionary new.
		view := [ctrl view] on: err do: [:ex | nil].
		app := self applicationFor: ctrl.
		d at: 'title' put: ([view label asString] on: err do: [:ex | nil]).
		d at: 'appClass' put: (app == nil ifTrue: [nil] ifFalse: [app class name asString]).
		d at: 'viewClass' put: (view == nil ifTrue: [nil] ifFalse: [view class name asString]).
		d at: 'bounds' put: ([view displayBox printString] on: err do: [:ex | nil]).
		result add: d].
	^result!

windowDiffBefore: beforeSet after: afterSet
	"Compare two controller snapshots; return Dictionary
	 { opened: [...], closed: [...] } - each list is full controller
	 descriptions, ready to embed in a JSON response."
	| opened closed d |
	opened := Core.OrderedCollection new.
	afterSet do: [:c | (beforeSet includes: c) ifFalse: [opened add: c]].
	closed := Core.OrderedCollection new.
	beforeSet do: [:c | (afterSet includes: c) ifFalse: [closed add: c]].
	d := Core.Dictionary new.
	d at: 'opened' put: (self describeControllers: opened).
	d at: 'closed' put: (self describeControllers: closed).
	^d! !

!VWBridge methodsFor: 'menu trees'!

menuTreeForMenuBar: aMenuBar
	"Build an OrderedCollection of Dictionaries describing each top-level
	 menu and its items recursively.
	 Primary source: menuBar.menuChannel.menuItems - the abstract Menu held by
	 the menuBar, whose entries are MenuItem objects with proper String
	 labels (and populated submenus when available).
	 Fallback: per-button menuHolder (used only if menuChannel is empty).
	 Uses self menuItemsOf: / self submenuOf: helpers (VW Menu does not
	 respond to #items - the right selector is #menuItems)."
	| err buttons channel channelItems result |
	err := self errorClass.
	result := Core.OrderedCollection new.
	channel := self get: #menuChannel or: 'menuChannel' from: aMenuBar.
	channelItems := self menuItemsOf: channel.
	(channelItems ~~ nil and: [channelItems isEmpty not]) ifTrue: [
		channelItems doWithIndex: [:item :i |
			| d label submenu subItems itemsCol |
			d := Core.Dictionary new.
			label := self extractLabelText: ([item label] on: err do: [:ex | nil]).
			submenu := self submenuOf: item.
			subItems := self menuItemsOf: submenu.
			itemsCol := Core.OrderedCollection new.
			subItems ~~ nil ifTrue: [
				subItems doWithIndex: [:sub :j |
					itemsCol add: (self menuItemTreeForItem: sub index: j depth: 1)]].
			d at: 'index' put: i.
			d at: 'label' put: label.
			d at: 'items' put: itemsCol.
			d at: 'source' put: 'menuChannel'.
			result add: d].
		^result].
	"Fallback path."
	buttons := self get: #menuButtons or: 'menuButtons' from: aMenuBar.
	buttons == nil ifTrue: [^result].
	buttons doWithIndex: [:btn :i |
		| d label menuHolder items itemsCol |
		d := Core.Dictionary new.
		label := self extractLabelText: ([btn label] on: err do: [:ex | nil]).
		menuHolder := self get: #menuHolder or: nil from: btn.
		items := self menuItemsOf: menuHolder.
		itemsCol := Core.OrderedCollection new.
		items ~~ nil ifTrue: [
			items doWithIndex: [:item :j |
				itemsCol add: (self menuItemTreeForItem: item index: j depth: 1)]].
		d at: 'index' put: i.
		d at: 'label' put: label.
		d at: 'items' put: itemsCol.
		d at: 'source' put: 'menuHolder'.
		result add: d].
	^result!

menuItemTreeForItem: anItem index: anIndex depth: aDepth
	"Build a Dictionary describing one MenuItem - label + value (the
	 perform: selector, nil for separators / submenu-openers) + recursively
	 the items of its submenu (if any). Depth-capped at 8.
	 Uses self submenuOf: / self menuItemsOf: helpers since VW Menu does
	 not respond to #items."
	| err d label value submenu items itemsCol |
	err := self errorClass.
	d := Core.Dictionary new.
	label := self extractLabelText: ([anItem label] on: err do: [:ex | nil]).
	value := [anItem value] on: err do: [:ex | nil].
	submenu := self submenuOf: anItem.
	items := self menuItemsOf: submenu.
	itemsCol := Core.OrderedCollection new.
	(items ~~ nil and: [aDepth < 8]) ifTrue: [
		items doWithIndex: [:sub :j |
			itemsCol add: (self menuItemTreeForItem: sub index: j depth: aDepth + 1)]].
	d at: 'index' put: anIndex.
	d at: 'label' put: label.
	d at: 'value' put: (value == nil ifTrue: [nil] ifFalse: [value asString]).
	d at: 'hasSubmenu' put: submenu ~~ nil.
	d at: 'items' put: itemsCol.
	^d! !

!VWBridge methodsFor: 'menu dispatching'!

handleMenuQuery: queryString
	"GET /menu?windowTitle=X (windowTitle optional)."
	| winTitle outcome |
	winTitle := self queryParam: 'windowTitle' from: queryString.
	outcome := self onUIDo: [self doMenuList: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	"Substring check (not beginsWith:) because jsonFor: on a Dictionary
	 does NOT guarantee key order - '{""ok"":true,...' might be serialized
	 as '{""menus"":[...],""ok"":true}' and beginsWith: would falsely 400."
	^((outcome indexOfSubCollection: '"ok":true' startingAt: 1) > 0)
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doMenuList: winTitle
	"Runs on UI process. Returns a JSON string."
	| menuBar tree response err |
	err := self errorClass.
	menuBar := self findMenuBarInWindowMatching: winTitle.
	menuBar == nil ifTrue: [^'{"error":"window_or_menubar_not_found"}'].
	tree := [self menuTreeForMenuBar: menuBar] on: err do: [:ex |
		^'{"error":"menu_walk_failed","message":"' , ex description , '"}'].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'menus' put: tree.
	^self jsonFor: response!

handleMenuClickBody: bodyString
	"POST /menu/click  body: {""path"":[...,""leaf""],""windowTitle"":""X""}"
	| dict pathArray winTitle outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	pathArray := dict at: 'path' ifAbsent: [nil].
	(pathArray == nil
		or: [(pathArray isKindOf: Core.Collection) not
			or: [pathArray isEmpty]]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_or_empty_path"}'].
	pathArray size < 2 ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"path_too_short","message":"top-level menu items just open submenus; need leaf with value"}'].
	winTitle := dict at: 'windowTitle' ifAbsent: [dict at: 'window' ifAbsent: [nil]].
	outcome := self onUIDo: [self doMenuClickPath: pathArray inWindow: winTitle].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^((outcome indexOfSubCollection: '"ok":true' startingAt: 1) > 0)
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doMenuClickPath: pathArray inWindow: winTitle
	"Runs on UI process. Returns a JSON string.
	 Dispatches based on the leaf MenuItem's value type:
	   - Symbol         : performer perform: symbol  (classic MVC menu action)
	   - BlockClosure   : leafValue value             (MAS menus mostly use this -
	                      block closures built by Menu>>addItemLabel:withOperation:
	                      that capture the action via lexical scope)
	   - anything else  : reject with unsupported_leaf_value
	 Snapshots scheduled controllers before + after the dispatch so the
	 response can tell the caller which windows the click opened/closed."
	| menuBar walked leafItem performer leafValue err result response dispatch blockCls
	  beforeSet afterSet windowsInfo |
	err := self errorClass.
	menuBar := self findMenuBarInWindowMatching: winTitle.
	menuBar == nil ifTrue: [^'{"error":"window_or_menubar_not_found"}'].
	walked := self walkMenuPath: pathArray inMenuBar: menuBar.
	(walked at: 3) ~~ nil ifTrue: [^walked at: 3].
	leafItem := walked at: 1.
	performer := walked at: 2.
	leafValue := [leafItem value] on: err do: [:ex | nil].
	leafValue == nil ifTrue: [
		^'{"error":"leaf_has_no_value","path_label":' , (self jsonFor: pathArray last) , '}'].
	dispatch := nil.
	leafValue isSymbol ifTrue: [dispatch := 'perform'].
	dispatch == nil ifTrue: [
		blockCls := self globalNamed: #BlockClosure.
		(blockCls ~~ nil and: [leafValue isKindOf: blockCls])
			ifTrue: [dispatch := 'block']].
	dispatch == nil ifTrue: [
		^'{"error":"unsupported_leaf_value","class":"' , leafValue class name asString ,
			'","value":' , (self jsonFor: leafValue printString) , '}'].
	beforeSet := self controllerSet.
	result := dispatch = 'perform'
		ifTrue: [
			[performer perform: leafValue. nil] on: err do: [:ex |
				'{"error":"perform_failed","selector":' , (self jsonFor: leafValue asString) ,
					',"message":' , (self jsonFor: ex description) , '}']]
		ifFalse: [
			[leafValue value. nil] on: err do: [:ex |
				'{"error":"block_eval_failed","message":' , (self jsonFor: ex description) , '}']].
	result ~~ nil ifTrue: [^result].
	afterSet := self controllerSet.
	windowsInfo := self windowDiffBefore: beforeSet after: afterSet.
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'path' put: pathArray asArray.
	response at: 'dispatch' put: dispatch.
	response at: 'leafValue' put: leafValue printString.
	response at: 'performer' put: performer class name asString.
	response at: 'windows' put: windowsInfo.
	^self jsonFor: response!

walkMenuPath: pathArray inMenuBar: aMenuBar
	"Walk pathArray (Collection of Strings) through menuBar.menuChannel.menuItems
	 recursively. Each segment matches an item by label (against
	 extractLabelText:), then descends via self submenuOf: -> menuItemsOf:.
	 Returns Core.Array {leafItem, performer, errorJSON}. Exactly one of
	 {leafItem+performer, errorJSON} is non-nil.
	 Uses self menuItemsOf: / self submenuOf: helpers since VW Menu does
	 not respond to #items."
	| err performer channel currentMenu currentItem i seg items |
	err := self errorClass.
	performer := self get: #performer or: 'performer' from: aMenuBar.
	performer == nil ifTrue: [
		^Core.Array with: nil with: nil with: '{"error":"no_performer"}'].
	channel := self get: #menuChannel or: 'menuChannel' from: aMenuBar.
	channel == nil ifTrue: [
		^Core.Array with: nil with: nil with: '{"error":"no_menu_channel"}'].
	currentMenu := channel.
	currentItem := nil.
	i := 1.
	[i <= pathArray size] whileTrue: [
		currentMenu == nil ifTrue: [
			^Core.Array with: nil with: nil with:
				('{"error":"no_submenu","at_segment":' , (i - 1) printString , '}')].
		seg := pathArray at: i.
		currentItem := nil.
		items := self menuItemsOf: currentMenu.
		items ~~ nil ifTrue: [
			items do: [:item |
				| label |
				currentItem == nil ifTrue: [
					label := self extractLabelText: ([item label] on: err do: [:ex | nil]).
					label = seg ifTrue: [currentItem := item]]]].
		currentItem == nil ifTrue: [
			^Core.Array with: nil with: nil with:
				('{"error":"item_not_found","seg":' , (self jsonFor: seg) , ',"at_segment":' , i printString , '}')].
		i < pathArray size ifTrue: [currentMenu := self submenuOf: currentItem].
		i := i + 1].
	^Core.Array with: currentItem with: performer with: nil! !

!VWBridge methodsFor: 'eval'!

handleEvalBody: bodyString
	"POST /eval - evaluate arbitrary Smalltalk source via Compiler.
	 Runs on the bridge's serve process; UI-touching code must wrap itself
	 (see top docstring). Returns JSON.
	 Empty body -> 400 empty_body.
	 Bug #5 Stage 1 mitigation (v0.8.8): body containing both 'VWBridge'
	 AND 'dispatch' substrings -> 400 recursive_dispatch_forbidden. This
	 is a textual heuristic - the real defense-in-depth is the per-
	 process re-entry counter in dispatch:headers:body: (Stage 2). The
	 substring filter still allows direct handler calls (e.g.
	 'VWBridge singleton handleWindows' has no 'dispatch') so the
	 documented workaround #1 keeps working.
	 Compile / runtime error -> 400 eval_failed with the exception description.
	 Success -> 200 ok=true result=<printString of evaluated expression>."
	| err result compiler printed |
	err := self errorClass.
	(bodyString == nil or: [bodyString isEmpty]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"empty_body"}'].
	(self looksLikeRecursiveDispatch: bodyString) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"recursive_dispatch_forbidden","hint":"/eval body references both ''VWBridge'' and ''dispatch'' - cannot call back into the bridge dispatcher (Bug #5). Call handler methods directly (e.g. VWBridge singleton handleWindows) or run tests from a VW workspace."}'].
	compiler := self globalNamed: #Compiler.
	compiler == nil ifTrue: [
		^self httpResponse: 500 type: 'application/json'
			body: '{"error":"no_compiler"}'].
	result := [compiler evaluate: bodyString] on: err do: [:ex |
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"eval_failed","message":' ,
				(self safeJsonFor: ex description) , '}'].
	printed := [result printString] on: err do: [:ex | 'PRINT_FAILED'].
	^self httpResponse: 200 type: 'application/json'
		body: '{"ok":true,"result":' , (self safeJsonFor: printed) , '}'!

looksLikeRecursiveDispatch: aSource
	"Bug #5 Stage 1: substring heuristic that returns true when an /eval
	 body looks like it's trying to re-enter the dispatcher. Requires
	 BOTH 'VWBridge' AND 'dispatch' substrings (case-sensitive) to be
	 present so legitimate workarounds keep working:
	   ALLOWED: 'VWBridge singleton handleWindows' (no 'dispatch')
	   ALLOWED: 'Dialog useNativeDialogs: false' (no 'VWBridge')
	   BLOCKED: 'VWBridge singleton dispatch: ''GET /health ...'''
	   BLOCKED: 'bridge := VWBridge singleton. bridge dispatch: ...'
	 Brittle by design - the per-process re-entry counter in
	 dispatch:headers:body: (Stage 2) is the real defense and catches
	 indirect paths this substring filter misses."
	| s hasBridge hasDispatch |
	aSource == nil ifTrue: [^false].
	s := aSource asString.
	hasBridge := (s indexOfSubCollection: 'VWBridge' startingAt: 1) > 0.
	hasBridge ifFalse: [^false].
	hasDispatch := (s indexOfSubCollection: 'dispatch' startingAt: 1) > 0.
	^hasDispatch! !

!VWBridge methodsFor: 'dialogs'!

handleDialogsQuery
	"GET /dialogs - enumerate live SimpleDialog (and subclass, e.g. ExtendedSimpleDialog) modals.
	 Returns 200 with {ok:true, dialogs:[...]}. Empty array if no live
	 modal OR if Dialog usesNativeDialogs is still true (native dialogs
	 are invisible to VW introspection - run
	   Dialog useNativeDialogs: false
	 via POST /eval after image restart to enable detection)."
	| outcome |
	outcome := self onUIDo: [self doListDialogs].
	outcome == nil ifTrue: [outcome := '{"ok":false,"error":"ui_timeout","dialogs":[]}'].
	^self httpResponse: 200 type: 'application/json' body: outcome!

doListDialogs
	"Runs on UI process. Returns JSON string.
	 Enumerates SimpleDialog instances that are LIVE (i.e. in
	 ScheduledControllers - have an open window). Filtering this way
	 (instead of via SimpleDialog allInstances) automatically excludes
	 stale instances and the dialogSupplier singleton."
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
		([ctrl model isKindOf: sdClass] on: err do: [:ex | false]) ifTrue: [
			dialogs add: (self describeDialog: ctrl model)]].
	response := Core.Dictionary new.
	response at: 'ok' put: true.
	response at: 'dialogs' put: dialogs.
	^self jsonFor: response!

describeDialog: aSimpleDialog
	"Build a Dictionary describing one live SimpleDialog (or any subclass):
	 id, class, message text, button labels.
	 v0.8.10 (Bug #4b full fix): three-tier extraction.
	 Tier 1 (existing): namedComponents lookup via extractDialogMessageFrom: +
	   extractDialogButtonsFrom: - SimpleDialog happy path where the builder
	   registered named aspects.
	 Tier 2 (NEW): view-tree walk via extractDialogFromView: - fallback when
	   Tier 1 returned nothing (msg nil AND no buttons). Catches
	   ExtendedSimpleDialog and similar subclasses that build their UI
	   dynamically via dialogSubSpecSymbol-resolved windowSpecs without
	   ever calling builder>>component:name:. The walk descends
	   mainWindow component children and classifies leaves by class-name
	   substring (*Button* / *Label*).
	 The 'class' field always tells callers which dialog subclass they're
	 dealing with (47 SimpleDialog subclasses exist in this image)."
	| d err builder comps msg btnLabels root extracted |
	err := self errorClass.
	d := Core.Dictionary new.
	d at: 'id' put: ([aSimpleDialog identityHash printString] on: err do: [:ex | nil]).
	d at: 'class' put: ([aSimpleDialog class name asString] on: err do: [:ex | nil]).
	builder := [aSimpleDialog builder] on: err do: [:ex | nil].
	msg := nil.
	btnLabels := Core.OrderedCollection new.
	"Tier 1: namedComponents lookup."
	builder ~~ nil ifTrue: [
		comps := [builder namedComponents] on: err do: [:ex | nil].
		comps ~~ nil ifTrue: [
			msg := self extractDialogMessageFrom: comps.
			btnLabels := self extractDialogButtonsFrom: comps]].
	"Tier 2: view-tree walk when Tier 1 found nothing. Conservative
	 condition (both empty) avoids overwriting partial Tier 1 results
	 - if Tier 1 ever returns msg-only or buttons-only for a SimpleDialog
	 subclass in the wild, refine here to merge per-field."
	(msg == nil and: [btnLabels isEmpty]) ifTrue: [
		root := [aSimpleDialog mainWindow component] on: err do: [:ex | nil].
		root ~~ nil ifTrue: [
			extracted := self extractDialogFromView: root.
			msg := extracted at: 1.
			btnLabels := extracted at: 2]].
	d at: 'message' put: msg.
	d at: 'buttons' put: btnLabels asArray.
	^d!

extractDialogMessageFrom: comps
	"Bug #4b: try common message aspect names in order. Return first non-nil
	 non-empty String, or nil if none match. SimpleDialog uses
	 #displayMessageString; the other candidates cover ExtendedSimpleDialog
	 and other subclasses whose 'source' app model may name the message
	 widget differently. spec.label may be String, Text, or ComposedText -
	 all respond to #asString returning the raw text."
	| err result |
	err := self errorClass.
	#(displayMessageString message text displayText labelString messageText) do: [:aspectSym |
		| widget |
		widget := [comps at: aspectSym ifAbsent: [nil]] on: err do: [:ex | nil].
		widget ~~ nil ifTrue: [
			result := [widget spec label asString] on: err do: [:ex | nil].
			(result ~~ nil and: [result isEmpty not]) ifTrue: [^result]]].
	^nil!

extractDialogButtonsFrom: comps
	"Bug #4b: iterate ALL widgets in namedComponents and collect labels of
	 any whose spec class name contains 'Button' (case-sensitive substring).
	 Captures ActionButtonSpec (SimpleDialog), PluggableActionButtonSpec,
	 and any future *ButtonSpec variants. Excludes purely-non-button
	 widgets (LabelSpec, InputFieldSpec, etc.).
	 Uses valuesDo:/do: fallback for namedComponents variants that don't
	 implement #valuesDo: (same defensive pattern as resolveAspect:)."
	| err btnLabels iterBlock |
	err := self errorClass.
	btnLabels := Core.OrderedCollection new.
	iterBlock := [:w |
		| specName label |
		specName := [w spec class name asString] on: err do: [:ex | nil].
		(specName ~~ nil and: [(specName indexOfSubCollection: 'Button' startingAt: 1) > 0]) ifTrue: [
			label := [w spec label asString] on: err do: [:ex | nil].
			(label ~~ nil and: [label isEmpty not]) ifTrue: [btnLabels add: label]]].
	(comps respondsTo: #valuesDo:)
		ifTrue: [comps valuesDo: iterBlock]
		ifFalse: [
			(comps respondsTo: #do:) ifTrue: [comps do: iterBlock]].
	^btnLabels!

extractDialogFromView: aRootView
	"Bug #4b Tier 2 (v0.8.10): depth-first walk of the dialog's view tree
	 to find the message Label widget and the button widgets. Used when
	 namedComponents is empty - typical for ExtendedSimpleDialog and other
	 SimpleDialog subclasses that build their UI dynamically via
	 dialogSubSpecSymbol-resolved windowSpecs without registering aspects
	 on the builder.
	 
	 Algorithm:
	  - DFS via #children (universal across View, Wrapper, CompositeView,
	    VisualPart in this image - probe-confirmed 2026-06-20 session-5).
	  - Identify candidates by runtime widget class-name substring:
	      '*Button*' -> button (e.g. ActionButtonView)
	      '*Label*'  -> message label (e.g. PassiveLabel, ActiveLabel)
	    'Label' check excludes anything also matching 'Button' so a future
	    LabelledButton-style class is still classified as button.
	  - First non-empty label in DFS order becomes the message; ALL buttons
	    are collected in DFS order. extractLabelText: unwraps ComposedText
	    (PassiveLabel.label) via #string fallback, and LabelWithAccessor
	    (ActionButtonView.label) via printString quoted-segment parsing.
	  - Depth-capped at 12 - the deepest live SimpleDialog tree observed
	    so far has depth 7, so 12 leaves comfortable headroom while bounding
	    pathological cases.
	 
	 Stack is an OrderedCollection used as a LIFO via addFirst:/removeFirst;
	 children pushed in reverse so they pop in original order (true DFS).
	 
	 Returns Core.Array with: messageOrNil with: buttonsOrderedCollection."
	| err msg buttons stack maxDepth pair obj depth children clsName isButton isLabel lblObj txt |
	err := self errorClass.
	msg := nil.
	buttons := Core.OrderedCollection new.
	stack := Core.OrderedCollection new.
	stack addFirst: (Core.Array with: aRootView with: 0).
	maxDepth := 12.
	[stack isEmpty] whileFalse: [
		pair := stack removeFirst.
		obj := pair at: 1.
		depth := pair at: 2.
		clsName := [obj class name asString] on: err do: [:ex | ''].
		isButton := (clsName indexOfSubCollection: 'Button' startingAt: 1) > 0.
		isLabel := ((clsName indexOfSubCollection: 'Label' startingAt: 1) > 0) and: [isButton not].
		(isButton or: [isLabel]) ifTrue: [
			lblObj := [obj label] on: err do: [:ex | nil].
			txt := self extractLabelText: lblObj.
			(txt ~~ nil and: [txt isEmpty not]) ifTrue: [
				isButton ifTrue: [buttons add: txt].
				(isLabel and: [msg == nil]) ifTrue: [msg := txt]]].
		(depth < maxDepth and: [obj respondsTo: #children]) ifTrue: [
			children := [obj children] on: err do: [:ex | nil].
			(children ~~ nil and: [children respondsTo: #reverseDo:]) ifTrue: [
				children reverseDo: [:c | stack addFirst: (Core.Array with: c with: depth + 1)]]]].
	^Core.Array with: msg with: buttons!

handleDialogsRespondBody: bodyString
	"POST /dialogs/respond - dispatch a button click on the live modal.
	 Body: {""choice"":""Yes""|""No""|""OK""|""Cancel""|""Accept""|""Decline""}
	 SINGLE-SHOT: clicking No on a search-confirm modal may pop a
	 second cascading modal (e.g. ""Search cancelled"" with OK). The
	 caller orchestrates: respond, GET /dialogs, respond again, until
	 /dialogs returns empty."
	| dict choice outcome |
	dict := self jsonParseFlat: bodyString.
	dict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json"}'].
	choice := dict at: 'choice' ifAbsent: [nil].
	choice == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"missing_choice","need":"choice: Yes|No|OK|Cancel|Accept|Decline"}'].
	outcome := self onUIDo: [self doRespondDialog: choice].
	outcome == nil ifTrue: [outcome := '{"error":"ui_timeout"}'].
	^((outcome indexOfSubCollection: '"ok":true' startingAt: 1) > 0)
		ifTrue: [self httpResponse: 200 type: 'application/json' body: outcome]
		ifFalse: [self httpResponse: 400 type: 'application/json' body: outcome]!

doRespondDialog: choice
	"v0.8.11 - Runs on bridge serve process (NOT UI process - mgr activeControllerProcess
	 returns nil while a modal is up, so onUIDo: falls back to direct execution).
	 
	 1. Records the outcome via the SimpleDialog model's accept/cancel ValueHolders.
	 2. Calls target closeAndUnschedule - destroys the OS window.
	 3. v0.8.11: calls purgeWedgedDialogProcesses - wakes the wedged modal loop.
	 
	 WHY THE PURGE (session-6 discovery): closeAndUnschedule destroys the OS window
	 but does NOT push a Destroy event into the modal loop's EventQueue. The fork
	 running [Dialog confirm: ...] is blocked deep in:
	   ApplicationDialogController>>eventLoop -> WindowManager>>processNextEvent
	   -> EventQueue>>next -> Semaphore>>waitIfCurtailedSignal
	 ...and never sees the OS-level destruction. Pre-v0.8.11 result: SILENT,
	 PERMANENT wedge of the forking process (no debugger, no exception, just hung).
	 Calling purgeDeadWindows on the wedged WindowManager (found via Process
	 allInstances stack walk) makes the loop notice the dead window and exit.
	 
	 KNOWN LIMITATION (Bug #2 Symptom A persists): Dialog confirm: returns nil
	 (not the accept ValueHolder's value) when dismissed externally - the
	 dialog framework hardcodes the force-close return path. For partialFind:'s
	 (Dialog confirm: ...) ifTrue: [...] pattern this raises MustBeBoolean in
	 the forking process. v0.8.11 makes that failure VISIBLE and RECOVERABLE
	 instead of silent. The real Symptom A fix needs either OS event injection
	 (synthetic mouse click on YesButton, hard) or a Dialog>>confirm: override
	 that reads accept value on force-close (MAS-side change). See
	 knowledge/vw-bridge-known-issues.md Bug #2 for the full investigation."
	| err choiceStr sdClass mgr target wantsAccept wantsCancel purgedCount |
	err := self errorClass.
	sdClass := self globalNamed: #SimpleDialog.
	sdClass == nil ifTrue: [
		^'{"ok":false,"error":"no_simple_dialog_class"}'].
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [
		^'{"ok":false,"error":"no_scheduled_controllers"}'].
	target := [mgr scheduledControllers detect: [:c |
		[c model isKindOf: sdClass] on: err do: [:ex | false]
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
	"Force close at the controller level - destroys the OS window."
	[target closeAndUnschedule] on: err do: [:ex |
		^'{"ok":false,"error":"close_failed","message":' , (self safeJsonFor: ex description) , '}'].
	"v0.8.11: purge wedged modal-loop processes so they don't hang forever."
	purgedCount := [self purgeWedgedDialogProcesses] on: err do: [:ex | 0].
	^'{"ok":true,"choice":' , (self safeJsonFor: choiceStr) ,
		',"method":"closeAndUnschedule+purgeDeadWindows","recordedAccept":' , wantsAccept printString ,
		',"recordedCancel":' , wantsCancel printString ,
		',"purgedWedged":' , purgedCount printString , '}'!

purgeWedgedDialogProcesses
	"v0.8.11 - find any Process suspended inside ApplicationDialogController>>eventLoop
	 and call purgeDeadWindows on its WindowManager. This wakes a modal loop that
	 is wedged after a closeAndUnschedule destroyed its OS window without notifying
	 the WindowManager's EventQueue.
	 
	 Returns the count of wedged processes that were unwedged. Safe to call when
	 no wedged processes exist (returns 0). Caller (doRespondDialog:) calls this
	 RIGHT AFTER closeAndUnschedule; in normal operation count will be 1 (the
	 fork that called Dialog confirm:). Higher counts indicate accumulated
	 pre-v0.8.11 wedges from earlier dismissals.
	 
	 IMPLEMENTATION: walks Process allInstances (~200-300 procs, fast filter)
	 looking for a suspended context with ApplicationDialogController as a
	 receiver. For each match, walks the same context for a WindowManager
	 receiver, then sends purgeDeadWindows. All operations are wrapped in
	 Error handlers - GC-collected processes, partially-walked contexts,
	 and inaccessible WindowManagers all return 0/no-op silently."
	| err procClass procs wedged count |
	err := self errorClass.
	procClass := self globalNamed: #Process.
	procClass == nil ifTrue: [^0].
	procs := [procClass allInstances asArray] on: err do: [:ex | #()].
	count := 0.
	wedged := procs select: [:p |
		| walk found |
		walk := [p suspendedContext] on: err do: [:ex | nil].
		found := false.
		[walk ~~ nil and: [found not]] whileTrue: [
			| rc |
			rc := [walk receiver class name asString] on: err do: [:ex | ''].
			(rc = 'ApplicationDialogController') ifTrue: [found := true].
			walk := [walk sender] on: err do: [:ex | nil]].
		found].
	wedged do: [:p |
		| walk wm |
		walk := [p suspendedContext] on: err do: [:ex | nil].
		wm := nil.
		[walk ~~ nil and: [wm == nil]] whileTrue: [
			| rec rc |
			rec := [walk receiver] on: err do: [:ex | nil].
			rc := rec == nil ifTrue: [''] ifFalse: [[rec class name asString] on: err do: [:ex | '']].
			(rc = 'WindowManager') ifTrue: [wm := rec].
			walk := [walk sender] on: err do: [:ex | nil]].
		wm ~~ nil ifTrue: [
			[wm purgeDeadWindows. count := count + 1] on: err do: [:ex | nil]]].
	^count! !

!VWBridge methodsFor: 'ui process'!

onUIDo: aBlock
	"Run aBlock on the UI process when possible; otherwise run it directly
	 (acceptable for read-only traversal). 5-second watchdog timeout."
	| mgr uiProc result sem proc |
	mgr := self globalNamed: #ScheduledControllers.
	uiProc := mgr == nil
		ifTrue: [nil]
		ifFalse: [[mgr activeControllerProcess] on: self errorClass do: [:ex | nil]].
	uiProc == nil ifTrue: [^aBlock value].
	proc := self globalNamed: #Processor.
	(proc ~~ nil and: [uiProc == proc activeProcess]) ifTrue: [^aBlock value].
	(uiProc respondsTo: #interruptWith:) ifFalse: [^aBlock value].
	result := nil.
	sem := Core.Semaphore new.
	uiProc interruptWith: [
		result := [aBlock value] on: self errorClass do: [:ex | nil].
		sem signal].
	self wait: sem timeoutMs: 5000.
	^result!

wait: aSemaphore timeoutMs: ms
	"This image has NO Semaphore timeout API (probe-confirmed), so use a
	 watchdog process that signals the semaphore after ms milliseconds."
	| watchdog prio |
	prio := [(self globalNamed: #Processor) userSchedulingPriority]
		on: self errorClass do: [:ex | 5].
	watchdog := [(Core.Delay forMilliseconds: ms) wait. aSemaphore signal] forkAt: prio.
	aSemaphore wait.
	[watchdog terminate] on: self errorClass do: [:ex | nil]! !

!VWBridge methodsFor: 'json'!

jsonFor: anObject
	anObject == nil ifTrue: [^'null'].
	anObject == true ifTrue: [^'true'].
	anObject == false ifTrue: [^'false'].
	(anObject isKindOf: Core.Number) ifTrue: [^anObject printString].
	(anObject isKindOf: Core.String) ifTrue: [^self jsonString: anObject asString].
	(anObject isKindOf: Core.Dictionary) ifTrue: [^self jsonObject: anObject].
	(anObject isKindOf: Core.Collection) ifTrue: [^self jsonArray: anObject].
	^self jsonString: anObject printString!

jsonObject: aDictionary
	| out first |
	out := Core.WriteStream on: Core.String new.
	out nextPut: ${.
	first := true.
	aDictionary keysAndValuesDo: [:k :v |
		first ifFalse: [out nextPut: $,].
		first := false.
		out nextPutAll: (self jsonString: k asString).
		out nextPut: $:.
		out nextPutAll: (self jsonFor: v)].
	out nextPut: $}.
	^out contents!

jsonArray: aCollection
	| out first |
	out := Core.WriteStream on: Core.String new.
	out nextPut: $[.
	first := true.
	aCollection do: [:each |
		first ifFalse: [out nextPut: $,].
		first := false.
		out nextPutAll: (self jsonFor: each)].
	out nextPut: $].
	^out contents!

jsonString: aString
	| out code |
	out := Core.WriteStream on: Core.String new.
	out nextPut: $".
	aString do: [:ch |
		code := ch asInteger.
		ch = $"
			ifTrue: [out nextPutAll: '\"']
			ifFalse: [
				ch = $\
					ifTrue: [out nextPutAll: '\\']
					ifFalse: [
						code < 32
							ifTrue: [out nextPut: (Core.Character value: 32)]
							ifFalse: [out nextPut: ch]]]].
	out nextPut: $".
	^out contents! !

!VWBridge methodsFor: 'json parsing'!

jsonParseFlat: aString
	"Minimal JSON parser. Returns Dictionary keyed by String, values are
	 String / Number / Boolean / nil / Array (via parseArray:). FLAT
	 objects only - no nested objects (none needed for our request
	 bodies). nil on parse error.
	 Uses a 1-element-Core.Array cursor because VW forbids assigning to
	 method args."
	| cursor c dict key val |
	aString isEmpty ifTrue: [^nil].
	cursor := Core.Array with: 1.
	self skipWs: aString cursor: cursor.
	c := self peek: aString cursor: cursor.
	c = ${ ifFalse: [^nil].
	self advance: cursor.
	dict := Core.Dictionary new.
	[self skipWs: aString cursor: cursor.
	 c := self peek: aString cursor: cursor.
	 c ~~ nil and: [c ~= $}]] whileTrue: [
		key := self parseQuotedString: aString cursor: cursor.
		key == nil ifTrue: [^nil].
		self skipWs: aString cursor: cursor.
		(self peek: aString cursor: cursor) = $: ifFalse: [^nil].
		self advance: cursor.
		self skipWs: aString cursor: cursor.
		val := self parseAnyValue: aString cursor: cursor.
		dict at: key put: val.
		self skipWs: aString cursor: cursor.
		(self peek: aString cursor: cursor) = $, ifTrue: [self advance: cursor]].
	(self peek: aString cursor: cursor) == nil ifTrue: [^nil].
	self advance: cursor.
	^dict!

advance: cursor
	cursor at: 1 put: (cursor at: 1) + 1!

peek: aString cursor: cursor
	| i |
	i := cursor at: 1.
	i > aString size ifTrue: [^nil].
	^aString at: i!

skipWs: aString cursor: cursor
	[| c |
	 c := self peek: aString cursor: cursor.
	 c ~~ nil
		and: [c = (Core.Character value: 32)
			or: [c = (Core.Character value: 9)
				or: [c = (Core.Character value: 10)
					or: [c = (Core.Character value: 13)]]]]]
		whileTrue: [self advance: cursor]!

parseQuotedString: aString cursor: cursor
	"At opening quote. Returns the string content (no quotes), or nil on error."
	| out c esc |
	(self peek: aString cursor: cursor) = $" ifFalse: [^nil].
	self advance: cursor.
	out := Core.WriteStream on: Core.String new.
	[c := self peek: aString cursor: cursor.
	 c ~~ nil and: [c ~= $"]] whileTrue: [
		c = $\
			ifTrue: [
				self advance: cursor.
				esc := self peek: aString cursor: cursor.
				esc == nil ifTrue: [^nil].
				esc = $n ifTrue: [out nextPut: (Core.Character value: 10)].
				esc = $t ifTrue: [out nextPut: (Core.Character value: 9)].
				esc = $r ifTrue: [out nextPut: (Core.Character value: 13)].
				(esc = $" or: [esc = $\ or: [esc = $/]]) ifTrue: [out nextPut: esc].
				self advance: cursor]
			ifFalse: [
				out nextPut: c.
				self advance: cursor]].
	c == nil ifTrue: [^nil].
	self advance: cursor.
	^out contents!

parseAnyValue: aString cursor: cursor
	"Parse a JSON value (whitespace already skipped). Returns the value
	 or nil. Note: a parsed JSON null also yields nil - callers should
	 not distinguish missing-key from explicit-null.
	 Supports: string / array / true / false / null / number.
	 (Nested objects not supported - flat-object requests only.)"
	| c start end |
	c := self peek: aString cursor: cursor.
	c == nil ifTrue: [^nil].
	c = $" ifTrue: [^self parseQuotedString: aString cursor: cursor].
	c = $[ ifTrue: [^self parseArray: aString cursor: cursor].
	c = $t ifTrue: [^self matchKeyword: 'true' as: true in: aString cursor: cursor].
	c = $f ifTrue: [^self matchKeyword: 'false' as: false in: aString cursor: cursor].
	c = $n ifTrue: [^self matchKeyword: 'null' as: nil in: aString cursor: cursor].
	start := cursor at: 1.
	[c := self peek: aString cursor: cursor.
	 c ~~ nil
		and: [(c between: $0 and: $9)
			or: [c = $- or: [c = $+ or: [c = $. or: [c = $e or: [c = $E]]]]]]]
		whileTrue: [self advance: cursor].
	end := (cursor at: 1) - 1.
	end < start ifTrue: [^nil].
	^[(aString copyFrom: start to: end) asNumber] on: self errorClass do: [:ex | nil]!

parseArray: aString cursor: cursor
	"At opening [. Returns OrderedCollection of values, or nil on error.
	 Supports nested arrays + all scalar value types via parseAnyValue:."
	| arr c |
	(self peek: aString cursor: cursor) = $[ ifFalse: [^nil].
	self advance: cursor.
	arr := Core.OrderedCollection new.
	self skipWs: aString cursor: cursor.
	c := self peek: aString cursor: cursor.
	[c ~~ nil and: [c ~= $]]] whileTrue: [
		| val |
		val := self parseAnyValue: aString cursor: cursor.
		arr add: val.
		self skipWs: aString cursor: cursor.
		(self peek: aString cursor: cursor) = $, ifTrue: [self advance: cursor].
		self skipWs: aString cursor: cursor.
		c := self peek: aString cursor: cursor].
	c == nil ifTrue: [^nil].
	self advance: cursor.
	^arr!

matchKeyword: kw as: value in: aString cursor: cursor
	"Consume the literal kw if it matches at cursor; return value. Else nil."
	| i len |
	i := cursor at: 1.
	len := kw size.
	(i + len - 1) > aString size ifTrue: [^nil].
	(aString copyFrom: i to: i + len - 1) = kw ifFalse: [^nil].
	cursor at: 1 put: i + len.
	^value!

safeJsonFor: anObject
	"Wrap jsonFor: in an error handler. Returns 'null' on any failure."
	^[self jsonFor: anObject] on: self errorClass do: [:ex | 'null']! !

!VWBridge methodsFor: 'http'!

httpResponse: code type: contentType body: bodyString
	| crlf out reason |
	crlf := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
	reason := code = 200
		ifTrue: ['OK']
		ifFalse: [
			code = 400
				ifTrue: ['Bad Request']
				ifFalse: [
					code = 401
						ifTrue: ['Unauthorized']
						ifFalse: [
							code = 404
								ifTrue: ['Not Found']
								ifFalse: [
									code = 405
										ifTrue: ['Method Not Allowed']
										ifFalse: [
											code = 500
												ifTrue: ['Internal Server Error']
												ifFalse: ['Error']]]]]].
	out := Core.WriteStream on: Core.String new.
	out nextPutAll: 'HTTP/1.1 ' , code printString , ' ' , reason; nextPutAll: crlf.
	out nextPutAll: 'Content-Type: ' , contentType; nextPutAll: crlf.
	out nextPutAll: 'Content-Length: ' , bodyString size printString; nextPutAll: crlf.
	out nextPutAll: 'Access-Control-Allow-Origin: *'; nextPutAll: crlf.
	out nextPutAll: 'Connection: close'; nextPutAll: crlf.
	out nextPutAll: crlf.
	out nextPutAll: bodyString.
	^out contents! !

"v0.8.12 Bug #2 Symptom A fix - SimpleDialog override (see method comment + knowledge/vw-bridge-known-issues.md Bug #2)"
Transcript cr; show: '[v0.8.12] Installing SimpleDialog>>choose:labels:values:default:for: override (Bug #2 Symptom A fix)'; cr!

!SimpleDialog methodsFor: 'mas-bug2-fix'!

choose: aLabel labels: labels values: values default: defaultValue for: aWindow
	"v0.8.12 Bug #2 Symptom A fix: synthesize boolean return from accept/cancel
	 ValueHolders when the framework's force-close yields nil. Conservative -
	 only fires for confirm-shaped values (Array with: true with: false).
	 All other nil results pass through unchanged.

	 WHY: closeAndUnschedule + purgeDeadWindows (v0.8.11) wakes the wedged
	 modal loop cleanly, but the framework hardcodes a nil return on
	 force-close exit regardless of accept/cancel state. Pre-probe (session-7)
	 confirmed both ValueHolders retain their bridge-set value through the
	 unwind. See knowledge/vw-bridge-known-issues.md Bug #2 for the full
	 investigation.

	 equalize: false matches the conventional default. The original frame 22
	 method is a 1-message delegator; the equalize: argument is a bytecode
	 pushSpecial (true/false/nil) and could not be decoded with stripped
	 sources. If wrong, cosmetic button-width difference only."
	| result confirmShaped |
	result := self
		choose: aLabel
		labels: labels
		values: values
		default: defaultValue
		equalize: false
		for: aWindow.
	confirmShaped := (values size = 2)
		and: [(values at: 1) == true
			and: [(values at: 2) == false]].
	(result == nil and: [confirmShaped]) ifTrue: [
		self accept value ifTrue: [^true].
		self cancel value ifTrue: [^false]].
	^result! !

"=== Auto-start the bridge on file-in and write .token for agent pickup ==="
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
