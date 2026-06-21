| s nl newCls oldBare vwbKeys |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
newCls := VWB.VWBridge.
oldBare := Smalltalk at: #VWBridge ifAbsent: [nil].
vwbKeys := VWB keys asSortedCollection asArray.
s nextPutAll: 'newCls.name='; nextPutAll: newCls name; nextPutAll: nl.
s nextPutAll: 'newCls.environment.name='; nextPutAll: newCls environment name; nextPutAll: nl.
s nextPutAll: 'oldBareSmalltalkAtVWBridge='; nextPutAll: oldBare printString; nextPutAll: nl.
s nextPutAll: 'VWB.keys='; nextPutAll: vwbKeys printString; nextPutAll: nl.
s nextPutAll: 'singleton.class.env='; nextPutAll: newCls singleton class environment name; nextPutAll: nl.
s nextPutAll: 'simpleDialogPatchCat='; nextPutAll: (SimpleDialog organization categoryOfElement: #choose:labels:values:default:for:) printString; nextPutAll: nl.
s contents
