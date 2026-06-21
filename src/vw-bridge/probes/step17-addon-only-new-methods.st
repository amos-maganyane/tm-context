!VWBridge methodsFor: 'screenshot helpers'!

screenshotHelperScriptPath
	"Hardcoded path - parallel to logFilePath convention."
	^'C:\Users\ammaganyane\tm\tm-context\scripts\screenshot-helper.ps1'!

pngExtentFromBytes: aByteArray
	"Parse PNG IHDR for width and height. Returns Array with: w with: h."
	| w h |
	aByteArray size < 24 ifTrue: [^Array with: 0 with: 0].
	(aByteArray at: 1) = 137 ifFalse: [^Array with: 0 with: 0].
	w := ((aByteArray at: 17) bitShift: 24)
		+ ((aByteArray at: 18) bitShift: 16)
		+ ((aByteArray at: 19) bitShift: 8)
		+ (aByteArray at: 20).
	h := ((aByteArray at: 21) bitShift: 24)
		+ ((aByteArray at: 22) bitShift: 16)
		+ ((aByteArray at: 23) bitShift: 8)
		+ (aByteArray at: 24).
	^Array with: w with: h!

captureScreenshotViaSubprocess: aSpec rect: aRect
	"Subprocess capture via PowerShell + System.Drawing. Returns outcome
	 Dictionary matching screenshotCaptureOverride shape."
	| helperPath argList proc stdoutBytes stderrText exitStatus extent result |
	helperPath := self screenshotHelperScriptPath.
	argList := Core.OrderedCollection new.
	argList add: '-ExecutionPolicy'; add: 'Bypass'.
	argList add: '-File'; add: helperPath.
	aRect isNil
		ifTrue: [argList add: '-Mode'; add: 'screen']
		ifFalse: [
			| x y w h |
			x := (aRect at: 'originX') asInteger.
			y := (aRect at: 'originY') asInteger.
			w := ((aRect at: 'cornerX') asInteger - x) max: 1.
			h := ((aRect at: 'cornerY') asInteger - y) max: 1.
			argList add: '-Mode'; add: 'window'.
			argList add: '-X'; add: x printString.
			argList add: '-Y'; add: y printString.
			argList add: '-W'; add: w printString.
			argList add: '-H'; add: h printString].
	proc := [OS.ExternalProcess defaultClass new] on: self errorClass do: [:ex |
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: 'cannot instantiate OS.ExternalProcess: ' , ex description].
	[proc lineEndTransparent] on: self errorClass do: [:ex | nil].
	[proc createInOutErrorPipes] on: self errorClass do: [:ex |
		[proc release] on: self errorClass do: [:ex2 | nil].
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: 'cannot create pipes: ' , ex description].
	[proc startProcess: 'powershell.exe' arguments: argList asArray]
		on: self errorClass do: [:ex |
			[proc release] on: self errorClass do: [:ex2 | nil].
			^self screenshotErrorWithCode: 'screenshot-capture-failed'
				status: 500
				message: 'cannot launch powershell.exe: ' , ex description].
	[proc wait] on: self errorClass do: [:ex | nil].
	stdoutBytes := [proc outputPipe upToEnd] on: self errorClass do: [:ex | ByteArray new].
	stderrText := [proc errorPipe upToEnd] on: self errorClass do: [:ex | ''].
	exitStatus := [proc exitStatus] on: self errorClass do: [:ex | -1].
	[proc release] on: self errorClass do: [:ex | nil].
	exitStatus = 0 ifFalse: [
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: 'powershell exit=' , exitStatus printString , '; stderr=' , stderrText asString].
	stdoutBytes isEmpty ifTrue: [
		^self screenshotErrorWithCode: 'screenshot-capture-failed'
			status: 500
			message: 'subprocess returned 0 bytes; stderr=' , stderrText asString].
	(stdoutBytes isKindOf: ByteArray) ifFalse: [stdoutBytes := stdoutBytes asByteArray].
	extent := self pngExtentFromBytes: stdoutBytes.
	result := Core.Dictionary new.
	result at: 'ok' put: true.
	result at: 'pngBytes' put: stdoutBytes.
	result at: 'width' put: (extent at: 1).
	result at: 'height' put: (extent at: 2).
	^result! !
