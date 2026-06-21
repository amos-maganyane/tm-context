"Probe Step 17 candidate (a): OS.ExternalProcess execute:arguments:do:errorStreamDo:
 one-shot pattern. Test whether this selector blocks until subprocess exit
 (unlike session-12 bare proc wait which returned immediately with exit=259).

 Three checks per call site (class-side first, instance-side fallback):
   1. Behavioral fingerprint (numArgs / numTemps / messages sent internally)
      reveals how the do/errorStreamDo blocks are invoked and what arg type
      they receive.
   2. Trivial cmd /c echo hello sync test - if outStream upToEnd returns
      non-empty hello text the wait works. Empty stdout AND zero error means
      same wait-broken behaviour as bare proc wait.
   3. Stream class inspection in the do block - tells us whether outStream
      is character-oriented or binary-oriented (relevant for PNG capture).

 Comment hygiene: zero exclamation marks per session-12 carry-forward
 constraint number one. Zero references to the router substring per the
 pre-session-12 Stage 1 substring guard.

 Read-only - no production state changed. Returns a single String dump."

| s nl epCls epInstMeth epClassMeth |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Probe step17 candidate-a: execute:arguments:do:errorStreamDo: one-shot ==='; nextPutAll: nl.

epCls := OS at: #ExternalProcess ifAbsent: [nil].
epCls isNil ifTrue: [
	s nextPutAll: 'FATAL: OS.ExternalProcess ABSENT'; nextPutAll: nl.
	^s contents].

s nextPutAll: 'OS.ExternalProcess class identity = '; nextPutAll: epCls name; nextPutAll: nl.
s nextPutAll: 'defaultClass = '; 
	nextPutAll: ([epCls defaultClass name] on: Error do: [:e | 'ERR-' , e messageText]) printString;
	nextPutAll: nl.

"--- A. Behavioural fingerprint of class-side selector ---"
s nextPutAll: nl; nextPutAll: '--- A1. CLASS-SIDE execute:arguments:do:errorStreamDo: fingerprint ---'; nextPutAll: nl.
epClassMeth := epCls class compiledMethodAt: #execute:arguments:do:errorStreamDo: ifAbsent: [nil].
epClassMeth isNil
	ifTrue: [s nextPutAll: '  ABSENT on class-side'; nextPutAll: nl]
	ifFalse: [
		s nextPutAll: '  numArgs='; nextPutAll: epClassMeth numArgs printString; nextPutAll: nl.
		s nextPutAll: '  numTemps='; nextPutAll: epClassMeth numTemps printString; nextPutAll: nl.
		s nextPutAll: '  messages='; nextPutAll: epClassMeth messages asSortedCollection asArray printString; nextPutAll: nl].

"--- A2. Behavioural fingerprint of instance-side selector ---"
s nextPutAll: nl; nextPutAll: '--- A2. INSTANCE-SIDE execute:arguments:do:errorStreamDo: fingerprint ---'; nextPutAll: nl.
epInstMeth := epCls compiledMethodAt: #execute:arguments:do:errorStreamDo: ifAbsent: [nil].
epInstMeth isNil
	ifTrue: [s nextPutAll: '  ABSENT on instance-side'; nextPutAll: nl]
	ifFalse: [
		s nextPutAll: '  numArgs='; nextPutAll: epInstMeth numArgs printString; nextPutAll: nl.
		s nextPutAll: '  numTemps='; nextPutAll: epInstMeth numTemps printString; nextPutAll: nl.
		s nextPutAll: '  messages='; nextPutAll: epInstMeth messages asSortedCollection asArray printString; nextPutAll: nl].

"--- B. CLASS-SIDE invocation with cmd /c echo hello (sync wait expected) ---"
s nextPutAll: nl; nextPutAll: '--- B. CLASS-SIDE invocation: cmd /c echo hello ---'; nextPutAll: nl.
[
	| outCapture errCapture outClass errClass invokeResult tStart tEnd |
	outCapture := WriteStream on: String new.
	errCapture := WriteStream on: String new.
	outClass := 'UNSET'.
	errClass := 'UNSET'.
	tStart := Core.Time millisecondClockValue.
	invokeResult := [
		epCls
			execute: 'cmd.exe'
			arguments: #('/c' 'echo' 'hello')
			do: [:outStream |
				outClass := outStream class name asString.
				[outCapture nextPutAll: outStream upToEnd asString]
					on: Error do: [:e | outCapture nextPutAll: '<upToEnd ERR ' , e messageText , '>']]
			errorStreamDo: [:errStream |
				errClass := errStream class name asString.
				[errCapture nextPutAll: errStream upToEnd asString]
					on: Error do: [:e | errCapture nextPutAll: '<upToEnd ERR ' , e messageText , '>']]]
		on: Error do: [:e | 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
	tEnd := Core.Time millisecondClockValue.
	s nextPutAll: '  elapsed_ms='; nextPutAll: (tEnd - tStart) printString; nextPutAll: nl.
	s nextPutAll: '  invokeResult='; nextPutAll: invokeResult printString; nextPutAll: nl.
	s nextPutAll: '  outClass='; nextPutAll: outClass; nextPutAll: nl.
	s nextPutAll: '  outContents printString='; nextPutAll: outCapture contents printString; nextPutAll: nl.
	s nextPutAll: '  outSize='; nextPutAll: outCapture contents size printString; nextPutAll: nl.
	s nextPutAll: '  errClass='; nextPutAll: errClass; nextPutAll: nl.
	s nextPutAll: '  errContents printString='; nextPutAll: errCapture contents printString; nextPutAll: nl
] on: Error do: [:e |
	s nextPutAll: '  OUTER-ERR '; nextPutAll: e class name; nextPutAll: ' - '; 
	nextPutAll: (e messageText ifNil: ['nil']); nextPutAll: nl].

"--- C. INSTANCE-SIDE invocation backup if class-side ABSENT or fails ---"
s nextPutAll: nl; nextPutAll: '--- C. INSTANCE-SIDE invocation: cmd /c echo hello via defaultClass new ---'; nextPutAll: nl.
[
	| proc outCapture errCapture outClass errClass invokeResult tStart tEnd |
	outCapture := WriteStream on: String new.
	errCapture := WriteStream on: String new.
	outClass := 'UNSET'.
	errClass := 'UNSET'.
	proc := [epCls defaultClass new] on: Error do: [:e | nil].
	proc isNil
		ifTrue: [s nextPutAll: '  cannot instantiate via defaultClass new'; nextPutAll: nl]
		ifFalse: [
			tStart := Core.Time millisecondClockValue.
			invokeResult := [
				proc
					execute: 'cmd.exe'
					arguments: #('/c' 'echo' 'hello')
					do: [:outStream |
						outClass := outStream class name asString.
						[outCapture nextPutAll: outStream upToEnd asString]
							on: Error do: [:e | outCapture nextPutAll: '<upToEnd ERR ' , e messageText , '>']]
					errorStreamDo: [:errStream |
						errClass := errStream class name asString.
						[errCapture nextPutAll: errStream upToEnd asString]
							on: Error do: [:e | errCapture nextPutAll: '<upToEnd ERR ' , e messageText , '>']]]
				on: Error do: [:e | 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
			tEnd := Core.Time millisecondClockValue.
			s nextPutAll: '  proc class='; nextPutAll: proc class name; nextPutAll: nl.
			s nextPutAll: '  elapsed_ms='; nextPutAll: (tEnd - tStart) printString; nextPutAll: nl.
			s nextPutAll: '  invokeResult='; nextPutAll: invokeResult printString; nextPutAll: nl.
			s nextPutAll: '  outClass='; nextPutAll: outClass; nextPutAll: nl.
			s nextPutAll: '  outContents printString='; nextPutAll: outCapture contents printString; nextPutAll: nl.
			s nextPutAll: '  outSize='; nextPutAll: outCapture contents size printString; nextPutAll: nl.
			s nextPutAll: '  errClass='; nextPutAll: errClass; nextPutAll: nl.
			s nextPutAll: '  errContents printString='; nextPutAll: errCapture contents printString; nextPutAll: nl]
] on: Error do: [:e |
	s nextPutAll: '  OUTER-ERR '; nextPutAll: e class name; nextPutAll: ' - ';
	nextPutAll: (e messageText ifNil: ['nil']); nextPutAll: nl].

s contents
