"Probe session-19 step 8: BUILD 2 parcels per user-confirmed Option A.
  VWBridge.pcl       = Core + Patches (production, what onboarding developer installs)
  VWBridge-Tests.pcl = Tests (dev / quality gates)

DESTRUCTIVE actions performed:
  1. mkdir $VW_BRIDGE_HOME/.generated/parcels/ if not exists
  2. write 2 .pcl files to disk
  3. mutate Kernel.Parcel parcels registry +2 then cleanup back to baseline
     (ensure: + on: Core.Notification do: [:n | n resume] for the cleanup)

Each per-parcel build wrapped in ensure: so the registry restore runs even
on error / notification leak. Idempotent: pre-count must equal post-count."
| s nl home generatedDir prodPath testsPath buildParcel preCount postCount |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

preCount := Kernel.Parcel parcels size.
s nextPutAll: '=== Phase P P6 parcel build (session-19) ==='; nextPutAll: nl.
s nextPutAll: 'pre-build parcel registry size = '; nextPutAll: preCount printString; nextPutAll: nl.

home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
generatedDir := home , '\.generated\parcels'.
(generatedDir asFilename exists) 
    ifFalse: [
        generatedDir asFilename makeDirectory.
        s nextPutAll: 'created dir: '; nextPutAll: generatedDir; nextPutAll: nl].

prodPath := generatedDir , '\VWBridge.pcl'.
testsPath := generatedDir , '\VWBridge-Tests.pcl'.

"buildParcel block: name, targetPath, addBlock.
 Wraps everything in ensure: so registry cleanup always runs.
 Wraps add+write in Notification-resume so benign signals don't abort.
 Per diagnostic probe 9: parcelOutOn: wants a Filename (not a Stream)
 because it calls asLogicalFileSpecification - ExternalWriteStream doesn't
 respond to that selector but NTFSFilename does."
buildParcel := [:name :targetPath :addBlock |
    | parcel |
    parcel := nil.
    [[s nextPutAll: '--- building '; nextPutAll: name; nextPutAll: ' ---'; nextPutAll: nl.
      parcel := Kernel.Parcel createParcelNamed: name.
      s nextPutAll: '  created: '; nextPutAll: parcel printString; nextPutAll: nl.
      addBlock value: parcel.
      s nextPutAll: '  populated content via addBlock'; nextPutAll: nl.
      parcel 
          parcelOutOn: targetPath asFilename
          withSource: false 
          hideOnLoad: false 
          republish: false 
          backup: false.
      s nextPutAll: '  wrote: '; nextPutAll: targetPath; 
        nextPutAll: ' exists='; nextPutAll: targetPath asFilename exists printString; nextPutAll: nl]
        on: Core.Notification do: [:n | n resume]]
    ensure: [
        parcel notNil ifTrue: [
            [Kernel.Parcel removeParcelNamed: name]
                on: Core.Notification do: [:n | n resume].
            s nextPutAll: '  removed '; nextPutAll: name; nextPutAll: ' from registry'; nextPutAll: nl]]].

"Build production parcel: VWBridge namespace + VWBridge class + SimpleDialog extension"
buildParcel 
    value: 'VWBridge' 
    value: prodPath 
    value: [:p | 
        p addNameSpace: VWB.
        p addEntiretyOfClass: VWB.VWBridge.
        p addSelector: #choose:labels:values:default:for: class: SimpleDialog].

"Build tests parcel: 3 test classes (VWB ns already added by production parcel on load)"
buildParcel 
    value: 'VWBridge-Tests' 
    value: testsPath 
    value: [:p | 
        p addEntiretyOfClasses: (Array 
            with: VWB.VWBridgeTest 
            with: VWB.VWBridgeWaitTest 
            with: VWB.VWBridgeScreenshotTest)].

postCount := Kernel.Parcel parcels size.
s nextPutAll: '=== final state ==='; nextPutAll: nl.
s nextPutAll: 'post-build parcel registry size = '; nextPutAll: postCount printString; nextPutAll: nl.
s nextPutAll: 'registry restored = '; nextPutAll: (postCount = preCount) printString; nextPutAll: nl.
s nextPutAll: 'VWBridge.pcl exists = '; nextPutAll: prodPath asFilename exists printString; nextPutAll: nl.
s nextPutAll: 'VWBridge-Tests.pcl exists = '; nextPutAll: testsPath asFilename exists printString; nextPutAll: nl.

s contents
