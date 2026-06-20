| s nl loadedBefore imageClassSelsBefore imageInstSelsBefore graphicsKeysBefore allBindingsBefore loadResult loadedAfter imageClassSelsAfter imageInstSelsAfter graphicsKeysAfter allBindingsAfter newParcels newImageClassSels newImageInstSels newGraphicsKeys newAllBindings pngWriterCandidates |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 Path A explicit-path load: loadParcelFrom: ==='; nextPutAll: nl.

"--- Pre-load snapshot ---"
loadedBefore := (Kernel.Parcel parcels collect: [:p | p name asString]) asSet.
imageClassSelsBefore := Graphics.Image class selectors asSet.
imageInstSelsBefore := Graphics.Image selectors asSet.
graphicsKeysBefore := Graphics keys asSet.
allBindingsBefore := Set new.
Smalltalk allNameSpaces do: [:ns | ns keys do: [:k | allBindingsBefore add: (ns name , '.' , k asString)]].
s nextPutAll: 'PRE.loaded='; nextPutAll: loadedBefore size printString;
  nextPutAll: '  PRE.Image class.sels='; nextPutAll: imageClassSelsBefore size printString;
  nextPutAll: '  PRE.Image inst.sels='; nextPutAll: imageInstSelsBefore size printString;
  nextPutAll: '  PRE.Graphics keys='; nextPutAll: graphicsKeysBefore size printString;
  nextPutAll: '  PRE.allBindings='; nextPutAll: allBindingsBefore size printString; nextPutAll: nl.

"--- Load explicit path ---"
s nextPutAll: nl; nextPutAll: '--- loadParcelFrom: preview\64-bit\ImageWriter.pcl ---'; nextPutAll: nl.
loadResult := [Kernel.Parcel loadParcelFrom: 'C:\visualworks931\preview\64-bit\ImageWriter.pcl' asFilename]
    on: Error do: [:e |
        s nextPutAll: 'LOAD ERROR: '; nextPutAll: e class name; nextPutAll: ' - '; nextPutAll: e messageText printString; nextPutAll: nl.
        nil].
s nextPutAll: 'load.result.class='; nextPutAll: loadResult class name; nextPutAll: nl.
s nextPutAll: 'load.result.printString='; nextPutAll: loadResult printString; nextPutAll: nl.

"--- Post-load snapshot ---"
loadedAfter := (Kernel.Parcel parcels collect: [:p | p name asString]) asSet.
imageClassSelsAfter := Graphics.Image class selectors asSet.
imageInstSelsAfter := Graphics.Image selectors asSet.
graphicsKeysAfter := Graphics keys asSet.
allBindingsAfter := Set new.
Smalltalk allNameSpaces do: [:ns | ns keys do: [:k | allBindingsAfter add: (ns name , '.' , k asString)]].
newParcels := loadedAfter reject: [:n | loadedBefore includes: n].
newImageClassSels := imageClassSelsAfter reject: [:sel | imageClassSelsBefore includes: sel].
newImageInstSels := imageInstSelsAfter reject: [:sel | imageInstSelsBefore includes: sel].
newGraphicsKeys := graphicsKeysAfter reject: [:k | graphicsKeysBefore includes: k].
newAllBindings := allBindingsAfter reject: [:k | allBindingsBefore includes: k].

s nextPutAll: nl; nextPutAll: 'POST.loaded='; nextPutAll: loadedAfter size printString;
  nextPutAll: '  POST.Image class.sels='; nextPutAll: imageClassSelsAfter size printString;
  nextPutAll: '  POST.Image inst.sels='; nextPutAll: imageInstSelsAfter size printString;
  nextPutAll: '  POST.Graphics keys='; nextPutAll: graphicsKeysAfter size printString;
  nextPutAll: '  POST.allBindings='; nextPutAll: allBindingsAfter size printString; nextPutAll: nl.

"--- DIFFS ---"
s nextPutAll: nl; nextPutAll: '=== New parcels ('; nextPutAll: newParcels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newParcels asSortedCollection) do: [:p | s nextPutAll: '  + '; nextPutAll: p; nextPutAll: nl].

s nextPutAll: nl; nextPutAll: '=== New Image class-side selectors ('; nextPutAll: newImageClassSels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newImageClassSels asSortedCollection) do: [:sel | s nextPutAll: '  + '; nextPutAll: sel asString; nextPutAll: nl].

s nextPutAll: nl; nextPutAll: '=== New Image instance-side selectors ('; nextPutAll: newImageInstSels size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newImageInstSels asSortedCollection) do: [:sel | s nextPutAll: '  + '; nextPutAll: sel asString; nextPutAll: nl].

s nextPutAll: nl; nextPutAll: '=== New Graphics namespace keys ('; nextPutAll: newGraphicsKeys size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newGraphicsKeys asSortedCollection) do: [:k | s nextPutAll: '  + '; nextPutAll: k asString; nextPutAll: nl].

"--- PNG-writer hunt across ALL new bindings ---"
pngWriterCandidates := newAllBindings select: [:k | | kn |
    kn := k asString.
    (((((kn indexOfSubCollection: 'PNG' startingAt: 1) > 0)
        or: [(kn indexOfSubCollection: 'Writer' startingAt: 1) > 0])
        or: [(kn indexOfSubCollection: 'Encoder' startingAt: 1) > 0])
        or: [(kn indexOfSubCollection: 'Image' startingAt: 1) > 0])
        or: [(kn indexOfSubCollection: 'PortableNetwork' startingAt: 1) > 0]].
s nextPutAll: nl; nextPutAll: '=== NEW PNG/Writer/Encoder/Image candidates ('; nextPutAll: pngWriterCandidates size printString; nextPutAll: ') ==='; nextPutAll: nl.
(pngWriterCandidates asSortedCollection) do: [:k | s nextPutAll: '  * '; nextPutAll: k; nextPutAll: nl].

s nextPutAll: nl; nextPutAll: '=== Total NEW bindings ('; nextPutAll: newAllBindings size printString; nextPutAll: ') ==='; nextPutAll: nl.
(newAllBindings asSortedCollection) do: [:k | s nextPutAll: '  + '; nextPutAll: k; nextPutAll: nl].

s contents
