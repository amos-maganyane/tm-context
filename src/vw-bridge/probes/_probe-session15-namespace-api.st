| s nl |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.

"Probe namespace-context API: does this image have a current/beCurrent selector?"
#(#beCurrent #current #currentNamespace #setCurrentNamespace: #becomeCurrent #makeCurrent) do: [:sel |
    s nextPutAll: 'NameSpace canUnderstand #'; nextPutAll: sel asString; nextPutAll: '=';
      nextPutAll: (NameSpace canUnderstand: sel) printString; nextPutAll: nl.
    s nextPutAll: 'NameSpace class canUnderstand #'; nextPutAll: sel asString; nextPutAll: '=';
      nextPutAll: (NameSpace class canUnderstand: sel) printString; nextPutAll: nl].

"Does Smalltalk have a current namespace concept?"
#(#currentNamespace #currentNamespace: #currentNameSpace #currentNameSpace:) do: [:sel |
    s nextPutAll: 'Smalltalk class canUnderstand #'; nextPutAll: sel asString; nextPutAll: '=';
      nextPutAll: (Smalltalk class canUnderstand: sel) printString; nextPutAll: nl].

"Compiler API: evaluate:in: or compile:in: takes a namespace context?"
#(#evaluate:in: #evaluate:notifying: #compile:in: #compile:in:notifying: #evaluate:for:notifying:logged:) do: [:sel |
    s nextPutAll: 'Compiler class canUnderstand #'; nextPutAll: sel asString; nextPutAll: '=';
      nextPutAll: (Compiler class canUnderstand: sel) printString; nextPutAll: nl].

s contents
