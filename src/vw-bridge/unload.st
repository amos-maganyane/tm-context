"=== VWBridge unload script (Phase P P2 Stage 3, v0.9.2) ==="
"Defensive idempotent cleanup. Inverse of load.st - removes ALL VWBridge
 footprint from the image. After successful unload, the image is byte-
 equivalent to its pre-load state in class presence (Kernel.Parcel
 introspection shows zero residual VWBridge classes; Smalltalk at: #VWB
 returns nil; SimpleDialog override removed).

 USE CASES:
   - Clean dev workflow: unload before re-running load.st for a fresh state
   - QA: verify load+unload+load idempotency (P2 quality gate)
   - Future P6 parcel: parallel to Parcel postUnloadBlock semantics

 BEHAVIOR (all steps defensive, every step is idempotent):
   1. Capture tokenPath BEFORE VWBridge class is gone
   2. Stop bridge listener (terminates listener process, closes socket)
   3. Delete .token file
   4. Remove SimpleDialog>>choose:labels:values:default:for: override
   5. Remove 4 VWB classes in reverse-dependency order:
      - VWBridgeScreenshotTest (depends on nothing local)
      - VWBridgeWaitTest (depends on nothing local)
      - VWBridgeTest (depends on nothing local)
      - VWBridge (the production class)
   6. Remove empty VWB namespace

 IMPORTANT:
   - Step 2 KILLS the listener. Any /eval call that runs this script is the
     LAST /eval call until load.st brings the bridge back.
   - removeSelector: on absent selector is naturally defensive in this image
     (probed session-17) - returns without raising.
   - removeFromSystem on absent class is wrapped here for belt-and-suspenders
     (constraint #12 + #13 verified session-14).

 NOT chunk-formatted. Do-it expression block for /eval POST or Workspace Do It."

| tokenPath classNamesInRemoveOrder |

"(1) Capture tokenPath BEFORE VWB.VWBridge is removed. Defensive against
 missing class (e.g. unload run twice). Treats any error as 'no path available'."
tokenPath := [VWB.VWBridge tokenFilePath]
    on: Core.Error do: [:ex | nil].
Transcript cr; show: '[unload.st] tokenPath captured = ', tokenPath printString; cr.

"(2) Stop bridge listener. Defensive - no-op if class is gone or singleton is nil."
[(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
    (ns at: #VWBridge ifAbsent: [nil]) ifNotNil: [:cls |
        Transcript show: '[unload.st] stopping VWB.VWBridge listener'; cr.
        cls stop]]]
    on: Core.Error do: [:ex |
        Transcript show: 'WARN: VWB.VWBridge stop failed: ', ex description; cr].

"(3) Delete .token file. Defensive against missing path and missing file."
tokenPath ifNotNil: [
    | tokenFile |
    tokenFile := tokenPath asFilename.
    [tokenFile exists ifTrue: [
        tokenFile delete.
        Transcript show: '[unload.st] .token deleted: ', tokenPath; cr]]
        on: Core.Error do: [:ex |
            Transcript show: 'WARN: .token delete failed: ', ex description; cr]].

"(4) Remove SimpleDialog override (Bug #2 patch). removeSelector: is naturally
 defensive on absent selectors but we wrap for belt-and-suspenders."
[(SimpleDialog includesSelector: #choose:labels:values:default:for:) ifTrue: [
    SimpleDialog removeSelector: #choose:labels:values:default:for:.
    Transcript show: '[unload.st] SimpleDialog>>choose:labels:values:default:for: removed'; cr]]
    on: Core.Error do: [:ex |
        Transcript show: 'WARN: SimpleDialog removeSelector failed: ', ex description; cr].

"(5) Remove 4 VWB classes in reverse-dep order. All test classes first
 (no in-namespace dependencies between them), then VWBridge itself.
 Defensive against already-removed classes."
classNamesInRemoveOrder := #(#VWBridgeScreenshotTest #VWBridgeWaitTest #VWBridgeTest #VWBridge).
classNamesInRemoveOrder do: [:nm |
    [(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
        (ns at: nm ifAbsent: [nil]) ifNotNil: [:cls |
            Transcript show: '[unload.st] removing class VWB.', nm; cr.
            cls removeFromSystem]]]
        on: Core.Error do: [:ex |
            Transcript show: 'WARN: VWB.', nm, ' removeFromSystem failed: ', ex description; cr]].

"(6) Remove empty VWB namespace. Defensive: only remove if empty (no other
 classes leaked in) and not already-removed."
[(Smalltalk at: #VWB ifAbsent: [nil]) ifNotNil: [:ns |
    ns keys isEmpty
        ifTrue: [
            ns removeFromSystem.
            Transcript show: '[unload.st] VWB namespace removed'; cr]
        ifFalse: [
            Transcript show: 'WARN: VWB namespace has ', ns keys size printString,
                ' residual keys, NOT removing: ', ns keys asSortedCollection printString; cr]]]
    on: Core.Error do: [:ex |
        Transcript show: 'WARN: VWB removeFromSystem failed: ', ex description; cr].

Transcript show: '[unload.st] DONE. Image should be byte-equivalent to pre-load.'; cr.

"Result for /eval caller (if this is the last call before bridge dies)"
^'[unload.st] OK - bridge stopped, VWB removed'
