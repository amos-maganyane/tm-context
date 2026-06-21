"Stage 2 verification - confirm namespace migration completed cleanly. Checks: (a) VWB namespace exists and contains 4 expected classes; (b) old top-level Root.Smalltalk.VWBridge + test classes are REMOVED (byte-equivalent gate); (c) class categories correct; (d) SimpleDialog patch still in *VWBridge-Patches category; (e) bridge is actually the new VWB.VWBridge singleton."
| s nl vwbNS singleton |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. VWB namespace presence + contents."
s nextPutAll: '-- VWB namespace --'; nextPutAll: nl.
vwbNS := Smalltalk at: #VWB ifAbsent: [nil].
s nextPutAll: '  Smalltalk at: VWB = '; nextPutAll: vwbNS printString; nextPutAll: nl.
vwbNS notNil ifTrue: [
    s nextPutAll: '  class: '; nextPutAll: vwbNS class name; nextPutAll: nl.
    s nextPutAll: '  keys (count='; nextPutAll: vwbNS keys size printString; nextPutAll: '): '.
    s nextPutAll: vwbNS keys asSortedCollection asArray printString; nextPutAll: nl].

"2. Verify each new class is reachable."
s nextPutAll: nl; nextPutAll: '-- VWB.* class lookups --'; nextPutAll: nl.
#(#VWBridge #VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | cls |
    cls := vwbNS at: nm ifAbsent: [nil].
    s nextPutAll: '  VWB.'; nextPutAll: nm asString; nextPutAll: ' = '; nextPutAll: cls printString.
    cls notNil ifTrue: [
        s nextPutAll: ' (env='; nextPutAll: cls environment name; nextPutAll: ', cat='; nextPutAll: cls category printString; nextPutAll: ')'].
    s nextPutAll: nl].

"3. Old top-level should be GONE (byte-equivalent gate)."
s nextPutAll: nl; nextPutAll: '-- Old top-level Root.Smalltalk.* (expect ALL <GONE>) --'; nextPutAll: nl.
#(#VWBridge #VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | cls |
    cls := Smalltalk at: nm ifAbsent: ['<GONE>'].
    s nextPutAll: '  Smalltalk at: '; nextPutAll: nm asString; nextPutAll: ' = '.
    (cls isString and: [cls = '<GONE>'])
        ifTrue: [s nextPutAll: '<GONE>']
        ifFalse: [
            s nextPutAll: cls printString.
            cls class isClass ifTrue: [s nextPutAll: ' (env='; nextPutAll: cls environment name; nextPutAll: ')']].
    s nextPutAll: nl].

"4. SimpleDialog patch still in *VWBridge-Patches category."
s nextPutAll: nl; nextPutAll: '-- SimpleDialog patch status --'; nextPutAll: nl.
[s nextPutAll: '  method exists: '; nextPutAll: ((SimpleDialog compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil]) notNil) printString; nextPutAll: nl.
 s nextPutAll: '  method category: '; nextPutAll: (SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  ERR '; nextPutAll: e messageText; nextPutAll: nl].

"5. Active bridge is the new VWB.VWBridge singleton."
s nextPutAll: nl; nextPutAll: '-- Active bridge identity --'; nextPutAll: nl.
[singleton := VWB.VWBridge singleton.
 s nextPutAll: '  VWB.VWBridge singleton class: '; nextPutAll: singleton class name; nextPutAll: nl.
 s nextPutAll: '  singleton class environment: '; nextPutAll: singleton class environment name; nextPutAll: nl.
 s nextPutAll: '  port: '; nextPutAll: singleton port printString; nextPutAll: nl.
 s nextPutAll: '  token prefix: '; nextPutAll: (singleton token copyFrom: 1 to: (10 min: singleton token size)); nextPutAll: nl.
 s nextPutAll: '  vwBridgeHome: '; nextPutAll: VWB.VWBridge vwBridgeHome; nextPutAll: nl.
 s nextPutAll: '  tokenFilePath: '; nextPutAll: VWB.VWBridge tokenFilePath; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  ERR '; nextPutAll: e messageText; nextPutAll: nl].

s contents