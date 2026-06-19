"=== VW Widget Bridge Phase B+1 v0.8.3 -- POST /eval endpoint ==="
"PREREQ:  VWBridge.st (v0.5), VWBridge-phaseA.st (v0.7), VWBridge-phaseB.st
          (v0.8.1), VWBridge-phaseB1.st (v0.8.2) must already be filed in.
          File this LAST. Restarts the bridge and rewrites .token.

 CHANGE:  Adds ONE new endpoint:
            POST /eval
              body: raw Smalltalk source code (any Content-Type)
              response 200: {""ok"":true,""result"":""<printString>""}
              response 400: {""error"":""eval_failed"",""message"":""<msg>""}
              response 400: {""error"":""empty_body""} if body is empty
          Also re-defines dispatch:headers:body: to register the route
          and bumps /health version from 0.8.1 to 0.8.3.

 WHY:     System-modal dialogs in VW (Dialog confirm:) block ALL workspaces
          from accepting input, making workspace-based probes impossible while
          a modal is up. The bridge listener stays alive (Phase B+1.A) but we
          had no way to run arbitrary introspection over HTTP. /eval closes
          that gap: code runs on the bridge's serve process - bypasses the
          wedged UI entirely. Pure introspection (allInstances, class methods,
          method source) works mid-modal because it doesn't need UI access.

 USAGE:   PowerShell:
              $tok = (Get-Content .token).Trim()
              $h = @{Authorization=""Bearer $tok""}
              Invoke-RestMethod -Uri http://127.0.0.1:9876/eval -Method POST `
                -Headers $h -Body 'Dialog allInstances size' `
                -ContentType 'text/plain'
              -> @{ok=$true; result='0'}

          curl:
              curl -X POST http://127.0.0.1:9876/eval \\
                -H ""Authorization: Bearer $TOK"" \\
                --data-binary 'Dialog allInstances size'

 UI ACCESS: /eval runs on the bridge's serve process, NOT the UI process. Code
            that needs UI synchronization should wrap itself, e.g.:
              | sem result |
              sem := Semaphore new.
              ScheduledControllers activeControllerProcess interruptWith: [
                result := <code touching UI>.
                sem signal].
              sem wait.
              result
            For pure introspection (allInstances, class methods, source
            inspection, etc.), no wrapping is needed.

 SECURITY: Bridge is bound to 127.0.0.1 only. Bearer token regenerated on every
           restart (and rewritten to .token on file-in). Bridge already accepts
           arbitrary file-in via 'asFilename fileIn' (strictly MORE powerful
           than /eval), so this is not a materially new attack surface for the
           dev workflow. DO NOT expose the bridge port outside localhost.

 NAMESPACE: Root.Smalltalk and Core.* qualified per the GBS image gotcha."!

!VWBridge methodsFor: 'eval'!

handleEvalBody: bodyString
	"POST /eval - evaluate arbitrary Smalltalk source via Compiler.
	 Runs on the bridge's serve process; UI-touching code must wrap itself
	 (see top docstring). Returns JSON.
	 Empty body -> 400 empty_body.
	 Compile / runtime error -> 400 eval_failed with the exception description.
	 Success -> 200 ok=true result=<printString of evaluated expression>."
	| err result compiler printed |
	err := self errorClass.
	(bodyString == nil or: [bodyString isEmpty]) ifTrue: [
		^self httpResponse: 400 type: 'application/json'
			body: '{"error":"empty_body"}'].
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
		body: '{"ok":true,"result":' , (self safeJsonFor: printed) , '}'! !

!VWBridge methodsFor: 'dispatching'!

dispatch: requestLine headers: headers body: bodyString
	"v0.8.3: REPLACES v0.8.1's dispatch. Adds POST /eval and bumps /health
	 version to 0.8.3. All other routes preserved."
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
				body: '{"status":"ok","version":"0.8.3"}'].
		path = '/windows' ifTrue: [^self handleWindows].
		path = '/windows/tree' ifTrue: [^self handleTree].
		path = '/value' ifTrue: [^self handleGetValueQuery: queryString].
		path = '/menu' ifTrue: [^self handleMenuQuery: queryString].
		^self httpResponse: 404 type: 'application/json'
			body: '{"error":"not_found","path":"' , path , '"}'].
	method = 'POST' ifTrue: [
		path = '/click' ifTrue: [^self handleClickBody: bodyString].
		path = '/type'  ifTrue: [^self handleTypeBody: bodyString].
		path = '/menu/click' ifTrue: [^self handleMenuClickBody: bodyString].
		path = '/eval' ifTrue: [^self handleEvalBody: bodyString].
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
