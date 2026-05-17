#requires -Version 7
<#
.SYNOPSIS
  Triggers a DirectLake "framing" refresh of the deployed semantic model and verifies bindings work.
#>
$ErrorActionPreference = 'Stop'

$wsId = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$smId = (Get-Content (Join-Path $PSScriptRoot '.dataset-id') -Raw).Trim()

$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; 'Content-Type'='application/json' }

# Use Power BI refresh REST (works for semantic models created via Fabric API too)
$pbiToken = az account get-access-token --resource https://analysis.windows.net/powerbi/api --query accessToken -o tsv
$ph = @{ Authorization="Bearer $pbiToken"; 'Content-Type'='application/json' }

Write-Host "Triggering refresh on semantic model $smId..." -ForegroundColor Cyan
$body = @{ type='Full'; commitMode='transactional'; objects=@() } | ConvertTo-Json

try {
  $resp = Invoke-WebRequest -Method Post `
    -Uri "https://api.powerbi.com/v1.0/myorg/groups/$wsId/datasets/$smId/refreshes" `
    -Headers $ph -Body $body
  Write-Host "Refresh requested. Status: $($resp.StatusCode)" -ForegroundColor Green
} catch {
  Write-Host "Refresh trigger response: $($_.Exception.Message)" -ForegroundColor Yellow
  if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message }
}

Write-Host "`nPolling refresh history..." -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 8
  try {
    $hist = Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/groups/$wsId/datasets/$smId/refreshes?`$top=1" -Headers $ph
    $latest = $hist.value[0]
    if (-not $latest) { Write-Host "  no refresh history yet"; continue }
    Write-Host "  status: $($latest.status)  type: $($latest.refreshType)  start: $($latest.startTime)"
    if ($latest.status -in @('Completed','Failed','Disabled')) {
      if ($latest.status -ne 'Completed') {
        Write-Host "Refresh ended with status $($latest.status)" -ForegroundColor Yellow
        if ($latest.serviceExceptionJson) { Write-Host $latest.serviceExceptionJson -ForegroundColor Red }
      } else {
        Write-Host "Refresh Completed." -ForegroundColor Green
      }
      break
    }
  } catch {
    Write-Host "  history poll: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

# Quick DAX sanity check via Execute Queries
Write-Host "`nRunning sanity DAX: EVALUATE ROW(`"NSV`",[NSV])..." -ForegroundColor Cyan
$dax = @{
  queries = @(@{ query = 'EVALUATE ROW("NSV",[NSV],"Cases",[Volume Cases],"OTIF",[OTIF %])' })
  serializerSettings = @{ includeNulls = $true }
} | ConvertTo-Json -Depth 5

try {
  $r = Invoke-RestMethod -Method Post `
    -Uri "https://api.powerbi.com/v1.0/myorg/groups/$wsId/datasets/$smId/executeQueries" `
    -Headers $ph -Body $dax
  Write-Host "DAX result:" -ForegroundColor Green
  $r.results[0].tables[0].rows | Format-Table -AutoSize
} catch {
  Write-Host "DAX failed: $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
}
