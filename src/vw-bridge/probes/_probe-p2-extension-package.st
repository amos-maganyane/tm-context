"Probe P2 extension package convention - confirms *PackageName category prefix is the canonical VW way to assign a method extension to a non-owning package. Read-only - inspects EXISTING extension methods in stock VW parcels via Kernel.Parcel introspection. Verifies Oracle's Q3 assumption without creating a scratch parcel."
| s nl loaded withExtensions sampleParcel sampleMethod sampleClass cnt |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. List currently-loaded parcels + which ones have extensions."
s nextPutAll: '-- Loaded parcels with extensions --'; nextPutAll: nl.
loaded := Kernel.Parcel parcels.
s nextPutAll: '  total loaded: '; nextPutAll: loaded size printString; nextPutAll: nl.
withExtensions := loaded select: [:p | [p hasExtensions] on: Error do: [:e | false]].
s nextPutAll: '  with extensions: '; nextPutAll: withExtensions size printString; nextPutAll: nl.
(withExtensions asArray first: (10 min: withExtensions size)) do: [:p |
    s nextPutAll: '    '; nextPutAll: p name; nextPutAll: ' (extends '.
    [s nextPutAll: p extendedClasses size printString; nextPutAll: ' class(es), '.
     s nextPutAll: p extensionMethods size printString; nextPutAll: ' methods)']
        on: Error do: [:e | s nextPutAll: 'ERR'].
    s nextPutAll: nl].

"2. Pick a representative parcel-with-extensions and inspect its first extension method."
s nextPutAll: nl; nextPutAll: '-- Sample extension method detail --'; nextPutAll: nl.
sampleParcel := withExtensions
    detect: [:p | [p extensionMethods notEmpty] on: Error do: [:e | false]]
    ifNone: [nil].
sampleParcel isNil
    ifTrue: [s nextPutAll: '  no extension-bearing parcel found'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  parcel: '; nextPutAll: sampleParcel name; nextPutAll: nl.
        s nextPutAll: '  extendedClasses (first 5): '; nextPutAll: nl.
        ((sampleParcel extendedClasses asArray first: (5 min: sampleParcel extendedClasses size))) do: [:c |
            s nextPutAll: '    '; nextPutAll: c name; nextPutAll: nl].
        s nextPutAll: '  extensionMethods (first 5): '; nextPutAll: nl.
        ((sampleParcel extensionMethods asArray first: (5 min: sampleParcel extensionMethods size))) do: [:m |
            s nextPutAll: '    '; nextPutAll: m printString; nextPutAll: nl].
        "Pick first extension method - what's its category on the extended class?"
        sampleParcel extensionMethods isEmpty ifFalse: [
            sampleMethod := sampleParcel extensionMethods asArray first.
            s nextPutAll: nl; nextPutAll: '  first ext method: '; nextPutAll: sampleMethod printString; nextPutAll: nl.
            s nextPutAll: '  class: '; nextPutAll: sampleMethod class name; nextPutAll: nl.
            "extensionMethods might return CompiledMethod or (class, selector) tuples - inspect."
            [s nextPutAll: '  selector: '; nextPutAll: sampleMethod selector asString; nextPutAll: nl]
                on: Error do: [:e | s nextPutAll: '  selector ERR'; nextPutAll: nl]]].

"3. Walk extension method categories on a specific extended class to find *PackageName patterns."
s nextPutAll: nl; nextPutAll: '-- Asterisk-categories on Core.Object instance side --'; nextPutAll: nl.
cnt := 0.
Core.Object selectors do: [:sel |
    | m |
    m := Core.Object compiledMethodAt: sel ifAbsent: [nil].
    (m notNil and: [
        (m category notNil and: [
            (m category asString indexOfSubCollection: '*' startingAt: 1) > 0])])
        ifTrue: [
            cnt := cnt + 1.
            cnt <= 12 ifTrue: [
                s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: ' -> '; nextPutAll: m category printString; nextPutAll: nl]]].
s nextPutAll: '  (total asterisk-categories on Core.Object: '; nextPutAll: cnt printString; nextPutAll: ')'; nextPutAll: nl.

"4. Same for Core.String."
s nextPutAll: nl; nextPutAll: '-- Asterisk-categories on Core.String instance side --'; nextPutAll: nl.
cnt := 0.
Core.String selectors do: [:sel |
    | m |
    m := Core.String compiledMethodAt: sel ifAbsent: [nil].
    (m notNil and: [
        (m category notNil and: [
            (m category asString indexOfSubCollection: '*' startingAt: 1) > 0])])
        ifTrue: [
            cnt := cnt + 1.
            cnt <= 8 ifTrue: [
                s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: ' -> '; nextPutAll: m category printString; nextPutAll: nl]]].
s nextPutAll: '  (total asterisk-categories on Core.String: '; nextPutAll: cnt printString; nextPutAll: ')'; nextPutAll: nl.

s contents