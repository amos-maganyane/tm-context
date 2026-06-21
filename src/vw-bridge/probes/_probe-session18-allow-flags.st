"Probe session-18 P5 ImageConfigurationSystem allow-flags state.

Confirms whether -filein / -doit / -evaluate / -pcl / -settings are actually
permitted to run in THIS MAS image. The class-side allow* methods may return
hardcoded false if MAS deployment locked them down. If allowFilein returns
false, Oracles Path 4 design will not work."

| s nl ics m cli |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
ics := Core.ImageConfigurationSystem.

s nextPutAll: 'class: '; nextPutAll: ics name; nextPutAll: ' env='; nextPutAll: ics environment name; nextPutAll: nl.
s nextPutAll: 'superclass: '; nextPutAll: ics superclass name; nextPutAll: nl.
s nextPutAll: 'instance count: '; nextPutAll: ics allInstances size printString; nextPutAll: nl.
s nextPutAll: 'class instVarNames: '; nextPutAll: ics class instVarNames printString; nextPutAll: nl.
s nextPutAll: nl.

s nextPutAll: '=== allow* zero-arg class-side accessors ==='; nextPutAll: nl.
#(#allowDevelopment #allowExpressions #allowFilein #allowParcelLoading #allowSettings #useDefaultConfigFile) do: [:sel |
    | val |
    val := [ics perform: sel] on: Core.Exception do: [:ex | 'ERR=' , ex class name asString].
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: ' => '; nextPutAll: val printString; nextPutAll: nl].
s nextPutAll: nl.

s nextPutAll: '=== behavior fingerprint: allowFilein class-method literals ==='; nextPutAll: nl.
m := ics class compiledMethodAt: #allowFilein ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: '  ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  numTemps='; nextPutAll: m numTemps printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
        s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl].
s nextPutAll: nl.

s nextPutAll: '=== Core.CommandLineInterest peek (per AppDevGuide p469) ==='; nextPutAll: nl.
cli := Smalltalk at: #CommandLineInterest ifAbsent: [nil].
cli isNil
    ifTrue: [s nextPutAll: 'CommandLineInterest: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '  class env: '; nextPutAll: cli environment name; nextPutAll: nl.
        s nextPutAll: '  class-side selectors count: '; nextPutAll: cli class selectors size printString; nextPutAll: nl.
        s nextPutAll: '  instance-side selectors count: '; nextPutAll: cli selectors size printString; nextPutAll: nl.
        s nextPutAll: '  active interest count (allInstances): '; nextPutAll: cli allInstances size printString; nextPutAll: nl].

s contents
