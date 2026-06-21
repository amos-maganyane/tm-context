"Probe session-19 step 13: discover CodeWriter class per Oracle recommendation.

Oracle's bottom line: bypass parcelOutOn: (which wraps Cursor wait showWhile:) and call
prepareCodeWriter: + writeToParcelFileNamed:... directly on the returned writer.

This probe:
  (1) Finds implementors of writeToParcelFileNamed:sourceFileNamed:... across all classes
  (2) Calls prepareCodeWriter: on a newly-created empty parcel to learn the writer's class
  (3) Cleans up the test parcel via Notification-resume

NO parcelOutOn: call - keeps bridge alive."
| s nl matches parcel testPath writer cleanup |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Find implementors of writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:"
matches := OrderedCollection new.
Smalltalk allClasses do: [:c |
    (c includesSelector: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:) 
        ifTrue: [matches add: c name asString , ' (inst)'].
    (c class includesSelector: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:) 
        ifTrue: [matches add: c name asString , ' (class)']].
s nextPutAll: '=== implementors of writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup: ==='; nextPutAll: nl.
matches isEmpty 
    ifTrue: [s nextPutAll: '  (none found)'; nextPutAll: nl]
    ifFalse: [matches do: [:m | s nextPutAll: '  '; nextPutAll: m; nextPutAll: nl]].

"(2) Discover writer class via prepareCodeWriter:"
parcel := Kernel.Parcel createParcelNamed: 'Test-CodeWriter-Probe'.
testPath := (OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME') , '\.generated\parcels\_test.pcl'.
s nextPutAll: '=== prepareCodeWriter: result ==='; nextPutAll: nl.
writer := [parcel prepareCodeWriter: testPath asFilename]
    on: Core.Notification do: [:n | n resume]. 
s nextPutAll: '  writer class = '; nextPutAll: writer class name; nextPutAll: nl.
s nextPutAll: '  writer printString = '; nextPutAll: writer printString; nextPutAll: nl.
s nextPutAll: '  responds writeToParcelFileNamed:... = '; 
  nextPutAll: (writer respondsTo: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:) printString; 
  nextPutAll: nl.
s nextPutAll: '  responds asLogicalFileSpecification = ';
  nextPutAll: (writer respondsTo: #asLogicalFileSpecification) printString; nextPutAll: nl.

"(3) Cleanup: remove test parcel from registry"
cleanup := [Kernel.Parcel removeParcelNamed: 'Test-CodeWriter-Probe']
    on: Core.Notification do: [:n | n resume].
s nextPutAll: 'cleanup result = '; nextPutAll: cleanup printString; nextPutAll: nl.
s nextPutAll: 'final registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

s contents
