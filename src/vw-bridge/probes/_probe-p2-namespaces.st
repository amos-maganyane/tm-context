"Probe P2 namespaces - how non-top-level and MAS-style top-level namespaces are organized in this image. Inputs Oracle's namespace-naming recommendation for VWBridge migration off Root.Smalltalk."
| s nl ns m |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. Established VW nested namespaces - sample shapes."
s nextPutAll: '-- Established nested VW namespaces --'; nextPutAll: nl.
#('Kernel' 'Tools' 'OS' 'Net' 'Core' 'UI' 'Graphics' 'FileTools' 'RuntimePackager') do: [:nsName |
    ns := Smalltalk at: nsName asSymbol ifAbsent: [nil].
    ns isNil
        ifTrue: [s nextPutAll: '  '; nextPutAll: nsName; nextPutAll: ' ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: '  '; nextPutAll: nsName; nextPutAll: ' class='; nextPutAll: ns class name.
            s nextPutAll: ' size='; nextPutAll: ns keys size printString; nextPutAll: nl]].

"2. MAS-style flat-name namespaces (no nesting)."
s nextPutAll: nl; nextPutAll: '-- MAS-style flat namespaces (sample) --'; nextPutAll: nl.
#('Pip' 'PipDispatcher' 'Wealth' 'WealthMain' 'WealthCommon' 'Risk' 'PP' 'PPBase') do: [:nsName |
    ns := Smalltalk at: nsName asSymbol ifAbsent: [nil].
    ns isNil
        ifTrue: [s nextPutAll: '  '; nextPutAll: nsName; nextPutAll: ' ABSENT'; nextPutAll: nl]
        ifFalse: [
            s nextPutAll: '  '; nextPutAll: nsName; nextPutAll: ' class='; nextPutAll: ns class name.
            s nextPutAll: ' size='; nextPutAll: ns keys size printString; nextPutAll: nl]].

"3. Discover NameSpace class - what selectors create a new namespace?"
s nextPutAll: nl; nextPutAll: '-- NameSpace creation API --'; nextPutAll: nl.
#(#defineNameSpace:private:imports:category: #defineNameSpace:imports:category: #addNamespace:) do: [:sel |
    s nextPutAll: '  Root.Smalltalk class canUnderstand: '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (Root.Smalltalk class canUnderstand: sel) printString; nextPutAll: nl].
"NameSpace selectors:"
[s nextPutAll: '  NameSpace class selectors size: '; nextPutAll: NameSpace class selectors size printString; nextPutAll: nl.
 s nextPutAll: '  Smalltalk class selectors related to NameSpace: '; nextPutAll: nl.
 (Smalltalk class selectors asSortedCollection asArray select: [:sel | (sel asString indexOfSubCollection: 'ame' startingAt: 1) > 0 or: [(sel asString indexOfSubCollection: 'space' startingAt: 1) > 0]]) do: [:sel |
    s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]
    on: Error do: [:e | s nextPutAll: '  ERR '; nextPutAll: e messageText; nextPutAll: nl].

"4. Class def syntax - look at Kernel.Parcel for an example of nested class."
s nextPutAll: nl; nextPutAll: '-- Kernel.Parcel class metadata --'; nextPutAll: nl.
s nextPutAll: '  category: '; nextPutAll: Kernel.Parcel category printString; nextPutAll: nl.
[s nextPutAll: '  sourcePackage: '; nextPutAll: Kernel.Parcel sourcePackage printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  sourcePackage ERR'; nextPutAll: nl].

"5. Sample a method from Kernel.Parcel - what's its package attribute?"
m := Kernel.Parcel class compiledMethodAt: #findAndLoadParcels ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  findAndLoadParcels method ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  findAndLoadParcels category: '; nextPutAll: m category printString; nextPutAll: nl.
        [s nextPutAll: '  findAndLoadParcels package: '; nextPutAll: m package printString; nextPutAll: nl]
            on: Error do: [:e | s nextPutAll: '  package ERR: '; nextPutAll: e messageText; nextPutAll: nl]].

"6. VWBridge current state metadata."
s nextPutAll: nl; nextPutAll: '-- VWBridge current state --'; nextPutAll: nl.
s nextPutAll: '  category: '; nextPutAll: VWBridge category printString; nextPutAll: nl.
s nextPutAll: '  superclass: '; nextPutAll: VWBridge superclass name; nextPutAll: nl.
s nextPutAll: '  namespace: '; nextPutAll: VWBridge environment name; nextPutAll: nl.
[s nextPutAll: '  sourcePackage: '; nextPutAll: VWBridge sourcePackage printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  sourcePackage ERR'; nextPutAll: nl].

s contents