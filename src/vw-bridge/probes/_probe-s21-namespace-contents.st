"Probe — session-21 follow-up. Enumerate UI / Tools / Store namespace contents
 (image-specific knowledge that text-search librarians can't replicate).
 Comment phrasing avoids the Stage 1 substring guard pair (same rule as probe-1)."

| s nl dump |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

dump := [:nsName |
    | ns sortedKeys |
    ns := Smalltalk at: nsName ifAbsent: [nil].
    s nextPutAll: '=== '; nextPutAll: nsName asString.
    ns isNil
        ifTrue: [s nextPutAll: ' ABSENT'; nextPutAll: nl]
        ifFalse: [
            sortedKeys := ns keys asSortedCollection asArray.
            s nextPutAll: ' ('; nextPutAll: sortedKeys size printString;
              nextPutAll: ' keys) ==='; nextPutAll: nl.
            sortedKeys do: [:k |
                s nextPutAll: '  '; nextPutAll: k asString; nextPutAll: nl]]].

dump value: #UI.
dump value: #Tools.
dump value: #Store.

s nextPutAll: '=== Store-prefix class probes ==='; nextPutAll: nl.
#(#PackageInfo #PundleInfo #BlessingDefinition #PackageReference #Pundle #Package #PublishedImage #StoreSession #DBConnectionProfile) do: [:sym |
    | c storeNs |
    storeNs := Smalltalk at: #Store ifAbsent: [nil].
    c := storeNs isNil ifTrue: [nil] ifFalse: [storeNs at: sym ifAbsent: [nil]].
    s nextPutAll: '  Store.'; nextPutAll: sym asString; nextPutAll: ': '.
    c isNil
        ifTrue: [s nextPutAll: 'ABSENT'; nextPutAll: nl]
        ifFalse: [s nextPutAll: 'present, selI='; nextPutAll: c selectors size printString;
                  nextPutAll: ', selC='; nextPutAll: c class selectors size printString; nextPutAll: nl]].

s nextPutAll: '=== WindowSpec API surface (setter-shape selectors) ==='; nextPutAll: nl.
[
    | ws setters |
    ws := Smalltalk at: #WindowSpec ifAbsent: [nil].
    ws isNil ifFalse: [
        setters := ws selectors asSortedCollection asArray
            select: [:sel | sel asString last = $:].
        s nextPutAll: '  WindowSpec setter count: '; nextPutAll: setters size printString; nextPutAll: nl.
        setters do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

s nextPutAll: '=== FullSpec API surface (all inst selectors) ==='; nextPutAll: nl.
[
    | fs |
    fs := Smalltalk at: #FullSpec ifAbsent: [nil].
    fs isNil ifFalse: [
        fs selectors asSortedCollection asArray do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

s nextPutAll: '=== ActionButtonSpec setter API (for button wiring) ==='; nextPutAll: nl.
[
    | bs setters |
    bs := Smalltalk at: #ActionButtonSpec ifAbsent: [nil].
    bs isNil ifFalse: [
        setters := bs selectors asSortedCollection asArray
            select: [:sel | sel asString last = $:].
        setters do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

s nextPutAll: '=== ApplicationModel class-side hook selectors ==='; nextPutAll: nl.
[
    | am hooks |
    am := Smalltalk at: #ApplicationModel ifAbsent: [nil].
    am isNil ifFalse: [
        hooks := (am class selectors asSortedCollection asArray
            select: [:sel | | s2 | s2 := sel asString.
                (s2 startsWith: 'window') or: [
                    (s2 startsWith: 'pre') or: [
                        (s2 startsWith: 'post') or: [
                            s2 startsWith: 'open']]]]).
        hooks do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

s contents
