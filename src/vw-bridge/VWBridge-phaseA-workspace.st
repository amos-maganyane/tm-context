"=== DEPRECATED -- do not file-in this script ==="
"The previous contents of this file tried to embed the full VWBridge source
 inside a single Smalltalk string and then file it back out using
 FileStream write:mode:check:type: and SourceManager default fileIn: .
 Both APIs are wrong for VW 9.3.1 in this image, and the whole approach
 is unnecessary -- VW's built-in file-in works fine.

 USE THIS INSTEAD (paste either line into a workspace and Do It):

   ""C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st"" asFilename fileIn.
   ""C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseA.st"" asFilename fileIn.

 The first installs the v0.5 base bridge (read-only widget walk).
 The second adds Phase A endpoints (/click /type /value + Bearer-token auth)
 and restarts the bridge automatically.

 If you Do It on this script, the line below just prints a hint and exits
 -- it does NOT install anything."

(Root.Smalltalk at: #Transcript ifAbsent: [nil])
    ifNotNil: [:t |
        t cr; show: '[VWBridge-phaseA-workspace.st] DEPRECATED.'.
        t cr; show: 'File in VWBridge.st then VWBridge-phaseA.st via the File Browser,'.
        t cr; show: 'or evaluate:'.
        t cr; show: '  ''C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st'' asFilename fileIn.'.
        t cr; show: '  ''C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-phaseA.st'' asFilename fileIn.'.
        t cr].
