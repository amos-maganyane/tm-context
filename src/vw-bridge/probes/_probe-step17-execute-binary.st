"Probe Step 17 candidate (a) part 3: outStream binary mode for byte-faithful PNG.
 Probe 2 confirmed one-shot waits but stdout is decoded as TwoByteString
 (first byte 235 instead of 137 - codepage translation corrupts PNG magic).
 StandardIOStream responds to #binary so flipping the mode should bypass
 character decoding.

 Test two read strategies after binary flip:
   A. outStream binary then upToEnd - expect ByteArray with byte values
   B. outStream binary then byte loop via atEnd and next into a fresh
      WriteStream on ByteArray - explicit byte-by-byte gather as fallback

 Comment hygiene: zero exclamation marks. Zero references to router substring.

 Side effects: invokes PowerShell helper to capture screen. Read-only on image."

| s nl epCls helperPath argList |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Probe step17 candidate-a part3: outStream binary mode ==='; nextPutAll: nl.

epCls := OS at: #ExternalProcess ifAbsent: [nil].
epCls isNil ifTrue: [
	s nextPutAll: 'FATAL: OS.ExternalProcess ABSENT'; nextPutAll: nl.
	^s contents].

helperPath := 'C:\Users\ammaganyane\tm\tm-context\scripts\screenshot-helper.ps1'.
argList := Core.OrderedCollection new.
argList add: '-ExecutionPolicy'; add: 'Bypass'.
argList add: '-File'; add: helperPath.
argList add: '-Mode'; add: 'screen'.

"--- Strategy A. binary then upToEnd ---"
s nextPutAll: nl; nextPutAll: '--- A. outStream binary then upToEnd ---'; nextPutAll: nl.
[
	| rawOutA captureSizeA firstBytesA invokeResultA tStart tEnd errCapA widthA heightA |
	rawOutA := nil.
	captureSizeA := -1.
	firstBytesA := nil.
	errCapA := WriteStream on: String new.
	tStart := Core.Time millisecondClockValue.
	invokeResultA := [
		epCls
			execute: 'powershell.exe'
			arguments: argList asArray
			do: [:outStream |
				outStream binary.
				rawOutA := [outStream upToEnd]
					on: Error do: [:e | '<read ERR ' , e messageText , '>'].
				s nextPutAll: '    rawOutA class='; nextPutAll: rawOutA class name; nextPutAll: nl.
				captureSizeA := rawOutA size.
				captureSizeA >= 16
					ifTrue: [firstBytesA := (1 to: 16) collect: [:i | (rawOutA at: i) asInteger]]
					ifFalse: [
						captureSizeA > 0
							ifTrue: [firstBytesA := (1 to: captureSizeA) collect: [:i | (rawOutA at: i) asInteger]]]]
			errorStreamDo: [:errStream |
				[errCapA nextPutAll: errStream upToEnd asString]
					on: Error do: [:e | errCapA nextPutAll: '<err read ERR ' , e messageText , '>']]]
		on: Error do: [:e | 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
	tEnd := Core.Time millisecondClockValue.
	s nextPutAll: '    invokeResultA='; nextPutAll: invokeResultA printString; nextPutAll: nl.
	s nextPutAll: '    elapsed_ms='; nextPutAll: (tEnd - tStart) printString; nextPutAll: nl.
	s nextPutAll: '    captureSizeA='; nextPutAll: captureSizeA printString; nextPutAll: nl.
	s nextPutAll: '    firstBytesA='; nextPutAll: firstBytesA printString; nextPutAll: nl.
	s nextPutAll: '    errContentsA='; nextPutAll: errCapA contents printString; nextPutAll: nl.
	(firstBytesA notNil and: [firstBytesA size >= 8]) ifTrue: [
		s nextPutAll: '    PNG magic match A = ';
			nextPutAll: ((firstBytesA first: 8) asArray = #(137 80 78 71 13 10 26 10)) printString;
			nextPutAll: nl].
	(rawOutA notNil and: [rawOutA size >= 24 and: [rawOutA class ~= String]]) ifTrue: [
		widthA := (((rawOutA at: 17) asInteger bitShift: 24)
			+ ((rawOutA at: 18) asInteger bitShift: 16))
			+ (((rawOutA at: 19) asInteger bitShift: 8) + (rawOutA at: 20) asInteger).
		heightA := (((rawOutA at: 21) asInteger bitShift: 24)
			+ ((rawOutA at: 22) asInteger bitShift: 16))
			+ (((rawOutA at: 23) asInteger bitShift: 8) + (rawOutA at: 24) asInteger).
		s nextPutAll: '    IHDR width A='; nextPutAll: widthA printString; nextPutAll: nl.
		s nextPutAll: '    IHDR height A='; nextPutAll: heightA printString; nextPutAll: nl]
] on: Error do: [:e |
	s nextPutAll: '    OUTER-ERR '; nextPutAll: e class name; nextPutAll: ' - ';
	nextPutAll: (e messageText ifNil: ['nil']); nextPutAll: nl].

"--- Strategy B. binary then byte loop via atEnd and next ---"
s nextPutAll: nl; nextPutAll: '--- B. outStream binary then atEnd loop into WriteStream on ByteArray ---'; nextPutAll: nl.
[
	| rawOutB captureSizeB firstBytesB invokeResultB tStart tEnd errCapB widthB heightB |
	rawOutB := nil.
	captureSizeB := -1.
	firstBytesB := nil.
	errCapB := WriteStream on: String new.
	tStart := Core.Time millisecondClockValue.
	invokeResultB := [
		epCls
			execute: 'powershell.exe'
			arguments: argList asArray
			do: [:outStream |
				| baStream |
				outStream binary.
				baStream := WriteStream on: (ByteArray new: 16384).
				[[outStream atEnd] whileFalse: [baStream nextPut: outStream next]]
					on: Error do: [:e | s nextPutAll: '    loop ERR ' , e messageText; nextPutAll: nl].
				rawOutB := baStream contents.
				s nextPutAll: '    rawOutB class='; nextPutAll: rawOutB class name; nextPutAll: nl.
				captureSizeB := rawOutB size.
				captureSizeB >= 16
					ifTrue: [firstBytesB := (1 to: 16) collect: [:i | (rawOutB at: i) asInteger]]
					ifFalse: [
						captureSizeB > 0
							ifTrue: [firstBytesB := (1 to: captureSizeB) collect: [:i | (rawOutB at: i) asInteger]]]]
			errorStreamDo: [:errStream |
				[errCapB nextPutAll: errStream upToEnd asString]
					on: Error do: [:e | errCapB nextPutAll: '<err read ERR ' , e messageText , '>']]]
		on: Error do: [:e | 'INVOKE-ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
	tEnd := Core.Time millisecondClockValue.
	s nextPutAll: '    invokeResultB='; nextPutAll: invokeResultB printString; nextPutAll: nl.
	s nextPutAll: '    elapsed_ms='; nextPutAll: (tEnd - tStart) printString; nextPutAll: nl.
	s nextPutAll: '    captureSizeB='; nextPutAll: captureSizeB printString; nextPutAll: nl.
	s nextPutAll: '    firstBytesB='; nextPutAll: firstBytesB printString; nextPutAll: nl.
	s nextPutAll: '    errContentsB='; nextPutAll: errCapB contents printString; nextPutAll: nl.
	(firstBytesB notNil and: [firstBytesB size >= 8]) ifTrue: [
		s nextPutAll: '    PNG magic match B = ';
			nextPutAll: ((firstBytesB first: 8) asArray = #(137 80 78 71 13 10 26 10)) printString;
			nextPutAll: nl].
	(rawOutB notNil and: [rawOutB size >= 24]) ifTrue: [
		widthB := (((rawOutB at: 17) asInteger bitShift: 24)
			+ ((rawOutB at: 18) asInteger bitShift: 16))
			+ (((rawOutB at: 19) asInteger bitShift: 8) + (rawOutB at: 20) asInteger).
		heightB := (((rawOutB at: 21) asInteger bitShift: 24)
			+ ((rawOutB at: 22) asInteger bitShift: 16))
			+ (((rawOutB at: 23) asInteger bitShift: 8) + (rawOutB at: 24) asInteger).
		s nextPutAll: '    IHDR width B='; nextPutAll: widthB printString; nextPutAll: nl.
		s nextPutAll: '    IHDR height B='; nextPutAll: heightB printString; nextPutAll: nl]
] on: Error do: [:e |
	s nextPutAll: '    OUTER-ERR '; nextPutAll: e class name; nextPutAll: ' - ';
	nextPutAll: (e messageText ifNil: ['nil']); nextPutAll: nl].

s contents
