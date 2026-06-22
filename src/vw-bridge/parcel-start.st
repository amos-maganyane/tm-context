"=== VWBridge parcel-start script (Phase P P6, session-19) ==="
"Post-parcel-load action invoked by Start-VWBridge.ps1 -Mode Parcel.

Called via vwnt.exe -pcl <VWBridge.pcl> -filein <chunk-wrapped parcel-start.st>:
the -pcl switch loads the parcel FIRST (defines VWB namespace + class + SimpleDialog
override); then -filein executes this script which starts the bridge listener and
writes .token for /eval auth.

USE CASES:
  - Wrapper-driven cold-start (canonical): Start-VWBridge.ps1 -Mode Parcel
  - Hand-driven via /eval after manual loadParcelFrom: in a development image
  - Emergency Workspace paste post-loadParcelFrom: (cold-start exception fallback)

ENVIRONMENT: VW_RUNTIME_API_HOME must be set (constraint #8).
v1.0.0: env var renamed from VW_BRIDGE_HOME to VW_RUNTIME_API_HOME.
NOT chunk-formatted - do-it expression block intended for /eval POST or
wrapper-generated chunk file-in.

PARALLEL: load.st (FileIn mode) does file-in + start + token-write together;
parcel-start.st (Parcel mode) skips file-in (parcel already loaded) and only
does start + token-write."

| home tokenPath tokenStream |

home := OS.CEnvironment userEnvironment
    at: 'VW_RUNTIME_API_HOME'
    ifAbsent: [self error: 'VW_RUNTIME_API_HOME env var is not set. Set it to the runtime install dir (folder containing parcels/VWBridge.pcl).'].

Transcript cr; show: '[parcel-start.st] VW_RUNTIME_API_HOME=' , home; cr.

"Start bridge listener - internally calls stop first if already running."
VWB.VWBridge start.

"Write token file for agent pickup. v1.0.0: token lives at
 %LOCALAPPDATA%\Enviro365\vw-runtime-api\token. Ensure directory chain
 exists before writing. Defensive against write-stream failure."
tokenPath := VWB.VWBridge tokenFilePath.
[tokenPath asFilename directory ensureDirectory]
    on: Core.Error do: [:ex |
        Transcript show: 'WARN: could not ensure token state directory: ' , ex description; cr].
tokenStream := [tokenPath asFilename writeStream] on: Core.Error do: [:ex | nil].
tokenStream == nil
    ifTrue: [Transcript show: 'WARN: could not write .token file (' , tokenPath , ')'; cr]
    ifFalse: [
        [tokenStream lineEndTransparent] on: Core.Error do: [:ex | nil].
        tokenStream nextPutAll: VWB.VWBridge singleton token.
        tokenStream close.
        Transcript show: '[parcel-start.st] .token written to ' , tokenPath; cr;
            show: '[parcel-start.st] token=' , VWB.VWBridge singleton token; cr].

Transcript show: '[parcel-start.st] DONE. Bridge UP at 127.0.0.1:' , VWB.VWBridge singleton port printString; cr.

^'[parcel-start.st] OK token=' , VWB.VWBridge singleton token , ' port=' , VWB.VWBridge singleton port printString
