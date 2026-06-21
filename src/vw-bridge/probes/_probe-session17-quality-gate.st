"=== Session-17 Stage 3 quality-gate test ===
 Full unload + load + verify cycle in a single /eval body.

 Strategy: the /eval handler runs on a forked process from the listener.
 When unload.st calls VWB.VWBridge stop, the LISTENER process dies but the
 HANDLER process keeps running (different process). The handler can then
 file-in + start a NEW listener and respond via the still-open client socket.

 To avoid compile-time binding to VWB.VWBridge (which gets removed during
 unload), the LOAD section uses dynamic Smalltalk at: #VWB lookups. The
 UNLOAD section can use VWB.VWBridge refs because the class exists when
 the body is compiled.

 file-in raises EndOfStreamNotification at EOF (constraint #24) - leave
 unwrapped so notification auto-resumes at top-level handler."

| s nl preState postUnloadState postLoadState
  tokenPath classNamesInRemoveOrder home homeFilename srcFile newVwBridgeCls newTokenStream |

s := WriteStream on: String new.
nl := String with: Core.Character lf.

"=========================================="
"PHASE 1: pre-state snapshot (uses VWB.VWBridge - exists at compile + execution)"
"=========================================="
preState := Core.Dictionary new.
preState at: 'VWB-present' put: ((Smalltalk at: #VWB ifAbsent: [nil]) notNil) printString.
preState at: 'VWB-class-count' put:
    ((Smalltalk at: #VWB ifAbsent: [nil]) ifNil: [0] ifNotNil: [:ns | ns keys size]) printString.
preState at: 'VWB-class-names' put:
    ((Smalltalk at: #VWB ifAbsent: [nil]) ifNil: [#()] ifNotNil: [:ns | ns classNames asSortedCollection asArray]) printString.
preState at: 'top-level-VWBridge' put: (Smalltalk at: #VWBridge ifAbsent: [nil]) printString.
preState at: 'SimpleDialog-override-installed' put:
    (SimpleDialog includesSelector: #choose:labels:values:default:for:) printString.
preState at: 'bridge-singleton-present' put:
    ((Smalltalk at: #VWB ifAbsent: [nil])
        ifNil: [false]
        ifNotNil: [:ns | (ns at: #VWBridge ifAbsent: [nil]) notNil
            and: [(ns at: #VWBridge) singleton notNil]]) printString.
preState at: 'token-file-exists' put:
    ([(VWB.VWBridge tokenFilePath) asFilename exists] on: Core.Error do: [:ex | false]) printString.
preState at: 'parcels-named-VWBridge-count' put:
    (Kernel.Parcel parcelNames select: [:nm | (nm asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0]) size printString.

s nextPutAll: '=== PHASE 1: pre-state snapshot ==='; nextPutAll: nl.
preState keys asSortedCollection do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '; nextPutAll: (preState at: k); nextPutAll: nl].
s nextPutAll: nl.

"=========================================="
"PHASE 2: run unload body inline (kills listener but handler survives)"
"=========================================="
s nextPutAll: '=== PHASE 2: unload body ==='; nextPutAll: nl.

"(2.1) Capture tokenPath BEFORE class is gone"
tokenPath := [VWB.VWBridge tokenFilePath] on: Core.Error do: [:ex | nil].
s nextPutAll: '  unload(1) tokenPath captured = '; nextPutAll: tokenPath printString; nextPutAll: nl.

"(2.2) Stop bridge listener"
[(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
    (ns at: #VWBridge ifAbsent: [nil]) ifNotNil: [:cls |
        s nextPutAll: '  unload(2) stopping listener'; nextPutAll: nl.
        cls stop]]]
    on: Core.Error do: [:ex |
        s nextPutAll: '  WARN unload(2): '; nextPutAll: ex description; nextPutAll: nl].

"(2.3) Delete .token"
tokenPath ifNotNil: [
    | tokenFile |
    tokenFile := tokenPath asFilename.
    [tokenFile exists ifTrue: [
        tokenFile delete.
        s nextPutAll: '  unload(3) .token deleted'; nextPutAll: nl]]
        on: Core.Error do: [:ex |
            s nextPutAll: '  WARN unload(3): '; nextPutAll: ex description; nextPutAll: nl]].

"(2.4) Remove SimpleDialog override"
[(SimpleDialog includesSelector: #choose:labels:values:default:for:) ifTrue: [
    SimpleDialog removeSelector: #choose:labels:values:default:for:.
    s nextPutAll: '  unload(4) SimpleDialog override removed'; nextPutAll: nl]]
    on: Core.Error do: [:ex |
        s nextPutAll: '  WARN unload(4): '; nextPutAll: ex description; nextPutAll: nl].

"(2.5) Remove 4 VWB classes in reverse-dep order"
classNamesInRemoveOrder := #(#VWBridgeScreenshotTest #VWBridgeWaitTest #VWBridgeTest #VWBridge).
classNamesInRemoveOrder do: [:nm |
    [(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
        (ns at: nm ifAbsent: [nil]) ifNotNil: [:cls |
            s nextPutAll: '  unload(5) removing VWB.'; nextPutAll: nm asString; nextPutAll: nl.
            cls removeFromSystem]]]
        on: Core.Error do: [:ex |
            s nextPutAll: '  WARN unload(5) VWB.'; nextPutAll: nm asString;
              nextPutAll: ': '; nextPutAll: ex description; nextPutAll: nl]].

"(2.6) Remove empty VWB namespace"
[(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
    ns keys isEmpty
        ifTrue: [
            ns removeFromSystem.
            s nextPutAll: '  unload(6) VWB namespace removed'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: '  WARN unload(6) VWB has '; nextPutAll: ns keys size printString;
              nextPutAll: ' residual keys: '; nextPutAll: ns keys asSortedCollection printString; nextPutAll: nl]]]
    on: Core.Error do: [:ex |
        s nextPutAll: '  WARN unload(6): '; nextPutAll: ex description; nextPutAll: nl].
s nextPutAll: nl.

"=========================================="
"PHASE 3: post-unload state snapshot (dynamic lookups; VWB.VWBridge is GONE)"
"=========================================="
postUnloadState := Core.Dictionary new.
postUnloadState at: 'VWB-present' put: ((Smalltalk at: #VWB ifAbsent: [nil]) notNil) printString.
postUnloadState at: 'top-level-VWBridge' put: (Smalltalk at: #VWBridge ifAbsent: [nil]) printString.
postUnloadState at: 'SimpleDialog-override-installed' put:
    (SimpleDialog includesSelector: #choose:labels:values:default:for:) printString.
postUnloadState at: 'token-file-exists' put:
    (tokenPath ifNil: [false] ifNotNil: [tokenPath asFilename exists]) printString.
postUnloadState at: 'parcels-named-VWBridge-count' put:
    (Kernel.Parcel parcelNames select: [:nm | (nm asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0]) size printString.
postUnloadState at: 'classParcelMap-VWB-keys' put:
    (Kernel.Parcel classParcelMap keys select: [:k | (k asString indexOfSubCollection: 'VWB' startingAt: 1) > 0]) printString.

s nextPutAll: '=== PHASE 3: post-unload snapshot ==='; nextPutAll: nl.
postUnloadState keys asSortedCollection do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '; nextPutAll: (postUnloadState at: k); nextPutAll: nl].
s nextPutAll: nl.

"=========================================="
"PHASE 4: run load body inline (DYNAMIC lookups - VWB.VWBridge re-created mid-flight)"
"=========================================="
s nextPutAll: '=== PHASE 4: load body ==='; nextPutAll: nl.

"(4.1) Resolve VW_BRIDGE_HOME"
home := OS.CEnvironment userEnvironment
    at: 'VW_BRIDGE_HOME'
    ifAbsent: [self error: 'VW_BRIDGE_HOME env var is not set'].
homeFilename := home asFilename.
s nextPutAll: '  load(1) VW_BRIDGE_HOME = '; nextPutAll: home; nextPutAll: nl.

"(4.2) File-in 5 source files (defines VWB namespace + 4 classes + installs override)"
#('VWBridge.st' 'VWBridge-Patches.st' 'VWBridge-Test.st' 'VWBridge-WaitTest.st' 'VWBridge-ScreenshotTest.st') do: [:fname |
    srcFile := (home , '\' , fname) asFilename.
    srcFile exists
        ifTrue: [
            s nextPutAll: '  load(2) fileIn: '; nextPutAll: fname; nextPutAll: nl.
            srcFile fileIn]
        ifFalse: [self error: '[load] missing source file: ', srcFile asString]].

"(4.3) DYNAMIC lookup of newly-defined VWB.VWBridge (avoids compile-time binding to old class)"
newVwBridgeCls := (Smalltalk at: #VWB ifAbsent: [nil])
    ifNotNil: [:ns | ns at: #VWBridge ifAbsent: [nil]].
newVwBridgeCls isNil ifTrue: [
    self error: '[load] VWB.VWBridge missing after file-in - cannot start'].

"(4.4) Start bridge listener via dynamic class ref"
s nextPutAll: '  load(3) starting bridge via dynamic class ref'; nextPutAll: nl.
newVwBridgeCls start.

"(4.5) Write .token via dynamic class ref"
newTokenStream := [newVwBridgeCls tokenFilePath asFilename writeStream]
    on: Core.Error do: [:ex | nil].
newTokenStream == nil
    ifTrue: [s nextPutAll: '  WARN load(4): could not open .token writeStream'; nextPutAll: nl]
    ifFalse: [
        [newTokenStream lineEndTransparent] on: Core.Error do: [:ex | nil].
        newTokenStream nextPutAll: newVwBridgeCls singleton token.
        newTokenStream close.
        s nextPutAll: '  load(4) .token written, new token = ';
          nextPutAll: newVwBridgeCls singleton token; nextPutAll: nl].
s nextPutAll: nl.

"=========================================="
"PHASE 5: post-load state snapshot (back to using VWB.VWBridge via dynamic lookup)"
"=========================================="
postLoadState := Core.Dictionary new.
postLoadState at: 'VWB-present' put: ((Smalltalk at: #VWB ifAbsent: [nil]) notNil) printString.
postLoadState at: 'VWB-class-count' put:
    ((Smalltalk at: #VWB ifAbsent: [nil]) ifNil: [0] ifNotNil: [:ns | ns keys size]) printString.
postLoadState at: 'VWB-class-names' put:
    ((Smalltalk at: #VWB ifAbsent: [nil]) ifNil: [#()] ifNotNil: [:ns | ns classNames asSortedCollection asArray]) printString.
postLoadState at: 'top-level-VWBridge' put: (Smalltalk at: #VWBridge ifAbsent: [nil]) printString.
postLoadState at: 'SimpleDialog-override-installed' put:
    (SimpleDialog includesSelector: #choose:labels:values:default:for:) printString.
postLoadState at: 'SimpleDialog-override-category' put:
    (SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) printString.
postLoadState at: 'bridge-singleton-present' put:
    ((Smalltalk at: #VWB ifAbsent: [nil])
        ifNil: [false]
        ifNotNil: [:ns | (ns at: #VWBridge ifAbsent: [nil]) notNil
            and: [(ns at: #VWBridge) singleton notNil]]) printString.
postLoadState at: 'bridge-token' put:
    ([newVwBridgeCls singleton token] on: Core.Error do: [:ex | 'ERR']) printString.
postLoadState at: 'bridge-port' put:
    ([newVwBridgeCls singleton port] on: Core.Error do: [:ex | 'ERR']) printString.
postLoadState at: 'token-file-exists' put:
    ([newVwBridgeCls tokenFilePath asFilename exists] on: Core.Error do: [:ex | 'ERR']) printString.

s nextPutAll: '=== PHASE 5: post-load snapshot ==='; nextPutAll: nl.
postLoadState keys asSortedCollection do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '; nextPutAll: (postLoadState at: k); nextPutAll: nl].

s nextPutAll: nl.
s nextPutAll: '=== Quality gate check ==='; nextPutAll: nl.
s nextPutAll: '  post-unload VWB-present should be false: '; 
    nextPutAll: ((postUnloadState at: 'VWB-present') = 'false') printString; nextPutAll: nl.
s nextPutAll: '  post-unload SimpleDialog override should be removed: ';
    nextPutAll: ((postUnloadState at: 'SimpleDialog-override-installed') = 'false') printString; nextPutAll: nl.
s nextPutAll: '  post-unload .token should be gone: ';
    nextPutAll: ((postUnloadState at: 'token-file-exists') = 'false') printString; nextPutAll: nl.
s nextPutAll: '  post-load VWB has 4 classes: ';
    nextPutAll: ((postLoadState at: 'VWB-class-count') = '4') printString; nextPutAll: nl.
s nextPutAll: '  post-load SimpleDialog override re-installed: ';
    nextPutAll: ((postLoadState at: 'SimpleDialog-override-installed') = 'true') printString; nextPutAll: nl.
s nextPutAll: '  post-load bridge singleton present: ';
    nextPutAll: ((postLoadState at: 'bridge-singleton-present') = 'true') printString; nextPutAll: nl.

s contents
