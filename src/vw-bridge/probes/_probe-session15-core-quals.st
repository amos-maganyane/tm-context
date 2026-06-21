| s nl |
s := Core.WriteStream on: Core.String new.
nl := Core.String with: Core.Character lf.
s nextPutAll: 'WriteStream='; nextPutAll: Core.WriteStream name; nextPutAll: nl.
s nextPutAll: 'String='; nextPutAll: Core.String name; nextPutAll: nl.
s nextPutAll: 'Character='; nextPutAll: Core.Character name; nextPutAll: nl.
s nextPutAll: 'sample='; nextPutAll: 'hello' printString; nextPutAll: nl.
s contents
