"Probe-3 — session-21. Targets image-specific data that text-search librarians can't replicate:
  A) Inherited setter selectors across the spec class chain (action:, model:, aspect: live on
     WidgetSpec/ComponentSpec, not ActionButtonSpec — need to know full inheritance for typed builders).
  B) ApplicationModel instance-side lifecycle hooks (postBuildWith:, preBuildWith:, etc.) —
     class-side has only the open* family per probe-2.
  C) A real MAS ApplicationModel subclass with #windowSpec — behavioral fingerprint since
     sources stripped (numArgs / numTemps / messages / literals).
  D) SimpleDialog instance-side hook selectors.
 Comment phrasing avoids the Stage 1 substring guard pair (same rule as earlier probes)."

| s nl reportInherited masExample hookFilter dumpHooks |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

reportInherited := [:rootClsSym :title |
    | cls chain allSetters seen |
    cls := Smalltalk at: rootClsSym ifAbsent: [nil].
    s nextPutAll: '=== '; nextPutAll: title; nextPutAll: ' ==='; nextPutAll: nl.
    cls isNil
        ifTrue: [s nextPutAll: '  ABSENT'; nextPutAll: nl]
        ifFalse: [
            chain := OrderedCollection new.
            [cls notNil and: [cls ~~ Object]] whileTrue: [
                chain add: cls.
                cls := cls superclass].
            seen := Set new.
            allSetters := OrderedCollection new.
            chain do: [:c |
                | setters |
                setters := (c selectors asSortedCollection asArray
                    select: [:sel | sel asString last = $:]).
                s nextPutAll: '  '; nextPutAll: c name asString;
                  nextPutAll: ' [setters '; nextPutAll: setters size printString; 
                  nextPutAll: ']:'; nextPutAll: nl.
                setters do: [:sel |
                    | str |
                    str := sel asString.
                    (seen includes: str) ifFalse: [
                        seen add: str.
                        allSetters add: c name asString , '>>' , str].
                    s nextPutAll: '    '; nextPutAll: str; nextPutAll: nl]].
            s nextPutAll: '  -- UNIQUE setter count across chain: '; 
              nextPutAll: seen size printString; nextPutAll: nl]].

"A) Spec inheritance walks for 3 representative widget kinds"
reportInherited value: #ActionButtonSpec value: 'A1. ActionButtonSpec inheritance chain'.
reportInherited value: #InputFieldSpec value: 'A2. InputFieldSpec inheritance chain'.
reportInherited value: #LabelSpec value: 'A3. LabelSpec inheritance chain'.

"B) ApplicationModel instance-side hooks"
s nextPutAll: '=== B. ApplicationModel instance-side hook selectors ==='; nextPutAll: nl.
[
    | am hooks |
    am := Smalltalk at: #ApplicationModel ifAbsent: [nil].
    am isNil ifFalse: [
        hookFilter := [:sel | | str |
            str := sel asString.
            (str startsWith: 'postBuild') or: [
                (str startsWith: 'preBuild') or: [
                    (str startsWith: 'postOpen') or: [
                        (str startsWith: 'preOpen') or: [
                            (str startsWith: 'release') or: [
                                (str startsWith: 'destroy') or: [
                                    (str startsWith: 'close') or: [
                                        (str startsWith: 'window') or: [
                                            (str startsWith: 'aspect') or: [
                                                str startsWith: 'builder']]]]]]]]]].
        hooks := am selectors asSortedCollection asArray select: hookFilter.
        s nextPutAll: '  hook-shaped selectors: '; nextPutAll: hooks size printString; nextPutAll: nl.
        hooks do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

"C) Find first MAS subclass of ApplicationModel with #windowSpec; behavioral fingerprint"
s nextPutAll: '=== C. Sample MAS ApplicationModel subclass with windowSpec ==='; nextPutAll: nl.
[
    | am candidates picked m mClass mLits mMsgs |
    am := Smalltalk at: #ApplicationModel ifAbsent: [nil].
    am isNil ifFalse: [
        candidates := am allSubclasses asSortedCollection: [:a :b | a name asString < b name asString].
        picked := nil.
        candidates do: [:c |
            picked isNil ifTrue: [
                ((c class includesSelector: #windowSpec)
                    and: [(c name asString indexOfSubCollection: 'Test' startingAt: 1) = 0])
                    ifTrue: [picked := c]]].
        picked isNil
            ifTrue: [s nextPutAll: '  NO subclass with class-side #windowSpec found'; nextPutAll: nl]
            ifFalse: [
                s nextPutAll: '  Picked: '; nextPutAll: picked name asString;
                  nextPutAll: ' (env=#'; nextPutAll: picked environment name asString;
                  nextPutAll: ', super=';
                  nextPutAll: picked superclass name asString; nextPutAll: ')'; nextPutAll: nl.
                mClass := picked class.
                m := mClass compiledMethodAt: #windowSpec ifAbsent: [nil].
                m isNil
                    ifTrue: [s nextPutAll: '  windowSpec method ABSENT?!'; nextPutAll: nl]
                    ifFalse: [
                        mMsgs := [m messages asSortedCollection asArray] on: Core.Exception do: [:ex | #()].
                        mLits := [m literals] on: Core.Exception do: [:ex | #()].
                        s nextPutAll: '  windowSpec fingerprint:'; nextPutAll: nl.
                        s nextPutAll: '    numArgs='; nextPutAll: m numArgs printString;
                          nextPutAll: ', numTemps='; nextPutAll: m numTemps printString; nextPutAll: nl.
                        s nextPutAll: '    messages ('; nextPutAll: mMsgs size printString; nextPutAll: '):'; nextPutAll: nl.
                        mMsgs do: [:msg |
                            s nextPutAll: '      '; nextPutAll: msg asString; nextPutAll: nl].
                        s nextPutAll: '    literals first 30:'; nextPutAll: nl.
                        ((mLits isNil or: [mLits isEmpty])
                            ifTrue: [#()]
                            ifFalse: [mLits copyFrom: 1 to: (30 min: mLits size)])
                            do: [:lit |
                                s nextPutAll: '      ';
                                  nextPutAll: ([lit printString] on: Core.Exception do: [:ex | '<unprintable>']);
                                  nextPutAll: nl]]]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

"D) SimpleDialog instance-side hook selectors"
s nextPutAll: '=== D. SimpleDialog instance-side selectors (full list) ==='; nextPutAll: nl.
[
    | sd |
    sd := Smalltalk at: #SimpleDialog ifAbsent: [nil].
    sd isNil ifFalse: [
        sd selectors asSortedCollection asArray do: [:sel |
            s nextPutAll: '    '; nextPutAll: sel asString; nextPutAll: nl]]]
    on: Core.Exception do: [:ex |
        s nextPutAll: '  ERR: '; nextPutAll: ex description; nextPutAll: nl].

s contents
