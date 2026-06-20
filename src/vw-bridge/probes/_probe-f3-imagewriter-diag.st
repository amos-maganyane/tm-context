| s nl searchPath foundByFindParcel foundByParcelNamed parcelNamesList loadedImageRelated |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Path A diagnostic: why ParcelMissingError? (READ-ONLY) ==='; nextPutAll: nl.

"--- 1. Live searchPathModel value ---"
s nextPutAll: nl; nextPutAll: '=== Kernel.Parcel searchPathModel value ==='; nextPutAll: nl.
searchPath := [Kernel.Parcel searchPathModel value]
    on: Error do: [:e | s nextPutAll: 'ERR: '; nextPutAll: e messageText printString; nextPutAll: nl. #()].
s nextPutAll: 'class='; nextPutAll: searchPath class name; nextPutAll: nl.
s nextPutAll: 'size='; nextPutAll: searchPath size printString; nextPutAll: nl.
searchPath do: [:p |
    s nextPutAll: '  '; nextPutAll: p printString; nextPutAll: nl].

"--- 2. findParcelNamed: 'ImageWriter' (discovery, no load) ---"
s nextPutAll: nl; nextPutAll: '=== findParcelNamed: ImageWriter ==='; nextPutAll: nl.
foundByFindParcel := [Kernel.Parcel findParcelNamed: 'ImageWriter']
    on: Error do: [:e | 
        s nextPutAll: 'ERR: '; nextPutAll: e class name; nextPutAll: ' - '; nextPutAll: e messageText printString; nextPutAll: nl. 
        nil].
s nextPutAll: 'class='; nextPutAll: foundByFindParcel class name; nextPutAll: nl.
s nextPutAll: 'printString='; nextPutAll: foundByFindParcel printString; nextPutAll: nl.

"--- 3. parcelNamed: 'ImageWriter' (alternate discovery) ---"
s nextPutAll: nl; nextPutAll: '=== parcelNamed: ImageWriter ==='; nextPutAll: nl.
foundByParcelNamed := [Kernel.Parcel parcelNamed: 'ImageWriter']
    on: Error do: [:e | 
        s nextPutAll: 'ERR: '; nextPutAll: e class name; nextPutAll: ' - '; nextPutAll: e messageText printString; nextPutAll: nl. 
        nil].
s nextPutAll: 'class='; nextPutAll: foundByParcelNamed class name; nextPutAll: nl.
s nextPutAll: 'printString='; nextPutAll: foundByParcelNamed printString; nextPutAll: nl.

"--- 4. Any currently-loaded parcel with 'Image' substring (cross-check earlier finding) ---"
s nextPutAll: nl; nextPutAll: '=== LOADED parcels matching ''Image'' ==='; nextPutAll: nl.
loadedImageRelated := Kernel.Parcel parcels select: [:p | 
    (p name asString indexOfSubCollection: 'Image' startingAt: 1) > 0].
loadedImageRelated do: [:p |
    s nextPutAll: '  '; nextPutAll: p name asString; 
      nextPutAll: ' (file='; nextPutAll: ([p file printString] on: Error do: [:e | 'ERR ' , e messageText]); 
      nextPutAll: ')'; nextPutAll: nl].

"--- 5. Probe the discovery APIs we have: what methods exist for finding parcels by name? ---"
s nextPutAll: nl; nextPutAll: '=== Kernel.Parcel class-side selectors matching ''ind|amed|earch|cache'' ==='; nextPutAll: nl.
((Kernel.Parcel class selectors asArray select: [:sel | | sn |
    sn := sel asString.
    ((((sn indexOfSubCollection: 'ind' startingAt: 1) > 0)
        or: [(sn indexOfSubCollection: 'amed' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'earch' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'ache' startingAt: 1) > 0]]) asSortedCollection) do: [:sel |
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

s contents
