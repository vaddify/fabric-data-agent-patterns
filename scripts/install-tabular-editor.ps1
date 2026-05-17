#requires -Version 7
$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:LOCALAPPDATA 'TabularEditor2'
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

$rel = Invoke-RestMethod 'https://api.github.com/repos/TabularEditor/TabularEditor/releases/latest' -Headers @{ 'User-Agent'='vaddify' }
Write-Host "Latest TE2: $($rel.tag_name)"
$asset = $rel.assets | Where-Object { $_.name -like '*Portable*.zip' } | Select-Object -First 1
if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1 }
if (-not $asset) { throw "No suitable asset in $($rel.tag_name)" }

$zip = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
Write-Host "Extracting to $installRoot ..."
Expand-Archive -Path $zip -DestinationPath $installRoot -Force
Remove-Item $zip -Force

$exe = Get-ChildItem $installRoot -Recurse -Filter 'TabularEditor.exe' | Select-Object -First 1
if (-not $exe) { throw "TabularEditor.exe not found after extract" }
Write-Host "TabularEditor.exe: $($exe.FullName)" -ForegroundColor Green
$exe.FullName | Set-Content -Path (Join-Path $PSScriptRoot '.te2-path') -Encoding ascii -NoNewline
