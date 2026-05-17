<#
.SYNOPSIS
  Scores a Fabric Data Agent against the question set in examples/questions.md.

.DESCRIPTION
  Sends each question to the agent via the Fabric AI Skill / Data Agent REST endpoint,
  captures the response, and writes a markdown report with pass/fail per question.

  Pass criterion (Pattern 01, Step 10): >= 80% pass rate.

  This script uses Azure CLI auth to acquire a Fabric token. The signed-in identity
  (or service principal) must have at least Member role on the workspace.

.PARAMETER WorkspaceId
.PARAMETER AgentId
.PARAMETER QuestionsPath
.PARAMETER OutputPath
.PARAMETER PassThreshold
  Fraction (0..1) required to pass overall. Default 0.8.

.EXAMPLE
  pwsh ./score-agent.ps1 -WorkspaceId <guid> -AgentId <guid> `
        -QuestionsPath ../examples/questions.md `
        -OutputPath ../examples/agent-score-report.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $WorkspaceId,
    [Parameter(Mandatory)] [string] $AgentId,
    [string] $QuestionsPath  = "$PSScriptRoot/../examples/questions.md",
    [string] $OutputPath     = "$PSScriptRoot/../examples/agent-score-report.md",
    [double] $PassThreshold  = 0.8
)

$ErrorActionPreference = 'Stop'

function Get-FabricToken {
    # Power BI workload audience is what the Data Agent OpenAI gateway expects.
    # Using the Fabric ARM audience succeeds auth but returns an ungrounded passthrough.
    $tok = az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv 2>$null
    if (-not $tok) { throw "Could not acquire Power BI token. Run 'az login' first." }
    return $tok
}

function Read-Questions {
    param([string] $Path)
    # Parses examples/questions.md. Expected format per item:
    # ### Q<n>: <question text>
    # - expected_measure: <name>
    # - expected_dimension: <name>
    # - expected_keyword: <substring that must appear in answer>
    $raw = Get-Content -Raw -Path $Path
    $items = @()
    $blocks = [regex]::Split($raw, '(?m)^###\s+Q\d+:\s+') | Where-Object { $_ -match '\S' }
    foreach ($b in $blocks) {
        $lines = $b -split "`r?`n"
        $q = $lines[0].Trim()
        $expectedKeyword = ($lines | Where-Object { $_ -match '^\s*-\s*expected_keyword:' } |
            ForEach-Object { ($_ -split ':',2)[1].Trim() }) -join ''
        if (-not $expectedKeyword) { continue }
        $items += [pscustomobject]@{ Question = $q; ExpectedKeyword = $expectedKeyword }
    }
    return $items
}

function Get-AgentHeaders {
    param([string] $Token)
    return @{
        Authorization = "Bearer $Token"
        'Content-Type' = 'application/json'
        Accept = 'application/json'
        ActivityId = [guid]::NewGuid().ToString()
    }
}

function Invoke-Agent {
    param([string] $Token, [string] $WorkspaceId, [string] $AgentId, [string] $AssistantId, [string] $Question)
    $base = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/dataagents/$AgentId/aiassistant/openai"
    $apiVersion = '2024-05-01-preview'
    $h = Get-AgentHeaders -Token $Token
    try {
        $thread = Invoke-RestMethod -Method POST -Uri "$base/threads?api-version=$apiVersion" -Headers $h -Body '{}' -TimeoutSec 60
        $tid = $thread.id
        $msgBody = @{ role='user'; content=$Question } | ConvertTo-Json
        Invoke-RestMethod -Method POST -Uri "$base/threads/$tid/messages?api-version=$apiVersion" -Headers $h -Body $msgBody -TimeoutSec 60 | Out-Null
        $runBody = @{ assistant_id = $AssistantId } | ConvertTo-Json
        $run = Invoke-RestMethod -Method POST -Uri "$base/threads/$tid/runs?api-version=$apiVersion" -Headers $h -Body $runBody -TimeoutSec 60
        $rid = $run.id
        # GET /threads/{tid}/runs/{rid} is unreliable on this endpoint; poll messages instead.
        $deadline = (Get-Date).AddSeconds(240)
        $assistantMsg = $null
        do {
            Start-Sleep -Seconds 5
            $msgs = Invoke-RestMethod -Method GET -Uri "$base/threads/$tid/messages?api-version=$apiVersion" -Headers $h
            $assistantMsg = $msgs.data | Where-Object { $_.role -eq 'assistant' -and $_.run_id -eq $rid } | Select-Object -First 1
        } while (-not $assistantMsg -and (Get-Date) -lt $deadline)
        if (-not $assistantMsg) { return "ERROR: timed out waiting for assistant message on run $rid" }
        $text = ($assistantMsg.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text.value }) -join "`n"
        return $text
    } catch {
        $detail = $_.ErrorDetails.Message
        return "ERROR: $($_.Exception.Message) | $detail"
    }
}

function New-AgentAssistant {
    param([string] $Token, [string] $WorkspaceId, [string] $AgentId)
    $base = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/dataagents/$AgentId/aiassistant/openai"
    $h = Get-AgentHeaders -Token $Token
    $body = @{ model = 'not used' } | ConvertTo-Json
    $a = Invoke-RestMethod -Method POST -Uri "$base/assistants?api-version=2024-05-01-preview" -Headers $h -Body $body -TimeoutSec 60
    return $a.id
}

$token = Get-FabricToken
$questions = Read-Questions -Path $QuestionsPath
if ($questions.Count -eq 0) { throw "No questions parsed from $QuestionsPath. Check formatting." }

Write-Host "Creating assistant..." -ForegroundColor Cyan
$assistantId = New-AgentAssistant -Token $token -WorkspaceId $WorkspaceId -AgentId $AgentId
Write-Host "Assistant: $assistantId" -ForegroundColor Green

$results = @()
foreach ($q in $questions) {
    Write-Host "→ $($q.Question)" -ForegroundColor Cyan
    $answer = Invoke-Agent -Token $token -WorkspaceId $WorkspaceId -AgentId $AgentId -AssistantId $assistantId -Question $q.Question
    $kwMatch = $answer -match [regex]::Escape($q.ExpectedKeyword)
    # Reject ungrounded clarification-request answers even when the keyword matches.
    $ungrounded = $answer -match '(?i)do not have access|don''t have access|please (provide|clarify|share|specify|upload)|could you (please )?(clarify|provide)'
    $pass = $kwMatch -and -not $ungrounded
    $results += [pscustomobject]@{
        Question = $q.Question
        ExpectedKeyword = $q.ExpectedKeyword
        Pass = $pass
        Answer = $answer
    }
    Write-Host ("   {0}" -f ($(if ($pass) { 'PASS' } else { 'FAIL' }))) -ForegroundColor $(if ($pass) { 'Green' } else { 'Red' })
}

$passCount  = ($results | Where-Object Pass).Count
$total      = $results.Count
$rate       = [math]::Round($passCount / $total, 3)

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Agent score report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- Workspace: ``$WorkspaceId``")
[void]$sb.AppendLine("- Agent: ``$AgentId``")
[void]$sb.AppendLine("- Run at: $(Get-Date -Format o)")
[void]$sb.AppendLine("- Score: **$passCount / $total** ($([math]::Round($rate*100,1))%)")
[void]$sb.AppendLine("- Gate (>= $([math]::Round($PassThreshold*100,0))%): **$(if ($rate -ge $PassThreshold) { 'PASS' } else { 'FAIL' })**")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| # | Result | Question | Expected keyword |")
[void]$sb.AppendLine("|---|--------|----------|------------------|")
$i = 0
foreach ($r in $results) {
    $i++
    $mark = if ($r.Pass) { '✅' } else { '❌' }
    [void]$sb.AppendLine("| $i | $mark | $($r.Question) | ``$($r.ExpectedKeyword)`` |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Raw answers")
foreach ($r in $results) {
    [void]$sb.AppendLine("### $($r.Question)")
    [void]$sb.AppendLine('```json')
    [void]$sb.AppendLine($r.Answer)
    [void]$sb.AppendLine('```')
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath) | Out-Null
Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
Write-Host "Report: $OutputPath" -ForegroundColor Yellow

if ($rate -lt $PassThreshold) {
    Write-Error "Gate failed: $passCount/$total < $($PassThreshold*100)%"
    exit 1
}
Write-Host "Gate passed." -ForegroundColor Green
exit 0
