"=== VWBridge Phase A v0.6 - Interaction Endpoints ===
 Extended HTTP parsing (headers + body), Bearer token enforcement,
 POST /click, POST /type, GET /value, POST /screenshot.
 All widget ops go through onUIDo: with Delay watchdog.
 Feature-detected APIs - each risky call wrapped in error handlers."

!VWBridge methodsFor: 'networking'!

serve: aConnection
	"Read full HTTP request: request line, headers, body. Validate
	 auth token. Dispatch to handler. Write response."
	| stream requestLine headers body contentTypeLen bodyString response |
	stream := self streamFor: aConnection.
	stream == nil ifTrue: [
		[aConnection close] on: self errorClass do: [:ex | nil].
		^self].
	[stream lineEndTransparent] on: self errorClass do: [:ex | nil].
	requestLine := [self readRequestLineFrom: stream] on: self errorClass do: [:ex | ''].
	requestLine isEmpty ifTrue: [
		response := self httpResponse: 400 type: 'text/plain' body: 'Bad Request'.
		[stream nextPutAll: response] on: self errorClass do: [:ex | nil].
		self flushStream: stream.
		[stream close] on: self errorClass do: [:ex | nil].
		[aConnection close] on: self errorClass do: [:ex | nil].
		^self].
	headers := self readHeadersFrom: stream.
	bodyString := ''.
	contentTypeLen := headers at: 'content-length' ifAbsent: [nil].
	contentTypeLen == nil ifTrue: [contentTypeLen := headers at: 'Content-Length' ifAbsent: [nil]].
	contentTypeLen ~~ nil ifTrue: [
		| len |
		len := [contentTypeLen asNumber] on: self errorClass do: [:ex | 0].
		len > 0 ifTrue: [
			bodyString := [stream next: len] on: self errorClass do: [:ex | '']].
		bodyString == nil ifTrue: [bodyString := '']].
	response := self dispatch: requestLine headers: headers body: bodyString.
	[stream nextPutAll: response] on: self errorClass do: [:ex | nil].
	self flushStream: stream.
	[stream close] on: self errorClass do: [:ex | nil].
	[aConnection close] on: self errorClass do: [:ex | nil]!

readHeadersFrom: aStream
	"Read HTTP headers until blank line. Return a Dictionary
	 with lowercase keys."
	| headers line colonPos key value |
	headers := Core.Dictionary new.
	[true] whileTrue: [
		line := [aStream upTo: (Core.Character value: 10)] on: self errorClass do: [:ex | ''].
		(line isEmpty or: [line = Core.String cr or: [line size = 1 and: [line first = (Core.Character value: 10)]]])
			ifTrue: [^headers].
		[line isEmpty not and: [line last asInteger = 13]] whileTrue: [
			line := line copyFrom: 1 to: line size - 1].
		colonPos := line indexOf: $:.
		colonPos > 0 ifTrue: [
			key := (line copyFrom: 1 to: colonPos - 1) asLowercase.
			value := line copyFrom: colonPos + 1 to: line size.
			[value first = (Core.Character value: 32)] whileTrue: [
				value := value copyFrom: 2 to: value size].
			headers at: key put: value]].
	^headers! !

!VWBridge methodsFor: 'auth'!

validateRequest: requestLine headers: headers
	"Check Bearer token. Return nil if valid, or an error response string if invalid.
	 /health is allowed without token for liveness checks."
	| parts path tokenHeader providedToken |
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [^self httpResponse: 400 type: 'application/json' body: '{"error":"bad_request"}'].
	path := parts at: 2.
	path = '/health' ifTrue: [^nil].
	path = '/favicon.ico' ifTrue: [^nil].
	tokenHeader := headers at: 'authorization' ifAbsent: [
		headers at: 'Authorization' ifAbsent: [nil]].
	tokenHeader == nil ifTrue: [
		^self httpResponse: 401 type: 'application/json' body: '{"error":"unauthorized","message":"Missing Authorization header"}'].
	(tokenHeader beginsWith: 'Bearer ') ifFalse: [
		^self httpResponse: 401 type: 'application/json' body: '{"error":"unauthorized","message":"Authorization must be Bearer <token>"}'].
	providedToken := tokenHeader copyFrom: 8 to: tokenHeader size.
	providedToken = token ifFalse: [
		^self httpResponse: 401 type: 'application/json' body: '{"error":"unauthorized","message":"Invalid token"}'].
	^nil! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"Route request to handler. Handles GET + POST + PUT.
	 Token validated before routing (except /health)."
	| parts method path authError |
	authError := self validateRequest: requestLine headers: headers.
	authError ~~ nil ifTrue: [^authError].
	parts := self split: requestLine on: (Core.Character value: 32).
	parts size < 2 ifTrue: [^self httpResponse: 400 type: 'text/plain' body: 'Bad Request'].
	method := parts at: 1.
	path := parts at: 2.
	"--- GET endpoints ---"
	method = 'GET' ifTrue: [
		path = '/health' ifTrue: [
			^self httpResponse: 200 type: 'application/json' body: '{"status":"ok","version":"0.6"}'].
		path = '/windows' ifTrue: [^self handleWindows].
		path = '/windows/tree' ifTrue: [^self handleTree].
		(path beginsWith: '/value') ifTrue: [^self handleGetValue: path].
		^self httpResponse: 404 type: 'application/json' body: '{"error":"not_found","message":"Unknown GET ' , path , '"}' ].
	"--- POST endpoints ---"
	method = 'POST' ifTrue: [
		path = '/click' ifTrue: [^self handleClick: bodyString].
		path = '/type'  ifTrue: [^self handleType: bodyString].
		path = '/screenshot' ifTrue: [^self handleScreenshot: bodyString].
		^self httpResponse: 404 type: 'application/json' body: '{"error":"not_found","message":"Unknown POST ' , path , '"}' ].
	"--- PUT endpoints ---"
	method = 'PUT' ifTrue: [
		(path beginsWith: '/value') ifTrue: [^self handleSetValue: path body: bodyString].
		^self httpResponse: 404 type: 'application/json' body: '{"error":"not_found","message":"Unknown PUT ' , path , '"}' ].
	"--- OPTIONS (CORS preflight) ---"
	method = 'OPTIONS' ifTrue: [
		^self httpResponse: 200 type: 'text/plain' body: ''].
	^self httpResponse: 405 type: 'application/json' body: '{"error":"method_not_allowed","message":"Method ' , method , ' not supported"}'!

resolveWidget: aspectName inWindow: windowTitle appClass: appClass
	"Find a widget by aspect name in a window matching title substring
	 or appClass. Returns {appModel. widgetWrapper. errorJSON} where
	 exactly one of {widgetWrapper. errorJSON} is non-nil.
	 Must be called on UI process."
	| mgr err |
	err := self errorClass.
	mgr := self globalNamed: #ScheduledControllers.
	mgr == nil ifTrue: [^Array with: nil with: nil with: '{"error":"no_scheduled_controllers"}'].
	([mgr scheduledControllers] on: err do: [:ex | #()]) do: [:ctrl |
		| app modelTitle matchesTitle matchesClass builderOK |
		app := self applicationFor: ctrl.
		builderOK := app ~~ nil and: [([app builder] on: err do: [:ex | nil]) ~~ nil].
		builderOK ifTrue: [
			modelTitle := [ctrl view label asString] on: err do: [:ex | nil].
			matchesTitle := windowTitle == nil
				ifTrue: [true]
				ifFalse: [
					modelTitle ~~ nil and: [
						[(modelTitle indexOfSubCollection: windowTitle startingAt: 1) > 0]
							on: err do: [:ex | false]]].
			matchesClass := appClass == nil
				ifTrue: [true]
				ifFalse: [app class name asString = appClass].
			(matchesTitle and: [matchesClass]) ifTrue: [
				| builder comps wrapper sym |
				builder := [app builder] on: err do: [:ex | nil].
				comps := [builder namedComponents] on: err do: [:ex | nil].
				comps == nil ifTrue: [^Array with: nil with: nil with: '{"error":"no_named_components"}'].
				"Try symbol key first"
				sym := [Core.Symbol intern: aspectName] on: err do: [:ex | nil].
				wrapper := sym == nil ifTrue: [nil] ifFalse: [comps at: sym ifAbsent: [nil]].
				"Fall back to string key"
				wrapper == nil ifTrue: [
					wrapper := comps at: aspectName ifAbsent: [nil]].
				"Fall back to label matching"
				wrapper == nil ifTrue: [
					comps keysAndValuesDo: [:k :w |
						(wrapper == nil and: [[w spec label asString = aspectName] on: err do: [:ex | false]])
							ifTrue: [wrapper := w]]].
				wrapper == nil
					ifTrue: [^Array with: nil with: nil with: '{"error":"widget_not_found","aspect":"' , aspectName , '"}' ]
					ifFalse: [^Array with: app with: wrapper with: nil]]]].
	^Array with: nil with: nil with: '{"error":"window_not_found","title":"' , (windowTitle == nil ifTrue: ['?'] ifFalse: [windowTitle]) , '"}'! !

!VWBridge methodsFor: 'interaction'!

handleClick: bodyString
	"POST /click
	 Body: {""aspect"": ""loginRpcWidget"", ""windowTitle"": ""GemStone Launcher""}
	 Action: resolve widget, call ApplicationModel>>perform: specAction on UI process."
	| bodyDict aspect windowTitle result |
	bodyDict := self jsonParse: bodyString.
	bodyDict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json","message":"Could not parse request body"}'].
	aspect := bodyDict at: 'aspect' ifAbsent: [
		bodyDict at: 'label' ifAbsent: [nil]].
	aspect == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_aspect","message":"Body must include aspect or label"}'].
	windowTitle := bodyDict at: 'windowTitle' ifAbsent: [
		bodyDict at: 'window' ifAbsent: [nil]].
	result := self onUIDo: [
		| resolve |
		resolve := self resolveWidget: aspect inWindow: windowTitle appClass: nil.
		(resolve at: 3) ~~ nil ifTrue: [resolve at: 3]  "error"
		ifFalse: [
			| app wrapper specAction |
			app := resolve at: 1.
			wrapper := resolve at: 2.
			specAction := [wrapper spec action] on: self errorClass do: [:ex | nil].
			specAction == nil ifTrue: [
				'{"error":"no_action","message":"Widget ' , aspect , ' has no action selector"}'
			] ifFalse: [
				| actionErr |
				actionErr := [app perform: specAction. nil] on: self errorClass do: [:ex |
					'{"error":"action_failed","message":"perform ' , specAction asString , ' failed: ' , ex description , '"}' ].
				actionErr ~~ nil
					ifTrue: [actionErr]
					ifFalse: ['{"ok":true,"action":"' , aspect , '","performed":"' , specAction asString , '"}' ]]]].
	result == nil ifTrue: [result := '{"error":"ui_timeout","message":"UI process did not respond"}'].
	(result beginsWith: '{"ok":') ifTrue: [
		^self httpResponse: 200 type: 'application/json' body: result]
	ifFalse: [
		^self httpResponse: 400 type: 'application/json' body: result]!

handleType: bodyString
	"POST /type
	 Body: {""aspect"": ""pageExplanation"", ""windowTitle"": ""Workspace"", ""value"": ""hello""}
	 Action: set ValueHolder value directly on UI process.
	 Also handles direct value set without specifying window (uses first match)."
	| bodyDict aspect windowTitle value result |
	bodyDict := self jsonParse: bodyString.
	bodyDict == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"invalid_json","message":"Could not parse request body"}'].
	aspect := bodyDict at: 'aspect' ifAbsent: [nil].
	aspect == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_aspect","message":"Body must include aspect"}'].
	windowTitle := bodyDict at: 'windowTitle' ifAbsent: [bodyDict at: 'window' ifAbsent: [nil]].
	value := bodyDict at: 'value' ifAbsent: [bodyDict at: 'text' ifAbsent: [nil]].
	value == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_value","message":"Body must include value or text"}'].
	result := self onUIDo: [
		| resolve |
		resolve := self resolveWidget: aspect inWindow: windowTitle appClass: nil.
		(resolve at: 3) ~~ nil ifTrue: [resolve at: 3]
		ifFalse: [
			| wrapper model |
			wrapper := resolve at: 2.
			model := [wrapper widget model] on: self errorClass do: [:ex | nil].
			model == nil ifTrue: [
				'{"error":"no_model","message":"Widget ' , aspect , ' has no model/value holder"}'
			] ifFalse: [
				[model value: value] on: self errorClass do: [:ex |
					'{"error":"set_failed","message":"Cannot set value: ' , ex description , '"}' ].
				'{"ok":true,"aspect":"' , aspect , '","value":"' , value , '"}' ]]].
	result == nil ifTrue: [result := '{"error":"ui_timeout","message":"UI process did not respond"}'].
	(result beginsWith: '{"ok":') ifTrue: [
		^self httpResponse: 200 type: 'application/json' body: result]
	ifFalse: [
		^self httpResponse: 400 type: 'application/json' body: result]!

handleGetValue: path
	"GET /value?aspect=X&windowTitle=Y
	 Reads current widget model value."
	| queryString aspect windowTitle result |
	queryString := ''.
	(path includes: $?) ifTrue: [
		| idx |
		idx := path indexOf: $?.
		queryString := path copyFrom: idx + 1 to: path size].
	aspect := self queryParam: 'aspect' from: queryString.
	windowTitle := self queryParam: 'windowTitle' from: queryString.
	aspect == nil ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_aspect","message":"Query must include aspect"}'].
	result := self onUIDo: [
		| resolve |
		resolve := self resolveWidget: aspect inWindow: windowTitle appClass: nil.
		(resolve at: 3) ~~ nil ifTrue: [resolve at: 3]
		ifFalse: [
			| wrapper model val |
			wrapper := resolve at: 2.
			model := [wrapper widget model] on: self errorClass do: [:ex | nil].
			model == nil ifTrue: [
				'{"error":"no_model","message":"Widget has no model"}']
			ifFalse: [
				val := [model value printString] on: self errorClass do: [:ex | ''].
				'{"aspect":"' , aspect , '","value":' , (self jsonFor: val) , '}' ]]].
	result == nil ifTrue: [result := '{"error":"ui_timeout"}'].
	(result beginsWith: '{"aspect":') ifTrue: [
		^self httpResponse: 200 type: 'application/json' body: result]
	ifFalse: [
		^self httpResponse: 400 type: 'application/json' body: result]!

handleSetValue: path body: bodyString
	"PUT /value?aspect=X&windowTitle=Y
	 Body: {""value"": ""new text""}
	 Sets ValueHolder value directly."
	| aspect windowTitle bodyDict value result queryString idx |
	queryString := ''.
	idx := path indexOf: $?.
	idx > 0 ifTrue: [queryString := path copyFrom: idx + 1 to: path size].
	aspect := self queryParam: 'aspect' from: queryString.
	windowTitle := self queryParam: 'windowTitle' from: queryString.
	bodyDict := self jsonParse: bodyString.
	value := bodyDict == nil ifTrue: [nil] ifFalse: [bodyDict at: 'value' ifAbsent: [nil]].
	(aspect == nil or: [value == nil]) ifTrue: [
		^self httpResponse: 400 type: 'application/json' body: '{"error":"missing_params","message":"Need aspect (query) and value (body)"}'].
	result := self onUIDo: [
		| resolve |
		resolve := self resolveWidget: aspect inWindow: windowTitle appClass: nil.
		(resolve at: 3) ~~ nil ifTrue: [resolve at: 3]
		ifFalse: [
			| wrapper model |
			wrapper := resolve at: 2.
			model := [wrapper widget model] on: self errorClass do: [:ex | nil].
			model == nil ifTrue: [
				'{"error":"no_model"}']
			ifFalse: [
				[model value: value] on: self errorClass do: [:ex |
					'{"error":"set_failed","message":"' , ex description , '"}' ].
				'{"ok":true,"aspect":"' , aspect , '","value":"' , value , '"}' ]]].
	result == nil ifTrue: [result := '{"error":"ui_timeout"}'].
	(result beginsWith: '{"ok":') ifTrue: [
		^self httpResponse: 200 type: 'application/json' body: result]
	ifFalse: [
		^self httpResponse: 400 type: 'application/json' body: result]!

queryParam: paramName from: queryString
	"Extract a query parameter value from ?key=value&key2=value2 string."
	| pairs |
	pairs := self split: queryString on: $&.
	pairs do: [:pair |
		| eqPos key value |
		eqPos := pair indexOf: $=.
		eqPos > 0 ifTrue: [
			key := (pair copyFrom: 1 to: eqPos - 1) asLowercase.
			value := pair copyFrom: eqPos + 1 to: pair size.
			key = paramName asLowercase ifTrue: [^value]]].
	^nil! !

!VWBridge methodsFor: 'screenshot'!

handleScreenshot: bodyString
	"POST /screenshot
	 Body: {""scope"": ""screen""} or {""scope"": ""window"", ""windowTitle"": ""X""}
	 Returns base64-encoded PNG in JSON: {""ok"":true,""screenshot"":""<base64>""}.
	 Feature-detects Display + PNG encoding."
	| bodyDict scope windowTitle result pngBytes b64 |
	bodyDict := bodyString isEmpty
		ifTrue: [Core.Dictionary new]
		ifFalse: [self jsonParse: bodyString].
	scope := 'screen'.
	windowTitle := nil.
	bodyDict ~~ nil ifTrue: [
		scope := bodyDict at: 'scope' ifAbsent: ['screen'].
		windowTitle := bodyDict at: 'windowTitle' ifAbsent: [nil]].
	result := self onUIDo: [
		| display form stream encoded err |
		err := self errorClass.
		"Find Display"
		display := self globalNamed: #Display.
		display == nil ifTrue: ['{"error":"no_display","message":"Display global not found"}']
		ifFalse: [
			"Capture screen area"
			form := [display contentsOfArea: display boundingBox] on: err do: [:ex | nil].
			form == nil ifTrue: ['{"error":"capture_failed","message":"Could not capture Display contents"}']
			ifFalse: [
				"Encode as PNG to ByteArray"
				stream := Core.WriteStream on: Core.ByteArray new.
				encoded := false.
				"Try PNGReadWriter"
				#(PNGReadWriter ImageReadWriter) do: [:clsName |
					encoded == false ifTrue: [
						| pngClass |
						pngClass := self globalNamed: clsName.
						pngClass == nil ifTrue: [
							#(Graphics UI) do: [:ns |
								pngClass == nil ifTrue: [
									| nsObj |
									nsObj := self globalNamed: ns.
									nsObj ~~ nil ifTrue: [
										pngClass := nsObj at: clsName ifAbsent: [nil]]]]].
						pngClass ~~ nil ifTrue: [
							(pngClass respondsTo: #putForm:onStream:) ifTrue: [
								[pngClass putForm: form onStream: stream.
								encoded := true] on: err do: [:ex | nil]].
							encoded == false ifTrue: [
								(pngClass respondsTo: #putForm:onFileNamed:) ifTrue: [
									| tmpName tmpFile |
									tmpName := 'C:\Users\ammaganyane\forge\vw_screenshot.png'.
									tmpFile := [tmpName asFilename] on: err do: [:ex | nil].
									tmpFile ~~ nil ifTrue: [
										[pngClass putForm: form onFileNamed: tmpFile.
										encoded := true.
										stream := [tmpFile readStream] on: err do: [:ex | nil].
										stream ~~ nil ifTrue: [
											stream binary.
											stream := Core.ReadStream on: (stream contents)]]
											on: err do: [:ex | nil]]]]]]].
				encoded == false ifTrue: [
					'{"error":"no_png_encoder","message":"No PNG encoding class found (tried PNGReadWriter, ImageReadWriter)"}'
				] ifFalse: [
					stream contents  "returns ByteArray - caller will base64 encode" ]]]].
	result == nil ifTrue: [
		^self httpResponse: 500 type: 'application/json' body: '{"error":"ui_timeout"}'].
	(result isKindOf: Core.String) ifTrue: [
		^self httpResponse: 500 type: 'application/json' body: result].
	"result is a ByteArray with PNG bytes"
	pngBytes := result.
	b64 := self base64Encode: pngBytes.
	^self httpResponse: 200 type: 'application/json' body: '{"ok":true,"screenshot":"' , b64 , '"}'! !

!VWBridge methodsFor: 'base64'!

base64Encode: aByteArray
	"Manual base64 encoding - no library dependency. Handles any ByteArray."
	| alphabet out i b |
	alphabet := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.
	out := Core.WriteStream on: Core.String new.
	i := 1.
	[i <= aByteArray size] whileTrue: [
		b := aByteArray at: i.
		out nextPut: (alphabet at: ((b bitAnd: 252) bitShift: -2) + 1).
		i + 1 <= aByteArray size
			ifTrue: [b := (b bitShift: 8) + (aByteArray at: i + 1)]
			ifFalse: [b := b bitShift: 8].
		out nextPut: (alphabet at: (((b bitAnd: 48) bitShift: -4) bitAnd: 63) + 1).
		i + 1 <= aByteArray size
			ifTrue: [
				i + 2 <= aByteArray size
					ifTrue: [b := (b bitShift: 8) + (aByteArray at: i + 2)]
					ifFalse: [b := b bitShift: 2].
				out nextPut: (alphabet at: (((b bitAnd: 60) bitShift: -2) bitAnd: 63) + 1).
				i + 2 <= aByteArray size
					ifTrue: [
						out nextPut: (alphabet at: ((b bitAnd: 63) + 1))]
					ifFalse: [out nextPut: $=]]
			ifFalse: [
				out nextPut: $=; nextPut: $=].
		i := i + 3].
	^out contents! !

!VWBridge methodsFor: 'json'!

jsonParse: aString
	"Minimal JSON parser - handles flat string-keyed objects,
	 strings, numbers, booleans, null. Returns a Dictionary or nil on error.
	 Does NOT handle nested objects or arrays (not needed for our bodies)."
	| out pos |
	pos := 1.
	aString isEmpty ifTrue: [^nil].
	out := self parseValue: aString pos: pos into: [:v :p | pos := p. v].
	^out == nil ifTrue: [nil] ifFalse: [
		(out isKindOf: Core.Dictionary) ifTrue: [out] ifFalse: [nil] ]!

parseValue: aString pos: pos into: aBlock
	"Parse one JSON value starting at pos. Evaluate aBlock with value and new position."
	| c |
	[pos <= aString size and: [
		c := aString at: pos.
		c = (Core.Character value: 32) or: [c = (Core.Character value: 9) or: [c = (Core.Character value: 10) or: [c = (Core.Character value: 13)]]]]]
		whileTrue: [pos := pos + 1].
	pos > aString size ifTrue: [^aBlock value: nil value: pos].
	c := aString at: pos.
	c = ${ ifTrue: [^self parseObject: aString pos: pos + 1 into: aBlock].
	c = $" ifTrue: [^self parseString: aString pos: pos + 1 into: aBlock].
	((c between: $0 and: $9) or: [c = $-]) ifTrue: [^self parseNumber: aString pos: pos into: aBlock].
	"true"
	(pos + 3 <= aString size and: [(aString copyFrom: pos to: pos + 3) = 'true']) ifTrue: [
		^aBlock value: true value: pos + 4].
	"false"
	(pos + 4 <= aString size and: [(aString copyFrom: pos to: pos + 4) = 'false']) ifTrue: [
		^aBlock value: false value: pos + 5].
	"null"
	(pos + 3 <= aString size and: [(aString copyFrom: pos to: pos + 3) = 'null']) ifTrue: [
		^aBlock value: nil value: pos + 4].
	^aBlock value: nil value: pos!

parseObject: aString pos: pos into: aBlock
	"Parse JSON object {key:value, ...} into Dictionary."
	| dict c |
	dict := Core.Dictionary new.
	[pos <= aString size] whileTrue: [
		[pos <= aString size and: [
			c := aString at: pos.
			c = (Core.Character value: 32) or: [c = (Core.Character value: 9) or: [c = (Core.Character value: 10) or: [c = (Core.Character value: 13)]]]]]
			whileTrue: [pos := pos + 1].
		pos > aString size ifTrue: [^aBlock value: dict value: pos].
		c := aString at: pos.
		c = $} ifTrue: [^aBlock value: dict value: pos + 1].
		c = $, ifTrue: [pos := pos + 1].
		c = $" ifTrue: [
			self parseString: aString pos: pos + 1 into: [:key :newPos |
				| colonPos |
				pos := newPos.
				[pos <= aString size and: [
					(aString at: pos) = (Core.Character value: 32) or: [(aString at: pos) = (Core.Character value: 9) or: [(aString at: pos) = $: ]]]]
					whileTrue: [
						(aString at: pos) = $:
							ifTrue: [pos := pos + 1]
							ifFalse: [pos := pos + 1]].
				self parseValue: aString pos: pos into: [:val :newPos2 |
					dict at: key put: val.
					pos := newPos2]]].
		c = $} ifFalse: [pos := pos + 1]].
	^aBlock value: dict value: pos!

parseString: aString pos: pos into: aBlock
	"Parse JSON string, handling escape sequences."
	| out c |
	out := Core.WriteStream on: Core.String new.
	[pos <= aString size] whileTrue: [
		c := aString at: pos.
		c = $" ifTrue: [^aBlock value: out contents value: pos + 1].
		c = $\ ifTrue: [
			pos := pos + 1.
			pos <= aString size ifTrue: [
				| esc |
				esc := aString at: pos.
				esc = $" ifTrue: [out nextPut: $"].
				esc = $\ ifTrue: [out nextPut: $\].
				esc = $/ ifTrue: [out nextPut: $/].
				esc = $n ifTrue: [out nextPut: (Core.Character value: 10)].
				esc = $t ifTrue: [out nextPut: (Core.Character value: 9)]]
			ifFalse: [^aBlock value: out contents value: pos].
			pos := pos + 1]
		ifFalse: [
			out nextPut: c.
			pos := pos + 1]].
	^aBlock value: out contents value: pos!

parseNumber: aString pos: pos into: aBlock
	"Parse a JSON number (integer or float)."
	| start ch intStr |
	start := pos.
	[pos <= aString size] whileTrue: [
		ch := aString at: pos.
		((ch between: $0 and: $9) or: [ch = $. or: [ch = $- or: [ch = $e or: [ch = $E or: [ch = $+]]]]])
			ifTrue: [pos := pos + 1]
			ifFalse: [^aBlock value: ((aString copyFrom: start to: pos - 1) asNumber) value: pos]].
	^aBlock value: nil value: pos! !
