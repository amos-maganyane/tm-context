| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | cls result |
    cls := VWB at: nm ifAbsent: [nil].
    s nextPutAll: nm asString; nextPutAll: ': '.
    cls isNil
        ifTrue: [s nextPutAll: 'ABSENT'; nextPutAll: nl]
        ifFalse: [
            result := 'STUB-RESULT'.
            s nextPutAll: result; nextPutAll: nl]].
s contents
