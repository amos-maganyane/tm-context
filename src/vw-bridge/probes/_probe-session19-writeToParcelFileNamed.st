"Probe session-19 step 11: SAFE diagnostic (no parcelOutOn: call - it wedges the bridge).

Inspect:
  (a) parcel codeComponent on a newly-created EMPTY parcel
  (b) writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup: fingerprint
      - this is what parcelOutOn: delegates to; might be the headless-safe entry point
  (c) Whether populated parcel (after addEntiretyOfClass:) has different codeComponent state

NO parcelOutOn: invocation - keeps bridge alive."
| s nl current cleanedUp parcel m fingerprintSelectors fingerprint |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Cleanup defensive"
current := (Kernel.Parcel parcelNames asArray) select: [:n | (n asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0].
cleanedUp := OrderedCollection new.
current do: [:n |
    [Kernel.Parcel removeParcelNamed: n] on: Core.Notification do: [:notif | notif resume].
    cleanedUp add: n].
s nextPutAll: 'pre-cleanup-removed = '; nextPutAll: cleanedUp asArray printString; nextPutAll: nl.
s nextPutAll: 'current registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

"(2) Empty parcel codeComponent state"
parcel := Kernel.Parcel createParcelNamed: 'Test-Empty'.
s nextPutAll: '=== empty parcel introspection ==='; nextPutAll: nl.
s nextPutAll: '  codeComponent respondsTo='; nextPutAll: (parcel respondsTo: #codeComponent) printString; nextPutAll: nl.
(parcel respondsTo: #codeComponent) ifTrue: [
    s nextPutAll: '  codeComponent value='; 
      nextPutAll: ([parcel codeComponent] on: Core.Exception do: [:ex | 'ERR:', ex description]) printString; 
      nextPutAll: nl].
#(#fileSpec #fileName #file #spec #source #sourceFileSpec #attached #definedThings #definedAndExtendedClasses) do: [:sel |
    | r |
    r := (parcel respondsTo: sel) 
        ifTrue: [[parcel perform: sel] on: Core.Exception do: [:ex | 'ERR:', ex description]]
        ifFalse: ['(absent)'].
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='; nextPutAll: r printString; nextPutAll: nl].

"(3) Now POPULATE the parcel and recheck"
parcel addEntiretyOfClass: VWB.VWBridge.
s nextPutAll: '=== after addEntiretyOfClass: VWB.VWBridge ==='; nextPutAll: nl.
(parcel respondsTo: #codeComponent) ifTrue: [
    s nextPutAll: '  codeComponent value='; 
      nextPutAll: ([parcel codeComponent] on: Core.Exception do: [:ex | 'ERR:', ex description]) printString; 
      nextPutAll: nl].
#(#definedThings #definedAndExtendedClasses) do: [:sel |
    | r |
    r := (parcel respondsTo: sel) 
        ifTrue: [[parcel perform: sel] on: Core.Exception do: [:ex | 'ERR:', ex description]]
        ifFalse: ['(absent)'].
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='; nextPutAll: r printString; nextPutAll: nl].
"Cleanup"
[Kernel.Parcel removeParcelNamed: 'Test-Empty'] on: Core.Notification do: [:n | n resume].

"(4) Lower-level writeToParcelFileNamed:... fingerprint"
m := Kernel.Parcel compiledMethodAt: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup: ifAbsent: [nil].
m isNil 
    ifTrue: [s nextPutAll: 'writeToParcelFileNamed:... ABSENT (instance side)'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== Kernel.Parcel>>writeToParcelFileNamed:...:backup: ==='; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl].

"(5) Identify any showWhile:/dialog-free instance-side write APIs"
fingerprintSelectors := (Kernel.Parcel selectors asArray) asSortedCollection asArray 
    select: [:sel | 
        ((sel asString indexOfSubCollection: 'write' startingAt: 1) > 0) 
            or: [(sel asString indexOfSubCollection: 'parcelOut' startingAt: 1) > 0]].
s nextPutAll: '=== Parcel instance-side write/parcelOut selectors ==='; nextPutAll: nl.
fingerprintSelectors do: [:sel | 
    | mthd |
    mthd := Kernel.Parcel compiledMethodAt: sel ifAbsent: [nil].
    fingerprint := mthd isNil 
        ifTrue: ['ABSENT'] 
        ifFalse: [(mthd messages includes: #showWhile:) printString].
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: ' (showWhile?='; nextPutAll: fingerprint; nextPutAll: ')'; nextPutAll: nl].

s contents
