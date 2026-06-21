"Probe session-19 step 6: cleanup leaked 'VWBridge-Core' parcel + enumerate Parcel add/include API.
The previous sandbox probe leaked a parcel because removeParcelNamed: raised a Notification
that was caught (aborting the removal) rather than resumed.

Cleanup pattern from constraint #25 (Direct-invoke v2 Notification-resume): use
on: Core.Notification do: [:n | n resume] - distinct from on: Core.Exception do:."
| s nl preCount removalResult postCount addSelectors patterns parcel |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

preCount := Kernel.Parcel parcels size.
s nextPutAll: 'pre-cleanup-count='; nextPutAll: preCount printString; nextPutAll: nl.

"Cleanup leaked parcel with Notification-resume"
removalResult := [[Kernel.Parcel removeParcelNamed: 'VWBridge-Core']
    on: Core.Notification 
    do: [:n | n resume]] 
    on: Core.Exception
    do: [:ex | 'EXCEPTION: ', ex description].
s nextPutAll: 'removal-result='; nextPutAll: removalResult printString; nextPutAll: nl.
postCount := Kernel.Parcel parcels size.
s nextPutAll: 'post-cleanup-count='; nextPutAll: postCount printString; nextPutAll: nl.
s nextPutAll: 'cleanup-worked='; nextPutAll: (postCount = (preCount - 1)) printString; nextPutAll: nl.

"Enumerate instance-side Parcel selectors related to content addition"
patterns := #('add' 'include' 'class' 'extension' 'method' 'content').
addSelectors := (Kernel.Parcel selectors asArray) asSortedCollection asArray
    select: [:sel |
        (patterns detect: [:pat | (sel asString indexOfSubCollection: pat startingAt: 1) > 0]
            ifNone: [nil]) notNil].
s nextPutAll: '=== Parcel instance-side selectors matching add|include|class|extension|method|content ==='; nextPutAll: nl.
addSelectors do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

"Also peek at parcelOutOn:withSource:hideOnLoad:republish:backup: behavioral fingerprint"
parcel := Kernel.Parcel class compiledMethodAt: #parcelNamed: ifAbsent: [nil].
parcel isNil
    ifTrue: [s nextPutAll: 'parcelNamed: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== parcelNamed: messages ==='; nextPutAll: nl.
        s nextPutAll: '  '; nextPutAll: parcel messages asSortedCollection asArray printString; nextPutAll: nl].

parcel := Kernel.Parcel compiledMethodAt: #parcelOutOn:withSource:hideOnLoad:republish:backup: ifAbsent: [nil].
parcel isNil
    ifTrue: [s nextPutAll: 'parcelOutOn:... ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== parcelOutOn:withSource:hideOnLoad:republish:backup: messages ==='; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: parcel numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: parcel messages asSortedCollection asArray printString; nextPutAll: nl].

s contents
