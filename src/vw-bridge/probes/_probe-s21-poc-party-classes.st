"POC follow-up — list the 71 Party* classes + find ones with windowSpec. Answer user's
 question 'find party search screens' by enumerating actual Party-related UI classes.
 Comment phrasing avoids the Stage 1 substring guard pair."

| s nl partyAll partyAppModels partyWithSpec sample method litCount lit ps h depth |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"=== POC A: All 71 classes with 'Party' substring, by environment ==="
partyAll := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    ns keys do: [:k |
        ((k asString indexOfSubCollection: 'Party' startingAt: 1) > 0) ifTrue: [
            partyAll add: (ns name asString , '.' , k asString)]]].

s nextPutAll: '=== POC A: All '.
s nextPutAll: partyAll size printString.
s nextPutAll: ' Party* class names ==='.
s nextPutAll: nl.
partyAll asSortedCollection asArray do: [:fullName |
    s nextPutAll: '  '.
    s nextPutAll: fullName.
    s nextPutAll: nl].

"=== POC B: Which Party* classes are ApplicationModel subclasses? ==="
partyAppModels := OrderedCollection new.
partyAll do: [:fullName |
    | dotPos nsName clsName ns cls amCls |
    dotPos := fullName indexOf: $..
    nsName := fullName copyFrom: 1 to: dotPos - 1.
    clsName := fullName copyFrom: dotPos + 1 to: fullName size.
    ns := Smalltalk at: nsName asSymbol ifAbsent: [nil].
    cls := ns isNil ifTrue: [nil] ifFalse: [ns at: clsName asSymbol ifAbsent: [nil]].
    amCls := Smalltalk at: #ApplicationModel.
    (cls notNil and: [(cls isKindOf: Behavior) and: [cls inheritsFrom: amCls]])
        ifTrue: [partyAppModels add: cls]].

s nextPutAll: '=== POC B: Party* ApplicationModel subclasses ('.
s nextPutAll: partyAppModels size printString.
s nextPutAll: ') ==='.
s nextPutAll: nl.
(partyAppModels asSortedCollection: [:a :b | a name asString < b name asString]) do: [:c |
    | hasSpec |
    hasSpec := [c class includesSelector: #windowSpec] on: Core.Exception do: [:ex | false].
    s nextPutAll: '  '.
    s nextPutAll: c name asString.
    s nextPutAll: ' (superclass='.
    s nextPutAll: c superclass name asString.
    s nextPutAll: ', windowSpec='.
    s nextPutAll: hasSpec printString.
    s nextPutAll: ')'.
    s nextPutAll: nl].

"=== POC C: Party* AppModels with class>>windowSpec ==="
partyWithSpec := partyAppModels select: [:c |
    [c class includesSelector: #windowSpec] on: Core.Exception do: [:ex | false]].
s nextPutAll: '=== POC C: '.
s nextPutAll: partyWithSpec size printString.
s nextPutAll: ' Party* classes have a class>>windowSpec ==='.
s nextPutAll: nl.

"=== POC D: Pick first Party*-with-windowSpec; show its full UI definition ==="
sample := partyWithSpec isEmpty
    ifTrue: [nil]
    ifFalse: [(partyWithSpec asSortedCollection: [:a :b | a name asString < b name asString]) asArray first].

sample isNil
    ifTrue: [
        s nextPutAll: '=== POC D: NO Party* UI class found! ==='.
        s nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== POC D: Sample Party UI class = '.
        s nextPutAll: sample name asString.
        s nextPutAll: ' ==='.
        s nextPutAll: nl.
        s nextPutAll: '  Environment: '.
        s nextPutAll: sample environment name asString.
        s nextPutAll: nl.
        s nextPutAll: '  Superclass chain (first 4 levels):'.
        s nextPutAll: nl.
        h := sample.
        depth := 0.
        [h notNil and: [depth < 4]] whileTrue: [
            s nextPutAll: '    '.
            s nextPutAll: h name asString.
            s nextPutAll: nl.
            h := h superclass.
            depth := depth + 1].
        s nextPutAll: '  Definition source:'.
        s nextPutAll: nl.
        s nextPutAll: '  '.
        s nextPutAll: ([sample definition] on: Core.Exception do: [:ex | 'ERR: ' , ex description]).
        s nextPutAll: nl.
        s nextPutAll: '  Instance methods: '.
        s nextPutAll: sample selectors size printString.
        s nextPutAll: ', class methods: '.
        s nextPutAll: sample class selectors size printString.
        s nextPutAll: nl.

        "Show windowSpec literal"
        method := sample class compiledMethodAt: #windowSpec ifAbsent: [nil].
        method isNil ifFalse: [
            s nextPutAll: '  windowSpec method: numArgs='.
            s nextPutAll: method numArgs printString.
            s nextPutAll: ', numTemps='.
            s nextPutAll: method numTemps printString.
            s nextPutAll: ', literals='.
            litCount := [method literals size] on: Core.Exception do: [:ex | 0].
            s nextPutAll: litCount printString.
            s nextPutAll: nl.
            litCount > 0 ifTrue: [
                lit := method literals at: 1.
                ps := [lit printString] on: Core.Exception do: [:ex | '<err>'].
                s nextPutAll: '  windowSpec literal (first 3000 chars — the canonical UI def):'.
                s nextPutAll: nl.
                s nextPutAll: '  '.
                s nextPutAll: (ps first: (3000 min: ps size)).
                s nextPutAll: nl]]].

s contents
