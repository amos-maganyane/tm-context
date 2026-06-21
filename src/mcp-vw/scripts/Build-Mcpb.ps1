#Requires -Version 5.1
<#
.SYNOPSIS
    Bundle mcp-vw into a .mcpb (Claude Desktop Extension) zip.

.DESCRIPTION
    Produces a portable .mcpb file at <McpVwDir>/build/mcp-vw-<version>.mcpb
    that the user can double-click in Claude Desktop to install. Contents:

        manifest.json       — at archive root
        dist/               — built TypeScript (tsc emit)
        node_modules/       — runtime dependencies only (production prune)

    Requires: `npm run build` to have run first (dist/ must exist).

.PARAMETER McpVwDir
    Directory containing manifest.json + dist/. Defaults to the script's
    parent directory.

.PARAMETER OutputDir
    Where to place the resulting .mcpb. Defaults to <McpVwDir>/build.

.EXAMPLE
    .\Build-Mcpb.ps1
        Build mcp-vw-<version>.mcpb into <McpVwDir>/build.

.NOTES
    Per architecture.md §8.1. .mcpb is just a zip — the format spec is
    a manifest.json at root + the server's runtime artifacts.
#>

[CmdletBinding()]
param(
    [string]$McpVwDir = $null,
    [string]$OutputDir = $null
)

$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------

if (-not $McpVwDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $McpVwDir = Split-Path -Parent $scriptDir
}
$McpVwDir = (Resolve-Path -LiteralPath $McpVwDir).ProviderPath

$manifestPath = Join-Path $McpVwDir 'manifest.json'
$distDir      = Join-Path $McpVwDir 'dist'
$nodeModules  = Join-Path $McpVwDir 'node_modules'
$packageJson  = Join-Path $McpVwDir 'package.json'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "[Build-Mcpb] manifest.json not found at $manifestPath"
}
if (-not (Test-Path -LiteralPath $distDir)) {
    throw "[Build-Mcpb] dist/ not found at $distDir. Run 'npm run build' first."
}
if (-not (Test-Path -LiteralPath $nodeModules)) {
    throw "[Build-Mcpb] node_modules/ not found. Run 'npm install --omit=dev' first to keep bundle lean."
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $McpVwDir 'build'
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# -----------------------------------------------------------------------------
# Read version from package.json
# -----------------------------------------------------------------------------

$pkg = Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json
$version = $pkg.version
if (-not $version) {
    throw "[Build-Mcpb] Could not read version from $packageJson"
}

$bundleName = "mcp-vw-$version.mcpb"
$bundlePath = Join-Path $OutputDir $bundleName

Write-Host "[Build-Mcpb] McpVwDir: $McpVwDir"
Write-Host "[Build-Mcpb] Version: $version"
Write-Host "[Build-Mcpb] Output: $bundlePath"

# -----------------------------------------------------------------------------
# Validate manifest.json is parseable JSON
# -----------------------------------------------------------------------------

try {
    $null = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch {
    throw "[Build-Mcpb] manifest.json is invalid JSON: $_"
}

# -----------------------------------------------------------------------------
# Stage to a tmp dir, then zip
# -----------------------------------------------------------------------------

$stage = Join-Path $env:TEMP "mcp-vw-build-$PID-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Write-Host "[Build-Mcpb] Staging to $stage"

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stage 'manifest.json')
    Copy-Item -LiteralPath $packageJson  -Destination (Join-Path $stage 'package.json')
    Copy-Item -LiteralPath $distDir      -Destination (Join-Path $stage 'dist') -Recurse

    # Copy node_modules; this is the big one (10s of MB). User runs
    # `npm install --omit=dev` before invoking this script to keep size sane.
    Write-Host "[Build-Mcpb] Copying node_modules (this may take 30-60s)..."
    Copy-Item -LiteralPath $nodeModules -Destination (Join-Path $stage 'node_modules') -Recurse

    # Include README if present.
    $readmePath = Join-Path $McpVwDir 'README.md'
    if (Test-Path -LiteralPath $readmePath) {
        Copy-Item -LiteralPath $readmePath -Destination (Join-Path $stage 'README.md')
    }

    # Remove any prior bundle.
    if (Test-Path -LiteralPath $bundlePath) {
        Remove-Item -LiteralPath $bundlePath -Force
    }

    # Compress to .mcpb (which is just .zip with a different extension).
    Write-Host "[Build-Mcpb] Compressing to .mcpb (this may take 30-60s)..."
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $bundlePath -CompressionLevel Optimal

    $bundleSize = (Get-Item -LiteralPath $bundlePath).Length
    $bundleSizeMB = [Math]::Round($bundleSize / 1MB, 2)
    Write-Host "[Build-Mcpb] DONE. Wrote $bundlePath ($bundleSizeMB MB)"
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
