#Requires -Version 5.1
<#
.SYNOPSIS
    Install mcp-vw into Claude Desktop's MCP server config.

.DESCRIPTION
    Detects Claude Desktop install (MSIX or non-MSIX) and writes the
    `vw-bridge` entry into `claude_desktop_config.json`. Handles the
    Windows MSIX path landmine where Claude Desktop runs out of
    %LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\ instead
    of the conventional %APPDATA%\Claude\.

    Idempotent — re-running rewrites the existing entry rather than
    duplicating it.

.PARAMETER McpVwDir
    Directory containing the built mcp-vw. Defaults to the script's
    parent directory (assumed: <repo>/src/mcp-vw/scripts/...).

.PARAMETER BridgeUrl
    URL of the VW Bridge. Defaults to http://127.0.0.1:9876.

.PARAMETER TokenFile
    Path to the bridge .token file. Defaults to $env:VW_BRIDGE_HOME/.token
    if VW_BRIDGE_HOME is set.

.PARAMETER SingleOwner
    Whether to enforce single-owner lock. Defaults to true.

.PARAMETER WhatIf
    Print the resolved config without writing the file.

.EXAMPLE
    .\install-mcp-vw.ps1
        Install with defaults; auto-detect MSIX path; pick up VW_BRIDGE_HOME from env.

.EXAMPLE
    .\install-mcp-vw.ps1 -BridgeUrl http://localhost:9876 -SingleOwner $false
        Install with custom bridge URL + opt out of single-owner lock.

.NOTES
    Per architecture.md §8.2. MSIX path detection via Get-AppxPackage.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$McpVwDir = $null,
    [string]$BridgeUrl = 'http://127.0.0.1:9876',
    [string]$TokenFile = $null,
    [bool]$SingleOwner = $true
)

$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Resolve mcp-vw dir + dist entrypoint
# -----------------------------------------------------------------------------

if (-not $McpVwDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $McpVwDir = Split-Path -Parent $scriptDir
}
$McpVwDir = (Resolve-Path -LiteralPath $McpVwDir).ProviderPath
$entryPoint = Join-Path $McpVwDir 'dist\src\index.js'

if (-not (Test-Path -LiteralPath $entryPoint)) {
    throw "[install-mcp-vw] Built entry point not found: $entryPoint. Run 'npm run build' in $McpVwDir first."
}
Write-Host "[install-mcp-vw] mcp-vw entry: $entryPoint"

# -----------------------------------------------------------------------------
# Resolve token file
# -----------------------------------------------------------------------------

if (-not $TokenFile) {
    $vwBridgeHome = $env:VW_BRIDGE_HOME
    if (-not $vwBridgeHome) {
        $vwBridgeHome = [Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'User')
    }
    if (-not $vwBridgeHome) {
        $vwBridgeHome = [Environment]::GetEnvironmentVariable('VW_BRIDGE_HOME', 'Machine')
    }
    if ($vwBridgeHome) {
        $TokenFile = Join-Path $vwBridgeHome '.token'
    } else {
        throw "[install-mcp-vw] -TokenFile not provided and VW_BRIDGE_HOME env var is not set. Either pass -TokenFile or set VW_BRIDGE_HOME."
    }
}
Write-Host "[install-mcp-vw] Token file: $TokenFile"

# -----------------------------------------------------------------------------
# Find Claude Desktop config directory (MSIX-aware)
# -----------------------------------------------------------------------------

function Find-ClaudeConfigDir {
    # 1) MSIX install: %LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude
    try {
        $pkg = Get-AppxPackage -Name '*Claude*' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg) {
            $msixCandidate = Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalCache\Roaming\Claude"
            if (Test-Path -LiteralPath $msixCandidate) {
                return @{ Path = $msixCandidate; Source = 'MSIX' }
            }
        }
    } catch {
        # Get-AppxPackage may not be available (e.g., Linux PowerShell Core); fall through.
    }

    # 2) Standard non-MSIX: %APPDATA%\Claude
    $standardCandidate = Join-Path $env:APPDATA 'Claude'
    if (Test-Path -LiteralPath $standardCandidate) {
        return @{ Path = $standardCandidate; Source = 'Standard (%APPDATA%\Claude)' }
    }

    # 3) Create the standard path so the user can re-run after first install.
    New-Item -ItemType Directory -Path $standardCandidate -Force | Out-Null
    return @{ Path = $standardCandidate; Source = 'Standard (newly created)' }
}

$configDirInfo = Find-ClaudeConfigDir
$configDir = $configDirInfo.Path
$configFile = Join-Path $configDir 'claude_desktop_config.json'
Write-Host "[install-mcp-vw] Claude config dir: $configDir ($($configDirInfo.Source))"
Write-Host "[install-mcp-vw] Config file: $configFile"

# -----------------------------------------------------------------------------
# Load existing config or initialize
# -----------------------------------------------------------------------------

$existing = $null
if (Test-Path -LiteralPath $configFile) {
    try {
        $existing = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    } catch {
        throw "[install-mcp-vw] Failed to parse existing $configFile : $_. Backup it manually + retry."
    }
}
if (-not $existing) {
    $existing = [pscustomobject]@{ mcpServers = [pscustomobject]@{} }
}
if (-not $existing.PSObject.Properties.Match('mcpServers').Count) {
    $existing | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([pscustomobject]@{}) -Force
}

# -----------------------------------------------------------------------------
# Build the vw-bridge entry
# -----------------------------------------------------------------------------

$entry = [pscustomobject]@{
    command = 'node'
    args    = @($entryPoint)
    env     = [pscustomobject]@{
        VW_BRIDGE_URL        = $BridgeUrl
        VW_BRIDGE_TOKEN_FILE = $TokenFile
        MCP_VW_SINGLE_OWNER  = if ($SingleOwner) { '1' } else { '0' }
    }
}

# Add or overwrite (idempotent).
if ($existing.mcpServers.PSObject.Properties.Match('vw-bridge').Count) {
    $existing.mcpServers.'vw-bridge' = $entry
    Write-Host "[install-mcp-vw] Overwriting existing vw-bridge entry (idempotent re-install)."
} else {
    $existing.mcpServers | Add-Member -NotePropertyName 'vw-bridge' -NotePropertyValue $entry -Force
    Write-Host "[install-mcp-vw] Adding new vw-bridge entry."
}

# -----------------------------------------------------------------------------
# Write atomically (tmp + rename)
# -----------------------------------------------------------------------------

$json = $existing | ConvertTo-Json -Depth 20

if ($PSCmdlet.ShouldProcess($configFile, 'Write claude_desktop_config.json')) {
    $tmpFile = "$configFile.tmp.$PID.$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    try {
        Set-Content -LiteralPath $tmpFile -Value $json -Encoding UTF8 -NoNewline
        Move-Item -LiteralPath $tmpFile -Destination $configFile -Force
    } catch {
        if (Test-Path -LiteralPath $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue }
        throw "[install-mcp-vw] Failed to write $configFile : $_"
    }
    Write-Host "[install-mcp-vw] Wrote $configFile"
} else {
    Write-Host "[install-mcp-vw] -WhatIf: would write:"
    Write-Host $json
}

Write-Host ""
Write-Host "[install-mcp-vw] Done. Restart Claude Desktop to pick up the new server."
Write-Host "[install-mcp-vw] After restart, the 'vw-bridge' server should appear with 18 tools."
