@echo off
REM Start-VWBridge.bat - Desktop-friendly launcher for VW Bridge (Phase P P5)
REM
REM Wraps Start-VWBridge.ps1 with a PowerShell invocation that bypasses the
REM execution-policy restriction without modifying machine policy. Forwards
REM all command-line arguments to the script.
REM
REM Place a desktop shortcut to this .bat. Replaces the AGENTS.md cold-start
REM Workspace-paste step.
REM
REM Exit code from PowerShell is preserved.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-VWBridge.ps1" %*
exit /b %ERRORLEVEL%
