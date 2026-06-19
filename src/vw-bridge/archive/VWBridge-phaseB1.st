"=== VW Widget Bridge Phase B+1 v0.8.2 -- non-blocking listener ==="
"PREREQ:  VWBridge.st (v0.5), VWBridge-phaseA.st (v0.7), VWBridge-phaseB.st
          (v0.8.1) must already be filed in. File this LAST. Restarts the
          bridge and writes the new token to .token (for agent pickup) AND
          to the Transcript (fallback for manual copy).

 CHANGE:  Single method override - VWBridge>>listenerLoop. Forks serve: per
          connection at userBackgroundPriority so a wedged request can no
          longer block the listener.

 WHY:     v0.8.1 ran serve: INLINE on the single listener process. A /click
          that triggered a Dialog confirm: popup wedged the UI process in
          the modal's nested event loop, which blocked serve: indefinitely
          (onUIDo: sat in aSemaphore wait until the user manually dismissed
          the popup). While serve: was stuck, the listener could not accept
          new connections - /health and every other read stalled too. One
          stuck /click was killing the whole bridge.

 EFFECT:  /health and /windows respond even while /click is internally
          wedged. This is the prerequisite for probing what dialogs look
          like in scheduledControllers mid-modal (Phase B+1.B), which we
          need to design /dialogs + /dialogs/respond endpoints.

 TRADE-OFF: Wedged serve: processes accumulate (one per stuck request). For
            development this is acceptable - restart the bridge (re-file
            all four .st files in order) to clear them. A future patch can
            add a hard per-request timeout that terminates the serve:
            process.

 VERIFICATION:  /health version stays ""0.8.1"" (this patch doesn't touch
                that route). Behavioral test:
                  1. Trigger a /click wedge (e.g. PartySearch findID with
                     exactMatch off).
                  2. In parallel, hit /health and /windows - both respond.
                  3. Dismiss the modal manually; /click eventually returns.
                With v0.8.1 step 2 would also stall.

 NAMESPACE: Root.Smalltalk and Core.* qualified per the GBS image gotcha."!

!VWBridge methodsFor: 'networking'!

listenerLoop
	"v0.8.2: fork serve: per connection so a wedged request doesn't block
	 the listener. Each connection runs on its own process at the same
	 priority the listener runs at (userBackgroundPriority by default)."
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
					forkAt: prio]]! !

"=== Restart the bridge and write the new token to .token for agent pickup ==="
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
