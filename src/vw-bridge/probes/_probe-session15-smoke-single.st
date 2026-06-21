| tc result caught |
tc := VWB.VWBridgeTest selector: #testVwBridgeHomeOverrideTakesPriority.
result := nil.
caught := nil.
[result := tc run]
    on: Core.Exception
    do: [:ex | caught := ex].
caught isNil
    ifTrue: ['PASS-OR-RESULT: ', result printString, ' | resultClass=', result class name]
    ifFalse: ['CAUGHT: ', caught class name asString, ' | msg=', (caught messageText ifNil: ['(nil)'])]
