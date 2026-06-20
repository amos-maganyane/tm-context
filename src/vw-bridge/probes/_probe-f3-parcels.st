| s nl loaded known |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Parcel probe (image-write codec hunt) ==='; nextPutAll: nl.

"--- LOADED parcels in image ---"
loaded := [Kernel.Parcel parcels] on: Error do: [:e |
    s nextPutAll: 'LOADED ERR: '; nextPutAll: e messageText; nextPutAll: nl.
    #()].
s nextPutAll: 'LOADED.class='; nextPutAll: loaded class name; nextPutAll: nl.
s nextPutAll: 'LOADED.size='; nextPutAll: loaded size printString; nextPutAll: nl.
((loaded asArray) asSortedCollection: [:a :b | a name asString < b name asString]) do: [:p |
    s nextPutAll: '  L '; nextPutAll: p name asString; nextPutAll: nl].

s nextPutAll: nl.

"--- KNOWN parcelNames (whatever that returns - likely all discoverable on search path) ---"
known := [Kernel.Parcel parcelNames] on: Error do: [:e |
    s nextPutAll: 'KNOWN ERR: '; nextPutAll: e messageText; nextPutAll: nl.
    #()].
s nextPutAll: 'KNOWN.class='; nextPutAll: known class name; nextPutAll: nl.
s nextPutAll: 'KNOWN.size='; nextPutAll: known size printString; nextPutAll: nl.
(known asArray asSortedCollection: [:a :b | a printString < b printString]) do: [:n |
    s nextPutAll: '  K '; nextPutAll: n printString; nextPutAll: nl].

s contents
