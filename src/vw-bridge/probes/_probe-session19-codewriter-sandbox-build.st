"Probe session-19 step 17: FIRST destructive build via CodeWriter direct call (Oracle primary path).

Builds a TEST parcel with just VWB.VWBridge (one class) to validate the API + measure
.pcl file size + verify no wedge. If green, proceed to full 2-parcel build.

Pattern (Oracle):
  writer := CodeWriter new.
  writer codeComponent: parcel.
  writer writeToParcelFileNamed: pcl sourceFileNamed: pst oldSourceIndex: nil hideSource: true republish: false backup: false.

writeToParcelFileNamed:sourceFileNamed:... fingerprint (step 16) confirmed:
  - showWhile?=false (no UI wedge)
  - messages do NOT include #asLogicalFileSpecification (no MNU on filename)
  - Uses #ensure: for cleanup, #error: for failures"
| s nl parcel writer pclPath pstPath home preCount cleanup writeResult |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
pclPath := home , '\.generated\parcels\_test-codewriter.pcl'.
pstPath := home , '\.generated\parcels\_test-codewriter.pst'.

"Ensure target dir exists"
((home , '\.generated\parcels') asFilename exists) ifFalse: [
    (home , '\.generated\parcels') asFilename makeDirectory].

"Delete any prior test file"
[pclPath asFilename delete] on: Core.Exception do: [:ex | nil].
[pstPath asFilename delete] on: Core.Exception do: [:ex | nil].

preCount := Kernel.Parcel parcels size.
s nextPutAll: 'pre-build registry size = '; nextPutAll: preCount printString; nextPutAll: nl.

"Create parcel + add content"
parcel := Kernel.Parcel createParcelNamed: 'Test-CodeWriter'.
parcel addEntiretyOfClass: VWB.VWBridge.
s nextPutAll: 'parcel definedThings = '; nextPutAll: parcel definedThings printString; nextPutAll: nl.

"Build via CodeWriter direct call - bypassing parcelOutOn:'s Cursor wait showWhile: wrapper"
writeResult := [[writer := CodeWriter new.
                 writer codeComponent: parcel.
                 writer 
                     writeToParcelFileNamed: pclPath asFilename
                     sourceFileNamed: pstPath asFilename
                     oldSourceIndex: nil
                     hideSource: true
                     republish: false
                     backup: false.
                 'write-completed-cleanly']
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | 
        'EXC: ' , ex class name asString , ' / ' , ex description].
s nextPutAll: 'write-result = '; nextPutAll: writeResult printString; nextPutAll: nl.

"Inspect output"
s nextPutAll: '=== output files ==='; nextPutAll: nl.
s nextPutAll: '  pcl exists = '; nextPutAll: pclPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: '  pst exists = '; nextPutAll: pstPath asFilename exists printString; nextPutAll: nl.

"Cleanup parcel registry - catch both Notification AND Error"
cleanup := [[Kernel.Parcel removeParcelNamed: 'Test-CodeWriter'] 
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | 'ERR:', ex description].
s nextPutAll: 'cleanup = '; nextPutAll: cleanup printString; nextPutAll: nl.
s nextPutAll: 'post-cleanup registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

s contents
