#requires -Version 7
param(
  [string]$DisplayName = 'lh_mfg_mvp',
  [string]$Description = 'Manufacturing/CPG MVP lakehouse - synthetic anonymized data only.'
)

$wsIdPath = Join-Path $PSScriptRoot '.workspace-id'
if (-not (Test-Path $wsIdPath)) { throw "Missing $wsIdPath. Run create-workspace.ps1 first." }
$wsId = (Get-Content $wsIdPath -Raw).Trim()

$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{
  Authorization  = "Bearer $token"
  'Content-Type' = 'application/json'
}

$listUri = "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses"
$existing = (Invoke-RestMethod -Uri $listUri -Headers $headers).value |
  Where-Object { $_.displayName -eq $DisplayName }

if ($existing) {
  Write-Host "Lakehouse '$DisplayName' already exists: $($existing.id)" -ForegroundColor Yellow
  $lhId = $existing.id
} else {
  $body = @{
    displayName = $DisplayName
    description = $Description
  } | ConvertTo-Json
  $created = Invoke-RestMethod -Method Post -Uri $listUri -Headers $headers -Body $body
  Write-Host "Created lakehouse '$DisplayName': $($created.id)" -ForegroundColor Green
  $lhId = $created.id
}

$lhId | Out-File -FilePath (Join-Path $PSScriptRoot '.lakehouse-id') -Encoding ascii -NoNewline

# Fetch SQL endpoint + OneLake paths
$detail = Invoke-RestMethod -Uri "$listUri/$lhId" -Headers $headers
Write-Host "`nLakehouse details:" -ForegroundColor Cyan
$detail | ConvertTo-Json -Depth 6
