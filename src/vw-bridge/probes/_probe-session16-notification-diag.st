"Session-16 - diagnose Notification empty-msg in testBug2DialogConfirmYesReturnsTrue.
Catches everything (Notification, Error, etc) and reports rich info: class name,
superclass chain, messageText, description, printString. Helps identify what's
raising the Notification and from where."
| s nl tc caught |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Run setUp + the test, catch any Exception, report rich info"
tc := VWB.VWBridgeTest new.
caught := nil.
[[tc setUp.
  tc perform: #testBug2DialogConfirmYesReturnsTrue.
  s nextPutAll: 'PASSED'; nextPutAll: nl]
    on: Core.Exception
    do: [:e |
        caught := e.
        s nextPutAll: 'CAUGHT class= '; nextPutAll: e class name asString; nextPutAll: nl.
        s nextPutAll: '  messageText= '; nextPutAll: (e messageText ifNil: ['(nil)']) printString; nextPutAll: nl.
        s nextPutAll: '  description= '.
        [s nextPutAll: e description printString] on: Core.Exception do: [:ex2 | s nextPutAll: '(error getting description: ', ex2 class name asString, ')'].
        s nextPutAll: nl.
        s nextPutAll: '  printString= '.
        [s nextPutAll: e printString] on: Core.Exception do: [:ex2 | s nextPutAll: '(error printing: ', ex2 class name asString, ')'].
        s nextPutAll: nl.
        "Superclass chain"
        s nextPutAll: '  superclass chain: '.
        e class allSuperclasses do: [:c | s nextPutAll: c name asString; nextPutAll: ' -> '].
        s nextPutAll: nl.
        "Is it a Core.Notification?"
        s nextPutAll: '  isKindOf Core.Notification = '; nextPutAll: (e isKindOf: Core.Notification) printString; nextPutAll: nl.
        s nextPutAll: '  isKindOf Core.Error = '; nextPutAll: (e isKindOf: Core.Error) printString; nextPutAll: nl]]
    ensure: [
        [tc tearDown] on: Core.Exception do: [:e | nil]].

"Also probe Smalltalk for what TEST_BUG2_YES_RET ended up as (the fork might still
 have written something even if main thread caught the Notification)"
s nextPutAll: 'TEST_BUG2_YES_RET= '; nextPutAll: (Root.Smalltalk at: #TEST_BUG2_YES_RET ifAbsent: ['(absent)']) printString; nextPutAll: nl.

s contents
