"=== session-20 probe: file-in updated VWBridge.st + verify v0.10.0 + /version accessors ==="
"Files in the updated VWBridge.st with Phase P P8 additions (class-side version,
buildCommitSha, buildTimestamp, parcelMode + /version handler + auth-exempt
extension). Returns the new accessor values so we can verify file-in landed
cleanly. /health and /version are then testable via curl without auth.
fileIn raises EndOfStreamNotification at EOF (carry-forward #24) - wrapped
with on: Core.Notification do: [:n | n resume] so the file-in completes all
chunks even when running under /eval (which doesn't have the top-level
auto-resume that load.st relies on)."
| home |
home := OS.CEnvironment userEnvironment at: 'VW_BRIDGE_HOME' ifAbsent: [nil].
home isNil ifTrue: [^'ERR: VW_BRIDGE_HOME not set'].
[(home , '\VWBridge.st') asFilename fileIn]
    on: Core.Notification do: [:n | n resume].
^'fileIn-OK version=' , VWB.VWBridge version
  , ' buildCommitSha=' , VWB.VWBridge buildCommitSha
  , ' buildTimestamp=' , VWB.VWBridge buildTimestamp
  , ' parcelMode=' , VWB.VWBridge parcelMode
