"Stage 2 file-in batch - namespace migration. VWBridge.st first: creates VWB namespace, defines VWB.VWBridge with methods, auto-start chunk stops + removes old top-level VWBridge then starts new VWB.VWBridge, rotates token. Patches.st: re-compiles SimpleDialog method (no namespace change). 3 test files: each creates new VWB.VWBridgeXxx + cleanup chunk removes old top-level VWBridgeXxx."
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Patches.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-WaitTest.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-ScreenshotTest.st' asFilename fileIn.
'Stage 2 file-in batch complete'