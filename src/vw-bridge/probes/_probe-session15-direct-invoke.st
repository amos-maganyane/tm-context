| tc result |
tc := VWB.VWBridgeTest new.
result := Core.WriteStream on: Core.String new.
result nextPutAll: 'STEP1 instance created. class='; nextPutAll: tc class name; nextPutAll: ' | '.
[tc setUp. result nextPutAll: 'STEP2 setUp OK | ']
    on: Core.Exception
    do: [:ex | 
        result nextPutAll: 'STEP2 setUp EX: '; nextPutAll: ex class name asString; nextPutAll: ' msg='; 
            nextPutAll: (ex messageText ifNil: ['(nil)']); nextPutAll: ' | '].
[tc perform: #testVwBridgeHomeOverrideTakesPriority. result nextPutAll: 'STEP3 test body OK']
    on: Core.Exception
    do: [:ex | 
        result nextPutAll: 'STEP3 test body EX: '; nextPutAll: ex class name asString; nextPutAll: ' msg='; 
            nextPutAll: (ex messageText ifNil: ['(nil)'])].
[tc tearDown] on: Core.Exception do: [:ex | nil].
"defensive: clear override always"
[VWB.VWBridge clearVwBridgeHomeOverride] on: Core.Exception do: [:ex | nil].
result contents
