| s nl unloadResult libjpegClasses imageReaderHier writerCandidates encoderCandidates |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 cleanup + LibJPEG + ImageReader hierarchy ==='; nextPutAll: nl.

"--- 1. Unload ImageWriter (clean state) ---"
s nextPutAll: nl; nextPutAll: '--- Unloading ImageWriter ---'; nextPutAll: nl.
unloadResult := [Kernel.Parcel unloadParcelNamed: 'ImageWriter']
    on: Error do: [:e |
        s nextPutAll: 'UNLOAD ERROR: '; nextPutAll: e class name asString; nextPutAll: ' - '; nextPutAll: e messageText printString; nextPutAll: nl.
        nil].
s nextPutAll: 'unload.result.printString='; nextPutAll: unloadResult printString; nextPutAll: nl.
s nextPutAll: 'POST-unload.loaded='; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
s nextPutAll: 'POST-unload.ImageWriter still listed='; 
  nextPutAll: ((Kernel.Parcel parcels collect: [:p | p name asString]) includes: 'ImageWriter') printString; nextPutAll: nl.

"--- 2. LibJPEG-turbo: what JPEG classes are loaded? ---"
s nextPutAll: nl; nextPutAll: '=== Classes matching JPEG|jpeg|TurboJPEG (LibJPEG-turbo loaded content) ==='; nextPutAll: nl.
libjpegClasses := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | | kn |
        kn := k asString.
        ((kn indexOfSubCollection: 'JPEG' startingAt: 1) > 0)
            or: [(kn indexOfSubCollection: 'jpeg' startingAt: 1) > 0]])
        do: [:k | libjpegClasses add: ns name , '.' , k asString]].
s nextPutAll: 'count='; nextPutAll: libjpegClasses size printString; nextPutAll: nl.
(libjpegClasses asSortedCollection) do: [:n | s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

"--- 3. ImageReader class hierarchy ---"
s nextPutAll: nl; nextPutAll: '=== Graphics.ImageReader class hierarchy ==='; nextPutAll: nl.
s nextPutAll: 'superclass='; nextPutAll: Graphics.ImageReader superclass name; nextPutAll: nl.
s nextPutAll: 'allSuperclasses='; nextPutAll: (Graphics.ImageReader allSuperclasses collect: [:c | c name]) printString; nextPutAll: nl.
s nextPutAll: 'subclasses=' ; nextPutAll: (Graphics.ImageReader subclasses collect: [:c | c name]) printString; nextPutAll: nl.
s nextPutAll: 'allSubclasses='; nextPutAll: (Graphics.ImageReader allSubclasses collect: [:c | c name]) printString; nextPutAll: nl.
s nextPutAll: 'superclass.subclasses (siblings)='; nextPutAll: (Graphics.ImageReader superclass subclasses collect: [:c | c name]) printString; nextPutAll: nl.

"--- 4. Look for any ImageWriter / ImageEncoder / BitmapWriter / BMP / TIFF / WebP class ---"
s nextPutAll: nl; nextPutAll: '=== Hunt: pixel-image-encoder class candidates anywhere in image ==='; nextPutAll: nl.
writerCandidates := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    (ns keys asArray select: [:k | | kn |
        kn := k asString.
        ((((((kn indexOfSubCollection: 'ImageWriter' startingAt: 1) > 0)
            or: [(kn indexOfSubCollection: 'ImageEncoder' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'BitmapWriter' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'BMPWriter' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'TIFF' startingAt: 1) > 0])
            or: [(kn indexOfSubCollection: 'WebP' startingAt: 1) > 0]])
        do: [:k | writerCandidates add: ns name , '.' , k asString]].
s nextPutAll: 'count='; nextPutAll: writerCandidates size printString; nextPutAll: nl.
(writerCandidates asSortedCollection) do: [:n | s nextPutAll: '  '; nextPutAll: n; nextPutAll: nl].

"--- 5. ImageReader instance methods - any peer write/encode methods? ---"
s nextPutAll: nl; nextPutAll: '=== Graphics.ImageReader instance selectors matching write|put|encode|store|emit|stream ==='; nextPutAll: nl.
encoderCandidates := (Graphics.ImageReader selectors asArray select: [:sel | | sn |
    sn := sel asString asLowercase.
    (((((sn indexOfSubCollection: 'write' startingAt: 1) > 0)
        or: [(sn indexOfSubCollection: 'put' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'encode' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'store' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'emit' startingAt: 1) > 0]]) asSortedCollection.
s nextPutAll: 'count='; nextPutAll: encoderCandidates size printString; nextPutAll: nl.
encoderCandidates do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

"--- 6. Graphics.PNGImageReader instance + class-side - any write capability? ---"
s nextPutAll: nl; nextPutAll: '=== Graphics.PNGImageReader (instance side) ==='; nextPutAll: nl.
s nextPutAll: 'selectors.size='; nextPutAll: Graphics.PNGImageReader selectors size printString; nextPutAll: nl.
(Graphics.PNGImageReader selectors asSortedCollection) do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
s nextPutAll: nl; nextPutAll: '=== Graphics.PNGImageReader class-side ==='; nextPutAll: nl.
(Graphics.PNGImageReader class selectors asSortedCollection) do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

s contents
