"Probe P1 env API. Confirms canonical env-read selector + fallback semantics + setEnv availability for test-time mutation in this VW image. Output answers Phase P P1 design decision (env-read pattern + override seam strategy + missing-var error path)."
| s nl env |
s := WriteStream on: String new.
nl := String with: Core.Character lf.
env := OS.OperatingSystem environment.

"Shape - what class, how many entries."
s nextPutAll: 'env class: '; nextPutAll: env class name; nextPutAll: nl.
[s nextPutAll: 'env size: '; nextPutAll: env size printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'env size ERR'; nextPutAll: nl].

"Read selector availability on the env object."
s nextPutAll: nl; nextPutAll: '-- env respondsTo: --'; nextPutAll: nl.
#(#at: #at:ifAbsent: #at:put: #removeKey: #includesKey: #keys #size #do:) do: [:sel |
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='.
    s nextPutAll: (env respondsTo: sel) printString; nextPutAll: nl].

"OS class-side env helpers - for test-time env injection (setEnv) and lookup shortcuts."
s nextPutAll: nl; nextPutAll: '-- OS.OperatingSystem class canUnderstand: --'; nextPutAll: nl.
#(#getEnv: #setEnv:value: #environment #environmentAt: #environmentAt:ifAbsent: #setEnvironmentVariable:value:) do: [:sel |
    s nextPutAll: '  '; nextPutAll: sel asString; nextPutAll: '='.
    s nextPutAll: (OS.OperatingSystem class canUnderstand: sel) printString; nextPutAll: nl].

"Real env-var reads. VW_BRIDGE_HOME absent in baseline; others should be present."
s nextPutAll: nl; nextPutAll: '-- env at: ifAbsent: --'; nextPutAll: nl.
#('VW_BRIDGE_HOME' 'USERPROFILE' 'VISUALWORKS' 'USERNAME' 'COMPUTERNAME') do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: '='.
    s nextPutAll: (env at: k ifAbsent: ['<MISSING>']) printString; nextPutAll: nl].

"Bare at: behavior when missing. Tells us whether to use at: + on:Error:do: or at:ifAbsent: in production. Affects the raise-loud-when-VW_BRIDGE_HOME-absent strategy."
s nextPutAll: nl; nextPutAll: '-- bare at: missing --'; nextPutAll: nl.
[s nextPutAll: '  result='; nextPutAll: (env at: 'NEVER_SET_VAR_PHASE_P_PROBE') printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  raises '; nextPutAll: e class name; nextPutAll: ' text='; nextPutAll: e messageText printString; nextPutAll: nl].

s contents