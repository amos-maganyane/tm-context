# screenshot-helper.ps1
# Phase F3 Step 17 - PowerShell System.Drawing screen/window capture helper for VWBridge /screenshot.
# Captures a rectangle from the composited desktop, encodes as PNG, emits raw bytes to stdout.
# BINARY-SAFE: uses [Console]::OpenStandardOutput().Write() - NEVER Write-Output / Write-Host
# (text mangling risk on high bytes / null bytes per Oracle F3).
# Per Oracle F3:
#   - Graphics.FromImage($bm).CopyFromScreen(...) NOT FromHwnd (composited desktop)
#   - [SystemInformation]::VirtualScreen for full multi-monitor including negative coords
#   - Validated INT-only args (never concat strings into PowerShell source)
# Exit codes:
#   0 success - PNG bytes on stdout, diagnostic INFO on stderr
#   2 capture failure - ERROR message on stderr, no stdout bytes
# Invoked from VWBridge>>captureScreenshotViaSubprocess:rect: via OS.ExternalProcess
# defaultClass new + lineEndTransparent + createInOutErrorPipes + startProcess:arguments:.

param(
    [Parameter(Mandatory=$true)][ValidateSet('screen', 'window')][string]$Mode,
    [int]$X = 0,
    [int]$Y = 0,
    [int]$W = 0,
    [int]$H = 0
)

try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    if ($Mode -eq "screen") {
        # Full virtual screen across all monitors (negative coords allowed)
        $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $X = $bounds.X
        $Y = $bounds.Y
        $W = $bounds.Width
        $H = $bounds.Height
        [Console]::Error.WriteLine("INFO: capturing virtual screen at ($X,$Y) size ${W}x${H}")
    } else {
        if ($W -le 0 -or $H -le 0) {
            [Console]::Error.WriteLine("ERROR: invalid window dimensions W=$W H=$H (must be positive)")
            exit 2
        }
        [Console]::Error.WriteLine("INFO: capturing window at ($X,$Y) size ${W}x${H}")
    }

    $bitmap = New-Object System.Drawing.Bitmap $W, $H
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            # Composited desktop capture - works across monitors including negative coords.
            # Source: ($X, $Y); Dest: (0, 0) on bitmap; Size: $bitmap.Size = ($W, $H).
            $graphics.CopyFromScreen($X, $Y, 0, 0, $bitmap.Size)
        } finally {
            $graphics.Dispose()
        }

        $ms = New-Object System.IO.MemoryStream
        try {
            $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $bytes = $ms.ToArray()
            [Console]::Error.WriteLine("INFO: encoded ${W}x${H} as $($bytes.Length) byte PNG")

            # Emit raw PNG bytes to stdout - binary safe.
            # NOT Write-Output / Write-Host (text mangling risk per Oracle F3).
            $stdout = [Console]::OpenStandardOutput()
            $stdout.Write($bytes, 0, $bytes.Length)
            $stdout.Flush()
        } finally {
            $ms.Dispose()
        }
    } finally {
        $bitmap.Dispose()
    }

    exit 0
} catch {
    [Console]::Error.WriteLine("ERROR: $_")
    [Console]::Error.WriteLine($_.ScriptStackTrace)
    exit 2
}
