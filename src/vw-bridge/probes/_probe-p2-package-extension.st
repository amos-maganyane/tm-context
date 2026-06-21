"Probe P2 package extension mechanism - how does VW assign a method extension on a base class to a SEPARATE package from the class's home package? Common conventions: category prefix *PackageName, or CompiledMethod package: setter, or something else. Examines an existing extension method in the image."
| s nl m |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. Find candidate extension methods - look at Core.String methods that might be extended by Tools or other packages."
s nextPutAll: '-- Sample categories on Core.String methods --'; nextPutAll: nl.
| cats |
cats := Set new.
(Core.String selectors asSortedCollection asArray first: (30 min: Core.String selectors size)) do: [:sel |
    m := Core.String compiledMethodAt: sel ifAbsent: [nil].
    m notNil ifTrue: [cats add: m category]].
cats asSortedCollection asArray do: [:c | s nextPutAll: '  '; nextPutAll: c printString; nextPutAll: nl].

"2. Look for ASTERISK-PREFIX categories which conventionally tag methods as belonging to a foreign package."
s nextPutAll: nl; nextPutAll: '-- Asterisk-prefixed categories on Core.String (extension methods) --'; nextPutAll: nl.
| extensions |
extensions := OrderedCollection new.
Core.String selectors do: [:sel |
    m := Core.String compiledMethodAt: sel ifAbsent: [nil].
    (m notNil and: [(m category asString indexOfSubCollection: '*' startingAt: 1) > 0])
        ifTrue: [extensions add: sel asString , ' -> ' , m category printString]].
s nextPutAll: '  count: '; nextPutAll: extensions size printString; nextPutAll: nl.
(extensions asSortedCollection asArray first: (10 min: extensions size)) do: [:e | s nextPutAll: '  '; nextPutAll: e; nextPutAll: nl].

"3. Sample Tools namespace - look for extension methods to other namespaces."
s nextPutAll: nl; nextPutAll: '-- Sample method package attribute (Tools.ParcelManager class>>initialize if present) --'; nextPutAll: nl.
m := Tools.ParcelManager class compiledMethodAt: #initialize ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  Tools.ParcelManager class>>initialize ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  category: '; nextPutAll: m category printString; nextPutAll: nl.
        [s nextPutAll: '  package: '; nextPutAll: m package printString; nextPutAll: nl]
            on: Error do: [:e | s nextPutAll: '  package ERR: '; nextPutAll: e messageText; nextPutAll: nl].
        [s nextPutAll: '  package class: '; nextPutAll: m package class name; nextPutAll: nl]
            on: Error do: [:e | nil]].

"4. Probe CompiledMethod >> package: setter availability (the conventional way to assign extension methods to a package programmatically)."
s nextPutAll: nl; nextPutAll: '-- CompiledMethod mutation surface --'; nextPutAll: nl.
m := SimpleDialog compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  m is nil - can not probe'; nextPutAll: nl]
    ifFalse: [
        #(#package: #setPackage: #category: #setCategory: #package #category) do: [:sel |
            s nextPutAll: '  CompiledMethod respondsTo: '; nextPutAll: sel asString; nextPutAll: ' = '.
            s nextPutAll: (m respondsTo: sel) printString; nextPutAll: nl]].

"5. Probe class-side >> compile:classified: or similar - the canonical compile-and-package method."
s nextPutAll: nl; nextPutAll: '-- Class-side compile-with-category APIs --'; nextPutAll: nl.
#(#compile:classified: #compile:classified:notifying: #compile:categorized: #compile:notifying:) do: [:sel |
    s nextPutAll: '  Object class canUnderstand: '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (Object class canUnderstand: sel) printString; nextPutAll: nl].

s contents