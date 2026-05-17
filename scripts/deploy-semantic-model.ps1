#requires -Version 7
<#
.SYNOPSIS
  Deploys the generated .pbip SemanticModel to the Fabric workspace via REST API.
.DESCRIPTION
  POST /v1/workspaces/{wsId}/semanticModels with definition.parts (TMDL files base64).
  Bypasses Power BI Desktop entirely.
#>
$ErrorActionPreference = 'Stop'

$wsId = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$repoRoot = Split-Path $PSScriptRoot -Parent
$smRoot = Join-Path $repoRoot 'patterns\01-fabric-data-agent-semantic-readiness\assets\model\mfg.SemanticModel'

$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{
  Authorization  = "Bearer $token"
  'Content-Type' = 'application/json'
}

# Build parts array from all files under definition/ plus definition.pbism
$parts = @()
$files = @(Get-ChildItem -Path $smRoot -Recurse -File | Where-Object { $_.Name -ne '.platform' })
foreach ($f in $files) {
  $relPath = $f.FullName.Substring($smRoot.Length + 1).Replace('\','/')
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  $b64 = [Convert]::ToBase64String($bytes)
  $parts += @{
    path        = $relPath
    payload     = $b64
    payloadType = 'InlineBase64'
  }
  Write-Host "  + $relPath ($($bytes.Length) bytes)"
}

# Idempotent: delete existing model with the same name
$displayName = 'sm_mfg_agentready'
$existing = (Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/semanticModels" -Headers $headers).value |
  Where-Object { $_.displayName -eq $displayName }
if ($existing) {
  Write-Host "`nDeleting existing semantic model $($existing.id)..." -ForegroundColor Yellow
  Invoke-RestMethod -Method Delete -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/semanticModels/$($existing.id)" -Headers $headers | Out-Null
  Start-Sleep -Seconds 2
}

$body = @{
  displayName = $displayName
  description = 'Agent-ready Manufacturing/CPG semantic model (anonymized).'
  definition  = @{ parts = $parts }
} | ConvertTo-Json -Depth 8

Write-Host "`nDeploying $($parts.Count) parts to workspace $wsId..." -ForegroundColor Cyan
try {
  $resp = Invoke-WebRequest -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/semanticModels" -Headers $headers -Body $body -ErrorAction Stop
  Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
  $opLoc = $resp.Headers['Location']
  if ($opLoc -is [array]) { $opLoc = $opLoc[0] }
  if ($opLoc) {
    Write-Host "Polling LRO: $opLoc"
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 5
      $st = Invoke-RestMethod -Uri $opLoc -Headers $headers
      Write-Host "  status: $($st.status)"
      if ($st.status -in @('Succeeded','Failed')) {
        if ($st.status -eq 'Failed') {
          Write-Host "Operation status object:" -ForegroundColor Red
          Write-Host ($st | ConvertTo-Json -Depth 10) -ForegroundColor Red
          throw "Deployment failed"
        }
        $result = Invoke-RestMethod -Uri "$opLoc/result" -Headers $headers
        $smId = $result.id
        Write-Host "`nSemantic model created: $smId" -ForegroundColor Green
        $smId | Out-File -FilePath (Join-Path $PSScriptRoot '.dataset-id') -Encoding ascii -NoNewline
        break
      }
    }
  } else {
    $smId = ($resp.Content | ConvertFrom-Json).id
    Write-Host "Created (sync): $smId" -ForegroundColor Green
    $smId | Out-File -FilePath (Join-Path $PSScriptRoot '.dataset-id') -Encoding ascii -NoNewline
  }
} catch {
  Write-Host "DEPLOY FAILED" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
  throw
}
