"Phase 0 step 5 (session-16 start) - bridge class identity verification.
Expect: env name '#VWB', Smalltalk slot nil (post-Stage 2 migration)."
| envName smalltalkSlot vwNs |
envName := VWB.VWBridge environment name.
smalltalkSlot := Smalltalk at: #VWBridge ifAbsent: [nil].
vwNs := Smalltalk at: #VWB ifAbsent: [nil].
'env=' , envName printString
    , ' smalltalkSlot=' , smalltalkSlot printString
    , ' vwNs=' , vwNs printString
    , ' classKeys=' , (vwNs isNil ifTrue: ['nil'] ifFalse: [vwNs keys asSortedCollection asArray printString])
