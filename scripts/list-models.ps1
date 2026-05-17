#requires -Version 7
$ErrorActionPreference = 'Stop'
$ws = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$t = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$r = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels" -Headers @{ Authorization = "Bearer $t" }
$r.value | Select-Object displayName, id, description | Format-Table -AutoSize
Write-Host ""
Write-Host "Workspace: $ws"
