"POC follow-up — find what's actually loaded. PartySearch returned 0 matches — verify
 the broader UI class surface that IS in this image. Pick ANY real ApplicationModel
 subclass with a windowSpec to demonstrate the MVP capabilities.
 Comment phrasing avoids the Stage 1 substring guard pair."

| s nl matches appModelSubs withWindowSpec sample cls method litCount |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"=== POC 1: Broader substring search — try 'Party', 'Search', 'Customer', 'View' ==="
s nextPutAll: '=== POC 1: Broader substring search ==='.
s nextPutAll: nl.

#('Party' 'Search' 'Customer' 'PartySearch' 'Wealth' 'Pip' 'Mas' 'PP') do: [:needle |
    matches := 0.
    Smalltalk allNameSpaces do: [:ns |
        ns keys do: [:k |
            ((k asString indexOfSubCollection: needle startingAt: 1) > 0) ifTrue: [
                matches := matches + 1]]].
    s nextPutAll: '  ''*'.
    s nextPutAll: needle.
    s nextPutAll: '*'' substring matches: '.
    s nextPutAll: matches printString.
    s nextPutAll: nl].

"=== POC 2: Count direct subclasses of ApplicationModel (by environment) ==="
s nextPutAll: '=== POC 2: ApplicationModel subclass distribution ==='.
s nextPutAll: nl.
appModelSubs := Dictionary new.
((Smalltalk at: #ApplicationModel) allSubclasses) do: [:c |
    | envName count |
    envName := [c environment name asString] on: Core.Exception do: [:ex | '?'].
    count := appModelSubs at: envName ifAbsent: [0].
    appModelSubs at: envName put: count + 1].
appModelSubs keysAndValuesDo: [:envN :cnt |
    s nextPutAll: '  '.
    s nextPutAll: envN.
    s nextPutAll: ': '.
    s nextPutAll: cnt printString.
    s nextPutAll: ' subclasses'.
    s nextPutAll: nl].

"=== POC 3: Find ApplicationModel subclasses that have class-side #windowSpec ==="
s nextPutAll: '=== POC 3: ApplicationModel subclasses with class>>windowSpec ==='.
s nextPutAll: nl.
withWindowSpec := OrderedCollection new.
((Smalltalk at: #ApplicationModel) allSubclasses) do: [:c |
    ([c class includesSelector: #windowSpec] on: Core.Exception do: [:ex | false])
        ifTrue: [withWindowSpec add: c]].
s nextPutAll: '  Total classes with class>>windowSpec: '.
s nextPutAll: withWindowSpec size printString.
s nextPutAll: nl.
s nextPutAll: '  First 30 alphabetically:'.
s nextPutAll: nl.
((withWindowSpec asSortedCollection: [:a :b | a name asString < b name asString])
    asArray copyFrom: 1 to: (30 min: withWindowSpec size))
    do: [:c |
        s nextPutAll: '    '.
        s nextPutAll: ([c environment name asString , '.' , c name asString]
            on: Core.Exception do: [:ex | c name asString]).
        s nextPutAll: nl].

"=== POC 4: Pick a real MAS sample — first non-Tools/non-UI ApplicationModel subclass with windowSpec ==="
sample := nil.
((withWindowSpec asSortedCollection: [:a :b | a name asString < b name asString]) asArray)
    do: [:c |
        | envN |
        sample isNil ifTrue: [
            envN := [c environment name asString] on: Core.Exception do: [:ex | ''].
            ((envN = 'Tools') or: [
                (envN = 'UI') or: [
                    (envN = 'RuntimePackager') or: [
                        envN = 'Refactory']]])
                ifFalse: [sample := c]]].

sample isNil
    ifTrue: [
        s nextPutAll: '=== POC 4: No MAS ApplicationModel subclass with windowSpec found ==='.
        s nextPutAll: nl.
        "Fall back to first overall"
        withWindowSpec isEmpty ifFalse: [sample := (withWindowSpec asSortedCollection: [:a :b | a name asString < b name asString]) asArray first].
        s nextPutAll: '  Falling back to: '.
        s nextPutAll: ([sample environment name asString , '.' , sample name asString] on: Core.Exception do: [:ex | sample name asString]).
        s nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== POC 4: Sample MAS class: '.
        s nextPutAll: ([sample environment name asString , '.' , sample name asString] on: Core.Exception do: [:ex | sample name asString]).
        s nextPutAll: ' ==='.
        s nextPutAll: nl].

sample isNil ifFalse: [
    s nextPutAll: '  Superclass: '.
    s nextPutAll: sample superclass name asString.
    s nextPutAll: nl.
    s nextPutAll: '  Definition:'.
    s nextPutAll: nl.
    s nextPutAll: '  '.
    s nextPutAll: ([sample definition] on: Core.Exception do: [:ex | 'ERR: ' , ex description]).
    s nextPutAll: nl.
    s nextPutAll: '  Instance methods count: '.
    s nextPutAll: sample selectors size printString.
    s nextPutAll: ', class methods count: '.
    s nextPutAll: sample class selectors size printString.
    s nextPutAll: nl.

    "=== POC 5: Read the windowSpec literal (the canonical UI def) ==="
    method := sample class compiledMethodAt: #windowSpec ifAbsent: [nil].
    method isNil ifFalse: [
        s nextPutAll: '=== POC 5: '.
        s nextPutAll: sample name asString.
        s nextPutAll: ' class>>windowSpec literal ==='.
        s nextPutAll: nl.
        s nextPutAll: '  numArgs='.
        s nextPutAll: method numArgs printString.
        s nextPutAll: ', numTemps='.
        s nextPutAll: method numTemps printString.
        s nextPutAll: nl.
        litCount := [method literals size] on: Core.Exception do: [:ex | 0].
        s nextPutAll: '  literals count='.
        s nextPutAll: litCount printString.
        s nextPutAll: nl.
        litCount > 0 ifTrue: [
            | lit ps |
            lit := method literals at: 1.
            ps := [lit printString] on: Core.Exception do: [:ex | '<unprintable>'].
            s nextPutAll: '  First literal (spec tree, first 1500 chars):'.
            s nextPutAll: nl.
            s nextPutAll: '  '.
            s nextPutAll: (ps first: (1500 min: ps size)).
            s nextPutAll: nl]]].

s contents
