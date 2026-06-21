"Probe session-19 step 21: Build VWBridge-Tests.pcl via Cursor monkey-patch + parcelOutOn:.

Same pattern as step 20 (proven working) but different content:
  - 3 test classes (VWB.VWBridgeTest, VWB.VWBridgeWaitTest, VWB.VWBridgeScreenshotTest)
  - No namespace add (VWB already loaded by VWBridge.pcl on production install)
  - No extension methods"
| s nl oldMethod parcel home pclPath pstPath result preCount patchInstalled |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
pclPath := home , '\.generated\parcels\VWBridge-Tests.pcl'.
pstPath := home , '\.generated\parcels\VWBridge-Tests.pst'.

((home , '\.generated\parcels') asFilename exists) ifFalse: [
    (home , '\.generated\parcels') asFilename makeDirectory].
[pclPath asFilename delete] on: Core.Exception do: [:ex | nil].
[pstPath asFilename delete] on: Core.Exception do: [:ex | nil].

preCount := Kernel.Parcel parcels size.
s nextPutAll: 'pre-build registry size = '; nextPutAll: preCount printString; nextPutAll: nl.

oldMethod := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true.
     s nextPutAll: 'patch installed'; nextPutAll: nl]
        on: Core.Notification do: [:n | n resume].

    patchInstalled ifTrue: [
        parcel := Kernel.Parcel createParcelNamed: 'VWBridge-Tests'.
        parcel addEntiretyOfClasses: (Array
            with: VWB.VWBridgeTest
            with: VWB.VWBridgeWaitTest
            with: VWB.VWBridgeScreenshotTest).
        s nextPutAll: 'parcel content added (3 test classes)'; nextPutAll: nl.

        result := [[parcel
            parcelOutOn: pclPath asFilename
            withSource: pstPath asFilename
            hideOnLoad: false
            republish: false
            backup: false]
            on: Core.Notification do: [:n | n resume]]
            on: Core.Exception do: [:ex |
                'EXC: ' , ex class name asString , ' / ' , ex description].
        s nextPutAll: 'parcelOutOn result = '; nextPutAll: result printString; nextPutAll: nl.

        [Kernel.Parcel removeParcelNamed: 'VWBridge-Tests'] on: Core.Notification do: [:n | n resume].
        s nextPutAll: 'parcel removed from registry'; nextPutAll: nl]
] ensure: [
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: oldMethod.
        s nextPutAll: 'Cursor>>showWhile: restored'; nextPutAll: nl]].

s nextPutAll: '=== final state ==='; nextPutAll: nl.
s nextPutAll: 'pcl exists = '; nextPutAll: pclPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'pst exists = '; nextPutAll: pstPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'registry restored = '; nextPutAll: (Kernel.Parcel parcels size = preCount) printString; nextPutAll: nl.

s contents
