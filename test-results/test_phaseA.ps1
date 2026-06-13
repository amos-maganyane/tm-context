# Phase A curl test script
# Run AFTER filing in VWBridge-phaseA.st into VW
# Usage: powershell -File test_phaseA.ps1 -Token "<token from Transcript>"

param([string]$Token = "")

$Base = "http://127.0.0.1:9876"
$Auth = @{Authorization = "Bearer $Token"}

Write-Host "=== Phase A Endpoint Tests ===" -ForegroundColor Cyan
Write-Host ""

# ---- TEST 1: Health (no auth needed) ----
Write-Host "[1] GET /health (expect v0.6)" -ForegroundColor Yellow
$r = Invoke-RestMethod -Uri "$Base/health" -Method Get -ErrorAction SilentlyContinue
if ($r.version -eq "0.6") { Write-Host "  PASS: version=$($r.version)" -ForegroundColor Green }
else { Write-Host "  FAIL: $($r | ConvertTo-Json)" -ForegroundColor Red }

# ---- TEST 2: Auth rejection (no token) ----
Write-Host "[2] POST /click without token (expect 401)" -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "$Base/click" -Method Post -Body '{"aspect":"test"}' -ContentType "application/json" -ErrorAction Stop
    Write-Host "  FAIL: should have returned 401" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) { Write-Host "  PASS: 401 unauthorized" -ForegroundColor Green }
    else { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }
}

if (-not $Token) {
    Write-Host ""
    Write-Host "No token provided. Run with: -Token '<token>'" -ForegroundColor Yellow
    Write-Host "Get token from VW Transcript after bridge restart."
    exit
}
Write-Host ""

# ---- TEST 3: GET /windows (with auth) ----
Write-Host "[3] GET /windows (with auth)" -ForegroundColor Yellow
$r = Invoke-RestMethod -Uri "$Base/windows" -Method Get -Headers $Auth -ErrorAction SilentlyContinue
if ($r.Count -gt 0) { Write-Host "  PASS: $($r.Count) windows" -ForegroundColor Green }
else { Write-Host "  FAIL: no windows" -ForegroundColor Red }

# List windows
$r | ForEach-Object { Write-Host "    window: $($_.title) (app=$($_.appClass))" }

# ---- TEST 4: GET /value ----
Write-Host "[4] GET /value?aspect=importSummary&windowTitle=Workspace" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod -Uri "$Base/value?aspect=importSummary&windowTitle=Workspace" -Method Get -Headers $Auth -ErrorAction Stop
    Write-Host "  PASS: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }

# ---- TEST 5: POST /type (set InputFieldView value) ----
Write-Host "[5] POST /type set value in Workspace" -ForegroundColor Yellow
$body = '{"aspect":"importSummary","windowTitle":"Workspace","value":"Hello from Phase A!"}'
try {
    $r = Invoke-RestMethod -Uri "$Base/type" -Method Post -Headers $Auth -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "  PASS: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }

# ---- TEST 6: Verify the value was set ----
Write-Host "[6] GET /value verify type worked" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod -Uri "$Base/value?aspect=importSummary&windowTitle=Workspace" -Method Get -Headers $Auth -ErrorAction Stop
    if ($r.value -like "*Hello from Phase A*") { Write-Host "  PASS: value verified" -ForegroundColor Green }
    else { Write-Host "  WARN: value=$($r.value)" -ForegroundColor Yellow }
} catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }

# ---- TEST 7: POST /click (click Abort on GemStone Launcher) ----
Write-Host "[7] POST /click on Abort button" -ForegroundColor Yellow
$body = '{"aspect":"abortWidget","windowTitle":"GemStone Launcher"}'
try {
    $r = Invoke-RestMethod -Uri "$Base/click" -Method Post -Headers $Auth -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "  PASS: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 400) {
        $errBody = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
        Write-Host "  ACTION returned: $errBody" -ForegroundColor Yellow
    } else { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }
}

# ---- TEST 8: POST /screenshot ----
Write-Host "[8] POST /screenshot (expect base64 PNG)" -ForegroundColor Yellow
$body = '{"scope":"screen"}'
try {
    $r = Invoke-RestMethod -Uri "$Base/screenshot" -Method Post -Headers $Auth -Body $body -ContentType "application/json" -ErrorAction Stop
    if ($r.ok -eq $true -and $r.screenshot.Length -gt 100) {
        Write-Host "  PASS: base64 screenshot, $($r.screenshot.Length) chars" -ForegroundColor Green
    } else { Write-Host "  FAIL: $($r | ConvertTo-Json -Compress)" -ForegroundColor Red }
} catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }

# ---- TEST 9: PUT /value ----
Write-Host "[9] PUT /value set value" -ForegroundColor Yellow
$body = '{"value":"via PUT"}'
try {
    $r = Invoke-RestMethod -Uri "$Base/value?aspect=importSummary&windowTitle=Workspace" -Method Put -Headers $Auth -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "  PASS: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }

# ---- TEST 10: Bad token ----
Write-Host "[10] POST /click with bad token (expect 401)" -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "$Base/click" -Method Post -Body '{"aspect":"test"}' -ContentType "application/json" `
        -Headers @{Authorization = "Bearer bad-token"} -ErrorAction Stop
    Write-Host "  FAIL: should have returned 401" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) { Write-Host "  PASS: 401 on bad token" -ForegroundColor Green }
    else { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "=== Tests Complete ===" -ForegroundColor Cyan
