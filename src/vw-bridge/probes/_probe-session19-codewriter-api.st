"Probe session-19 step 15: locate CodeWriter + its API + cleanup leak.

Key finding step 14: writeToParcelFileNamed:... is on CodeWriter (top-level class, NOT
Kernel.Parcel or CodeComponent). The #codeComponent: in parcelOutOn:'s literals is
sent to a CodeWriter instance, not to the parcel.

Correct build flow is likely:
  writer := CodeWriter new.
  writer codeComponent: aParcel.
  writer writeToParcelFileNamed: pclPath sourceFileNamed: pstPath oldSourceIndex: nil hideSource: true republish: false backup: false.

This probe enumerates CodeWriter's API + cleans up the leaked Test-Setup-Probe parcel."
| s nl cleanup leaked codeWriterCls classSels instSels relevantSels |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Cleanup leaked parcels - try both Notification AND Error catch"
leaked := (Kernel.Parcel parcelNames asArray) 
    select: [:n | (n asString indexOfSubCollection: 'Test-' startingAt: 1) > 0].
s nextPutAll: 'leaked Test-* parcels before cleanup = '; nextPutAll: leaked asArray printString; nextPutAll: nl.
leaked do: [:n |
    cleanup := [[Kernel.Parcel removeParcelNamed: n] 
        on: Core.Notification do: [:notif | notif resume]]
        on: Core.Exception do: [:ex | 'ERR:', ex description].
    s nextPutAll: '  '; nextPutAll: n; nextPutAll: ' -> '; nextPutAll: cleanup printString; nextPutAll: nl].
s nextPutAll: 'registry size post-cleanup = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

"(2) Locate CodeWriter class - top-level?"
codeWriterCls := Smalltalk at: #CodeWriter ifAbsent: [nil].
s nextPutAll: '=== CodeWriter location ==='; nextPutAll: nl.
codeWriterCls isNil
    ifTrue: [
        s nextPutAll: '  Smalltalk top-level lookup FAILED, walking namespaces...'; nextPutAll: nl.
        Smalltalk allNameSpaces do: [:ns |
            (ns keys includes: #CodeWriter) ifTrue: [
                s nextPutAll: '  found at '; nextPutAll: ns name asString; nextPutAll: '.CodeWriter'; nextPutAll: nl.
                codeWriterCls := ns at: #CodeWriter]]]
    ifFalse: [
        s nextPutAll: '  Smalltalk.CodeWriter found, env = '; nextPutAll: codeWriterCls environment name printString; nextPutAll: nl].

codeWriterCls notNil ifTrue: [
    s nextPutAll: '  class name = '; nextPutAll: codeWriterCls name asString; nextPutAll: nl.
    s nextPutAll: '  superclass = '; nextPutAll: codeWriterCls superclass name asString; nextPutAll: nl.
    classSels := (codeWriterCls class selectors asArray) asSortedCollection asArray.
    instSels := (codeWriterCls selectors asArray) asSortedCollection asArray.
    s nextPutAll: '  class-side selector count = '; nextPutAll: classSels size printString; nextPutAll: nl.
    s nextPutAll: '  inst-side selector count = '; nextPutAll: instSels size printString; nextPutAll: nl.
    
    "Constructor candidates"
    s nextPutAll: '=== CodeWriter class-side selectors (constructors etc.) ==='; nextPutAll: nl.
    classSels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl].
    
    "Setters and writers"
    relevantSels := instSels select: [:sel | 
        (((sel asString indexOfSubCollection: 'codeComponent' startingAt: 1) > 0)
            or: [((sel asString indexOfSubCollection: 'writeTo' startingAt: 1) > 0)
                or: [((sel asString indexOfSubCollection: 'parcel' startingAt: 1) > 0)
                    or: [((sel asString indexOfSubCollection: 'source' startingAt: 1) > 0)
                        or: [(sel asString indexOfSubCollection: 'init' startingAt: 1) > 0]]]])].
    s nextPutAll: '=== CodeWriter inst-side selectors matching codeComponent|writeTo|parcel|source|init ==='; nextPutAll: nl.
    relevantSels do: [:sel | s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: nl]].

s contents
