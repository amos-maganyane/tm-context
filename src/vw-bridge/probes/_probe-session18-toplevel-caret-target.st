"Probe target for session-18 P5 orthogonal probe - chunk file-in of top-level caret.
This file is a single chunk with a top-level method-return. Per Oracle session-17
recommendation, load.st is fed via -filein as a single chunk wrapped with CR-LF-bang-CR-LF.
If path asFilename fileIn on this file raises BlockContext cannotReturn or
similar, then Oracles wrapper design needs adjustment (drop the top-level caret in
load.st and use a non-returning final expression like Transcript show: ...)."
^'session-18-toplevel-caret-OK'
!
