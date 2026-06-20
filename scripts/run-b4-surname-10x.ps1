# scripts/run-b4-surname-10x.ps1
#
# Phase B4 quality gate: 10x sequential real-usage verification of the v0.9.0 /wait endpoint
# per ROADMAP-QUALITY-FIRST.md ("zero flakes across 10 consecutive sequential runs of the
# real-usage flow").
#
# Doubles as end-to-end verification of Bug #2 v0.8.12 fix for #surname broad search
# (session-7 only verified #contractNumber).
#
# Per-iteration workflow:
#   0. Cleanup non-baseline ScheduledControllers (close Portfolio / Party views from prior iter)
#   1. Set PartySearchView state via /eval: searchCriteriaType=#surname, exactMatch=false, term=<param>
#   2. POST /click {aspect:findID} -> triggers partialFind: -> opens 'Continue?' modal (5-8s for #surname)
#   3. POST /wait {kind:dialog-appears, match:{messageContains:'Continue'}, timeoutMs:15000} -> 200
#   4. POST /dialogs/respond {choice:'Yes'} -> dismisses modal, action handler runs to completion
#   5. POST /wait {kind:dialog-closes, match:{messageContains:'Continue'}, timeoutMs:5000} -> 200
#   6. Verify via /eval that partialMatchResultsChoices size >= ExpectedMinResults
#      (this is the Bug #2 v0.8.12 fix verification for #surname)
#
# Pass: 10/10 iterations succeed -> exit 0
# Fail: any iteration fails -> diagnostic dump + exit 1
#
# Usage:
#   pwsh -File .\scripts\run-b4-surname-10x.ps1
#   pwsh -File .\scripts\run-b4-surname-10x.ps1 -Iterations 3 -SurnameTerm 'M'
#
# Prerequisites:
#   - VWBridge v0.9.0+ running at http://127.0.0.1:9876
#   - src/vw-bridge/.token contains current token
#   - PartySearchView open in MAS (label = 'Party Search')
#   - PartyManager populated with at least ExpectedMinResults parties whose surnames contain SurnameTerm

param(
    [int]$Iterations = 10,
    [string]$SurnameTerm = 'A',
    [int]$ExpectedMinResults = 1,
    [string]$BridgeUrl = 'http://127.0.0.1:9876'
)

$ErrorActionPreference = 'Stop'
$tokenPath = Join-Path $PSScriptRoot '..\src\vw-bridge\.token'
if (-not (Test-Path -LiteralPath $tokenPath)) {
    Write-Host "ERROR: token file not found at $tokenPath" -ForegroundColor Red
    exit 2
}
$Token = (Get-Content -LiteralPath $tokenPath -Raw).Trim()
$AuthHeader = "Authorization: Bearer $Token"

function Invoke-Bridge {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [string]$Body,
        [string]$ContentType = 'application/json',
        [int]$MaxTimeSec = 60
    )
    $url = "$BridgeUrl$Path"
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        $curlArgs = @('-s', '-m', "$MaxTimeSec", '-X', $Method, $url, '-H', $AuthHeader)
        if ($PSBoundParameters.ContainsKey('Body') -and $Body) {
            [System.IO.File]::WriteAllText($tmpFile, $Body, [System.Text.UTF8Encoding]::new($false))
            $curlArgs += '-H'
            $curlArgs += "Content-Type: $ContentType"
            $curlArgs += '--data-binary'
            $curlArgs += "@$tmpFile"
        }
        $raw = & curl.exe @curlArgs
        if (-not $raw) { return @{ ok = $false; error = 'empty-response-or-curl-timeout' } }
        try {
            return $raw | ConvertFrom-Json
        } catch {
            return @{ ok = $false; error = 'bad-json'; raw = $raw }
        }
    } finally {
        if (Test-Path -LiteralPath $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue }
    }
}

function Close-NonBaselineWindows {
    # Closes any ScheduledController whose view label is NOT in the baseline set,
    # AND whose model is NOT a SimpleDialog (dialogs are diagnostic, not cleanup targets).
    # Baseline = labels that should always survive iteration.
    # NOTE: Smalltalk `a or: [b] or: [c]` would parse as #or:or: (binary keyword chain
    # is not supported); explicit parens chain the unary or:.
    $eval = @'
| baseline closed sdCls |
closed := 0.
sdCls := Smalltalk at: #SimpleDialog ifAbsent: [nil].
baseline := #('Party Search' 'Workspace' 'GemStone Launcher' 'MAS Loaded Items').
ScheduledControllers scheduledControllers asArray do: [:c |
    | label keep isDlg |
    label := [c view label asString] on: Error do: [:e | nil].
    label notNil ifTrue: [
        keep := ((baseline includes: label)
            or: [(label indexOfSubCollection: 'MOMENTUM WEALTH' startingAt: 1) > 0])
            or: [(label indexOfSubCollection: 'storedev64' startingAt: 1) > 0].
        isDlg := sdCls notNil and: [c model isKindOf: sdCls].
        (keep not and: [isDlg not]) ifTrue: [
            [c closeAndUnschedule. closed := closed + 1] on: Error do: [:e | nil]]]].
'closed=' , closed printString
'@
    return Invoke-Bridge -Method POST -Path '/eval' -Body $eval -ContentType 'text/plain'
}

function Setup-SearchState {
    param([string]$Term)
    # NOTE: Term gets interpolated into Smalltalk string literal. Single quotes in term break it.
    # For test discipline, sanitize: reject any term containing a quote.
    if ($Term -match "'") { throw "Term '$Term' contains a single quote - rejected for /eval safety" }
    $eval = @"
| ctrl model |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
ctrl ifNil: [^'ERR: PartySearch not open'].
model := ctrl model.
(model instVarNamed: 'searchCriteriaType') value: #surname.
(model instVarNamed: 'searchCriteriaString') value: '$Term'.
(model instVarNamed: 'exactMatch') value: false.
"@ + @'

'state set: #surname term=' , (model instVarNamed: 'searchCriteriaString') value
'@
    return Invoke-Bridge -Method POST -Path '/eval' -Body $eval -ContentType 'text/plain'
}

function Get-ResultsCount {
    $eval = @'
| ctrl model pmrc |
ctrl := ScheduledControllers scheduledControllers detect: [:c |
    [c view label asString = 'Party Search'] on: Error do: [:e | false]] ifNone: [nil].
ctrl ifNil: [^'-1'].
model := ctrl model.
pmrc := (model instVarNamed: 'partialMatchResultsChoices') value.
pmrc isNil ifTrue: ['-2'] ifFalse: [pmrc size printString]
'@
    $r = Invoke-Bridge -Method POST -Path '/eval' -Body $eval -ContentType 'text/plain'
    if (-not $r.ok) { return -99 }
    # /eval result is the printString of the last expr, which for a String is wrapped in single quotes
    $s = "$($r.result)".Trim("'")
    try { return [int]$s } catch { return -98 }
}

function Snapshot-State {
    # For failure diagnostics: capture /windows + /dialogs + log tail
    $win = Invoke-Bridge -Method GET -Path '/windows'
    $dlg = Invoke-Bridge -Method GET -Path '/dialogs'
    return @{
        windows = $win
        dialogs = $dlg
    }
}

function Run-Iteration {
    param([int]$N)
    $iterStart = Get-Date
    # Use a hashtable internally, cast to PSCustomObject before return
    # (Measure-Object requires real properties, not OrderedDictionary keys)
    $r = @{
        iteration = $N
        success = $false
        elapsedMs = 0
        steps = [System.Collections.ArrayList]@()
        error = $null
        snapshot = $null
    }
    $clickJob = $null

    try {
        # 0. Cleanup: close any Portfolio / Party views from prior iteration
        $cleanup = Close-NonBaselineWindows
        [void]$r.steps.Add([ordered]@{ step = 'cleanup'; ok = $cleanup.ok; result = "$($cleanup.result)" })
        if (-not $cleanup.ok) { throw "cleanup failed: $($cleanup | ConvertTo-Json -Compress -Depth 4)" }

        # 1. Setup search state via /eval (#surname, term, exactMatch=false)
        $setup = Setup-SearchState -Term $SurnameTerm
        [void]$r.steps.Add([ordered]@{ step = 'setup'; ok = $setup.ok; result = "$($setup.result)" })
        if (-not $setup.ok) { throw "setup failed: $($setup | ConvertTo-Json -Compress -Depth 4)" }

        # 2. Start /click findID in BACKGROUND.
        #    The bridge's handleClickBody -> onUIDo -> doClick -> model value: true
        #    runs the PluggableAdaptor setter which invokes partialFind:, which calls
        #    Dialog confirm:, which BLOCKS the UI process in the modal's event loop
        #    until the modal is dismissed AND the action handler (ContractManager /
        #    PartyManager query + result population) completes. So /click HTTP does
        #    not return until the entire workflow finishes.
        $clickJob = Start-Job -ArgumentList $Token, $BridgeUrl -ScriptBlock {
            param($tok, $url)
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                $body = '{"aspect":"findID","windowTitle":"Party Search"}'
                [System.IO.File]::WriteAllText($tmpFile, $body, [System.Text.UTF8Encoding]::new($false))
                & curl.exe -s -m 60 -X POST "$url/click" `
                    -H "Authorization: Bearer $tok" `
                    -H 'Content-Type: application/json' `
                    --data-binary "@$tmpFile"
            } finally {
                if (Test-Path -LiteralPath $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue }
            }
        }

        # 3. /wait dialog-appears Continue (15s - #surname takes 5-8s per session-3)
        # Note: dialog kinds use top-level `messageContains` (not nested in `match`); see VWBridge.st L1953
        $waitDlgBody = '{"kind":"dialog-appears","messageContains":"Continue","timeoutMs":15000,"intervalMs":250}'
        $waitDlg = Invoke-Bridge -Method POST -Path '/wait' -Body $waitDlgBody
        [void]$r.steps.Add([ordered]@{ step = 'wait_dialog_appears'; ok = $waitDlg.ok; polls = $waitDlg.polls; elapsedMs = $waitDlg.elapsedMs })
        if (-not $waitDlg.ok) { throw "wait dialog-appears failed: $($waitDlg | ConvertTo-Json -Compress -Depth 4)" }

        # 4. /dialogs/respond Yes -- dismisses modal AND unblocks the /click background job
        $respondBody = '{"choice":"Yes"}'
        $respond = Invoke-Bridge -Method POST -Path '/dialogs/respond' -Body $respondBody
        [void]$r.steps.Add([ordered]@{ step = 'respond_yes'; ok = $respond.ok; recordedAccept = $respond.recordedAccept; purgedWedged = $respond.purgedWedged })
        if (-not $respond.ok) { throw "respond failed: $($respond | ConvertTo-Json -Compress -Depth 4)" }

        # 5. /wait dialog-closes Continue (5s -- should be alreadySatisfied:true after step 4)
        # Note: dialog kinds use top-level `messageContains` (not nested); see VWBridge.st L1953
        $waitCloseBody = '{"kind":"dialog-closes","messageContains":"Continue","timeoutMs":5000,"intervalMs":100}'
        $waitClose = Invoke-Bridge -Method POST -Path '/wait' -Body $waitCloseBody
        [void]$r.steps.Add([ordered]@{ step = 'wait_dialog_closes'; ok = $waitClose.ok; polls = $waitClose.polls; elapsedMs = $waitClose.elapsedMs; alreadySatisfied = $waitClose.alreadySatisfied })
        if (-not $waitClose.ok) { throw "wait dialog-closes failed: $($waitClose | ConvertTo-Json -Compress -Depth 4)" }

        # 6. Wait for /click background job to complete (action handler should be done by now)
        $jobDone = Wait-Job -Job $clickJob -Timeout 30
        if (-not $jobDone -or $clickJob.State -ne 'Completed') {
            throw "click job did not complete in 30s (state=$($clickJob.State))"
        }
        $clickRaw = Receive-Job -Job $clickJob
        $clickResp = $null
        try { $clickResp = $clickRaw | ConvertFrom-Json } catch {}
        [void]$r.steps.Add([ordered]@{ step = 'click_findID_response'; ok = $clickResp.ok; method = $clickResp.method; raw_snippet = ("$clickRaw" -replace '[\r\n]', ' ').Substring(0, [Math]::Min(120, ("$clickRaw").Length)) })
        if (-not $clickResp.ok) { throw "click response not ok: $clickRaw" }

        # 7. Verify Bug #2 v0.8.12 fix worked for #surname: partialMatchResultsChoices populated
        Start-Sleep -Milliseconds 200
        $count = Get-ResultsCount
        [void]$r.steps.Add([ordered]@{ step = 'verify_results'; count = $count; expected_min = $ExpectedMinResults })
        if ($count -lt $ExpectedMinResults) {
            throw "Bug #2 fix verification FAILED: partialMatchResultsChoices size=$count, expected >= $ExpectedMinResults"
        }

        $r.success = $true
    } catch {
        $r.error = $_.Exception.Message
        # On failure, snapshot state for diagnosis
        try { $r.snapshot = Snapshot-State } catch { $r.snapshot = @{ snapshot_error = $_.Exception.Message } }
    } finally {
        # Always clean up the background job (even if still running, force-remove)
        if ($clickJob) {
            try {
                if ($clickJob.State -eq 'Running') { Stop-Job -Job $clickJob -ErrorAction SilentlyContinue }
                Remove-Job -Job $clickJob -Force -ErrorAction SilentlyContinue
            } catch {}
        }
        $r.elapsedMs = [int]((Get-Date) - $iterStart).TotalMilliseconds
    }
    return [PSCustomObject]$r
}

# ===== Main =====
$runStart = Get-Date
Write-Host ""
Write-Host "===== Phase B4 + Bug #2 #surname Real-Usage 10x =====" -ForegroundColor Cyan
Write-Host "Iterations: $Iterations | Surname term: '$SurnameTerm' | Bridge: $BridgeUrl"
Write-Host "Token (last 8): ...$($Token.Substring([Math]::Max(0, $Token.Length - 8)))"
Write-Host ""

# Sanity: /health
# Note: /health envelope is {"status":"ok","version":"0.9.0"} - no `ok` field on this endpoint
$h = Invoke-Bridge -Method GET -Path '/health'
Write-Host "Bridge health: $($h | ConvertTo-Json -Compress)"
if ($h.status -ne 'ok') {
    Write-Host "ERROR: bridge unhealthy (status='$($h.status)')" -ForegroundColor Red
    exit 2
}

$results = @()
for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host -NoNewline "[$i/$Iterations] "
    $r = Run-Iteration -N $i
    $results += $r
    if ($r.success) {
        Write-Host ("PASS  ({0,5}ms)" -f $r.elapsedMs) -ForegroundColor Green
    } else {
        Write-Host ("FAIL  ({0,5}ms)  err={1}" -f $r.elapsedMs, $r.error) -ForegroundColor Red
    }
}

$totalMs = [int]((Get-Date) - $runStart).TotalMilliseconds
# Force array wrap so .Count works for 1-element results (PS array coercion quirk)
$passes = @($results | Where-Object { $_.success }).Count
$fails = $Iterations - $passes
$avgMs = if ($results.Count -gt 0) { [int](($results | Measure-Object -Property elapsedMs -Average).Average) } else { 0 }

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor Cyan
Write-Host ("Passes:  {0,3} / {1}" -f $passes, $Iterations)
Write-Host ("Fails:   {0,3}" -f $fails)
Write-Host ("AvgMs:   {0,5}" -f $avgMs)
Write-Host ("TotalMs: {0}" -f $totalMs)

Write-Host ""
Write-Host "===== /wait timing breakdown (PASS iterations) =====" -ForegroundColor Cyan
Write-Host "iter | dialog-appears polls/ms | dialog-closes polls/ms | results"
Write-Host "-----+-------------------------+------------------------+--------"
foreach ($r in $results) {
    if ($r.success) {
        $dlgIn  = $r.steps | Where-Object { $_.step -eq 'wait_dialog_appears' } | Select-Object -First 1
        $dlgOut = $r.steps | Where-Object { $_.step -eq 'wait_dialog_closes'  } | Select-Object -First 1
        $vr     = $r.steps | Where-Object { $_.step -eq 'verify_results' }       | Select-Object -First 1
        Write-Host ("{0,4} | {1,5}/{2,5}            | {3,5}/{4,5}            | {5}" -f `
            $r.iteration, $dlgIn.polls, $dlgIn.elapsedMs, $dlgOut.polls, $dlgOut.elapsedMs, $vr.count)
    }
}

if ($fails -gt 0) {
    Write-Host ""
    Write-Host "===== FAILURES (detailed) =====" -ForegroundColor Red
    foreach ($r in $results) {
        if (-not $r.success) {
            Write-Host ""
            Write-Host "Iter $($r.iteration) ($($r.elapsedMs)ms): $($r.error)" -ForegroundColor Red
            Write-Host "Steps:" ($r.steps | ConvertTo-Json -Depth 5 -Compress)
            Write-Host "Snapshot:" ($r.snapshot | ConvertTo-Json -Depth 6 -Compress)
        }
    }
    exit 1
}

Write-Host ""
Write-Host "===== B4 PASS: $passes/$Iterations zero flakes =====" -ForegroundColor Green
exit 0
