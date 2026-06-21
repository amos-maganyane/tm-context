"Session-16 - verify fix primitives for ScreenshotTest helpers ByteArray-awareness.
Need to confirm: (1) aString asByteArray works (2) ByteArray indexOfSubCollection: ByteArray
startingAt: works (3) bytewise char-mapping works for slice-to-String conversion."
| s nl ba bs idxBA convResult sliceBytes mapped |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Step 1: String asByteArray"
s nextPutAll: '=== 1. String asByteArray ==='; nextPutAll: nl.
ba := ['HTTP/1.1 200' asByteArray] on: Core.Exception do: [:ex | 'ERR:', ex class name asString].
s nextPutAll: 'asByteArray => '; nextPutAll: ba printString; nextPutAll: nl.

"Step 2: ByteArray indexOfSubCollection: ByteArray"
s nextPutAll: '=== 2. ByteArray indexOfSubCollection: ByteArray ==='; nextPutAll: nl.
bs := #[72 84 84 80 47 49 46 49 32 50 48 48 13 10].  "HTTP/1.1 200\r\n"
idxBA := [bs indexOfSubCollection: #[72 84 84 80] startingAt: 1] on: Core.Exception do: [:ex | 'ERR:', ex class name asString].
s nextPutAll: 'idx of HTTP bytes => '; nextPutAll: idxBA printString; nextPutAll: nl.
idxBA := [bs indexOfSubCollection: #[200] startingAt: 1] on: Core.Exception do: [:ex | 'ERR:', ex class name asString].
s nextPutAll: 'idx of #[200] byte => '; nextPutAll: idxBA printString; nextPutAll: nl.

"Step 3: ByteArray slice -> String via character mapping"
s nextPutAll: '=== 3. ByteArray -> String character mapping ==='; nextPutAll: nl.
sliceBytes := #[72 84 84 80 47 49 46 49 32 50 48 48].
convResult := [sliceBytes asString] on: Core.Exception do: [:ex | 'ERR:asString:', ex class name asString].
s nextPutAll: 'asString => '; nextPutAll: convResult printString; nextPutAll: nl.

"Step 4: explicit char-by-char mapping (fallback if asString doesn't exist)"
s nextPutAll: '=== 4. ByteArray collect-with-Char-value: ==='; nextPutAll: nl.
mapped := [| str | str := Core.String new: sliceBytes size. 1 to: sliceBytes size do: [:i | str at: i put: (Core.Character value: (sliceBytes at: i))]. str]
    on: Core.Exception do: [:ex | 'ERR:loop:', ex class name asString, ' | ', (ex messageText ifNil: ['(no msg)'])].
s nextPutAll: 'mapped => '; nextPutAll: mapped printString; nextPutAll: nl.

s contents
