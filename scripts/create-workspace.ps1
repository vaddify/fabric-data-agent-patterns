#requires -Version 7
param(
  [string]$DisplayName = 'ws-coe-mvp',
  [string]$CapacityId  = 'ed1f752d-7c59-4389-bae7-a405a080cf6d',
  [string]$Description = 'Fabric CoE MVP workspace - Pattern 01 Data Agent semantic readiness. Anonymized labels only.'
)

$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{
  Authorization  = "Bearer $token"
  'Content-Type' = 'application/json'
}

# Idempotent: check if it exists
$existing = (Invoke-RestMethod -Uri 'https://api.fabric.microsoft.com/v1/workspaces' -Headers $headers).value |
  Where-Object { $_.displayName -eq $DisplayName }

if ($existing) {
  Write-Host "Workspace '$DisplayName' already exists: $($existing.id)" -ForegroundColor Yellow
  $wsId = $existing.id
} else {
  $body = @{
    displayName = $DisplayName
    description = $Description
    capacityId  = $CapacityId
  } | ConvertTo-Json
  $created = Invoke-RestMethod -Method Post -Uri 'https://api.fabric.microsoft.com/v1/workspaces' -Headers $headers -Body $body
  Write-Host "Created workspace '$DisplayName': $($created.id)" -ForegroundColor Green
  $wsId = $created.id
}

# Persist for next scripts
$wsId | Out-File -FilePath (Join-Path $PSScriptRoot '.workspace-id') -Encoding ascii -NoNewline
Write-Host "Workspace ID written to scripts/.workspace-id" -ForegroundColor Cyan
