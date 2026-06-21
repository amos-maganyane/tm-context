| s nl m |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"For each of our 3 classes - what does testClasses return? shouldInheritSelectors? testSelectors size?"
#(#VWBridgeTest #VWBridgeWaitTest #VWBridgeScreenshotTest) do: [:nm |
    | c |
    c := VWB at: nm ifAbsent: [nil].
    s nextPutAll: nm asString; nextPutAll: '.testClasses=';
      nextPutAll: c testClasses asArray printString; nextPutAll: nl.
    s nextPutAll: nm asString; nextPutAll: '.shouldInheritSelectors=';
      nextPutAll: c shouldInheritSelectors printString; nextPutAll: nl.
    s nextPutAll: nm asString; nextPutAll: '.testSelectors.size=';
      nextPutAll: c testSelectors size printString; nextPutAll: nl].

"Examine TestCase class>>testClasses source-fingerprint"
m := TestCase class compiledMethodAt: #testClasses ifAbsent: [nil].
m ifNotNil: [
    s nextPutAll: 'TestCase class>>testClasses messages='; 
      nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
    s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl].

"buildSuite:On: details"
m := TestCase class compiledMethodAt: #buildSuite:On: ifAbsent: [nil].
m ifNotNil: [
    s nextPutAll: 'TestCase class>>buildSuite:On: messages='; 
      nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
    s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl.
    s nextPutAll: '  numArgs='; nextPutAll: m numArgs printString; nextPutAll: nl].

"buildSuiteFromLocalSelectors details"
m := TestCase class compiledMethodAt: #buildSuiteFromLocalSelectors ifAbsent: [nil].
m ifNotNil: [
    s nextPutAll: 'TestCase class>>buildSuiteFromLocalSelectors messages='; 
      nextPutAll: m messages asSortedCollection asArray printString; nextPutAll: nl.
    s nextPutAll: '  literals='; nextPutAll: m literals printString; nextPutAll: nl].

s contents
