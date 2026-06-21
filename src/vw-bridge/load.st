"=== VWBridge load script (Phase P P2 Stage 3, v0.9.2) ==="
"External load orchestrator. Replaces the auto-start chunk previously at the
 end of VWBridge.st so VWBridge.st becomes parcel-ready (file-in without
 side-effects) for P6.

 USE CASES:
   - Cold-start (bridge is dead): paste this whole block into VW Workspace
     and Do It. This is the AGENTS.md cold-start exception until Phase P P5
     ships an external auto-start trigger.
   - Reload (bridge is up): POST as /eval body via curl.exe.
   - Future P5: external trigger (Topaz stdin, CLI arg, file watcher) feeds
     this expression into the image.

 BEHAVIOR:
   1. Resolve VW_BRIDGE_HOME from OS env var (fails loud per constraint #8)
   2. Defensively stop+remove any leaked top-level Root.Smalltalk.VWBridge
   3. File-in 5 source files in dependency order
   4. Start the bridge (rotates token)
   5. Write .token to tokenFilePath for agent pickup

 file-in raises EndOfStreamNotification at EOF (constraint #24) - this script
 leaves the fileIn unwrapped so the notification auto-resumes cleanly at the
 top-level handler. Wrapping with on: Core.Exception do: catches the benign
 notification and aborts file-in mid-stream (silent recompile failure).

 NOT chunk-formatted. This is a do-it expression block intended for /eval
 POST or Workspace Do It, NOT for File In."

| home homeFilename tokenPath tokenStream srcFile oldVwBridge |

"(1) Resolve install root - fails loud per constraint #8"
home := OS.CEnvironment userEnvironment
    at: 'VW_BRIDGE_HOME'
    ifAbsent: [self error: 'VW_BRIDGE_HOME env var is not set. Set it to the bridge install directory (the folder containing VWBridge.st), e.g. C:\path\to\src\vw-bridge. See INSTALL.md (Phase P P7).'].
homeFilename := home asFilename.

Transcript cr; show: '[load.st] VW_BRIDGE_HOME=', home; cr.

"(2) Defensive Stage 2 migration cleanup - removes top-level Root.Smalltalk.VWBridge
 if it leaked back (idempotent; no-op if absent or already migrated)"
oldVwBridge := Smalltalk at: #VWBridge ifAbsent: [nil].
(oldVwBridge notNil and: [oldVwBridge environment == Root.Smalltalk]) ifTrue: [
    Transcript show: '[load.st] cleanup: stopping + removing old Root.Smalltalk.VWBridge'; cr.
    [oldVwBridge stop] on: Core.Error do: [:ex | nil].
    [oldVwBridge removeFromSystem] on: Core.Error do: [:ex |
        Transcript show: 'WARN: could not remove old Root.Smalltalk.VWBridge: ', ex description; cr]].

"(3) File-in 5 source files in dependency order. Each is a chunk file and
 raises EndOfStreamNotification at EOF - unwrapped so notification auto-resumes
 at the top-level handler."
#('VWBridge.st' 'VWBridge-Patches.st' 'VWBridge-Test.st' 'VWBridge-WaitTest.st' 'VWBridge-ScreenshotTest.st') do: [:fname |
    srcFile := (home , '\' , fname) asFilename.
    srcFile exists
        ifTrue: [
            Transcript show: '[load.st] fileIn: ', fname; cr.
            srcFile fileIn]
        ifFalse: [self error: '[load.st] missing source file: ', srcFile asString]].

"(4) Start the bridge listener. start internally calls stop first, so an
 already-running bridge gets cleanly restarted with a fresh token."
VWB.VWBridge start.

"(5) Write .token file for agent pickup. Defensive against write-stream failure."
tokenPath := VWB.VWBridge tokenFilePath.
tokenStream := [tokenPath asFilename writeStream] on: Core.Error do: [:ex | nil].
tokenStream == nil
    ifTrue: [Transcript show: 'WARN: could not write .token file (', tokenPath, ') - copy token manually from Transcript'; cr]
    ifFalse: [
        [tokenStream lineEndTransparent] on: Core.Error do: [:ex | nil].
        tokenStream nextPutAll: VWB.VWBridge singleton token.
        tokenStream close.
        Transcript show: '[load.st] .token written to ', tokenPath; cr;
            show: '[load.st] token=', VWB.VWBridge singleton token; cr].

Transcript show: '[load.st] DONE. Bridge UP at 127.0.0.1:', VWB.VWBridge singleton port printString; cr.

"Result for /eval caller - returns the new token so callers can rotate immediately"
^'[load.st] OK token=' , VWB.VWBridge singleton token , ' port=' , VWB.VWBridge singleton port printString
