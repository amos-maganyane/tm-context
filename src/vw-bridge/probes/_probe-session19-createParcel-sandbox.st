"Probe session-19 step 5: SANDBOXED createParcelNamed: to discover content-population behavior.
Creates a 'VWBridge-Core' parcel via the class-side API, inspects what it contains,
then removes it via removeParcelNamed: (probe 4 confirmed selector exists).

DESTRUCTIVE: adds 1 entry to Kernel.Parcel parcels registry, then cleans up.
Idempotent: pre-count and post-cleanup-count must match."
| s nl preCount parcel postCreateCount postCleanupCount classesAccessor extAccessor introspectSels |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

preCount := Kernel.Parcel parcels size.
s nextPutAll: 'pre-count='; nextPutAll: preCount printString; nextPutAll: nl.

parcel := [Kernel.Parcel createParcelNamed: 'VWBridge-Core']
    on: Core.Exception
    do: [:ex | 
        s nextPutAll: 'createParcelNamed ERR: '; nextPutAll: ex description; nextPutAll: nl. 
        nil].

s nextPutAll: 'parcel-handle='; nextPutAll: parcel printString; nextPutAll: nl.

parcel notNil ifTrue: [
    s nextPutAll: 'parcel-class='; nextPutAll: parcel class name; nextPutAll: nl.
    postCreateCount := Kernel.Parcel parcels size.
    s nextPutAll: 'post-create-count='; nextPutAll: postCreateCount printString; nextPutAll: nl.
    s nextPutAll: 'parcel-name='; nextPutAll: parcel name printString; nextPutAll: nl.

    "Classes accessor"
    s nextPutAll: 'parcel-respondsTo-classes='; nextPutAll: (parcel respondsTo: #classes) printString; nextPutAll: nl.
    classesAccessor := (parcel respondsTo: #classes) 
        ifTrue: [[parcel classes] on: Core.Exception do: [:ex | 'ERR:', ex description]]
        ifFalse: ['(absent)'].
    s nextPutAll: 'parcel-classes='; nextPutAll: classesAccessor printString; nextPutAll: nl.

    "Extensions accessor"
    s nextPutAll: 'parcel-respondsTo-extensions='; nextPutAll: (parcel respondsTo: #extensions) printString; nextPutAll: nl.
    extAccessor := (parcel respondsTo: #extensions) 
        ifTrue: [[parcel extensions] on: Core.Exception do: [:ex | 'ERR:', ex description]]
        ifFalse: ['(absent)'].
    s nextPutAll: 'parcel-extensions='; nextPutAll: extAccessor printString; nextPutAll: nl.

    "Other introspection selectors"
    introspectSels := #(#bundleName #version #versionString #isDirty #summary #isDeployed #isLoaded #isAttached #postLoad #postUnloadBlock).
    introspectSels do: [:sel |
        | result |
        result := (parcel respondsTo: sel) 
            ifTrue: [[parcel perform: sel] on: Core.Exception do: [:ex | 'ERR:', ex description]]
            ifFalse: ['(absent)'].
        s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='; nextPutAll: result printString; nextPutAll: nl].

    "CLEANUP - remove from registry"
    [Kernel.Parcel removeParcelNamed: 'VWBridge-Core'] 
        on: Core.Exception 
        do: [:ex | s nextPutAll: 'removeParcelNamed ERR: '; nextPutAll: ex description; nextPutAll: nl].
    postCleanupCount := Kernel.Parcel parcels size.
    s nextPutAll: 'post-cleanup-count='; nextPutAll: postCleanupCount printString; nextPutAll: nl.
    s nextPutAll: 'cleanup-restored-state='; nextPutAll: (postCleanupCount = preCount) printString; nextPutAll: nl].

s contents
