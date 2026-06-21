"Probe Step 17 candidate (a) part 2: PowerShell screenshot via execute one-shot.
 Verify PNG byte-faithfulness through OS.ExternalProcess outputStream.

 Three sections:
   1. StandardIOStream API surface inspection - look for binary / readStream /
      contents / upToEndOfFile selectors so we know what byte-mode levers exist.
   2. PowerShell helper invocation via one-shot. Capture stdout into a buffer.
      Read each character as integer 0-255 to get byte values regardless of
      whether the stream returns String or ByteArray.
   3. PNG magic verification - first 8 bytes must equal 137 80 78 71 13 10 26 10
      for byte-faithful capture. Decode IHDR width and height at bytes 17-24.

 Comment hygiene: zero exclamation marks. Zero references to router substring.

 Side effects: invokes powershell.exe with ExecutionPolicy Bypass for the
 screenshot-helper.ps1 script. Captures full virtual screen (no UI side effect).
 Read-only on image state."

| s nl epCls sis helperPath argList captureSize firstBytes firstBytesPrintable widthBE heightBE rawOut |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Probe step17 candidate-a part2: PowerShell screenshot byte-faithful ==='; nextPutAll: nl.

epCls := OS at: #ExternalProcess ifAbsent: [nil].
epCls isNil ifTrue: [
	s nextPutAll: 'FATAL: OS.ExternalProcess ABSENT'; nextPutAll: nl.
	^s contents].

"--- A. StandardIOStream API surface inspection ---"
s nextPutAll: nl; nextPutAll: '--- A. StandardIOStream API surface ---'; nextPutAll: nl.
sis := Smalltalk at: #StandardIOStream ifAbsent: [
	OS at: #StandardIOStream ifAbsent: [nil]].
sis isNil
	ifTrue: [s nextPutAll: '  StandardIOStream NOT in Smalltalk or OS at top-level - try via probe of actual instance later'; nextPutAll: nl]
	ifFalse: [
		s nextPutAll: '  StandardIOStream class identity = '; nextPutAll: sis name; nextPutAll: nl.
		s nextPutAll: '  superclass = '; nextPutAll: sis superclass name; nextPutAll: nl.
		s nextPutAll: '  responds to #binary = '; 
			nextPutAll: (sis canUnderstand: #binary) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #upToEnd = ';
			nextPutAll: (sis canUnderstand: #upToEnd) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #upToEndOfFile = ';
			nextPutAll: (sis canUnderstand: #upToEndOfFile) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #contents = ';
			nextPutAll: (sis canUnderstand: #contents) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #asByteArray = ';
			nextPutAll: (sis canUnderstand: #asByteArray) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #atEnd = ';
			nextPutAll: (sis canUnderstand: #atEnd) printString; nextPutAll: nl.
		s nextPutAll: '  responds to #next = ';
			nextPutAll: (sis canUnderstand: #next) printString; nextPutAll: nl].

"--- B. Build args for PowerShell helper ---"
helperPath := 'C:\Users\ammaganyane\tm\tm-context\scripts\screenshot-helper.ps1'.
argList := Core.OrderedCollection new.
argList add: '-ExecutionPolicy'; add: 'Bypass'.
argList add: '-File'; add: helperPath.
argList add: '-Mode'; add: 'screen'.

"--- C. Invoke PowerShell via one-shot - capture stdout raw ---"
s nextPutAll: nl; nextPutAll: '--- C. PowerShell screenshot via execute:arguments:do:errorStreamDo: ---'; nextPutAll: nl.
captureSize := -1.
firstBytes := nil.
firstBytesPrintable := 'UNSET'.
rawOut := nil.
[
	| errCapture invokeResult tStart tEnd |
	errCapture := WriteStream on: String new.
	tStart := Core.Time millisecondClockValue.
	invokeResult := [
		epCls
			execute: 'powershell.exe'
			arguments: argList asArray
			do: [:outStream |
				"Try reading via upToEnd - returns a String for character-mode streams"
				rawOut := [outStream upToEnd]
					on: Error do: [:e | '<read ERR ' , e messageText , '>'].
				s nextPutAll: '  outStream class='; nextPutAll: outStream class name; nextPutAll: nl.
				s nextPutAll: '  rawOut class='; nextPutAll: rawOut class name; nextPutAll: nl.
				captureSize := rawOut size.
				"Capture first 16 byte integers via asInteger per char"
				captureSize >= 16
					ifTrue: [
						firstBytes := (1 to: 16) collect: [:i | (rawOut at: i) asInteger]]
					ifFalse: [
						firstBytes := (1 to: captureSize) collect: [:i | (rawOut at: i) asInteger]]]
			errorStreamDo: [:errStream |
				[errCapture nextPutAll: errStream upToEnd asString]
					on: Error do: [:e | errCapture nextPutAll: '<err read ERR ' , e messageText , '>']]]
		on: Error do: [:e | 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
	tEnd := Core.Time millisecondClockValue.
	s nextPutAll: '  invokeResult='; nextPutAll: invokeResult printString; nextPutAll: nl.
	s nextPutAll: '  elapsed_ms='; nextPutAll: (tEnd - tStart) printString; nextPutAll: nl.
	s nextPutAll: '  captureSize='; nextPutAll: captureSize printString; nextPutAll: nl.
	s nextPutAll: '  firstBytes='; nextPutAll: firstBytes printString; nextPutAll: nl.
	s nextPutAll: '  errContents printString='; nextPutAll: errCapture contents printString; nextPutAll: nl
] on: Error do: [:e |
	s nextPutAll: '  OUTER-ERR '; nextPutAll: e class name; nextPutAll: ' - ';
	nextPutAll: (e messageText ifNil: ['nil']); nextPutAll: nl].

"--- D. PNG magic check + IHDR width/height parse ---"
s nextPutAll: nl; nextPutAll: '--- D. PNG verification ---'; nextPutAll: nl.
(firstBytes isNil or: [firstBytes size < 8])
	ifTrue: [s nextPutAll: '  insufficient bytes to verify PNG magic'; nextPutAll: nl]
	ifFalse: [
		s nextPutAll: '  PNG magic match (expect 137 80 78 71 13 10 26 10) = ';
			nextPutAll: ((firstBytes first: 8) asArray = #(137 80 78 71 13 10 26 10)) printString;
			nextPutAll: nl].

(rawOut isNil or: [rawOut size < 24])
	ifTrue: [s nextPutAll: '  insufficient bytes for IHDR parse'; nextPutAll: nl]
	ifFalse: [
		widthBE := (((rawOut at: 17) asInteger bitShift: 24)
			+ ((rawOut at: 18) asInteger bitShift: 16))
			+ (((rawOut at: 19) asInteger bitShift: 8) + (rawOut at: 20) asInteger).
		heightBE := (((rawOut at: 21) asInteger bitShift: 24)
			+ ((rawOut at: 22) asInteger bitShift: 16))
			+ (((rawOut at: 23) asInteger bitShift: 8) + (rawOut at: 24) asInteger).
		s nextPutAll: '  IHDR width='; nextPutAll: widthBE printString; nextPutAll: nl.
		s nextPutAll: '  IHDR height='; nextPutAll: heightBE printString; nextPutAll: nl].

s contents
