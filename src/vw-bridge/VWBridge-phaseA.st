"=== VW Widget Bridge Phase A v0.7 -- adds /click /type /value endpoints ===
 PREREQ:  VWBridge.st (v0.5) must already be filed in - defines the VWBridge class.
 INSTALL: Launcher -> File Browser -> this file -> File In.
          The file-in restarts the bridge automatically to pick up the new methods.
 NEW ENDPOINTS (all require  Authorization: Bearer <token>  except /health):
   GET  /value?aspect=X&windowTitle=Y     read widget current value
   POST /click    body: {""aspect"":""X"",""windowTitle"":""Y""}
                  fires  wrapper widget model value: true  (PluggableAdaptor
                  triggers the configured action callback in its setter block).
   POST /type     body: {""aspect"":""X"",""value"":""hello"",""windowTitle"":""Y""}
                  sets   wrapper widget model value: newValue
   PUT  /value?aspect=X&windowTitle=Y    body: {""value"":""new""}
                  alternative to POST /type
 TOKEN:  printed in the Transcript at startup. Required on every non-/health request.
 PROBE-CONFIRMED DESIGN NOTES (storedev64, phaseA_results.txt):
   - spec action returns nil for ActionButtonSpec in this image -> we DO NOT
     try app perform: spec action. We fire via the model adaptor instead.
   - widget model is a PluggableAdaptor for buttons / ValueHolder for inputs.
     Both respond to value: -- one click strategy covers both surfaces.
   - JSON parser uses a 1-element-Array cursor (VW forbids assigning to method args).
   - All namespace refs qualified (Root.Smalltalk, Core.*) for this GBS image.
   - Replaces v0.5 serve:/dispatch: to add HTTP headers + body + auth.
   - Screenshot NOT included: probe shows Display has no boundingBox, no PNG
     encoder, no Base64 class. Defer to Phase B."!

!VWBridge methodsFor: 'helpers'!

beginsWithIgnoreCase: aString prefix: aPrefix
	"Case-insensitive prefix match. Returns true if aString starts with aPrefix."
	| s p |
	aString == nil ifTrue: [^false].
	s := aString asString.
	p := aPrefix asString.
	s size < p size ifTrue: [^false].
	^(s copyFrom: 1 to: p size) asLowercase = p asLowercase! !

!VWBridge methodsFor: 'networking'!

serve: aConnection
	"Phase A: full HTTP read (request line + headers + body) + auth + dispatch.
	 Replaces v0.5 single-line serve:."
	| stream requestLine headers bodyLen bodyString response err |
	err := self errorClass.
	stream := self streamFor: aConnection.
	stream == nil ifTrue: [
		[aConnection close] on: err do: [:ex | nil].
		^self].
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
	 response string to short-circuit the dispatcher."
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
	"Phase A dispatcher. Auth gate + method/path routing (GET, POST, PUT, OPTIONS)."
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
				body: '{"status":"ok","version":"0.7"}'].
		path = '/windows' ifTrue: [^self handleWindows].
		path = '/windows/tree' ifTrue: [^self handleTree].
		path = '/value' ifTrue: [^self handleGetValueQuery: queryString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'POST' ifTrue: [
		path = '/click' ifTrue: [^self handleClickBody: bodyString].
		path = '/type'  ifTrue: [^self handleTypeBody: bodyString].
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
	"Compatibility shim: v0.5 single-arg dispatch routes through Phase A with
	 empty headers/body. Kept so any old caller still works."
	^self dispatch: requestLine headers: Core.Dictionary new body: ''! !

!VWBridge methodsFor: 'interaction'!

resolveAspect: aspectName inWindowMatching: titleSubstring
	"Locate {appModel, widgetWrapper} by aspect name. titleSubstring nil = any window.
	 Returns Core.Array {app. wrapper. errorJSON}. Exactly one of {wrapper, errorJSON} non-nil.
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
							wrapper := comps at: aspectSym ifAbsent: [nil]].
						wrapper == nil ifTrue: [
							wrapper := comps at: aspectName ifAbsent: [nil]].
						wrapper == nil ifTrue: [
							comps valuesDo: [:w |
								wrapper == nil ifTrue: [
									([w spec label asString = aspectName] on: err do: [:ex | false])
										ifTrue: [wrapper := w]]]].
						wrapper ~~ nil ifTrue: [
							found := Core.Array with: app with: wrapper with: nil]]]]]].
	found ~~ nil ifTrue: [^found].
	^Core.Array with: nil with: nil
		with: '{"error":"widget_not_found","aspect":"' , aspectName , '"}'!

handleClickBody: bodyString
	"POST /click  -- invokes the widget's spec action on the application."
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

	 Image-specific click strategy (probe-confirmed in storedev64):
	   spec action returns nil here, so app perform: spec action is a dead end.
	   Buttons in this image use a PluggableAdaptor whose setter block invokes
	   the configured action callback when value: is sent.
	   Sending  wrapper widget model value: true  fires the click.
	 The same approach naturally selects radios / list rows / tabs whose
	 model is a ValueHolder driven by the widget."
	| r w err model oldVal result |
	err := self errorClass.
	r := self resolveAspect: aspect inWindowMatching: winTitle.
	(r at: 3) ~~ nil ifTrue: [^r at: 3].
	w := r at: 2.
	model := [w widget model] on: err do: [:ex | nil].
	model == nil ifTrue: [
		^'{"error":"no_model","aspect":"' , aspect , '"}'].
	oldVal := [model value] on: err do: [:ex | nil].
	result := [model value: true. nil] on: err do: [:ex |
		'{"error":"click_failed","message":"' , ex description , '"}'].
	^result == nil
		ifTrue: ['{"ok":true,"aspect":"' , aspect , '","method":"model_value_true","oldValue":' , (self safeJsonFor: oldVal printString) , '}']
		ifFalse: [result]!

handleTypeBody: bodyString
	"POST /type  -- sets the widget's ValueHolder value."
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

!VWBridge methodsFor: 'json parsing'!

jsonParseFlat: aString
	"Minimal JSON parser. Returns Dictionary keyed by String, values are
	 String / Number / Boolean / nil. FLAT objects only - no arrays or
	 nested objects (none needed for our request bodies). nil on parse error.
	 Uses a 1-element-Core.Array cursor because VW forbids assigning to method args."
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
	 not distinguish missing-key from explicit-null."
	| c start end |
	c := self peek: aString cursor: cursor.
	c == nil ifTrue: [^nil].
	c = $" ifTrue: [^self parseQuotedString: aString cursor: cursor].
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

"=== Restart the bridge to pick up Phase A dispatcher + endpoints ==="
VWBridge stop.
VWBridge start!
