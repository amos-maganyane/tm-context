"Probe session-19 step 4: identify parcel-list removal API + Bundle class location + ImageConfigurationSystem behavior.
Read-only.  Allows safe cleanup pattern for the upcoming sandbox createParcelNamed: probe."
| s nl removeSels bundleNames inst icsSels existingMatch |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
"Removal selectors on Kernel.Parcel"
removeSels := (Kernel.Parcel class selectors asArray) asSortedCollection asArray
    select: [:sel | (sel asString indexOfSubCollection: 'remove' startingAt: 1) > 0].
s nextPutAll: '=== Kernel.Parcel class-side remove* selectors ==='; nextPutAll: nl.
removeSels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
"Bundle-like classes"
bundleNames := #('Bundle' 'BundleParcel' 'ParcelBundle' 'CompositeParcel' 'Pundle' 'AbstractPundle').
s nextPutAll: '=== Bundle-like class candidates ==='; nextPutAll: nl.
Smalltalk allNameSpaces do: [:ns |
    ns keys do: [:k |
        (bundleNames includes: k asString) ifTrue: [
            s nextPutAll: '  '; nextPutAll: ns name asString; nextPutAll: '.'; nextPutAll: k asString; nextPutAll: nl]]].
"ImageConfigurationSystem class-side surface"
s nextPutAll: '=== Core.ImageConfigurationSystem class-side selectors (alphabetical) ==='; nextPutAll: nl.
icsSels := (Core.ImageConfigurationSystem class selectors asArray) asSortedCollection asArray.
icsSels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
"ImageConfigurationSystem live instance (defensive: may be empty/absent at probe time)"
inst := [Core.ImageConfigurationSystem allInstances asArray] on: Core.Error do: [:ex | #()].
s nextPutAll: '=== ImageConfigurationSystem live instance count ==='; nextPutAll: nl.
s nextPutAll: '  allInstances size='; nextPutAll: inst size printString; nextPutAll: nl.
inst isEmpty
    ifFalse: [
        | i |
        i := inst first.
        s nextPutAll: '  first.class='; nextPutAll: i class name; nextPutAll: nl.
        s nextPutAll: '  allowFilein(instVar)='; nextPutAll: ([i instVarNamed: 'allowFilein'] on: Core.Error do: [:ex | 'ERR:', ex description]) printString; nextPutAll: nl.
        s nextPutAll: '  allowParcelLoading(instVar)='; nextPutAll: ([i instVarNamed: 'allowParcelLoading'] on: Core.Error do: [:ex | 'ERR:', ex description]) printString; nextPutAll: nl].
"Existing parcels matching VWBridge name pattern (should be none yet)"
s nextPutAll: '=== existing parcels named *VWBridge* ==='; nextPutAll: nl.
existingMatch := OrderedCollection new.
((Kernel.Parcel parcelNames asArray) asSortedCollection asArray) do: [:n |
    (n asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0 ifTrue: [
        existingMatch add: n asString]].
existingMatch isEmpty
    ifTrue: [s nextPutAll: '  (none)'; nextPutAll: nl]
    ifFalse: [existingMatch do: [:n | s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl]].
"How many parcels total are registered now"
s nextPutAll: '=== parcel registry size ==='; nextPutAll: nl.
s nextPutAll: '  Kernel.Parcel parcels size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
s nextPutAll: '  Kernel.Parcel parcelNames size = '; nextPutAll: Kernel.Parcel parcelNames size printString; nextPutAll: nl.
s contents
