#requires -Version 5.1
<#
.SYNOPSIS
    Auto-start wrapper for the VW Bridge (Phase P P5).

.DESCRIPTION
    Launches vwnt.exe with the MAS storedev64.im image and uses the documented
    VW image-level -filein switch (AppDevGuide.pdf p36) to feed src/vw-bridge/load.st
    at image-startup time. Wraps load.st into a single chunk (load body + CR-LF !
    CR-LF) so the chunk-file-in parser accepts it as one do-it expression.

    Replaces the AGENTS.md cold-start exception that previously required pasting
    load.st into a VW Workspace by hand.

    Per Oracle Path 4 design (memory entity Phase-P-P5-Oracle-recommendation,
    session-17), verified empirically session-18:
      - VW 9.3.1 AppDevGuide.pdf p36 documents -filein verbatim.
      - allowFilein=true in this MAS image (Core.ImageConfigurationSystem probe).
      - Top-level ^ in chunk file-in is silently consumed (probe D session-18).
      - load.st contains zero '!' chars (preflight asserts).

.PARAMETER HealthPollTimeoutSec
    How long to wait for /health to respond 200 after launch. Default 90s -
    a cold image-load + file-in of 5 source files takes ~30-60s on this machine.

.PARAMETER HealthPollIntervalMs
    Poll interval for /health. Default 500ms.

.PARAMETER NoWait
    Skip post-launch /health verification. Use for unattended launches that
    don't care whether the bridge actually came up.

.PARAMETER KillExisting
    If vwnt.exe is already running, kill it first before launching. Required
    for the P5 quality gate (5 cold-start cycles). Without this, the wrapper
    is idempotent - it exits 0 if /health is already responding.

.PARAMETER SkipNativeDialogToggle
    Skip the post-launch Smalltalk.Dialog useNativeDialogs: false toggle.
    The toggle is required because VW resets useNativeDialogs on every restart
    and the SimpleDialog override only takes effect when useNativeDialogs=false.

.EXAMPLE
    .\Start-VWBridge.ps1
    Default: idempotent launch. If /health 200, exit 0. Else launch and verify.

.EXAMPLE
    .\Start-VWBridge.ps1 -KillExisting
    Quality gate cycle: kill any running vwnt.exe, launch, verify /health,
    verify .token rotated, toggle useNativeDialogs.

.NOTES
    Exit codes:
      0 success (or bridge already up)
      2 VW_BRIDGE_HOME env var missing
      3 required file missing (vwnt.exe / storedev64.im / load.st)
      4 load.st contains '!' character (would break chunk-wrap)
      5 /health did not respond within timeout
      6 .token did not rotate (load.st step 5 failed) or .token missing
      7 launch failed before vwnt.exe started
#>
[CmdletBinding()]
param(
    [int]$HealthPollTimeoutSec = 90,
    [int]$HealthPollIntervalMs = 500,
    [switch]$NoWait,
    [switch]$KillExisting,
    [switch]$SkipNativeDialogToggle
)

$ErrorActionPreference = 'Stop'

function Write-Section([string]$msg) {
    Write-Host "[Start-VWBridge] $msg" -ForegroundColor Cyan
}
function Write-Good([string]$msg) {
    Write-Host "[Start-VWBridge] $msg" -ForegroundColor Green
}
function Write-Warn([string]$msg) {
    Write-Host "[Start-VWBridge] $msg" -ForegroundColor Yellow
}
function Write-Bad([string]$msg) {
    Write-Host "[Start-VWBridge] $msg" -ForegroundColor Red
}

#region --- (1) preflight ---

# VW_BRIDGE_HOME resolution order: Process env, User env, Machine env.
# Process env covers explicit `$env:VW_BRIDGE_HOME = '...'` before launch.
# User/Machine env cover desktop-shortcut + fresh-terminal launches where the
# parent process doesn't have the var. vwnt.exe itself reads via
# OS.CEnvironment userEnvironment (live OS-level read, per api-contract #8)
# so a Machine-level VW_BRIDGE_HOME would be visible inside the image even
# if not inherited via process env - but the wrapper needs it for .token /
# .generated / .err path derivation, so we resolve explicitly here.
$bridgeHome = $env:VW_BRIDGE_HOME
if (-not $bridgeHome) {
    $bridgeHome = [Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User')
}
if (-not $bridgeHome) {
    $bridgeHome = [Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'Machine')
}
if (-not $bridgeHome) {
    Write-Bad "VW_BRIDGE_HOME environment variable is not set at Process, User, or Machine level."
    Write-Bad "Set it to the bridge install dir (folder containing load.st), e.g.:"
    Write-Bad "  [Environment]::SetEnvironmentVariable('VW_BRIDGE_HOME', 'C:\path\to\src\vw-bridge', 'User')"
    exit 2
}
# Propagate to process env so any child (vwnt.exe, curl.exe) inherits it.
$env:VW_BRIDGE_HOME = $bridgeHome

$vwnt     = 'C:\visualworks931\bin\win64\vwnt.exe'
$image    = 'C:\visualworks931\image\storedev64.im'
$imageDir = 'C:\visualworks931\image'
$loadSt   = Join-Path $bridgeHome 'load.st'
$tokenFile = Join-Path $bridgeHome '.token'

foreach ($path in @($vwnt, $image, $loadSt)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Bad "Required file not found: $path"
        exit 3
    }
}
Write-Section "preflight OK (VW_BRIDGE_HOME=$bridgeHome)"

# --- (1b) assert load.st has no '!' (would break the chunk-wrap) ---
$loadStBytes = [System.IO.File]::ReadAllBytes($loadSt)
$bangCount = ($loadStBytes | Where-Object { $_ -eq 0x21 } | Measure-Object).Count
if ($bangCount -gt 0) {
    Write-Bad "load.st contains $bangCount '!' character(s); chunk-wrapping with '\r\n!\r\n' would split the chunk early."
    Write-Bad "Rewrite '!' out of load.st (api-contract.md: chunk parser splits at '!' even inside comments)."
    exit 4
}

#endregion

#region --- (2) idempotency check ---

$null = & curl.exe -s -f --max-time 2 http://127.0.0.1:9876/health 2>$null
$healthExitCode = $LASTEXITCODE
if ($healthExitCode -eq 0) {
    if (-not $KillExisting) {
        $resp = & curl.exe -s --max-time 2 http://127.0.0.1:9876/health 2>$null
        Write-Good "bridge already responding to /health: $resp"
        Write-Section "use -KillExisting to force restart"
        exit 0
    }
    Write-Warn "bridge already up but -KillExisting set; proceeding to kill"
}

#endregion

#region --- (3) optional kill of existing vwnt.exe ---

if ($KillExisting) {
    $existing = @(Get-Process -Name vwnt -ErrorAction SilentlyContinue)
    foreach ($p in $existing) {
        Write-Warn "killing existing vwnt.exe PID $($p.Id) (started $($p.StartTime))"
        Stop-Process -Id $p.Id -Force
    }
    if ($existing.Count -gt 0) {
        Start-Sleep -Seconds 2  # let port 9876 + .cha lock clear
    }
}

#endregion

#region --- (4) generate startup chunk: load.st body + CR-LF ! CR-LF ---

$generatedDir = Join-Path $bridgeHome '.generated'
if (-not (Test-Path -LiteralPath $generatedDir)) {
    $null = New-Item -ItemType Directory -Path $generatedDir
}
$generatedChunk = Join-Path $generatedDir 'load-startup.st'

# Read load.st as text. load.st is LF-only ASCII; ReadAllText preserves bytes as-is.
$body = [System.IO.File]::ReadAllText($loadSt, [System.Text.Encoding]::ASCII)
$wrappedContent = $body + "`r`n!`r`n"

# Write as ASCII (no BOM) - chunk parser is byte-oriented and won't accept UTF-8 BOM.
[System.IO.File]::WriteAllText($generatedChunk, $wrappedContent, [System.Text.Encoding]::ASCII)
Write-Section "generated $generatedChunk ($($wrappedContent.Length) chars)"

#endregion

#region --- (5) capture pre-launch state ---

$oldTokenTime = if (Test-Path -LiteralPath $tokenFile) {
    (Get-Item -LiteralPath $tokenFile).LastWriteTimeUtc
} else {
    [DateTime]::MinValue
}

#endregion

#region --- (6) launch vwnt.exe -filein <generated-chunk> -err <err-file> ---

$errFile = Join-Path $bridgeHome 'vwbridge-autostart.err'
# Truncate prior err file so we only see this launch's diagnostics
if (Test-Path -LiteralPath $errFile) {
    Clear-Content -LiteralPath $errFile -ErrorAction SilentlyContinue
}

# Per AppDevGuide.pdf p35: syntax is <oe> [oe-switches] <image-name> [image-switches].
# Image name MUST precede image switches. -err is Runtime Packager addition (p481)
# - works in this image but treat its functionality as best-effort.
$arguments = @($image, '-filein', $generatedChunk, '-err', $errFile)
Write-Section "launching: $vwnt $($arguments -join ' ')"
Write-Section "workdir:   $imageDir"

try {
    $process = Start-Process -FilePath $vwnt `
                             -ArgumentList $arguments `
                             -WorkingDirectory $imageDir `
                             -PassThru
} catch {
    Write-Bad "launch failed: $_"
    exit 7
}
Write-Section "vwnt.exe PID: $($process.Id), started $($process.StartTime)"

if ($NoWait) {
    Write-Warn "-NoWait set; exiting without verifying /health"
    exit 0
}

#endregion

#region --- (7) poll /health until 200 or timeout ---

$deadline = (Get-Date).AddSeconds($HealthPollTimeoutSec)
$healthy = $false
$polls = 0
$healthResp = $null

while ((Get-Date) -lt $deadline) {
    $polls++
    $null = & curl.exe -s -f --max-time 2 http://127.0.0.1:9876/health 2>$null
    if ($LASTEXITCODE -eq 0) {
        $healthResp = & curl.exe -s --max-time 2 http://127.0.0.1:9876/health 2>$null
        $healthy = $true
        break
    }
    # Sanity check: is vwnt.exe still running? If it crashed we should bail early.
    if ($process.HasExited) {
        Write-Bad "vwnt.exe exited with code $($process.ExitCode) before /health responded"
        if (Test-Path -LiteralPath $errFile) {
            Write-Bad "--- $errFile ---"
            Get-Content -LiteralPath $errFile | ForEach-Object { Write-Bad "  $_" }
        }
        exit 5
    }
    Start-Sleep -Milliseconds $HealthPollIntervalMs
}

if (-not $healthy) {
    Write-Bad "/health did not respond within ${HealthPollTimeoutSec}s ($polls poll attempt(s))"
    if (Test-Path -LiteralPath $errFile) {
        Write-Bad "--- $errFile (last 50 lines) ---"
        Get-Content -LiteralPath $errFile -Tail 50 | ForEach-Object { Write-Bad "  $_" }
    }
    exit 5
}
Write-Good "/health 200 OK after $polls poll(s) ($($polls * $HealthPollIntervalMs)ms): $healthResp"

#endregion

#region --- (8) verify .token rotated ---

if (-not (Test-Path -LiteralPath $tokenFile)) {
    Write-Bad ".token file does not exist at $tokenFile - load.st step 5 (write token) failed"
    exit 6
}
$newTokenTime = (Get-Item -LiteralPath $tokenFile).LastWriteTimeUtc
if ($newTokenTime -le $oldTokenTime) {
    Write-Bad ".token timestamp did NOT advance (old=$oldTokenTime, new=$newTokenTime)"
    Write-Bad "load.st did not call VWB.VWBridge start, OR the new vwnt.exe is the same one as before"
    exit 6
}
$token = [System.IO.File]::ReadAllText($tokenFile).Trim()
Write-Good ".token rotated at $newTokenTime, value=$token"

#endregion

#region --- (9) post-launch: toggle Smalltalk.Dialog useNativeDialogs: false ---

if (-not $SkipNativeDialogToggle) {
    $toggleBody = "Smalltalk.Dialog useNativeDialogs: false. ^'native-dialogs-OFF'"
    $toggleResp = & curl.exe -s -X POST http://127.0.0.1:9876/eval `
        -H "Authorization: Bearer $token" `
        -H "Content-Type: text/plain" `
        --data-binary $toggleBody 2>$null
    if ($LASTEXITCODE -eq 0 -and $toggleResp -match 'native-dialogs-OFF') {
        Write-Good "Smalltalk.Dialog useNativeDialogs: false (Bug #2 fix active)"
    } else {
        Write-Warn "useNativeDialogs toggle response: $toggleResp"
    }
}

#endregion

Write-Good "Start-VWBridge.ps1 SUCCESS"
exit 0
