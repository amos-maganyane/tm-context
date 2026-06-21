"Probe session-18 P5 ImageConfigurationSystem image-level switch enumeration.

Non-destructive image-side analog of -listOptions. Queries this MAS image to confirm:
  1. ImageConfigurationSystem class is present
  2. -filein image-level switch is actually defined (not stripped by MAS)
  3. What other switches are available
  4. The Headless package referenced by -listOptions in AppDevGuide.pdf p36

Per AppDevGuide page 251: ImageConfigurationSystem defines several standard image
level command line options and their handling. So introspecting that class gives the
authoritative list for THIS image."

| s nl ics swMap headless mech result |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

s nextPutAll: '=== ImageConfigurationSystem lookup ==='; nextPutAll: nl.
ics := Smalltalk at: #ImageConfigurationSystem ifAbsent: [nil].
ics isNil
    ifTrue: [
        s nextPutAll: 'Top-level lookup: nil (not at Smalltalk top); walking namespaces...'; nextPutAll: nl.
        Smalltalk allNameSpaces do: [:ns |
            (ns keys asArray select: [:k | (k asString indexOfSubCollection: 'ImageConfigurationSystem' startingAt: 1) > 0])
                do: [:k | s nextPutAll: '  found: '; nextPutAll: (ns name , '.' , k asString); nextPutAll: nl]]]
    ifFalse: [
        s nextPutAll: 'top-level ImageConfigurationSystem present, env='; nextPutAll: ics environment name; nextPutAll: nl].

s nextPutAll: nl.
s nextPutAll: '=== walk for *ImageConfig* / *Headless* / *CommandLine* / *Startup* across all namespaces ==='; nextPutAll: nl.
Smalltalk allNameSpaces do: [:ns |
    ns keys asArray do: [:k |
        | key |
        key := k asString.
        (((key indexOfSubCollection: 'ImageConfig' startingAt: 1) > 0)
            or: [((key indexOfSubCollection: 'Headless' startingAt: 1) > 0)
                or: [((key indexOfSubCollection: 'CommandLine' startingAt: 1) > 0)
                    or: [((key indexOfSubCollection: 'StartUp' startingAt: 1) > 0)
                        or: [((key indexOfSubCollection: 'Startup' startingAt: 1) > 0)
                            or: [((key indexOfSubCollection: 'SwitchHandler' startingAt: 1) > 0)
                                or: [((key indexOfSubCollection: 'ImageSwitch' startingAt: 1) > 0)]]]]]])
            ifTrue: [s nextPutAll: '  '; nextPutAll: ns name; nextPutAll: '.'; nextPutAll: key; nextPutAll: nl]]].

s nextPutAll: nl.
s nextPutAll: '=== if ImageConfigurationSystem present, list class-side selectors ==='; nextPutAll: nl.
ics isNil
    ifFalse: [
        | sels |
        sels := ics class selectors asSortedCollection asArray.
        s nextPutAll: 'class-side selectors count = '; nextPutAll: sels size printString; nextPutAll: nl.
        sels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl]].

s nextPutAll: nl.
s nextPutAll: '=== look up Headless namespace ==='; nextPutAll: nl.
headless := Smalltalk at: #Headless ifAbsent: [nil].
headless isNil
    ifTrue: [s nextPutAll: 'Headless top-level: nil'; nextPutAll: nl]
    ifFalse: [s nextPutAll: 'Headless top-level: '; nextPutAll: headless printString; nextPutAll: nl].

s nextPutAll: nl.
s nextPutAll: '=== probe: -filein switch defined? probe via SessionManager / cli option scan ==='; nextPutAll: nl.
mech := Smalltalk at: #SessionManager ifAbsent: [nil].
mech isNil
    ifTrue: [s nextPutAll: 'SessionManager: ABSENT'; nextPutAll: nl]
    ifFalse: [
        | inst |
        inst := mech instance.
        s nextPutAll: 'SessionManager instance: '; nextPutAll: inst printString; nextPutAll: nl.
        inst isNil ifFalse: [
            s nextPutAll: '  class: '; nextPutAll: inst class name; nextPutAll: nl.
            (inst respondsTo: #commandLineArgs) ifTrue: [s nextPutAll: '  responds-to commandLineArgs'; nextPutAll: nl].
            (inst respondsTo: #arguments) ifTrue: [s nextPutAll: '  responds-to arguments'; nextPutAll: nl]]].

s contents
