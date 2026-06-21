"Probe P1 verify - confirm all 4 derived path methods return env-var-derived paths after file-in. Includes both class-side and instance-side checks."
| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
s nextPutAll: 'VWBridge vwBridgeHome = '; nextPutAll: VWBridge vwBridgeHome printString; nextPutAll: nl.
s nextPutAll: 'VWBridge tokenFilePath = '; nextPutAll: VWBridge tokenFilePath printString; nextPutAll: nl.
s nextPutAll: 'VWBridge logFilePath = '; nextPutAll: VWBridge logFilePath printString; nextPutAll: nl.
s nextPutAll: 'VWBridge screenshotHelperScriptPath = '; nextPutAll: VWBridge screenshotHelperScriptPath printString; nextPutAll: nl.
s nextPutAll: 'inst logFilePath = '; nextPutAll: VWBridge singleton logFilePath printString; nextPutAll: nl.
s nextPutAll: 'inst screenshotHelperScriptPath = '; nextPutAll: VWBridge singleton screenshotHelperScriptPath printString; nextPutAll: nl.
"Verify override seam works:"
s nextPutAll: nl; nextPutAll: '-- override seam --'; nextPutAll: nl.
[VWBridge vwBridgeHomeOverride: 'C:\fake\test\path'.
 s nextPutAll: 'with override set: vwBridgeHome = '; nextPutAll: VWBridge vwBridgeHome printString; nextPutAll: nl.
 s nextPutAll: 'with override set: tokenFilePath = '; nextPutAll: VWBridge tokenFilePath printString; nextPutAll: nl]
    ensure: [VWBridge clearVwBridgeHomeOverride].
s nextPutAll: 'after clear: vwBridgeHome = '; nextPutAll: VWBridge vwBridgeHome printString; nextPutAll: nl.
"Verify .token file is at the expected new path with the rotated token:"
[| tokenFromFile |
 tokenFromFile := VWBridge tokenFilePath asFilename readStream upToEnd.
 s nextPutAll: nl; nextPutAll: 'tokenFilePath file content matches singleton.token = '; nextPutAll: (tokenFromFile = VWBridge singleton token) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'token file read ERR: '; nextPutAll: e messageText; nextPutAll: nl].
"Verify .ps1 helper file exists at the new path:"
[s nextPutAll: 'helper script exists at new path = '; nextPutAll: VWBridge screenshotHelperScriptPath asFilename exists printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'helper exists ERR: '; nextPutAll: e messageText; nextPutAll: nl].
s contents