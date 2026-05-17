#requires -Version 7
<#
.SYNOPSIS
  Runs BPA against the local TMDL model via Tabular Editor 2.
#>
$ErrorActionPreference = 'Stop'

$te = (Get-Content (Join-Path $PSScriptRoot '.te2-path') -Raw).Trim()
$repoRoot = Split-Path $PSScriptRoot -Parent
$tmdlDir = Join-Path $repoRoot 'patterns\01-fabric-data-agent-semantic-readiness\assets\model\mfg.SemanticModel\definition'
$rules   = Join-Path $repoRoot 'patterns\01-fabric-data-agent-semantic-readiness\assets\bpa-rules.json'
$report  = Join-Path $repoRoot 'patterns\01-fabric-data-agent-semantic-readiness\examples\bpa-report.txt'

New-Item -ItemType Directory -Force -Path (Split-Path $report) | Out-Null

Write-Host "TE2: $te"
Write-Host "TMDL: $tmdlDir"
Write-Host "Rules: $rules"
Write-Host ""

# TE2 accepts a TMDL folder as input. -A applies analyzer rules from JSON. -V verbose.
& $te $tmdlDir -A $rules -V *>&1 | Tee-Object -FilePath $report
$exit = $LASTEXITCODE
Write-Host ""
Write-Host "TE2 exit code: $exit" -ForegroundColor $(if ($exit -eq 0) { 'Green' } else { 'Yellow' })
exit $exit
