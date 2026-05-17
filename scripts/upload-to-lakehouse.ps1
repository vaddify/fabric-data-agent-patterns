#requires -Version 7
<#
.SYNOPSIS
  Uploads CSVs from data/synthetic to lh_mfg_mvp/Files/raw via OneLake DFS,
  then triggers Lakehouse table load API to create Delta tables.
#>
param(
  [string]$SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'data\synthetic')
)
$ErrorActionPreference = 'Stop'

$wsId = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$lhId = (Get-Content (Join-Path $PSScriptRoot '.lakehouse-id') -Raw).Trim()

# Two tokens: OneLake uses storage resource; Lakehouse load API uses Fabric resource.
$storageToken = az account get-access-token --resource https://storage.azure.com --query accessToken -o tsv
$fabricToken  = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv

$dfsBase = "https://onelake.dfs.fabric.microsoft.com/$wsId/$lhId/Files/raw"
$apiBase = "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses/$lhId"

# ------------------------------------------------------------
# 1. Upload each CSV via DFS (create -> append -> flush)
# ------------------------------------------------------------
$files = Get-ChildItem -Path $SourceDir -Filter *.csv | Sort-Object Name
Write-Host "Uploading $($files.Count) files to $dfsBase" -ForegroundColor Cyan

foreach ($f in $files) {
  $relName = $f.Name
  $url = "$dfsBase/$relName"
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  $len = $bytes.Length

  Write-Host "  -> $relName ($len bytes)"

  # Create empty file
  $createHeaders = @{
    Authorization      = "Bearer $storageToken"
    'x-ms-version'     = '2023-11-03'
    'Content-Length'   = '0'
  }
  Invoke-WebRequest -Method Put -Uri "$url`?resource=file" -Headers $createHeaders -ErrorAction Stop | Out-Null

  # Append data
  $appendHeaders = @{
    Authorization  = "Bearer $storageToken"
    'x-ms-version' = '2023-11-03'
    'Content-Type' = 'text/csv'
  }
  Invoke-WebRequest -Method Patch -Uri "$url`?action=append&position=0" -Headers $appendHeaders -Body $bytes -ContentType 'text/csv' -ErrorAction Stop | Out-Null

  # Flush
  $flushHeaders = @{
    Authorization    = "Bearer $storageToken"
    'x-ms-version'   = '2023-11-03'
    'Content-Length' = '0'
  }
  Invoke-WebRequest -Method Patch -Uri "$url`?action=flush&position=$len" -Headers $flushHeaders -ErrorAction Stop | Out-Null
}
Write-Host "Upload complete." -ForegroundColor Green

# ------------------------------------------------------------
# 2. Trigger Load to Table for each CSV  (CSV -> Delta)
# ------------------------------------------------------------
Write-Host "`nTriggering Load to Table on each CSV..." -ForegroundColor Cyan
$apiHeaders = @{
  Authorization  = "Bearer $fabricToken"
  'Content-Type' = 'application/json'
}

foreach ($f in $files) {
  $tableName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $body = @{
    relativePath  = "Files/raw/$($f.Name)"
    pathType      = 'File'
    mode          = 'overwrite'
    formatOptions = @{
      format    = 'Csv'
      header    = $true
      delimiter = ','
    }
  } | ConvertTo-Json -Depth 5

  $loadUri = "$apiBase/tables/$tableName/load"
  try {
    $resp = Invoke-WebRequest -Method Post -Uri $loadUri -Headers $apiHeaders -Body $body -ErrorAction Stop
    $opLoc = $resp.Headers['Location']
    if ($opLoc -is [array]) { $opLoc = $opLoc[0] }
    Write-Host "  -> $tableName : accepted ($($resp.StatusCode))"
    if ($opLoc) {
      # Poll up to 60 seconds
      $deadline = (Get-Date).AddSeconds(60)
      while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $st = Invoke-RestMethod -Uri $opLoc -Headers $apiHeaders
        if ($st.status -in @('Succeeded','Failed')) {
          Write-Host "     status: $($st.status)" -ForegroundColor ($(if($st.status -eq 'Succeeded'){'Green'}else{'Red'}))
          if ($st.status -eq 'Failed') { Write-Host ($st | ConvertTo-Json -Depth 5) -ForegroundColor Red }
          break
        }
      }
    }
  } catch {
    Write-Host "  -> $tableName : FAILED $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host "`nDone. Verify tables in Fabric portal: Workspace ws-coe-mvp / lh_mfg_mvp / Tables." -ForegroundColor Cyan
