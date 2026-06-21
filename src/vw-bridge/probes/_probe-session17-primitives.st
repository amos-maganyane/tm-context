"Session-17 Stage 3 primitive probe.
 Verifies the defensive primitives unload.st needs:
 (1) removeSelector: on absent selector - raises or no-op?
 (2) removeFromSystem on already-removed class - raises or no-op?
 (3) namespace empty check + removeFromSystem - safe path
 (4) snapshot of pre-load state for quality-gate comparison
 (5) Kernel.Parcel introspection of VWB-related state"
| s nl absentRemove vwbPreState parcelVwbState patchPresent fileinScopeNote |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Session-17 Stage 3 primitive probe ==='; nextPutAll: nl; nextPutAll: nl.

"(1) Test removeSelector: on an obviously-absent selector"
absentRemove := [Core.Object removeSelector: #vwbridgeStage3AbsentSelectorVWB. 'no raise'] 
    on: Core.Error do: [:ex | 'RAISED: ' , ex class name , ' | ' , ex description].
s nextPutAll: '(1) Object removeSelector: #absent -> '; nextPutAll: absentRemove printString; nextPutAll: nl.

"(1b) Test SimpleDialog removeSelector: on an absent selector (real path - won't actually remove)"
s nextPutAll: '(1b) SimpleDialog removeSelector: #absent -> '; nextPutAll: 
    ([SimpleDialog removeSelector: #vwbridgeStage3AbsentSelectorVWB2. 'no raise'] 
        on: Core.Error do: [:ex | 'RAISED: ' , ex class name , ' | ' , ex description]) printString; nextPutAll: nl.

"(2) Confirm SimpleDialog override is currently present (don't remove it!)"
patchPresent := SimpleDialog includesSelector: #choose:labels:values:default:for:.
s nextPutAll: '(2) SimpleDialog override present: '; nextPutAll: patchPresent printString; nextPutAll: nl.
patchPresent ifTrue: [
    s nextPutAll: '    category = '; 
    nextPutAll: (SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) printString;
    nextPutAll: nl].

"(3) Snapshot pre-load state - the values we want unload.st to fully zero out and load.st to fully restore"
vwbPreState := Core.Dictionary new.
vwbPreState at: 'VWB-binding-present' put: ((Smalltalk at: #VWB ifAbsent: [nil]) notNil) printString.
vwbPreState at: 'VWB-class-count' put: 
    (((Smalltalk at: #VWB ifAbsent: [nil]) 
        ifNil: [0] 
        ifNotNil: [:ns | ns keys size])) printString.
vwbPreState at: 'VWB-class-names' put: 
    (((Smalltalk at: #VWB ifAbsent: [nil]) 
        ifNil: [#()] 
        ifNotNil: [:ns | ns classNames asSortedCollection asArray])) printString.
vwbPreState at: 'top-level-VWBridge' put: ((Smalltalk at: #VWBridge ifAbsent: [nil]) printString).
vwbPreState at: 'SimpleDialog-override-installed' put: patchPresent printString.
vwbPreState at: 'token-file-exists' put: 
    ([(VWB.VWBridge tokenFilePath) asFilename exists] on: Core.Error do: [:ex | 'ERR: ' , ex description]) printString.
vwbPreState at: 'token-file-path' put: 
    ([VWB.VWBridge tokenFilePath] on: Core.Error do: [:ex | 'ERR: ' , ex description]) printString.
vwbPreState at: 'bridge-singleton-present' put: (VWB.VWBridge singleton notNil) printString.
vwbPreState at: 'bridge-token' put: 
    ([VWB.VWBridge singleton token] on: Core.Error do: [:ex | nil]) printString.

s nextPutAll: '(3) Pre-load state snapshot:'; nextPutAll: nl.
vwbPreState keys asSortedCollection do: [:k |
    s nextPutAll: '    '; nextPutAll: k; nextPutAll: ' = '; 
      nextPutAll: (vwbPreState at: k); nextPutAll: nl].

"(4) Kernel.Parcel introspection - what does Parcel know about VWB?"
parcelVwbState := Core.Dictionary new.
parcelVwbState at: 'loaded-parcels-count' put: Kernel.Parcel parcels size printString.
parcelVwbState at: 'parcels-named-VWBridge' put: 
    ((Kernel.Parcel parcelNames select: [:nm | (nm asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0]) printString).
parcelVwbState at: 'parcels-named-VWB' put: 
    ((Kernel.Parcel parcelNames select: [:nm | (nm asString indexOfSubCollection: 'VWB' startingAt: 1) > 0]) printString).
parcelVwbState at: 'classParcelMap-VWB-keys' put: 
    ([(Kernel.Parcel classParcelMap keys 
        select: [:k | (k asString indexOfSubCollection: 'VWB' startingAt: 1) > 0]) asArray] 
        on: Core.Error do: [:ex | 'ERR: ' , ex description]) printString.

s nextPutAll: '(4) Kernel.Parcel introspection:'; nextPutAll: nl.
parcelVwbState keys asSortedCollection do: [:k |
    s nextPutAll: '    '; nextPutAll: k; nextPutAll: ' = '; 
      nextPutAll: (parcelVwbState at: k); nextPutAll: nl].

"(5) Note: fileIn on a .st file via Smalltalk-Compiler reads + executes chunks.
 'path' asFilename fileIn raises EndOfStreamNotification at EOF (constraint #24).
 Confirm via cheap test - what selectors does 'asFilename' produce?"
fileinScopeNote := ('C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename) class name.
s nextPutAll: '(5) asFilename class = '; nextPutAll: fileinScopeNote; nextPutAll: nl.

s contents
