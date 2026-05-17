<#
.SYNOPSIS
  Runs Best Practice Analyzer against a .pbip semantic model using Tabular Editor CLI.

.DESCRIPTION
  Gate for Pattern 01, Step 7. Exits non-zero if any severity >= 2 rule fails.

.PARAMETER PbipPath
  Path to the folder containing the .pbip / Model.tmdl.

.PARAMETER TabularEditorExe
  Path to TabularEditor.exe (TE2 free). Defaults to standard install location.

.PARAMETER RulesPath
  Path to bpa-rules.json. Defaults to sibling file.

.EXAMPLE
  pwsh ./validate-semantic-model.ps1 -PbipPath ./model
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $PbipPath,
    [string] $TabularEditorExe = "$env:ProgramFiles\Tabular Editor\TabularEditor.exe",
    [string] $RulesPath = "$PSScriptRoot/bpa-rules.json",
    [int]    $FailSeverity = 2
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $TabularEditorExe)) {
    throw "Tabular Editor not found at '$TabularEditorExe'. Install from https://tabulareditor.com or pass -TabularEditorExe."
}
if (-not (Test-Path $RulesPath))  { throw "BPA rules not found at '$RulesPath'." }
if (-not (Test-Path $PbipPath))   { throw "PBIP path not found at '$PbipPath'." }

$modelBim = Get-ChildItem -Path $PbipPath -Recurse -Include 'model.bim','database.json' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $modelBim) { throw "No model.bim or database.json found under '$PbipPath'. Open the .pbip in Power BI Desktop once to materialize it." }

Write-Host "Running BPA on $($modelBim.FullName)" -ForegroundColor Cyan

$reportPath = Join-Path $PSScriptRoot '..\examples\bpa-report.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $reportPath) | Out-Null

$args = @(
    "`"$($modelBim.FullName)`"",
    "-A", "`"$RulesPath`"",
    "-V"
)

$proc = Start-Process -FilePath $TabularEditorExe -ArgumentList $args -NoNewWindow -PassThru -Wait -RedirectStandardOutput $reportPath
$exit = $proc.ExitCode

Write-Host "---- BPA report ($reportPath) ----" -ForegroundColor Yellow
Get-Content $reportPath | Write-Host

if ($exit -ne 0) {
    Write-Error "BPA failed with exit code $exit. Review $reportPath."
    exit $exit
}

Write-Host "BPA passed." -ForegroundColor Green
exit 0
