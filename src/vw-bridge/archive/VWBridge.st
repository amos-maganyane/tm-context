"=== VW Widget Bridge v0.5 -- HTTP listener on 127.0.0.1:9876 ==="
"INSTALL:  Launcher -> File Browser -> select this file -> File In.
 (Chunk format: do NOT paste into a workspace and Do It.)
 STOP:     evaluate   VWBridge stop    in any workspace.
 RESTART:  evaluate   VWBridge start
 Endpoints:  GET /health   GET /windows   GET /windows/tree
 v0.5: socket layer confirmed by phase1 probe (SocketAccessor
 newTCPserverAtPort: / listenFor: / accept / readAppendStream all exist).
 Semaphore timeout replaced with a Delay watchdog (no timeout API here).
 All namespace references fully qualified (Root.Smalltalk, Core.*)
 because unqualified names are ambiguous in this GBS image."

Root.Smalltalk defineClass: #VWBridge
	superclass: #{Core.Object}
	indexedType: #none
	private: false
	instanceVariableNames: 'port listener process token '
	classInstanceVariableNames: 'singleton '
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
	t == nil ifFalse: [t cr; show: aString]! !

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
	listener := self createListener.
	listener == nil ifTrue: [^self].
	[true] whileTrue: [
		| client |
		client := [listener accept] on: self errorClass do: [:ex | nil].
		client == nil
			ifTrue: [(Core.Delay forMilliseconds: 200) wait]
			ifFalse: [
				[self serve: client] on: self errorClass do: [:ex |
					[client close] on: self errorClass do: [:e2 | nil]]]]!

createListener
	"Create a TCP server socket. Feature-detected; finalize after phase1 probe."
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
	| stream requestLine response |
	stream := self streamFor: aConnection.
	stream == nil ifTrue: [
		[aConnection close] on: self errorClass do: [:ex | nil].
		^self].
	"Disable line-end conversion: VW external streams otherwise rewrite
	 CR/LF on the wire, which corrupts HTTP framing."
	[stream lineEndTransparent] on: self errorClass do: [:ex | nil].
	requestLine := [self readRequestLineFrom: stream] on: self errorClass do: [:ex | ''].
	response := requestLine isEmpty
		ifTrue: [self httpResponse: 400 type: 'text/plain' body: 'Bad Request']
		ifFalse: [self dispatch: requestLine].
	[stream nextPutAll: response] on: self errorClass do: [:ex | nil].
	self flushStream: stream.
	[stream close] on: self errorClass do: [:ex | nil].
	[aConnection close] on: self errorClass do: [:ex | nil]!

readRequestLineFrom: aStream
	| line |
	line := aStream upTo: (Core.Character value: 10).
	[line isEmpty not and: [line last asInteger = 13]] whileTrue: [
		line := line copyFrom: 1 to: line size - 1].
	^line! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine
	| parts method path |
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [^self httpResponse: 400 type: 'text/plain' body: 'Bad Request'].
	method := parts at: 1.
	path := parts at: 2.
	method = 'GET' ifFalse: [^self httpResponse: 404 type: 'text/plain' body: 'Not Found'].
	path = '/health' ifTrue: [
		^self httpResponse: 200 type: 'application/json' body: '{"status":"ok","version":"0.5"}'].
	path = '/windows' ifTrue: [^self handleWindows].
	path = '/windows/tree' ifTrue: [^self handleTree].
	^self httpResponse: 404 type: 'text/plain' body: 'Not Found'!

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

!VWBridge methodsFor: 'ui process'!

onUIDo: aBlock
	"Run aBlock on the UI process when possible; otherwise run it directly
	 (acceptable for read-only traversal)."
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

!VWBridge methodsFor: 'http'!

httpResponse: code type: contentType body: bodyString
	| crlf out reason |
	crlf := Core.String with: (Core.Character value: 13) with: (Core.Character value: 10).
	reason := code = 200
		ifTrue: ['OK']
		ifFalse: [
			code = 400
				ifTrue: ['Bad Request']
				ifFalse: [code = 404 ifTrue: ['Not Found'] ifFalse: ['Error']]].
	out := Core.WriteStream on: Core.String new.
	out nextPutAll: 'HTTP/1.1 ' , code printString , ' ' , reason; nextPutAll: crlf.
	out nextPutAll: 'Content-Type: ' , contentType; nextPutAll: crlf.
	out nextPutAll: 'Content-Length: ' , bodyString size printString; nextPutAll: crlf.
	out nextPutAll: 'Access-Control-Allow-Origin: *'; nextPutAll: crlf.
	out nextPutAll: 'Connection: close'; nextPutAll: crlf.
	out nextPutAll: crlf.
	out nextPutAll: bodyString.
	^out contents! !

"AUTO-START ON FILE-IN"
VWBridge start!
