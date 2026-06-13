# VM Command Safety Rules

## NEVER Execute

- Commands that modify running VW image files (mas.im, storeDev64.im, etc.)
- Commands that kill/restart processes (Stop-Process, taskkill)
- Commands that modify system files (hosts, services, registry)
- Commands that delete any file in C:\WEALTH\ or C:\visualworks931\
- Commands that modify network configuration
- Commands that install Windows services
- Commands that change user permissions or security settings
- Commands that write to C:\WEALTH\visualworks931\ (deployed app directory)
- Any command with -Force flag on destructive operations

## SAFE: Read-Only Commands

- dir, type, Get-Content (file listing and reading)
- Get-Process, Get-Service (process/service inspection)
- Get-NetTCPConnection (network inspection)
- Test-NetConnection (connectivity checks)
- Get-ChildItem (directory listing)
- Get-CimInstance (system info queries)

## SAFE: Write to Isolated Locations Only

- C:\Users\ammaganyane\forge\ (our working directory - must create first)
- $env:TEMP\ (temporary files)
- Node.js scripts in our working directory

## CAUTION: Ask Before

- Running vwntconsole.exe (spawns new VW process - safe but uses resources)
- Writing .st files (safe if in our directory, but confirm approach)
- Starting new Node.js processes (port conflicts possible)
- Any network-facing listeners (bind to 127.0.0.1 only)

## Validation Before Execution

1. Does this command modify anything outside our sandbox?
2. Could this command affect the running VW instance?
3. Could this command affect GemStone connectivity?
4. Is there a read-only alternative that gets the same info?
