"Probe session-19 step 10: diagnose WHY parcelOutOn: still MNUs on asLogicalFileSpecification.

Three hypotheses:
  (a) parcel codeComponent is nil → asLogicalFileSpecification on nil → MNU
  (b) parcel.codeComponent is some non-Filename → MNU
  (c) parcelOutOn: doesn't accept the empty-created-parcel pattern at all

Tests:
  1. Cleanup any leaked VWBridge parcels
  2. Create an empty parcel, inspect codeComponent
  3. Try parcelOutOn: on an EXISTING loaded parcel - see if the API works at all"
| s nl current cleanedUp parcel home tp existingParcel result |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Cleanup defensive"
current := (Kernel.Parcel parcelNames asArray) select: [:n | (n asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0].
cleanedUp := OrderedCollection new.
current do: [:n |
    [Kernel.Parcel removeParcelNamed: n] on: Core.Notification do: [:notif | notif resume].
    cleanedUp add: n].
s nextPutAll: 'pre-cleanup-removed = '; nextPutAll: cleanedUp asArray printString; nextPutAll: nl.

"(2) Inspect newly-created empty parcel internals"
parcel := Kernel.Parcel createParcelNamed: 'Test-Empty-Probe'.
s nextPutAll: '=== empty parcel inspection ==='; nextPutAll: nl.
s nextPutAll: '  parcel='; nextPutAll: parcel printString; nextPutAll: nl.
s nextPutAll: '  respondsTo:#codeComponent='; nextPutAll: (parcel respondsTo: #codeComponent) printString; nextPutAll: nl.
(parcel respondsTo: #codeComponent) ifTrue: [
    s nextPutAll: '  codeComponent='; 
      nextPutAll: ([parcel codeComponent] on: Core.Exception do: [:ex | 'ERR:', ex description]) printString; 
      nextPutAll: nl].
#(#fileName #file #sourceFile #spec #specification #logicalFileSpecification) do: [:sel |
    | r |
    r := (parcel respondsTo: sel) 
        ifTrue: [[parcel perform: sel] on: Core.Exception do: [:ex | 'ERR']]
        ifFalse: ['(absent)'].
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='; nextPutAll: r printString; nextPutAll: nl].
"Cleanup test parcel"
[Kernel.Parcel removeParcelNamed: 'Test-Empty-Probe'] on: Core.Notification do: [:n | n resume].

"(3) Try parcelOutOn: on an EXISTING loaded parcel"
existingParcel := Kernel.Parcel parcels first.
s nextPutAll: '=== existing parcel test ==='; nextPutAll: nl.
s nextPutAll: '  existing-name='; nextPutAll: existingParcel name printString; nextPutAll: nl.
home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
tp := home , '\.generated\parcels\_test-existing.pcl'.
result := [[existingParcel 
    parcelOutOn: tp asFilename 
    withSource: false 
    hideOnLoad: false 
    republish: false 
    backup: false] 
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | 'EXC:', ex class name , '/', ex description].
s nextPutAll: '  parcelOutOn: result='; nextPutAll: result printString; nextPutAll: nl.
s nextPutAll: '  file exists='; nextPutAll: tp asFilename exists printString; nextPutAll: nl.
(tp asFilename exists) ifTrue: [
    tp asFilename delete].

s contents
