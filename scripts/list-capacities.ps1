#requires -Version 7
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-RestMethod -Uri 'https://api.fabric.microsoft.com/v1/capacities' -Headers $headers
$resp.value | Select-Object id, displayName, sku, region, state | Format-Table -AutoSize
