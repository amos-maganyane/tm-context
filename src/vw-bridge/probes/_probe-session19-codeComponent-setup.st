"Probe session-19 step 14: setup codeComponent before prepareCodeWriter: call.

Oracle's primary path (prepareCodeWriter: + writeToParcelFileNamed:...) requires parcel.codeComponent to be set.
parcelOutOn: messages list includes #codeComponent: (setter) - meaning the wrapping method 
sets codeComponent BEFORE calling prepareCodeWriter:.

Empty parcel respondsTo:#codeComponent=false. Need to discover:
  (1) What class is Parcel's superclass (CodeComponent per probe 2)?
  (2) Does CodeComponent have a codeComponent accessor?
  (3) Can we set codeComponent: self (parcel as own codeComponent)?
  (4) After setup, does prepareCodeWriter: succeed?"
| s nl matches parent parcel codeComponentCls testPath writer result |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Find implementors of writeToParcelFileNamed:..."
matches := OrderedCollection new.
Smalltalk allClasses do: [:c |
    (c includesSelector: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:) 
        ifTrue: [matches add: c name asString , ' (inst)']].
s nextPutAll: '=== implementors of writeToParcelFileNamed:... ==='; nextPutAll: nl.
matches isEmpty 
    ifTrue: [s nextPutAll: '  (none)'; nextPutAll: nl]
    ifFalse: [matches do: [:m | s nextPutAll: '  '; nextPutAll: m; nextPutAll: nl]].

"(2) Parcel hierarchy"
parent := Kernel.Parcel superclass.
s nextPutAll: '=== Parcel hierarchy ==='; nextPutAll: nl.
s nextPutAll: '  Kernel.Parcel superclass = '; nextPutAll: parent name asString; nextPutAll: nl.
s nextPutAll: '  Kernel.Parcel superclass superclass = '; nextPutAll: parent superclass name asString; nextPutAll: nl.

"(3) CodeComponent class lookup"
codeComponentCls := (Smalltalk allNameSpaces inject: nil into: [:found :ns | 
    found ifNil: [ns at: #CodeComponent ifAbsent: [nil]]]).
s nextPutAll: '  CodeComponent found = '; nextPutAll: codeComponentCls printString; nextPutAll: nl.
codeComponentCls notNil ifTrue: [
    s nextPutAll: '  CodeComponent>>codeComponent exists = '; 
      nextPutAll: (codeComponentCls includesSelector: #codeComponent) printString; nextPutAll: nl.
    s nextPutAll: '  CodeComponent>>codeComponent: exists = '; 
      nextPutAll: (codeComponentCls includesSelector: #codeComponent:) printString; nextPutAll: nl].

"(4) Try prepareCodeWriter: with codeComponent: self pre-setup"
parcel := Kernel.Parcel createParcelNamed: 'Test-Setup-Probe'.
parcel addEntiretyOfClass: VWB.VWBridge.
testPath := (OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME') , '\.generated\parcels\_test.pcl'.

"Set codeComponent: self - speculative but matches parcelOutOn:'s #codeComponent: literal"
[parcel codeComponent: parcel] on: Core.Exception do: [:ex | 
    s nextPutAll: 'codeComponent: self ERR: '; nextPutAll: ex description; nextPutAll: nl].
s nextPutAll: '=== after codeComponent: parcel ==='; nextPutAll: nl.
s nextPutAll: '  codeComponent instVar = '; 
  nextPutAll: ([parcel instVarNamed: 'codeComponent'] on: Core.Exception do: [:ex | 'ERR:', ex description]) printString; 
  nextPutAll: nl.

"Now try prepareCodeWriter:"
result := [[writer := parcel prepareCodeWriter: testPath asFilename.
            'writer-class=', writer class name asString , 
            ' responds-write=', (writer respondsTo: #writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:) printString]
    on: Core.Notification do: [:n | n resume]]
    on: Core.Exception do: [:ex | 'EXC: ', ex class name asString , ' / ', ex description].
s nextPutAll: '  prepareCodeWriter: result = '; nextPutAll: result printString; nextPutAll: nl.

"Cleanup"
[Kernel.Parcel removeParcelNamed: 'Test-Setup-Probe'] on: Core.Notification do: [:n | n resume].
s nextPutAll: 'final registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

s contents
