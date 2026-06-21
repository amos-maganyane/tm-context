"Probe Step 18 socket-write: inspect what selectors the external socket
 stream supports for binary-safe writes. We need to know whether a flip to
 binary mode plus nextPutAll: ByteArray works (analog to Step 17 outStream
 binary fix), or whether a different write strategy is needed.

 Strategy: open a SocketAccessor TCP server on a side port (9877), accept
 a self-loopback connection, inspect the connection stream class + selectors,
 try writing a small ByteArray with various strategies, report what worked.

 Comment hygiene: zero exclamation marks. No router substring.
 Side effects: binds port 9877 temporarily then releases.
 Read-only on bridge state."

| s nl serverSock client connSock connStream connClass binaryOK byteArrayWriteOK perCharWriteOK loopThread loopErr port sa |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Probe step18 socket-write API surface ==='; nextPutAll: nl.

port := 9877.

"--- A. Find SocketAccessor class ---"
sa := Smalltalk at: #SocketAccessor ifAbsent: [
	OS at: #SocketAccessor ifAbsent: [nil]].
sa isNil
	ifTrue: [s nextPutAll: 'FATAL: SocketAccessor not found'; nextPutAll: nl. ^s contents]
	ifFalse: [s nextPutAll: 'SocketAccessor class = '; nextPutAll: sa name; nextPutAll: nl].

"--- B. Start side TCP listener on port 9877 + fork acceptor ---"
serverSock := [sa newTCPserverAtPort: port]
	on: Error do: [:e |
		s nextPutAll: 'cannot bind port '; nextPutAll: port printString; 
		nextPutAll: ': '; nextPutAll: e messageText; nextPutAll: nl. 
		nil].
serverSock isNil ifTrue: [^s contents].
[(serverSock respondsTo: #listenFor:) ifTrue: [serverSock listenFor: 5]]
	on: Error do: [:e | nil].
s nextPutAll: 'side listener bound on port '; nextPutAll: port printString; nextPutAll: nl.

"--- C. Fork the accept loop - wait briefly for client side to connect ---"
connSock := nil.
loopErr := nil.
loopThread := [
	[connSock := serverSock accept]
		on: Error do: [:e | loopErr := e messageText]] fork.

"--- D. Client side: connect to 127.0.0.1:9877 ---"
client := [sa newTCPclientToHost: '127.0.0.1' port: port]
	on: Error do: [:e |
		s nextPutAll: 'client connect failed: '; nextPutAll: e messageText; nextPutAll: nl.
		nil].

"--- E. Brief sleep so the accept-fork has a chance to grab the connection ---"
(Delay forMilliseconds: 200) wait.

connSock isNil
	ifTrue: [
		s nextPutAll: 'connSock still nil after 200ms; loopErr=';
		nextPutAll: loopErr printString; nextPutAll: nl]
	ifFalse: [
		s nextPutAll: nl; nextPutAll: '--- F. Inspect connSock stream ---'; nextPutAll: nl.
		connStream := [
			(connSock respondsTo: #readAppendStream)
				ifTrue: [[connSock readAppendStream] on: Error do: [:e | nil]]
				ifFalse: [
					(connSock respondsTo: #readWriteStream)
						ifTrue: [[connSock readWriteStream] on: Error do: [:e | nil]]
						ifFalse: [nil]]]
			on: Error do: [:e | nil].
		connStream isNil
			ifTrue: [s nextPutAll: 'connStream nil - cannot inspect'; nextPutAll: nl]
			ifFalse: [
				connClass := connStream class name.
				s nextPutAll: 'connStream class = '; nextPutAll: connClass; nextPutAll: nl.
				s nextPutAll: 'supports #binary = '; 
				nextPutAll: (connStream respondsTo: #binary) printString; nextPutAll: nl.
				s nextPutAll: 'supports #nextPutAll: = ';
				nextPutAll: (connStream respondsTo: #nextPutAll:) printString; nextPutAll: nl.
				s nextPutAll: 'supports #nextPut: = ';
				nextPutAll: (connStream respondsTo: #nextPut:) printString; nextPutAll: nl.
				s nextPutAll: 'supports #lineEndTransparent = ';
				nextPutAll: (connStream respondsTo: #lineEndTransparent) printString; nextPutAll: nl.
				s nextPutAll: 'supports #writeByteArray: = ';
				nextPutAll: (connStream respondsTo: #writeByteArray:) printString; nextPutAll: nl.
				s nextPutAll: 'supports #nextPutAllFlush: = ';
				nextPutAll: (connStream respondsTo: #nextPutAllFlush:) printString; nextPutAll: nl.

				"--- G. Try strategy 1: lineEndTransparent + nextPutAll: ByteArray ---"
				s nextPutAll: nl; nextPutAll: '--- G. Strategy 1 (current production) - lineEndTransparent + nextPutAll: ByteArray ---'; nextPutAll: nl.
				[connStream lineEndTransparent] on: Error do: [:e | nil].
				byteArrayWriteOK := [
					connStream nextPutAll: #[137 80 78 71 13 10 26 10].
					'ok']
					on: Error do: [:e | 'ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
				s nextPutAll: 'nextPutAll: bytearray result = '; nextPutAll: byteArrayWriteOK; nextPutAll: nl.

				"--- H. Try strategy 2: binary flip + nextPutAll: ByteArray ---"
				s nextPutAll: nl; nextPutAll: '--- H. Strategy 2 - binary flip + nextPutAll: ByteArray ---'; nextPutAll: nl.
				binaryOK := [connStream binary. 'ok'] on: Error do: [:e | 'ERR ' , e messageText].
				s nextPutAll: 'binary flip result = '; nextPutAll: binaryOK; nextPutAll: nl.
				byteArrayWriteOK := [
					connStream nextPutAll: #[137 80 78 71 13 10 26 10].
					'ok']
					on: Error do: [:e | 'ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
				s nextPutAll: 'nextPutAll: bytearray after binary = '; nextPutAll: byteArrayWriteOK; nextPutAll: nl.

				"--- I. Try strategy 3: nextPut: byte-by-byte loop ---"
				s nextPutAll: nl; nextPutAll: '--- I. Strategy 3 - nextPut: byte-by-byte loop ---'; nextPutAll: nl.
				perCharWriteOK := [
					#[137 80 78 71] do: [:b | connStream nextPut: b].
					'ok']
					on: Error do: [:e | 'ERR ' , e class name , ' - ' , (e messageText ifNil: ['nil'])].
				s nextPutAll: 'nextPut: byte loop = '; nextPutAll: perCharWriteOK; nextPutAll: nl].

		"--- Cleanup ---"
		[connStream notNil ifTrue: [connStream close]] on: Error do: [:e | nil].
		[connSock close] on: Error do: [:e | nil]].

"--- Cleanup ---"
[client notNil ifTrue: [client close]] on: Error do: [:e | nil].
[serverSock close] on: Error do: [:e | nil].
loopThread notNil ifTrue: [[loopThread terminate] on: Error do: [:e | nil]].

s contents
