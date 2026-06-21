"Probe session-19 step 20: Cursor>>showWhile: monkey-patch + canonical parcelOutOn: build.

Path (Oracle Backup 1):
  1. Save original Cursor>>showWhile: compiledMethod via compiledMethodAt:
  2. Install pass-through patch: 'showWhile: aBlock ^aBlock value' via compile:classified:
  3. Call canonical parcel parcelOutOn: which does ALL setup (ChangeSet/timestamp/codeComponent)
  4. Restore original via methodDictionary swap inside ensure: block

Builds VWBridge.pcl (production: VWB namespace + VWBridge class + SimpleDialog extension).
DOES NOT build VWBridge-Tests.pcl - that's the next step if this works."
| s nl oldMethod parcel home pclPath pstPath result preCount patchInstalled |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
pclPath := home , '\.generated\parcels\VWBridge.pcl'.
pstPath := home , '\.generated\parcels\VWBridge.pst'.

"Ensure output dir exists"
((home , '\.generated\parcels') asFilename exists) ifFalse: [
    (home , '\.generated\parcels') asFilename makeDirectory].

"Delete any prior files"
[pclPath asFilename delete] on: Core.Exception do: [:ex | nil].
[pstPath asFilename delete] on: Core.Exception do: [:ex | nil].

preCount := Kernel.Parcel parcels size.
s nextPutAll: 'pre-build registry size = '; nextPutAll: preCount printString; nextPutAll: nl.

"Save original Cursor>>showWhile: compiledMethod"
oldMethod := Cursor compiledMethodAt: #showWhile:.
s nextPutAll: 'saved Cursor>>showWhile: '; nextPutAll: oldMethod printString; nextPutAll: nl.

patchInstalled := false.
[
    "Install pass-through patch (will broadcast a method-change Notification; resume)"
    [Cursor compile: 'showWhile: aBlock ^aBlock value' classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true.
     s nextPutAll: 'patch installed (Cursor>>showWhile: -> pass-through)'; nextPutAll: nl]
        on: Core.Notification do: [:n | n resume].

    patchInstalled ifTrue: [
        "Build parcel content"
        parcel := Kernel.Parcel createParcelNamed: 'VWBridge'.
        parcel addNameSpace: VWB.
        parcel addEntiretyOfClass: VWB.VWBridge.
        parcel addSelector: #choose:labels:values:default:for: class: SimpleDialog.
        s nextPutAll: 'parcel content added (ns + class + extension)'; nextPutAll: nl.

        "Call canonical parcelOutOn: - showWhile: now pass-through, no UI wedge.
         Per Oracle: pass REAL .pst filename for withSource: (not nil/false/stream).
         hideOnLoad: is the boolean (suppress UI on parcel load)."
        result := [[parcel
            parcelOutOn: pclPath asFilename
            withSource: pstPath asFilename
            hideOnLoad: false
            republish: false
            backup: false]
            on: Core.Notification do: [:n | n resume]]
            on: Core.Exception do: [:ex |
                'EXC: ' , ex class name asString , ' / ' , ex description , 
                ' / recv-class=' , ([ex receiver class name asString] on: Core.Exception do: [:e | '?'])].
        s nextPutAll: 'parcelOutOn result = '; nextPutAll: result printString; nextPutAll: nl.

        "Cleanup the parcel from registry"
        [Kernel.Parcel removeParcelNamed: 'VWBridge'] on: Core.Notification do: [:n | n resume].
        s nextPutAll: 'parcel removed from registry'; nextPutAll: nl]
] ensure: [
    "ALWAYS restore Cursor>>showWhile: even on error - guards against permanent system change"
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: oldMethod.
        s nextPutAll: 'Cursor>>showWhile: restored via methodDictionary swap'; nextPutAll: nl]].

"Final inspection"
s nextPutAll: '=== final state ==='; nextPutAll: nl.
s nextPutAll: 'pcl exists = '; nextPutAll: pclPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'pst exists = '; nextPutAll: pstPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'final registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
s nextPutAll: 'registry restored = '; nextPutAll: (Kernel.Parcel parcels size = preCount) printString; nextPutAll: nl.

s contents
