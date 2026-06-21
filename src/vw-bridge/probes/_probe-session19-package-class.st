"Probe session-19 step 2: locate Package + Bundle + Pundle classes; understand parcel content-unit API.
Non-destructive class-lookup walk across all 312 namespaces."
| s nl matches candidates probeSelectors thisCls thisNs found |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
candidates := #('Package' 'Bundle' 'Pundle' 'PackageOrganizer' 'SourcePackage' 'SystemPackage').
matches := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns | 
    ns keys do: [:k | 
        candidates do: [:cand | 
            (k asString = cand) ifTrue: [
                matches add: (ns name asString , '.' , k asString)]]]].
s nextPutAll: '=== exact-name matches across all namespaces ==='; nextPutAll: nl.
matches asSortedCollection asArray do: [:m | s nextPutAll: '  '; nextPutAll: m; nextPutAll: nl].
"Now try to find the central class that the system uses for packages"
s nextPutAll: '=== Smalltalk at: lookups for common names ==='; nextPutAll: nl.
#(#Package #Bundle #Pundle #SourcePackage #PackageOrganizer #PackageInfo) do: [:sym |
    thisCls := Smalltalk at: sym ifAbsent: [nil].
    s nextPutAll: '  Smalltalk at: #'; nextPutAll: sym asString; nextPutAll: ' -> '; 
      nextPutAll: thisCls printString; nextPutAll: nl].
"Try Store namespace (VW package mgmt traditionally lives there)"
s nextPutAll: '=== Store namespace ==='; nextPutAll: nl.
thisNs := Smalltalk at: #Store ifAbsent: [nil].
thisNs isNil 
    ifTrue: [s nextPutAll: '  Store namespace ABSENT'; nextPutAll: nl]
    ifFalse: [
        probeSelectors := thisNs keys asSortedCollection asArray.
        s nextPutAll: '  Store has '; nextPutAll: probeSelectors size printString; 
          nextPutAll: ' keys: '; nextPutAll: (probeSelectors first: (probeSelectors size min: 20)) printString; nextPutAll: nl].
"Try the bundleName/parcelName instance methods on a Parcel instance to see what they return"
s nextPutAll: '=== Sample loaded parcel inspect ==='; nextPutAll: nl.
found := Kernel.Parcel parcels isEmpty
    ifTrue: [nil]
    ifFalse: [Kernel.Parcel parcels first].
found isNil 
    ifTrue: [s nextPutAll: '  no parcels loaded'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  class='; nextPutAll: found class name; nextPutAll: nl.
        s nextPutAll: '  bundleName='; nextPutAll: (found respondsTo: #bundleName) printString; nextPutAll: nl.
        (found respondsTo: #bundleName) ifTrue: [
            s nextPutAll: '    value='; nextPutAll: found bundleName printString; nextPutAll: nl]].
s contents
