"Stage 1 file-in batch - 5 chained fileIns. VWBridge.st first (which restarts bridge + rotates token via auto-start chunk at end). Patches.st next (recompiles SimpleDialog method with new *VWBridge-Patches category). Then 3 test files (updates test class categories to VWBridge-Tests)."
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Patches.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-Test.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-WaitTest.st' asFilename fileIn.
'C:\Users\ammaganyane\tm\tm-context\src\vw-bridge\VWBridge-ScreenshotTest.st' asFilename fileIn.
'Stage 1 file-in batch complete'