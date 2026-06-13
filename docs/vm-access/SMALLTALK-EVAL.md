# Headless Smalltalk Evaluation Pattern

## Working Configuration

- **Executable**: C:\visualworks931\bin\win64\vwntconsole.exe
- **Image**: C:\Users\ammaganyane\forge\test.im (copy of storeDev64.im)
- **Flags**: `-xq -noherald` (exit quietly, no splash)
- **Input**: `-filein <script.st>`
- **Output**: Transcript goes to stdout

## Command Template

```powershell
cd C:\Users\ammaganyane\forge
Set-Content -Path eval.st -Value @"
<smalltalk code here>
ObjectMemory quit
"@
C:\visualworks931\bin\win64\vwntconsole.exe -xq -noherald test.im -filein eval.st 2>&1
```

## Important Notes

1. **Strings use single quotes** in Smalltalk (double quotes are comments)
2. **Must end with `ObjectMemory quit`** or the process hangs
3. **Transcript show:** sends output to stdout (captured by bridge)
4. **File output** via `asFilename writeStream` failed - likely needs Filename package loaded
5. **Image creates a .cha file** on first run (test.cha) - tracks changes
6. **Does NOT interact with running VW instance** - this is a separate process
7. **Each run modifies the image** (filed-in code persists) - may need fresh copies periodically

## Confirmed Working

```
Transcript show: Smalltalk version.
ObjectMemory quit
```
Output: `VisualWorks, 9.3.1 of August 16, 2023`

## Limitations

- This evaluates against a COPY of the dev image, not the running instance
- The image has GemStone connection code that may try to connect on startup (but -xq suppresses GUI)
- No direct way to inject code into the already-running VW process via this method
- For running-instance interaction, need to file-in a TCP listener into the live image manually
