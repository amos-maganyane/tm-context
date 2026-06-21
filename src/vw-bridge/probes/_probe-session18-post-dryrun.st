"Probe session-18 post dry-run verification of VWB.VWBridge identity + Bug#2 fix.

Defensive: useNativeDialogs unary getter doesnt exist in this image - only the
useNativeDialogs: keyword setter does. Verifies the setter response shape instead."

| s nl override ns vwb top dialog dialogClass setterRespond |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

ns := VWB.VWBridge environment name.
vwb := Smalltalk at: #VWB ifAbsent: [nil].
top := Smalltalk at: #VWBridge ifAbsent: [nil].

s nextPutAll: 'env-name='; nextPutAll: ns printString; nextPutAll: nl.
s nextPutAll: 'top-level-VWBridge='; nextPutAll: top printString; nextPutAll: nl.
s nextPutAll: 'VWB-keys-count='; nextPutAll: vwb keys size printString; nextPutAll: nl.
s nextPutAll: 'VWB-keys='; nextPutAll: (vwb keys asSortedCollection asArray collect: [:k | k asString]) printString; nextPutAll: nl.
s nextPutAll: 'singleton-token='; nextPutAll: VWB.VWBridge singleton token; nextPutAll: nl.
s nextPutAll: 'singleton-port='; nextPutAll: VWB.VWBridge singleton port printString; nextPutAll: nl.

override := SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:.
s nextPutAll: 'SimpleDialog-override-category='; nextPutAll: override printString; nextPutAll: nl.

dialog := Smalltalk at: #Dialog ifAbsent: [nil].
dialogClass := dialog isNil ifTrue: [nil] ifFalse: [dialog class].
s nextPutAll: 'Dialog-class='; nextPutAll: (dialog isNil ifTrue: ['NIL'] ifFalse: [dialog class name]); nextPutAll: nl.
setterRespond := dialog isNil ifTrue: [false] ifFalse: [dialogClass canUnderstand: #useNativeDialogs:].
s nextPutAll: 'Dialog-class-canUnderstand-useNativeDialogs:='; nextPutAll: setterRespond printString; nextPutAll: nl.

"Try a few possible getter shapes - belt-and-suspenders.
Each guarded with respondsTo: BEFORE the perform: so MNU never happens."
#(#useNativeDialogs #usesNativeDialogs #nativeDialogs) do: [:sel |
    | resp |
    resp := (dialogClass canUnderstand: sel)
        ifTrue: [
            [(dialog perform: sel) printString]
                on: Core.Exception do: [:ex | 'ERR=' , ex class name asString]]
        ifFalse: ['NOT-UNDERSTOOD'].
    s nextPutAll: '  try-getter '; nextPutAll: sel asString; nextPutAll: ': '; nextPutAll: resp; nextPutAll: nl].

s contents
