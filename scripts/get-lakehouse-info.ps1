#requires -Version 7
$wsId = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$lhId = (Get-Content (Join-Path $PSScriptRoot '.lakehouse-id') -Raw).Trim()
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token" }

$detail = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses/$lhId" -Headers $headers
Write-Host "Lakehouse:" -ForegroundColor Cyan
$detail | ConvertTo-Json -Depth 8

# Also list tables
Write-Host "`nTables:" -ForegroundColor Cyan
$tables = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses/$lhId/tables" -Headers $headers
$tables.data | Select-Object name, type, format | Format-Table -AutoSize
