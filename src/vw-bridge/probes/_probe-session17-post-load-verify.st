"Session-17 post-load.st verification probe.
 Verifies load.st left the image in the expected state:
   - VWB namespace present with 4 classes
   - SimpleDialog override installed
   - bridge singleton present
   - token matches .token file
   - top-level Smalltalk.VWBridge absent (Stage 2 invariant)"
| s nl postState |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== Post load.st verification ==='; nextPutAll: nl.

postState := Core.Dictionary new.
postState at: 'VWB-binding-present' put: ((Smalltalk at: #VWB ifAbsent: [nil]) notNil) printString.
postState at: 'VWB-class-count' put: 
    (((Smalltalk at: #VWB ifAbsent: [nil]) 
        ifNil: [0] 
        ifNotNil: [:ns | ns keys size])) printString.
postState at: 'VWB-class-names' put: 
    (((Smalltalk at: #VWB ifAbsent: [nil]) 
        ifNil: [#()] 
        ifNotNil: [:ns | ns classNames asSortedCollection asArray])) printString.
postState at: 'top-level-VWBridge' put: ((Smalltalk at: #VWBridge ifAbsent: [nil]) printString).
postState at: 'SimpleDialog-override-installed' put: 
    (SimpleDialog includesSelector: #choose:labels:values:default:for:) printString.
postState at: 'SimpleDialog-override-category' put: 
    (SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) printString.
postState at: 'bridge-singleton-present' put: (VWB.VWBridge singleton notNil) printString.
postState at: 'bridge-token' put: VWB.VWBridge singleton token.
postState at: 'bridge-port' put: VWB.VWBridge singleton port printString.
postState at: 'token-file-exists' put: 
    (VWB.VWBridge tokenFilePath asFilename exists) printString.
postState at: 'token-file-path' put: VWB.VWBridge tokenFilePath.

postState keys asSortedCollection do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '; 
      nextPutAll: (postState at: k); nextPutAll: nl].

s contents
