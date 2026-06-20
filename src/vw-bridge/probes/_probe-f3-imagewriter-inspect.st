| s nl pcl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

s nextPutAll: '=== F3 ImageWriter Parcel introspection ==='; nextPutAll: nl.

pcl := Kernel.Parcel parcelNamed: 'ImageWriter'.
s nextPutAll: 'parcel.class='; nextPutAll: pcl class name; nextPutAll: nl.
s nextPutAll: 'parcel.printString='; nextPutAll: pcl printString; nextPutAll: nl.

"Try various introspection selectors defensively"
#(#name #fileName #version #versionString #summary #comment #bundleName #isLoaded #isDirty #prerequisites #components #codeComponents #classes #classDefinitions #extensions #classExtensions #bindings #releaseInformation #parameters #hidden #date #fullName)
    do: [:sel |
        | r |
        r := [pcl perform: sel] on: Error do: [:e | 'ERR ' , e class name asString , ': ' , e messageText printString].
        s nextPutAll: '  pcl '; nextPutAll: sel asString; nextPutAll: ' -> '; nextPutAll: r printString; nextPutAll: nl].

"All instance selectors on Parcel matching 'content|class|extension|component|prereq' for finding inspection APIs"
s nextPutAll: nl; nextPutAll: '=== Parcel instance selectors matching content|class|extension|component|prereq|defin ==='; nextPutAll: nl.
((Kernel.Parcel selectors asArray select: [:sel | | sn |
    sn := sel asString asLowercase.
    (((((sn indexOfSubCollection: 'content' startingAt: 1) > 0)
        or: [(sn indexOfSubCollection: 'class' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'extension' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'component' startingAt: 1) > 0])
        or: [(sn indexOfSubCollection: 'defin' startingAt: 1) > 0]]) asSortedCollection) do: [:sel |
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].

s contents
