#requires -Version 7
$ErrorActionPreference = 'Stop'
$t = az account get-access-token --resource https://analysis.windows.net/powerbi/api --query accessToken -o tsv
$caps = Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/capacities" -Headers @{ Authorization = "Bearer $t" }
$caps.value | Format-Table displayName, id, sku, state, region
$f64 = $caps.value | Where-Object { $_.displayName -eq $env:FABRIC_CAPACITY_NAME } | Select-Object -First 1
if ($f64) {
    Write-Host ""
    Write-Host "Found F64 capacity GUID: $($f64.id)" -ForegroundColor Green
    $f64.id | Set-Content -NoNewline (Join-Path $PSScriptRoot '.capacity-id')
}
