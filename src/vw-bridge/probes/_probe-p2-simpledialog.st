"Probe P2 SimpleDialog patch ownership - was choose:labels:values:default:for: shipped by VW before the bridge override, or is the bridge override the first definition? Informs unload safety (removeSelector: removes override AND restores inherited, vs removes the method entirely)."
| s nl m superCls walker found |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. SimpleDialog class location + shape."
s nextPutAll: '-- SimpleDialog class info --'; nextPutAll: nl.
s nextPutAll: '  class: '; nextPutAll: SimpleDialog class name; nextPutAll: nl.
s nextPutAll: '  category: '; nextPutAll: SimpleDialog category printString; nextPutAll: nl.
s nextPutAll: '  superclass: '; nextPutAll: SimpleDialog superclass name; nextPutAll: nl.
s nextPutAll: '  full namespace path: '; nextPutAll: SimpleDialog environment name; nextPutAll: '.'; nextPutAll: SimpleDialog name; nextPutAll: nl.

"2. choose:labels:values:default:for: directly on SimpleDialog?"
s nextPutAll: nl; nextPutAll: '-- choose:labels:values:default:for: --'; nextPutAll: nl.
m := SimpleDialog compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  DIRECT on SimpleDialog: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  DIRECT on SimpleDialog: PRESENT'; nextPutAll: nl.
        s nextPutAll: '    category: '; nextPutAll: m category printString; nextPutAll: nl.
        s nextPutAll: '    numArgs: '; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '    numTemps: '; nextPutAll: m numTemps printString; nextPutAll: nl.
        [s nextPutAll: '    package: '; nextPutAll: m package printString; nextPutAll: nl]
            on: Error do: [:e | s nextPutAll: '    package ERR'; nextPutAll: nl].
        [s nextPutAll: '    selector: '; nextPutAll: m selector asString; nextPutAll: nl]
            on: Error do: [:e | s nextPutAll: '    selector ERR'; nextPutAll: nl].
        [s nextPutAll: '    messages: '; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl]
            on: Error do: [:e | s nextPutAll: '    messages ERR'; nextPutAll: nl]].

"3. Walk superclass chain to find any inherited implementor."
s nextPutAll: nl; nextPutAll: '-- Superclass implementor walk --'; nextPutAll: nl.
walker := SimpleDialog superclass.
found := false.
[walker notNil] whileTrue: [
    | superM |
    superM := walker compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil].
    superM isNil
        ifFalse: [
            found := true.
            s nextPutAll: '  '; nextPutAll: walker name; nextPutAll: ' has it'; nextPutAll: nl.
            s nextPutAll: '    category: '; nextPutAll: superM category printString; nextPutAll: nl.
            [s nextPutAll: '    package: '; nextPutAll: superM package printString; nextPutAll: nl]
                on: Error do: [:e | s nextPutAll: '    package ERR'; nextPutAll: nl]].
    walker := walker superclass].
found ifFalse: [s nextPutAll: '  NO superclass implementor found - choose:labels:values:default:for: is DIRECT-ONLY on SimpleDialog'; nextPutAll: nl].

"4. Find all implementors of #choose:labels:values:default:for: across the image."
s nextPutAll: nl; nextPutAll: '-- All implementors of #choose:labels:values:default:for: --'; nextPutAll: nl.
| implementors |
implementors := OrderedCollection new.
Smalltalk allClasses do: [:cls |
    (cls compiledMethodAt: #choose:labels:values:default:for: ifAbsent: [nil]) notNil
        ifTrue: [implementors add: cls name asString]].
s nextPutAll: '  count: '; nextPutAll: implementors size printString; nextPutAll: nl.
implementors do: [:n | s nextPutAll: '    '; nextPutAll: n; nextPutAll: nl].

"5. SimpleDialog removeSelector: probe (read-only - check selector exists, do not actually call)."
s nextPutAll: nl; nextPutAll: '-- Removal mechanism availability --'; nextPutAll: nl.
#(#removeSelector: #removeSelector:ifAbsent: #removeFromSystem #removeFromSystemUnlogged) do: [:sel |
    s nextPutAll: '  SimpleDialog class canUnderstand: '; nextPutAll: sel asString; nextPutAll: ' = '.
    s nextPutAll: (SimpleDialog class canUnderstand: sel) printString; nextPutAll: nl].

s contents