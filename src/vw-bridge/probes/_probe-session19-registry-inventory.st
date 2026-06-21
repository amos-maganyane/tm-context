"Probe session-19 step 12: quick safe registry inventory after 2nd recovery.
Verify the failed parcelOutOn: attempts did not leave leaked parcels (the wedge
recovery via Start-VWBridge.ps1 -KillExisting restarted the image entirely so 
parcel state is fresh-from-load.st).

Pure introspection - no parcelOutOn:, no UI calls. Cannot wedge bridge."
| s nl current existing |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
s nextPutAll: 'registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
existing := (Kernel.Parcel parcelNames asArray) select: [:n | (n asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0].
s nextPutAll: 'VWBridge-* parcels = '; nextPutAll: existing asArray printString; nextPutAll: nl.
"Defensive cleanup if any leaked (idempotent)"
current := OrderedCollection new.
existing do: [:n |
    [Kernel.Parcel removeParcelNamed: n] on: Core.Notification do: [:notif | notif resume].
    current add: n].
s nextPutAll: 'cleaned-up = '; nextPutAll: current asArray printString; nextPutAll: nl.
s nextPutAll: 'final-registry-size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
s contents
