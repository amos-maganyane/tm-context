| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | cls suite |
    cls := VWB at: nm ifAbsent: [nil].
    s nextPutAll: nm asString; nextPutAll: ': '.
    cls isNil
        ifTrue: [s nextPutAll: 'ABSENT'; nextPutAll: nl]
        ifFalse: [
            suite := cls suite.
            s nextPutAll: suite class name; nextPutAll: ' size='; nextPutAll: suite tests size printString; nextPutAll: nl]].
s contents
