"Session-15: find correct TestFailure signal pattern then verify on:Core.Exception do: catches it"
| outcomes |
outcomes := Core.OrderedCollection new.

"Pattern A: TestFailure signal: 'msg' (class-side keyword)"
[TestFailure signal: 'A: class-side signal:']
    on: Core.Exception
    do: [:ex | outcomes add: 'A=CAUGHT: ', ex class name asString, '|msg=', (ex messageText ifNil: ['(nil)'])].

"Pattern B: TestFailure signal (class-side unary)"
[TestFailure signal]
    on: Core.Exception
    do: [:ex | outcomes add: 'B=CAUGHT: ', ex class name asString, '|msg=', (ex messageText ifNil: ['(nil)'])].

"Pattern C: TestFailure new (just instance creation - might MNU if no new)"
[| inst | inst := TestFailure new. outcomes add: 'C=INSTANCE_OK: ', inst printString]
    on: Core.Exception
    do: [:ex | outcomes add: 'C=CAUGHT: ', ex class name asString, '|msg=', (ex messageText ifNil: ['(nil)'])].

"Examine TestFailure's class-side API"
outcomes add: 'TestFailure-class-selectors=', (TestFailure class selectors asSortedCollection asArray first: 20) printString.
outcomes add: 'TestFailure-instance-selectors-first20=', (TestFailure selectors asSortedCollection asArray first: 20) printString.

outcomes asArray printString
