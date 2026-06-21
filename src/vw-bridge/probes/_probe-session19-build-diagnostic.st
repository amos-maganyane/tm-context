"Probe session-19 step 9: diagnose parcelOutOn: failure + verify cleanup ran + find correct write API.

Hypothesis: parcelOutOn: wants a LogicalFileSpecification (or Filename), not a writeStream.
Per probe 6 fingerprint it delegates to writeToParcelFileNamed:sourceFileNamed:oldSourceIndex:hideSource:republish:backup:
which is filename-shaped, not stream-shaped."
| s nl m current cleanedUp home tp ws lfs |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"(1) Check for leaked VWBridge parcels"
s nextPutAll: 'current registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.
current := (Kernel.Parcel parcelNames asArray) select: [:n | (n asString indexOfSubCollection: 'VWBridge' startingAt: 1) > 0].
s nextPutAll: 'VWBridge-* parcels currently registered = '; nextPutAll: current printString; nextPutAll: nl.

"(2) Clean up any leaked parcels (defensive: in case ensure: didn't run)"
cleanedUp := OrderedCollection new.
current do: [:n |
    [Kernel.Parcel removeParcelNamed: n] on: Core.Notification do: [:notif | notif resume].
    cleanedUp add: n].
s nextPutAll: 'cleaned up = '; nextPutAll: cleanedUp asArray printString; nextPutAll: nl.
s nextPutAll: 'post-cleanup registry size = '; nextPutAll: Kernel.Parcel parcels size printString; nextPutAll: nl.

"(3) Probe parcelOutOn:withSource:hideOnLoad:republish:backup: source-level - look for actual call shape"
m := Kernel.Parcel class compiledMethodAt: #savedParcel:to: ifAbsent: [nil].
m isNil 
    ifTrue: [s nextPutAll: 'savedParcel:to: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== Kernel.Parcel class>>savedParcel:to: ==='; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
        s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl].

m := Kernel.Parcel compiledMethodAt: #fileOutOn: ifAbsent: [nil].
m isNil 
    ifTrue: [s nextPutAll: 'fileOutOn: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== Kernel.Parcel>>fileOutOn: ==='; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl].

m := Kernel.Parcel compiledMethodAt: #fileOutAsFor: ifAbsent: [nil].
m isNil
    ifTrue: [s nextPutAll: 'fileOutAsFor: ABSENT'; nextPutAll: nl]
    ifFalse: [
        s nextPutAll: '=== Kernel.Parcel>>fileOutAsFor: ==='; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl].

"(4) Verify writeStream type + asLogicalFileSpecification capability"
home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME'.
tp := home , '\.generated\parcels\_probe.tmp'.
ws := tp asFilename writeStream binary.
s nextPutAll: '=== writeStream binary inspection ==='; nextPutAll: nl.
s nextPutAll: '  class='; nextPutAll: ws class name; nextPutAll: nl.
s nextPutAll: '  superclass='; nextPutAll: ws class superclass name; nextPutAll: nl.
s nextPutAll: '  ws responds asLogicalFileSpecification = '; nextPutAll: (ws respondsTo: #asLogicalFileSpecification) printString; nextPutAll: nl.
ws close.

"(5) Check Filename's response to asLogicalFileSpecification"
s nextPutAll: '=== Filename inspection ==='; nextPutAll: nl.
s nextPutAll: '  tp asFilename class = '; nextPutAll: tp asFilename class name; nextPutAll: nl.
s nextPutAll: '  responds asLogicalFileSpecification = '; nextPutAll: (tp asFilename respondsTo: #asLogicalFileSpecification) printString; nextPutAll: nl.
lfs := [tp asFilename asLogicalFileSpecification] on: Core.Exception do: [:ex | 'ERR:', ex description].
s nextPutAll: '  asLogicalFileSpecification = '; nextPutAll: lfs printString; nextPutAll: nl.

"(6) Delete the temp file"
[tp asFilename delete] on: Core.Exception do: [:ex | nil].

s contents
