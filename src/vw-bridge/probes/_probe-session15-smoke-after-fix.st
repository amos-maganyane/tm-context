| s nl setUpMethod result |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"1. Verify setUp literals are now hard-bound (not deferred)"
setUpMethod := VWB.VWBridgeTest compiledMethodAt: #setUp ifAbsent: [nil].
s nextPutAll: 'setUp.literals='; nextPutAll: setUpMethod literals printString; nextPutAll: nl.
s nextPutAll: 'setUp.firstLit.value='; nextPutAll: setUpMethod literals first value printString; nextPutAll: nl.

"2. Re-run the smoke test - expect PASS now"
result := (VWB.VWBridgeTest selector: #testVwBridgeHomeOverrideTakesPriority) run.
s nextPutAll: 'smoke.result='; nextPutAll: result printString; nextPutAll: nl.

s contents
