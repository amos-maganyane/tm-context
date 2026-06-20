| s nl loadedBefore loadResult loadedAfter newParcels writerClasses imageClassSelsBefore imageInstSelsBefore imageClassSelsAfter imageInstSelsAfter newImageClassSels newImageInstSels |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Path A test-load: ImageWriter preview parcel ==='; nextPutAll: nl.

"--- Pre-load snapshot ---"
loadedBefore := (Kernel.Parcel parcels collect: [:p | p name asString]) asSet.
imageClassSelsBefore := Graphics.Image class selectors asSet.
imageInstSelsBefore := Graphics.Image selectors asSet.
s nextPutAll: 'PRE.loaded.count='; nextPutAll: loadedBefore size printString; nextPutAll: nl.
s nextPutAll: 'PRE.Image class.selectors='; nextPutAll: imageClassSelsBefore size printString; nextPutAll: nl.
s nextPutAll: 'PRE.Image inst.selectors='; nextPutAll: imageInstSelsBefore size printString; nextPutAll: nl.
s nextPutAll: 'PRE.ImageWriter in loaded='; nextPutAll: (loadedBefore includes: 'ImageWriter') printString; nextPutAll: nl.

"--- Load ImageWriter from search path (preview/64-bit/) ---"
s nextPutAll: nl; nextPutAll: '--- Calling ensureLoadedParcel:withVersion: ---'; nextPutAll: nl.
loadResult := [Kernel.Parcel ensureLoadedParcel: 'ImageWriter' withVersion: nil]
    on: Error
    do: [:e |
        s nextPutAll: 'LOAD ERROR: '; nextPutAll: e class name; nextPutAll: ' - '; nextPutAll: e messageText printString; nextPutAll: nl.
        nil].
s nextPutAll: 'load.result.class='; nextPutAll: loadResult class name; nextPutAll: nl.
s nextPutAll: 'load.result.printString='; nextPutAll: loadResult printString; nextPutAll: nl.

"--- Post-load snapshot ---"
loadedAfter := (Kernel.Parcel parcels collect: [:p | p name asString]) asSet.
imageClassSelsAfter := Graphics.Image class selectors asSet.
imageInstSelsAfter := Graphics.Image selectors asSet.
newParcels := loadedAfter reject: [:n | loadedBefore includes: n].
newImageClassSels := imageClassSelsAfter reject: [:sel | imageClassSelsBefore includes: sel].
newImageInstSels := imageInstSelsAfter reject: [:sel | imageInstSelsBefore includes: sel].

s nextPutAll: nl; nextPutAll: 'POST.loaded.count='; nextPutAll: loadedAfter size printString; nextPutAll: nl.
s nextPutAll: 'POST.Image class.selectors='; nextPutAll: imageClassSelsAfter size printString; nextPutAll: nl.
s nextPutAll: 'POST.Image inst.selectors='; nextPutAll: imageInstSelsAfter size printString; nextPutAll: nl.
s nextPutAll: 'POST.ImageWriter in loaded='; nextPutAll: (loadedAfter includes: 'ImageWriter') printString; nextPutAll: nl.

"--- DIFF: new parcels loaded (could be ImageWriter + prereqs) ---"
s nextPutAll: nl; nextPutAll: '=== New parcels loaded ('; nextPutAll: newParcels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newParcels asSortedCollection) do: [:p |
    s nextPutAll: '  + '; nextPutAll: p; nextPutAll: nl].

"--- DIFF: new Graphics.Image class-side selectors (extensions) ---"
s nextPutAll: nl; nextPutAll: '=== New Image class-side selectors ('; nextPutAll: newImageClassSels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newImageClassSels asSortedCollection) do: [:sel |
    s nextPutAll: '  + '; nextPutAll: sel asString; nextPutAll: nl].

"--- DIFF: new Graphics.Image instance-side selectors (extensions) ---"
s nextPutAll: nl; nextPutAll: '=== New Image instance-side selectors ('; nextPutAll: newImageInstSels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newImageInstSels asSortedCollection) do: [:sel |
    s nextPutAll: '  + '; nextPutAll: sel asString; nextPutAll: nl].

"--- WRITER hunt: walk all namespaces for *Writer* / *Encoder* / *PNG* / *PortableNetwork* bindings ---"
writerClasses := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | | kn |
        kn := k asString.
        ((((kn indexOfSubCollection: 'Writer' startingAt: 1) > 0)
            or: [(kn indexOfSubCollection: 'Encoder' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'PNG' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'PortableNetwork' startingAt: 1) > 0]])
        do: [:k | writerClasses add: ns name , '.' , k asString]].
s nextPutAll: nl; nextPutAll: '=== Writer/Encoder/PNG classes POST-load ('; nextPutAll: writerClasses size printString; nextPutAll: ') ==='; nextPutAll: nl.
(writerClasses asSortedCollection) do: [:n |
    s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

s contents
