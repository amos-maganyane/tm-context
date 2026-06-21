"Session-15 P1-only gate via custom TestSuite (no router calls, all 5 config tests)"
| s nl suite result configSelectors |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
configSelectors := #(
    #testVwBridgeHomeOverrideTakesPriority
    #testClearVwBridgeHomeOverrideRestoresEnvLookup
    #testTokenFilePathDerivesFromVwBridgeHome
    #testLogFilePathDerivesFromVwBridgeHome
    #testScreenshotHelperScriptPathDerivesFromVwBridgeHome).
suite := TestSuite new.
configSelectors do: [:sel | suite addTest: (VWB.VWBridgeTest selector: sel)].
result := suite run.
s nextPutAll: 'P1.config.gate='; nextPutAll: result printString; nextPutAll: nl.
s nextPutAll: '  selectorsRun='; nextPutAll: configSelectors size printString; nextPutAll: nl.
s nextPutAll: '  failures.size='; nextPutAll: result failures size printString; nextPutAll: nl.
s nextPutAll: '  errors.size='; nextPutAll: result errors size printString; nextPutAll: nl.
"If any failure, list the failed selectors"
(result failures size > 0 or: [result errors size > 0]) ifTrue: [
    result failures do: [:tc | s nextPutAll: '  FAIL: '; nextPutAll: tc selector asString; nextPutAll: nl].
    result errors do: [:tc | s nextPutAll: '  ERR: '; nextPutAll: tc selector asString; nextPutAll: nl]].
s contents
