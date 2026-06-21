| tc result info |
tc := VWB.VWBridgeTest selector: #testVwBridgeHomeOverrideTakesPriority.
result := tc run.
info := Core.WriteStream on: Core.String new.
info nextPutAll: 'runCount='; nextPutAll: result runCount printString; nextPutAll: ' | '.
info nextPutAll: 'passedCount='; nextPutAll: result passedCount printString; nextPutAll: ' | '.
info nextPutAll: 'failureCount='; nextPutAll: result failureCount printString; nextPutAll: ' | '.
info nextPutAll: 'errorCount='; nextPutAll: result errorCount printString; nextPutAll: ' | '.
result errorCount > 0 ifTrue: [
    | errs |
    errs := result errors asArray.
    info nextPutAll: 'firstErrCls=', errs first class name; nextPutAll: ' | '.
    info nextPutAll: 'firstErrSelectors=', (errs first class selectors asSortedCollection asArray first: 10) printString].
info contents
