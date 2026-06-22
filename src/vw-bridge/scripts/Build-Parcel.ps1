#requires -Version 5.1
<#
.SYNOPSIS
    Rebuild VWBridge.pcl + VWBridge.pst with current source (Phase P P8).

.DESCRIPTION
    Drives a headless parcel build via /eval against the live VWB.VWBridge
    instance. Uses the session-19 Cursor>>showWhile: monkey-patch pattern
    (carry-forward #35) to make Kernel.Parcel>>parcelOutOn:withSource:
    hideOnLoad:republish:backup: headless-safe.

    The produced parcel ships:
      - VWB namespace
      - VWB.VWBridge class definition + ALL its methods (instance + class
        side, including version / buildCommitSha / buildTimestamp / parcelMode
        accessors + setters)
      - SimpleDialog>>choose:labels:values:default:for: extension (Bug #2 fix)

    Build metadata (commit SHA + timestamp + parcel-vs-FileIn mode) is NOT
    baked into the parcel as compiled methods - that approach wedges this
    image during compile: on VWB.VWBridge (UI announcement during compile
    routes through Cursor wait showWhile: even after the Cursor monkey-patch
    is installed). Instead, Start-VWBridge.ps1 injects the values via /eval
    setters AT EVERY COLD START in both modes. /version therefore reflects
    "what bridge is running" rather than "when was the parcel built".

    Requires the bridge to be UP - this script drives via /eval.

.NOTES
    Exit codes:
      0 success
      1 bridge not responding at /health
      2 VW_RUNTIME_API_HOME env var missing
      3 /eval build returned non-success
      4 expected output artifacts missing
      5 copy to shipping location failed

    After a successful build, validate with:
        .\Start-VWBridge.ps1 -Mode Parcel -KillExisting

    Then curl http://127.0.0.1:9876/version to confirm the wrapper-injected
    metadata is reachable through the new parcel's accessors.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Section([string]$m) { Write-Host "[Build-Parcel] $m" -ForegroundColor Cyan }
function Write-Good([string]$m)    { Write-Host "[Build-Parcel] $m" -ForegroundColor Green }
function Write-Warn([string]$m)    { Write-Host "[Build-Parcel] $m" -ForegroundColor Yellow }
function Write-Bad([string]$m)     { Write-Host "[Build-Parcel] $m" -ForegroundColor Red }

function Get-GitHeadSha([string]$startPath) {
    # Resolve git HEAD by reading .git/HEAD directly (no git CLI dependency).
    # Walks up from $startPath to find the .git directory. Returns 'unknown'
    # on any failure. Same logic as Start-VWBridge.ps1 Get-GitHeadSha.
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
                    $packedRefsPath = Join-Path $gitDir 'packed-refs'
                    if (Test-Path -LiteralPath $packedRefsPath) {
                        $line = Get-Content -LiteralPath $packedRefsPath |
                                Where-Object { $_ -match "\s$([regex]::Escape($refName))$" } |
                                Select-Object -First 1
                        if ($line) { return ($line -split '\s+')[0] }
                    }
                    return 'unknown'
                } else {
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

$bridgeHome = $env:VW_RUNTIME_API_HOME
if (-not $bridgeHome) {
    $bridgeHome = [Environment]::GetEnvironmentVariable('VW_RUNTIME_API_HOME', 'User')
}
if (-not $bridgeHome) {
    $bridgeHome = [Environment]::GetEnvironmentVariable('VW_RUNTIME_API_HOME', 'Machine')
}
if (-not $bridgeHome) {
    Write-Bad "VW_RUNTIME_API_HOME not set at Process/User/Machine scope"
    exit 2
}
$env:VW_RUNTIME_API_HOME = $bridgeHome

$tokenFile = Join-Path $bridgeHome '.token'
if (-not (Test-Path -LiteralPath $tokenFile)) {
    Write-Bad ".token not found at $tokenFile - is the bridge running? Launch via Start-VWBridge.bat first."
    exit 1
}
$token = (Get-Content -LiteralPath $tokenFile -Raw).Trim()

$health = & curl.exe -s -f --max-time 2 http://127.0.0.1:9876/health 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Bad "/health did not respond - launch via Start-VWBridge.bat first."
    exit 1
}
Write-Section "preflight OK (VW_RUNTIME_API_HOME=$bridgeHome)"
Write-Section "bridge: $health"

#endregion

#region --- (2) capture build metadata (for logging only - NOT baked into parcel) ---

$buildSha = Get-GitHeadSha $bridgeHome
$buildTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Section "build context: sha=$buildSha"
Write-Section "               ts=$buildTs"
Write-Section "(these values are logged for traceability but NOT embedded into the parcel)"

#endregion

#region --- (3) prepare output directories ---

$generatedDir = Join-Path $bridgeHome '.generated\parcels'
if (-not (Test-Path -LiteralPath $generatedDir)) {
    $null = New-Item -ItemType Directory -Path $generatedDir -Force
}
$generatedPcl = Join-Path $generatedDir 'VWBridge.pcl'
$generatedPst = Join-Path $generatedDir 'VWBridge.pst'

# Clean any prior artifacts so we can be sure the build actually wrote new ones
foreach ($f in @($generatedPcl, $generatedPst)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

#endregion

#region --- (4) generate build probe ---

# IMPORTANT: do NOT include both 'VWBridge' AND 'dispatch' substrings in this
# /eval body (Stage 1 substring guard, AGENTS.md). 'VWBridge' is present
# (unavoidable); 'dispatch' must NOT appear anywhere.
#
# Probe Smalltalk source (verbatim session-19 pattern):
#   - Top-of-block temps
#   - All cross-namespace refs fully qualified
#   - Cursor>>showWhile: monkey-patch installed (carry-forward #35) to make
#     parcelOutOn: headless-safe
#   - Plain Kernel.Parcel createParcelNamed: + addNameSpace: + addEntiretyOfClass:
#     + addSelector:class: + parcelOutOn:withSource:hideOnLoad:republish:backup:
#   - Cleanup via removeParcelNamed: wrapped in Notification-resume (#38)
#
# Build metadata (SHA / timestamp) is NOT baked in - that approach wedged the
# bridge mid-build even with the Cursor patch installed, because the ensure:
# block's reference to VWB.VWBridge after parcel cleanup raised a "no binding"
# exception. Start-VWBridge.ps1 instead injects metadata via /eval setters at
# every cold-start in both FileIn and Parcel modes.
$probeBody = @'
| home parcelDir pclPath pstPath patchInstalled cursorOldMethod parcel |
home := OS.CEnvironment userEnvironment at: 'VW_RUNTIME_API_HOME'.
parcelDir := home , '\.generated\parcels'.
pclPath := parcelDir , '\VWBridge.pcl'.
pstPath := parcelDir , '\VWBridge.pst'.

cursorOldMethod := Cursor compiledMethodAt: #showWhile:.
patchInstalled := false.
[
    [Cursor compile: 'showWhile: aBlock ^aBlock value'
        classified: '*VWBridge-Patches temp-headless-build'.
     patchInstalled := true]
        on: Core.Notification do: [:n | n resume].
    patchInstalled ifTrue: [
        parcel := Kernel.Parcel createParcelNamed: 'VWBridge'.
        parcel addNameSpace: VWB.
        parcel addEntiretyOfClass: VWB.VWBridge.
        parcel addSelector: #choose:labels:values:default:for: class: SimpleDialog.
        parcel
            parcelOutOn: pclPath asFilename
            withSource: pstPath asFilename
            hideOnLoad: false
            republish: false
            backup: false.
        [Kernel.Parcel removeParcelNamed: 'VWBridge']
            on: Core.Notification do: [:n | n resume]]
] ensure: [
    patchInstalled ifTrue: [
        Cursor methodDictionary at: #showWhile: put: cursorOldMethod]].

^'build-OK pcl=' , pclPath , ' pst=' , pstPath
'@

$probeFile = Join-Path $bridgeHome '.generated\build-parcel-probe.st'
$probeDir = Split-Path -Parent $probeFile
if (-not (Test-Path -LiteralPath $probeDir)) {
    $null = New-Item -ItemType Directory -Path $probeDir -Force
}
[System.IO.File]::WriteAllText($probeFile, $probeBody, [System.Text.Encoding]::ASCII)
Write-Section "wrote probe ($($probeBody.Length) chars) to $probeFile"

#endregion

#region --- (5) POST probe to /eval ---

Write-Section "driving parcel build via /eval (Cursor>>showWhile: monkey-patch + parcelOutOn:)"
$resp = & curl.exe -s -X POST http://127.0.0.1:9876/eval `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: text/plain" `
    --data-binary "@$probeFile" 2>$null
if ($LASTEXITCODE -ne 0 -or $resp -notmatch 'build-OK') {
    Write-Bad "build /eval failed:"
    Write-Bad "  $resp"
    exit 3
}
Write-Good "build /eval response: $resp"

#endregion

#region --- (6) verify output artifacts ---

if (-not (Test-Path -LiteralPath $generatedPcl)) {
    Write-Bad "expected $generatedPcl missing after build"
    exit 4
}
if (-not (Test-Path -LiteralPath $generatedPst)) {
    Write-Bad "expected $generatedPst missing after build"
    exit 4
}
$pclInfo = Get-Item -LiteralPath $generatedPcl
$pstInfo = Get-Item -LiteralPath $generatedPst
Write-Good "built VWBridge.pcl = $($pclInfo.Length) bytes"
Write-Good "built VWBridge.pst = $($pstInfo.Length) bytes"

#endregion

#region --- (7) copy to shipping location ---

$shipDir = Join-Path $bridgeHome 'parcels'
if (-not (Test-Path -LiteralPath $shipDir)) {
    $null = New-Item -ItemType Directory -Path $shipDir -Force
}
$shipPcl = Join-Path $shipDir 'VWBridge.pcl'
$shipPst = Join-Path $shipDir 'VWBridge.pst'

try {
    Copy-Item -LiteralPath $generatedPcl -Destination $shipPcl -Force
    Copy-Item -LiteralPath $generatedPst -Destination $shipPst -Force
} catch {
    Write-Bad "copy to shipping location failed: $_"
    exit 5
}
Write-Good "copied to $shipDir"

#endregion

Write-Good "Build-Parcel.ps1 SUCCESS"
Write-Section "validate via cold-start:"
Write-Section "  .\Start-VWBridge.ps1 -Mode Parcel -KillExisting"
Write-Section "then curl http://127.0.0.1:9876/version to confirm baked-in metadata"
exit 0
