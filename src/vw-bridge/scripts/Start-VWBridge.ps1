#requires -Version 5.1
<#
.SYNOPSIS
    Auto-start wrapper for the VW Bridge (Phase P P5 + P6).

.DESCRIPTION
    Launches vwnt.exe with the MAS storedev64.im image and uses documented
    VW image-level command-line switches (AppDevGuide.pdf p36) to install + start
    the bridge at image-startup time.

    Two modes:
      -Mode FileIn  (default, P5 path): -filein chunk-wrapped load.st orchestrates
                    file-in of 5 source files + VWB.VWBridge start + .token write.
      -Mode Parcel  (P6 path): -pcl VWBridge.pcl loads the binary parcel (VWB
                    namespace + VWBridge class + SimpleDialog override), then
                    -filein chunk-wrapped parcel-start.st calls VWB.VWBridge start
                    + .token write. AppDevGuide.pdf p36 confirms left-to-right
                    switch ordering, so -pcl resolves before -filein executes.

    Per Oracle Path 4 design (memory entity Phase-P-P5-Oracle-recommendation,
    session-17), verified through 5-cycle quality gate session-18:
      - VW 9.3.1 AppDevGuide.pdf p36 documents -filein verbatim.
      - allowFilein=true in this MAS image (Core.ImageConfigurationSystem probe).
      - Top-level ^ in chunk file-in is silently consumed (probe D session-18).
      - source file contains zero '!' chars (preflight asserts).

    Phase P P6 (session-19) added the Parcel mode after empirical resolution of
    the headless parcel-build path (Cursor>>showWhile: monkey-patch + canonical
    parcelOutOn:withSource:hideOnLoad:republish:backup: with Filename source arg).

.PARAMETER Mode
    FileIn (default) or Parcel. FileIn uses the P5 source-load orchestration via
    load.st. Parcel uses the P6 binary parcel via VWBridge.pcl + post-load start
    script (parcel-start.st).

.PARAMETER Parcel
    Path to the .pcl file (Parcel mode only). Defaults to
    $VW_BRIDGE_HOME/parcels/VWBridge.pcl.

.PARAMETER HealthPollTimeoutSec
    How long to wait for /health to respond 200 after launch. Default 90s -
    a cold image-load + parcel-load (or file-in of 5 sources) takes <10s on
    this machine per s18 quality gate.

.PARAMETER HealthPollIntervalMs
    Poll interval for /health. Default 500ms.

.PARAMETER NoWait
    Skip post-launch /health verification. Use for unattended launches that
    don't care whether the bridge actually came up.

.PARAMETER KillExisting
    If vwnt.exe is already running, kill it first before launching. Required
    for the P5/P6 quality gate (5 cold-start cycles). Without this, the wrapper
    is idempotent - it exits 0 if /health is already responding.

.PARAMETER SkipNativeDialogToggle
    Skip the post-launch Smalltalk.Dialog useNativeDialogs: false toggle.
    The toggle is required because VW resets useNativeDialogs on every restart
    and the SimpleDialog override only takes effect when useNativeDialogs=false.

.EXAMPLE
    .\Start-VWBridge.ps1
    Default: idempotent FileIn-mode launch. If /health 200, exit 0. Else launch.

.EXAMPLE
    .\Start-VWBridge.ps1 -Mode Parcel -KillExisting
    Quality-gate cycle in parcel mode: kill any running vwnt.exe, launch with
    -pcl + post-load start, verify /health + .token rotation + Dialog toggle.

.NOTES
    Exit codes:
      0 success (or bridge already up)
      2 VW_BRIDGE_HOME env var missing
      3 required file missing (vwnt.exe / image / source script / parcel)
      4 source script contains '!' character (would break chunk-wrap)
      5 /health did not respond within timeout
      6 .token did not rotate (start-script step failed) or .token missing
      7 launch failed before vwnt.exe started
#>
[CmdletBinding()]
param(
    [ValidateSet('FileIn', 'Parcel')]
    [string]$Mode = 'FileIn',
    [string]$Parcel,
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

function Get-GitHeadSha([string]$startPath) {
    # Walks up from $startPath looking for a .git directory, then resolves HEAD
    # to a 40-char SHA. Pure-PowerShell - does NOT shell out to `git` (which
    # isn't on PowerShell's PATH on this workstation, only via WSL).
    # Returns 'unknown' on any failure (no repo, packed refs not parseable, etc.).
    try {
        $current = (Get-Item -LiteralPath $startPath -ErrorAction Stop).FullName
        while ($current -and $current.Length -gt 3) {
            $gitDir = Join-Path $current '.git'
            if (Test-Path -LiteralPath $gitDir) {
                $headPath = Join-Path $gitDir 'HEAD'
                if (-not (Test-Path -LiteralPath $headPath)) { return 'unknown' }
                $head = (Get-Content -LiteralPath $headPath -Raw).Trim()
                if ($head -match '^ref:\s+(.+)$') {
                    $refName = $matches[1]
                    $refPath = Join-Path $gitDir $refName
                    if (Test-Path -LiteralPath $refPath) {
                        return (Get-Content -LiteralPath $refPath -Raw).Trim()
                    }
                    # Fall back to packed-refs (common after `git gc`)
                    $packedRefsPath = Join-Path $gitDir 'packed-refs'
                    if (Test-Path -LiteralPath $packedRefsPath) {
                        $line = Get-Content -LiteralPath $packedRefsPath |
                                Where-Object { $_ -match "\s$([regex]::Escape($refName))$" } |
                                Select-Object -First 1
                        if ($line) { return ($line -split '\s+')[0] }
                    }
                    return 'unknown'
                } else {
                    # Detached HEAD - HEAD content IS the SHA
                    return $head
                }
            }
            $parent = Split-Path -Parent $current
            if ($parent -eq $current) { break }
            $current = $parent
        }
    } catch { }
    return 'unknown'
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

# Mode-aware source-script + parcel resolution.
# FileIn mode: load.st orchestrates file-in of 5 sources + start + token write.
# Parcel mode: parcel-start.st only does start + token write (parcel adds classes via -pcl).
if ($Mode -eq 'FileIn') {
    $sourceSt = Join-Path $bridgeHome 'load.st'
    $parcelPath = $null
} else {
    $sourceSt = Join-Path $bridgeHome 'parcel-start.st'
    if ($Parcel) {
        $parcelPath = $Parcel
    } else {
        $parcelPath = Join-Path $bridgeHome 'parcels\VWBridge.pcl'
    }
}
$tokenFile = Join-Path $bridgeHome '.token'

$requiredFiles = @($vwnt, $image, $sourceSt)
if ($Mode -eq 'Parcel') { $requiredFiles += $parcelPath }
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Bad "Required file not found: $path"
        exit 3
    }
}
Write-Section "preflight OK (VW_BRIDGE_HOME=$bridgeHome, Mode=$Mode)"
if ($Mode -eq 'Parcel') { Write-Section "  parcel: $parcelPath" }

# --- (1b) assert source script has no '!' (would break the chunk-wrap) ---
$sourceBytes = [System.IO.File]::ReadAllBytes($sourceSt)
$bangCount = ($sourceBytes | Where-Object { $_ -eq 0x21 } | Measure-Object).Count
if ($bangCount -gt 0) {
    Write-Bad "$sourceSt contains $bangCount '!' character(s); chunk-wrapping with '\r\n!\r\n' would split the chunk early."
    Write-Bad "Rewrite '!' out (api-contract.md: chunk parser splits at '!' even inside comments)."
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

#region --- (4) generate startup chunk: source body + CR-LF ! CR-LF ---

$generatedDir = Join-Path $bridgeHome '.generated'
if (-not (Test-Path -LiteralPath $generatedDir)) {
    $null = New-Item -ItemType Directory -Path $generatedDir
}
$generatedChunkName = if ($Mode -eq 'FileIn') { 'load-startup.st' } else { 'parcel-start-startup.st' }
$generatedChunk = Join-Path $generatedDir $generatedChunkName

# Read source script as text. Source files are LF-only ASCII; ReadAllText preserves bytes as-is.
$body = [System.IO.File]::ReadAllText($sourceSt, [System.Text.Encoding]::ASCII)
$wrappedContent = $body + "`r`n!`r`n"

# Write as ASCII (no BOM) - chunk parser is byte-oriented and won't accept UTF-8 BOM.
[System.IO.File]::WriteAllText($generatedChunk, $wrappedContent, [System.Text.Encoding]::ASCII)
Write-Section "generated $generatedChunk ($($wrappedContent.Length) chars from $sourceSt)"

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
# In Parcel mode, -pcl precedes -filein per p470 left-to-right semantics:
# parcel loads first (adds VWB namespace + classes + extension), then -filein
# executes parcel-start.st which calls VWB.VWBridge start + writes .token.
$arguments = @($image)
if ($Mode -eq 'Parcel') {
    $arguments += '-pcl', $parcelPath
}
$arguments += '-filein', $generatedChunk, '-err', $errFile
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

#region --- (10) post-launch: inject build info via /eval (Phase P P8) ---

# Resolve git HEAD SHA by reading .git/HEAD directly (no git CLI dependency).
$buildCommitSha = Get-GitHeadSha $bridgeHome
# UTC ISO-8601 (yyyy-MM-ddTHH:mm:ssZ) - sortable, unambiguous.
$buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Both modes set all 3 fields. The values reflect THIS cold-start (not the
# parcel's original build time). The /version response is therefore "what
# is this running bridge" rather than "when was the parcel built". For
# parcel-build provenance, check git log of parcels/VWBridge.pcl.
$infoBody = "VWB.VWBridge buildCommitSha: '$buildCommitSha'. VWB.VWBridge buildTimestamp: '$buildTimestamp'. VWB.VWBridge parcelMode: '$Mode'. ^'build-info-set'"
$infoResp = & curl.exe -s -X POST http://127.0.0.1:9876/eval `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: text/plain" `
    --data-binary $infoBody 2>$null
if ($LASTEXITCODE -eq 0 -and $infoResp -match 'build-info-set') {
    Write-Good "build-info injected (sha=$buildCommitSha, ts=$buildTimestamp, mode=$Mode)"
} else {
    Write-Warn "build-info inject response: $infoResp"
}

#endregion

Write-Good "Start-VWBridge.ps1 SUCCESS"
exit 0
