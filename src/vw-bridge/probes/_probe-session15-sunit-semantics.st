| s nl cls testSels suiteOwner suiteMethod meta |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Per-class selector counts (no suite invocation, just dict introspection)"
#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | c |
    c := VWB at: nm ifAbsent: [nil].
    c isNil
        ifTrue: [s nextPutAll: nm asString; nextPutAll: ': ABSENT'; nextPutAll: nl]
        ifFalse: [
            testSels := c selectors select: [:sel | sel asString startsWith: 'test'].
            s nextPutAll: nm asString; nextPutAll: ': '; nextPutAll: testSels size printString;
              nextPutAll: ' test* selectors, '; nextPutAll: c selectors size printString;
              nextPutAll: ' total. superclass='; nextPutAll: c superclass name; nextPutAll: nl]].

"Walk metaclass hierarchy to find where #suite is defined"
cls := VWB.VWBridgeTest.
meta := cls class.
suiteOwner := nil.
[suiteOwner isNil and: [meta notNil and: [meta name ~= #ProtoObject]]] whileTrue: [
    (meta includesSelector: #suite) ifTrue: [suiteOwner := meta].
    suiteOwner isNil ifTrue: [meta := meta superclass]].
s nextPutAll: 'suiteOwner='; nextPutAll: (suiteOwner ifNil: ['none'] ifNotNil: [suiteOwner name]);
  nextPutAll: nl.
suiteOwner ifNotNil: [
    suiteMethod := suiteOwner compiledMethodAt: #suite ifAbsent: [nil].
    suiteMethod ifNotNil: [
        s nextPutAll: '  messages='; nextPutAll: suiteMethod messages asSortedCollection asArray printString; nextPutAll: nl.
        s nextPutAll: '  literals='; nextPutAll: suiteMethod literals printString; nextPutAll: nl]].

"Look for alternative runner APIs (canUnderstand is pure introspection)"
#(#testSelectors #buildSuite #buildSuiteFromSelectors #runAll #suiteClass #addTestsFor:) do: [:sel |
    s nextPutAll: 'canUnderstand #'; nextPutAll: sel asString; nextPutAll: '=';
      nextPutAll: (cls class canUnderstand: sel) printString; nextPutAll: nl].

"TestRunner / TestSuite / TestResult / TestCase top-level visibility"
#(#TestRunner #TestSuite #TestResult #TestCase) do: [:sym |
    s nextPutAll: 'top.'; nextPutAll: sym asString; nextPutAll: '=';
      nextPutAll: (Smalltalk at: sym ifAbsent: [nil]) printString; nextPutAll: nl].

s contents
