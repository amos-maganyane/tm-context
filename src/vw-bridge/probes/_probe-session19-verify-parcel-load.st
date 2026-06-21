"Probe session-19 step 22: in-place verify VWBridge.pcl loads correctly.

DESTRUCTIVE: unloads current bridge state, loads from .pcl, asserts state restored.
Mirror of session-17 'In-place-unload-load-quality-gate-test' technique - /eval handler
runs on different process than listener, survives stop, can file in + start new listener.

PHASES:
  1. pre-state snapshot
  2. unload (stop listener, remove SimpleDialog override, remove VWB classes + namespace)
  3. post-unload snapshot (assert VWB absent)
  4. Kernel.Parcel loadParcelFrom: VWBridge.pcl
  5. post-load snapshot (assert VWB.VWBridge + SimpleDialog override restored)
  6. try VWBridge start (new listener; bridge UP again)
  7. write new .token for future /eval auth"
| s nl pclPath preToken loadResult bridgeStartResult tokenWriteResult newToken tokenPath |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

pclPath := (OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME') , '\.generated\parcels\VWBridge.pcl'.

"=== PHASE 1: pre-state snapshot ==="
s nextPutAll: '=== PHASE 1 pre-state ==='; nextPutAll: nl.
s nextPutAll: '  VWB env name = '; nextPutAll: VWB.VWBridge environment name printString; nextPutAll: nl.
s nextPutAll: '  VWB keys count = '; nextPutAll: VWB keys size printString; nextPutAll: nl.
preToken := VWB.VWBridge singleton token.
s nextPutAll: '  current token = '; nextPutAll: preToken; nextPutAll: nl.

"=== PHASE 2: unload (mirror unload.st structure) ==="
s nextPutAll: '=== PHASE 2 unload ==='; nextPutAll: nl.
[VWB.VWBridge stop] on: Core.Exception do: [:ex | nil].
[Smalltalk.SimpleDialog removeSelector: #choose:labels:values:default:for:] on: Core.Exception do: [:ex | nil].
[(VWB at: #VWBridgeScreenshotTest ifAbsent: [nil]) ifNotNil: [:c | c removeFromSystem]] on: Core.Exception do: [:ex | nil].
[(VWB at: #VWBridgeWaitTest ifAbsent: [nil]) ifNotNil: [:c | c removeFromSystem]] on: Core.Exception do: [:ex | nil].
[(VWB at: #VWBridgeTest ifAbsent: [nil]) ifNotNil: [:c | c removeFromSystem]] on: Core.Exception do: [:ex | nil].
[(VWB at: #VWBridge ifAbsent: [nil]) ifNotNil: [:c | c removeFromSystem]] on: Core.Exception do: [:ex | nil].
((Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns | ns keys isEmpty]) ifTrue: [
    [(Smalltalk at: #VWB) removeFromSystem] on: Core.Exception do: [:ex | nil]].
s nextPutAll: '  unload sequence completed'; nextPutAll: nl.

"=== PHASE 3: post-unload snapshot ==="
s nextPutAll: '=== PHASE 3 post-unload ==='; nextPutAll: nl.
s nextPutAll: '  VWB-present = '; nextPutAll: (Smalltalk includesKey: #VWB) printString; nextPutAll: nl.
s nextPutAll: '  override-present = '; nextPutAll: (Smalltalk.SimpleDialog includesSelector: #choose:labels:values:default:for:) printString; nextPutAll: nl.

"=== PHASE 4: loadParcelFrom: ==="
s nextPutAll: '=== PHASE 4 loadParcelFrom: ==='; nextPutAll: nl.
loadResult := [[Kernel.Parcel loadParcelFrom: pclPath asFilename] on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | 'EXC: ' , ex class name asString , ' / ' , ex description].
s nextPutAll: '  load result = '; nextPutAll: loadResult printString; nextPutAll: nl.

"=== PHASE 5: post-load snapshot ==="
s nextPutAll: '=== PHASE 5 post-load ==='; nextPutAll: nl.
s nextPutAll: '  VWB-present = '; nextPutAll: (Smalltalk includesKey: #VWB) printString; nextPutAll: nl.
s nextPutAll: '  VWB-keys = '; 
nextPutAll: ((Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns | ns keys asSortedCollection asArray printString] ifNil: ['nil']); 
nextPutAll: nl.
s nextPutAll: '  override-present = '; nextPutAll: (Smalltalk.SimpleDialog includesSelector: #choose:labels:values:default:for:) printString; nextPutAll: nl.
s nextPutAll: '  override-category = '; 
nextPutAll: ((Smalltalk.SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) ifNil: ['nil']) printString; 
nextPutAll: nl.

"=== PHASE 6: bridge start ==="
s nextPutAll: '=== PHASE 6 bridge start ==='; nextPutAll: nl.
bridgeStartResult := [
    | cls |
    cls := (Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns | ns at: #VWBridge ifAbsent: [nil]].
    cls ifNil: ['no VWBridge class after load'] ifNotNil: [
        cls start.
        newToken := cls singleton token.
        'start-ok, token=' , newToken]
] on: Core.Exception do: [:ex | 'EXC: ' , ex description].
s nextPutAll: '  '; nextPutAll: bridgeStartResult printString; nextPutAll: nl.

"=== PHASE 7: write new .token for future /eval auth ==="
s nextPutAll: '=== PHASE 7 token write ==='; nextPutAll: nl.
newToken isNil 
    ifTrue: [s nextPutAll: '  no token to write'; nextPutAll: nl]
    ifFalse: [
        tokenPath := (Smalltalk at: #VWB) at: #VWBridge ifAbsent: [nil].
        tokenPath ifNotNil: [:cls | tokenPath := cls tokenFilePath].
        tokenWriteResult := [
            | ws |
            ws := tokenPath asFilename writeStream.
            ws nextPutAll: newToken.
            ws close.
            'token-written-to ' , tokenPath
        ] on: Core.Exception do: [:ex | 'EXC: ' , ex description].
        s nextPutAll: '  '; nextPutAll: tokenWriteResult printString; nextPutAll: nl].

s contents
