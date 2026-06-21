"POC probe — session-21. Demonstrate the v2 MVP capabilities work via /eval BEFORE
 locking the design. Specifically: can we find UI classes (PartySearch screens)?

 Tests 5 capabilities, each one mapping to an MVP-tier MCP tool:
  POC 1 -> vw_list_namespace_entries / vw_search_classes : find PartySearch* classes
  POC 2 -> vw_get_class_definition : get definition source
  POC 3 -> vw_list_methods : list methods grouped
  POC 4 -> vw_get_method_fingerprint : read the windowSpec literal (canonical spec)
  POC 5 -> vw_get_class_hierarchy : verify it's an ApplicationModel subclass

 Comment phrasing avoids the Stage 1 substring guard pair."

| s nl partySearchClasses cls method lit hierarchy litCount |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"=== POC 1: Find all PartySearch* classes via namespace walk ==="
partySearchClasses := OrderedCollection new.
Smalltalk allNameSpaces do: [:ns |
    ns keys do: [:k |
        ((k asString indexOfSubCollection: 'PartySearch' startingAt: 1) > 0) ifTrue: [
            partySearchClasses add: (ns name asString , '.' , k asString)]]].

s nextPutAll: '=== POC 1: PartySearch classes found ('.
s nextPutAll: partySearchClasses size printString.
s nextPutAll: ') ==='.
s nextPutAll: nl.
partySearchClasses asSortedCollection asArray do: [:fullName |
    s nextPutAll: '  '.
    s nextPutAll: fullName.
    s nextPutAll: nl].

"=== POC 2: Resolve PartySearchView and get definition ==="
cls := nil.
Smalltalk allNameSpaces do: [:ns |
    (cls isNil and: [ns includesKey: #PartySearchView]) ifTrue: [
        cls := ns at: #PartySearchView]].

cls isNil
    ifTrue: [
        s nextPutAll: '=== POC 2: PartySearchView ABSENT ==='.
        s nextPutAll: nl.
        "Fall back: pick first match for the rest of the POCs"
        partySearchClasses isEmpty ifFalse: [
            | first nsName clsName ns |
            first := partySearchClasses asSortedCollection asArray first.
            nsName := first copyFrom: 1 to: (first indexOf: $.) - 1.
            clsName := first copyFrom: (first indexOf: $.) + 1 to: first size.
            ns := Smalltalk at: nsName asSymbol ifAbsent: [nil].
            ns isNil ifFalse: [
                cls := ns at: clsName asSymbol ifAbsent: [nil].
                s nextPutAll: '  Falling back to: '.
                s nextPutAll: first.
                s nextPutAll: nl]]]
    ifFalse: [
        s nextPutAll: '=== POC 2: PartySearchView definition ==='.
        s nextPutAll: nl].

cls isNil ifFalse: [
    s nextPutAll: '  Class: '.
    s nextPutAll: cls name asString.
    s nextPutAll: ', superclass: '.
    s nextPutAll: cls superclass name asString.
    s nextPutAll: nl.
    s nextPutAll: '  Environment: '.
    s nextPutAll: cls environment name asString.
    s nextPutAll: nl.
    s nextPutAll: '  Definition source:'.
    s nextPutAll: nl.
    s nextPutAll: '  '.
    s nextPutAll: ([cls definition] on: Core.Exception do: [:ex | 'ERR: ' , ex description]).
    s nextPutAll: nl.

    "=== POC 3: List methods (first 20 instance + counts) ==="
    s nextPutAll: '=== POC 3: First 20 instance methods (of '.
    s nextPutAll: cls selectors size printString.
    s nextPutAll: ' total) ==='.
    s nextPutAll: nl.
    ((cls selectors asSortedCollection asArray) copyFrom: 1 to: (20 min: cls selectors size))
        do: [:sel |
            s nextPutAll: '  '.
            s nextPutAll: sel asString.
            s nextPutAll: nl].
    s nextPutAll: '  ... + '.
    s nextPutAll: cls class selectors size printString.
    s nextPutAll: ' class-side methods'.
    s nextPutAll: nl.

    "=== POC 4: Class-side windowSpec fingerprint ==="
    method := cls class compiledMethodAt: #windowSpec ifAbsent: [nil].
    method isNil
        ifTrue: [
            s nextPutAll: '=== POC 4: class>>windowSpec ABSENT ==='.
            s nextPutAll: nl]
        ifFalse: [
            s nextPutAll: '=== POC 4: class>>windowSpec literal (the canonical UI def) ==='.
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
                lit := method literals at: 1.
                s nextPutAll: '  First literal (spec tree, first 2000 chars):'.
                s nextPutAll: nl.
                s nextPutAll: '  '.
                s nextPutAll: (([lit printString] on: Core.Exception do: [:ex | 'ERR'])
                    first: (2000 min: lit printString size)).
                s nextPutAll: nl]].

    "=== POC 5: Inheritance chain ==="
    s nextPutAll: '=== POC 5: Inheritance chain ==='.
    s nextPutAll: nl.
    hierarchy := cls.
    [hierarchy notNil] whileTrue: [
        s nextPutAll: '  '.
        s nextPutAll: hierarchy name asString.
        s nextPutAll: nl.
        hierarchy := hierarchy superclass]].

s contents
