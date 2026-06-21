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

ENVIRONMENT: VW_BRIDGE_HOME must be set (constraint #8).
NOT chunk-formatted - do-it expression block intended for /eval POST or
wrapper-generated chunk file-in.

PARALLEL: load.st (FileIn mode) does file-in + start + token-write together;
parcel-start.st (Parcel mode) skips file-in (parcel already loaded) and only
does start + token-write."

| home tokenPath tokenStream |

home := OS.CEnvironment userEnvironment
    at: 'VW_BRIDGE_HOME'
    ifAbsent: [self error: 'VW_BRIDGE_HOME env var is not set. Set it to the bridge install dir (folder containing parcels/VWBridge.pcl).'].

Transcript cr; show: '[parcel-start.st] VW_BRIDGE_HOME=' , home; cr.

"Start bridge listener - internally calls stop first if already running."
VWB.VWBridge start.

"Write .token file for agent pickup. Defensive against write-stream failure."
tokenPath := VWB.VWBridge tokenFilePath.
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
