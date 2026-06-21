"=== session-20 probe: parcel build with Cursor monkey-patch INSTALLED FIRST ==="
"Hypothesis: compile: on VWB.VWBridge fires a Cursor wait showWhile: UI
announcement that wedges the headless listener (same wedge cause as
parcelOutOn: per carry-forward #35). The fix is to install Cursor>>showWhile:
monkey-patch BEFORE any other compile, then do all compiles + parcel build
inside the patched block."
| home parcelDir pclPath pstPath oldShaMethod oldTsMethod patchInstalled cursorOldMethod parcel |
home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
parcelDir := home , '\.generated\parcels'.
pclPath := parcelDir , '\VWBridge.pcl'.
pstPath := parcelDir , '\VWBridge.pst'.

cursorOldMethod := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
oldShaMethod := nil.
oldTsMethod := nil.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value'
        classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true]
        on: Core.Notification do: [:n | n resume].
    patchInstalled ifTrue: [
        oldShaMethod := VWB.VWBridge class compiledMethodAt: #buildCommitSha ifAbsent: [nil].
        oldTsMethod := VWB.VWBridge class compiledMethodAt: #buildTimestamp ifAbsent: [nil].
        VWB.VWBridge class
            compile: 'buildCommitSha ^''SESSION20TESTSHA12345'''
            classified: 'config'.
        VWB.VWBridge class
            compile: 'buildTimestamp ^''2026-06-21T17:00:00Z'''
            classified: 'config'.
        parcel := Kernel.Parcel createParcelNamed: 'VWBridge'.
        parcel addNameSpace: VWB.
        parcel addEntiretyOfClass: VWB.VWBridge.
        parcel addSelector: #choose:labels:values:default:for: class: SimpleDialog.
        parcel
            parcelOutOn: pclPath asFilename
            withSource: pstPath asFilename
            hideOnLoad: false
            republish: false
            backup: false.
        [Kernel.Parcel removeParcelNamed: 'VWBridge']
            on: Core.Notification do: [:n | n resume]]
] ensure: [
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: cursorOldMethod].
    oldShaMethod isNil ifFalse: [
        VWB.VWBridge class methodDictionary at: #buildCommitSha put: oldShaMethod].
    oldTsMethod isNil ifFalse: [
        VWB.VWBridge class methodDictionary at: #buildTimestamp put: oldTsMethod]].

^'build-OK pcl=' , pclPath , ' pst=' , pstPath
