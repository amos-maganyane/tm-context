| s nl |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Subclasses of our 3 classes - should be empty"
#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | c |
    c := VWB at: nm ifAbsent: [nil].
    s nextPutAll: nm asString; nextPutAll: '.subclasses='; 
      nextPutAll: c subclasses asArray printString; nextPutAll: nl.
    s nextPutAll: nm asString; nextPutAll: '.allSubclasses.size='; 
      nextPutAll: c allSubclasses size printString; nextPutAll: nl].

"How many TestCase subclasses exist in the whole image?"
s nextPutAll: 'TestCase.subclasses.size='; nextPutAll: TestCase subclasses size printString; nextPutAll: nl.
s nextPutAll: 'TestCase.allSubclasses.size='; nextPutAll: TestCase allSubclasses size printString; nextPutAll: nl.

"Examine TestCase class side methods - what does buildSuite actually do?"
#(#buildSuite #buildSuiteFromSelectors #testSelectors #suiteClass #suite) do: [:sel |
    | m |
    m := TestCase class compiledMethodAt: sel ifAbsent: [nil].
    m ifNotNil: [
        s nextPutAll: 'TestCase class>>'; nextPutAll: sel asString; nextPutAll: ': '; nextPutAll: nl.
        s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl.
        s nextPutAll: '  messages='; nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
        s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl]].

"TestSuite + TestRunner key API"
s nextPutAll: 'TestSuite.envName='; nextPutAll: TestSuite environment name; nextPutAll: nl.
s nextPutAll: 'TestSuite.canUnderstand:#addTest:='; nextPutAll: (TestSuite canUnderstand: #addTest:) printString; nextPutAll: nl.
s nextPutAll: 'TestSuite.canUnderstand:#run='; nextPutAll: (TestSuite canUnderstand: #run) printString; nextPutAll: nl.

s contents
