"Probe session-19 step 18: detailed MNU receiver capture from CodeWriter write.

Step 17 got MNU '#removeKey:ifAbsent:' DEEP in writeToParcelFileNamed:... call chain.
No wedge (Bridge alive, registry restored). Need: receiver class + receiver printString + selector.

Also probes CodeWriter's full setter API to identify any missing setup we owe before write."
| s nl parcel writer pclPath pstPath home setters allInstSels |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
pclPath := home , '\.generated\parcels\_test-codewriter.pcl'.
pstPath := home , '\.generated\parcels\_test-codewriter.pst'.

"List ALL CodeWriter inst-side setters (selectors ending in :)"
allInstSels := (CodeWriter selectors asArray) asSortedCollection asArray.
setters := allInstSels select: [:sel | 
    (sel asString last == $:) and: [sel numArgs = 1]].
s nextPutAll: '=== CodeWriter inst-side SETTERS (1-arg, ends in :) ==='; nextPutAll: nl.
setters do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

"Setup + write with detailed exception capture"
parcel := Kernel.Parcel createParcelNamed: 'Test-CW-MNU'.
parcel addEntiretyOfClass: VWB.VWBridge.
writer := CodeWriter new.
writer codeComponent: parcel.

s nextPutAll: '=== detailed write attempt ==='; nextPutAll: nl.
[[writer 
    writeToParcelFileNamed: pclPath asFilename
    sourceFileNamed: pstPath asFilename
    oldSourceIndex: nil
    hideSource: true
    republish: false
    backup: false]
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  exception class = '; nextPutAll: ex class name asString; nextPutAll: nl.
        s nextPutAll: '  description = '; nextPutAll: ex description; nextPutAll: nl.
        [s nextPutAll: '  receiver class = '; nextPutAll: ex receiver class name asString; nextPutAll: nl]
            on: Core.Exception do: [:e | s nextPutAll: '  (receiver class introspect ERR)'; nextPutAll: nl].
        [s nextPutAll: '  receiver printString = '; nextPutAll: ex receiver printString; nextPutAll: nl]
            on: Core.Exception do: [:e | s nextPutAll: '  (receiver printString ERR)'; nextPutAll: nl].
        [s nextPutAll: '  selector = '; nextPutAll: ex selector printString; nextPutAll: nl]
            on: Core.Exception do: [:e | s nextPutAll: '  (selector ERR)'; nextPutAll: nl]].

"Cleanup"
[[Kernel.Parcel removeParcelNamed: 'Test-CW-MNU'] 
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | nil].
s nextPutAll: 'cleanup-registry-size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
s nextPutAll: 'pcl-exists = '; nextPutAll: pclPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'pst-exists = '; nextPutAll: pstPath asFilename exists printString; nextPutAll: nl.

s contents
