"Probe P1 v4 - confirm canonical env-read selectors on OS.CEnvironment and test-time mutation surface. Final probe before P1 design."
| s nl |
s := WriteStream on: String new.
nl := String with: Core.Character lf.

"1. getenv: (class-side, by name)."
s nextPutAll: '-- getenv: (canonical read) --'; nextPutAll: nl.
#('USERPROFILE' 'USERNAME' 'VW_BRIDGE_HOME' 'COMPUTERNAME' 'OS') do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '.
    [s nextPutAll: (OS.CEnvironment getenv: k) printString; nextPutAll: nl]
        on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl]].

"2. caseInsensitiveGetenv: (Windows-friendly)."
s nextPutAll: nl; nextPutAll: '-- caseInsensitiveGetenv: --'; nextPutAll: nl.
#('userprofile' 'USERPROFILE' 'UserProfile' 'vw_bridge_home' 'VW_BRIDGE_HOME') do: [:k |
    s nextPutAll: '  '; nextPutAll: k; nextPutAll: ' = '.
    [s nextPutAll: (OS.CEnvironment caseInsensitiveGetenv: k) printString; nextPutAll: nl]
        on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl]].

"3. userEnvironment - what dictionary instance does it return."
s nextPutAll: nl; nextPutAll: '-- userEnvironment --'; nextPutAll: nl.
[| env |
 env := OS.CEnvironment userEnvironment.
 s nextPutAll: '  class: '; nextPutAll: env class name; nextPutAll: nl.
 s nextPutAll: '  size: '; nextPutAll: env size printString; nextPutAll: nl.
 s nextPutAll: '  at: USERPROFILE = '; nextPutAll: (env at: 'USERPROFILE' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl.
 s nextPutAll: '  at: VW_BRIDGE_HOME = '; nextPutAll: (env at: 'VW_BRIDGE_HOME' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR userEnvironment '; nextPutAll: e messageText; nextPutAll: nl].

"4. Test-time injection - set, read back via three paths, then clean up."
s nextPutAll: nl; nextPutAll: '-- inject + read + cleanup --'; nextPutAll: nl.
[OS.CEnvironment userEnvironmentAt: 'VW_BRIDGE_PROBE_TEST' put: 'hello_phase_p'.
 s nextPutAll: '  after set, getenv: VW_BRIDGE_PROBE_TEST = '; nextPutAll: (OS.CEnvironment getenv: 'VW_BRIDGE_PROBE_TEST') printString; nextPutAll: nl.
 s nextPutAll: '  after set, userEnvironment at: = '; nextPutAll: (OS.CEnvironment userEnvironment at: 'VW_BRIDGE_PROBE_TEST' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  inject ERR '; nextPutAll: e messageText; nextPutAll: nl].

[OS.CEnvironment userEnvironment removeKey: 'VW_BRIDGE_PROBE_TEST' ifAbsent: [nil].
 s nextPutAll: '  after remove, getenv: = '; nextPutAll: (OS.CEnvironment getenv: 'VW_BRIDGE_PROBE_TEST') printString; nextPutAll: nl.
 s nextPutAll: '  after remove, userEnvironment at: = '; nextPutAll: (OS.CEnvironment userEnvironment at: 'VW_BRIDGE_PROBE_TEST' ifAbsent: ['<MISSING>']) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: '  cleanup ERR '; nextPutAll: e messageText; nextPutAll: nl].

"5. Does userEnvironment hand back a fresh dict each call, or the same live dict?"
s nextPutAll: nl; nextPutAll: '-- identity stability --'; nextPutAll: nl.
[| a b |
 a := OS.CEnvironment userEnvironment.
 b := OS.CEnvironment userEnvironment.
 s nextPutAll: '  a == b = '; nextPutAll: (a == b) printString; nextPutAll: nl]
    on: Error do: [:e | s nextPutAll: 'ERR '; nextPutAll: e messageText; nextPutAll: nl].

s contents