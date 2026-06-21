"Probe P2 SimpleDialog patch ownership (v2 - clean temp decl, defensive errors). Critical question: was choose:labels:values:default:for: ORIGINALLY in this image, or added solely by the bridge override? Determines unload safety (does removeSelector: restore inherited original, or leave a hole that breaks production)."
| s nl m walker impls catSafe pkgSafe |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

catSafe := [:cls | [cls category printString] on: Error do: [:e | 'ERR(' , e messageText , ')']].
pkgSafe := [:method | [method package printString] on: Error do: [:e | 'ERR(' , e messageText , ')']].

"1. SimpleDialog class basics."
s nextPutAll: '-- SimpleDialog --'; nextPutAll: nl.
s nextPutAll: '  superclass: '; nextPutAll: SimpleDialog superclass name; nextPutAll: nl.
s nextPutAll: '  category: '; nextPutAll: (catSafe value: SimpleDialog); nextPutAll: nl.

"2. Is choose:labels:values:default:for: DIRECTLY on SimpleDialog?"
s nextPutAll: nl; nextPutAll: '-- DIRECT on SimpleDialog --'; nextPutAll: nl.
m := SimpleDialog compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  PRESENT'; nextPutAll: nl.
        s nextPutAll: '  category: '; nextPutAll: [m category printString] on: Error do: [:e | 'ERR']; nextPutAll: nl.
        s nextPutAll: '  package: '; nextPutAll: (pkgSafe value: m); nextPutAll: nl.
        s nextPutAll: '  numArgs: '; nextPutAll: m numArgs printString; nextPutAll: nl].

"3. Walk superclass chain - is there an inherited implementor?"
s nextPutAll: nl; nextPutAll: '-- Superclass implementor walk --'; nextPutAll: nl.
walker := SimpleDialog superclass.
[walker notNil] whileTrue: [
    | superM |
    superM := walker compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
    superM isNil
        ifFalse: [
            s nextPutAll: '  '; nextPutAll: walker name; nextPutAll: nl.
            s nextPutAll: '    category: '; nextPutAll: [superM category printString] on: Error do: [:e | 'ERR']; nextPutAll: nl.
            s nextPutAll: '    package: '; nextPutAll: (pkgSafe value: superM); nextPutAll: nl].
    walker := walker superclass].

"4. All implementors of #choose:labels:values:default:for: across all classes."
s nextPutAll: nl; nextPutAll: '-- All implementors across allClasses --'; nextPutAll: nl.
impls := OrderedCollection new.
Smalltalk allClasses do: [:cls |
    (cls compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil]) notNil
        ifTrue: [impls add: cls name asString]].
s nextPutAll: '  count: '; nextPutAll: impls size printString; nextPutAll: nl.
impls do: [:n | s nextPutAll: '    '; nextPutAll: n; nextPutAll: nl].

"5. Removal mechanism availability."
s nextPutAll: nl; nextPutAll: '-- SimpleDialog metaclass selectors for removal --'; nextPutAll: nl.
#(#removeSelector: #removeSelector:ifAbsent: #removeFromSystem #removeFromSystemUnlogged) do: [:sel |
    s nextPutAll: '  canUnderstand: '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (SimpleDialog class canUnderstand: sel) printString; nextPutAll: nl].

"6. CompiledMethod accessor surface (package + category)."
s nextPutAll: nl; nextPutAll: '-- CompiledMethod accessors --'; nextPutAll: nl.
m isNil ifFalse: [
    #(#package #category #selector #numArgs #numTemps #methodClass) do: [:sel |
        s nextPutAll: '  respondsTo: '; nextPutAll: sel asString; nextPutAll: ' = '.
        s nextPutAll: (m respondsTo: sel) printString; nextPutAll: nl]].

s contents