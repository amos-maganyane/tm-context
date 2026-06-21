"Probe session-19 step 19: locate ParcelWriter + ParcelBuilder classes in image.

StoreCI-Building (open-source CI tool for VW, https://github.com/randycoulman/StoreCI)
uses a ParcelWriter class for headless parcel build. If our image has this class
(or its equivalent), we have the canonical headless build API.

Search:
  - Walk all namespaces for ParcelWriter, ParcelBuilder, ParcelDeployer, ParcelLoader
  - Also check Store namespace for build/deploy/output APIs"
| s nl matches names storeNs storeRelevant |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Find any class with 'Parcel' substring in its name + 'Writer/Builder/Deployer/Loader' suffix"
matches := OrderedCollection new.
names := #('ParcelWriter' 'ParcelBuilder' 'ParcelDeployer' 'ParcelLoader' 
           'PundleWriter' 'PundleBuilder' 'PundleDeployer' 'BuildingSubsystem' 'PundleLoader').
Smalltalk allNameSpaces do: [:ns |
    ns keys do: [:k |
        (names includes: k asString) ifTrue: [
            matches add: ns name asString , '.' , k asString]]].
s nextPutAll: '=== exact-name matches across all namespaces ==='; nextPutAll: nl.
matches isEmpty
    ifTrue: [s nextPutAll: '  (none)'; nextPutAll: nl]
    ifFalse: [matches do: [:m | s nextPutAll: '  '; nextPutAll: m; nextPutAll: nl]].

"(2) Store namespace keys matching build/write/deploy/output/save patterns"
storeNs := Smalltalk at: #Store ifAbsent: [nil].
storeNs notNil ifTrue: [
    storeRelevant := (storeNs keys asArray) select: [:k |
        ((k asString indexOfSubCollection: 'Write' startingAt: 1) > 0) or: [
        ((k asString indexOfSubCollection: 'Build' startingAt: 1) > 0) or: [
        ((k asString indexOfSubCollection: 'Deploy' startingAt: 1) > 0) or: [
        ((k asString indexOfSubCollection: 'Output' startingAt: 1) > 0) or: [
        ((k asString indexOfSubCollection: 'Parcel' startingAt: 1) > 0)]]]]].
    s nextPutAll: '=== Store keys matching Write|Build|Deploy|Output|Parcel ==='; nextPutAll: nl.
    storeRelevant asSortedCollection do: [:k | s nextPutAll: '  Store.'; nextPutAll: k asString; nextPutAll: nl]].

"(3) BasicPackagePolicy as anchor - check related package classes"
s nextPutAll: '=== Store classes BasicPackage* ==='; nextPutAll: nl.
storeNs notNil ifTrue: [
    (storeNs keys asArray) asSortedCollection do: [:k |
        ((k asString indexOfSubCollection: 'BasicPackage' startingAt: 1) > 0) 
            ifTrue: [s nextPutAll: '  Store.'; nextPutAll: k asString; nextPutAll: nl]]].

s contents
