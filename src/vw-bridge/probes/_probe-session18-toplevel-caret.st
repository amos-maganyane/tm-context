"Probe session-18 P5 orthogonal - top-level caret in chunk file-in.
Wraps path asFilename fileIn with Notification-resume + Exception-catch
to detect whether top-level caret in the target raises BlockContext cannotReturn
when fed via chunk file-in (Oracles -filein mechanism uses the same chunk
evaluator internally).

Output interpretation:
  string fileIn-returned-OK == top-level caret silently consumed (fileIn returns nil normally)
  string EXCEPTION ...      == top-level caret raises in chunk eval (Oracles load.st needs fix)"

| targetPath result |
targetPath := 'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\probes\_probe-session18-toplevel-caret-target.st'.

result := [[targetPath asFilename fileIn.
            'fileIn-returned-OK (no exception, no notification)']
              on: Core.Notification
              do: [:nex |
                  | msg |
                  msg := 'NOTIFICATION class=' , nex class name asString
                          , ' msg=' , (nex messageText ifNil: ['(nil)']) printString.
                  nex resume.
                  msg]]
            on: Core.Exception
            do: [:ex |
                'EXCEPTION class=' , ex class name asString
                  , ' msg=' , (ex messageText ifNil: ['(nil)']) printString].

result
