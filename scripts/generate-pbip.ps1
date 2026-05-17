#requires -Version 7
<#
.SYNOPSIS
  Generates a complete .pbip (PBIP) directory for the Manufacturing/CPG model.
.DESCRIPTION
  Emits TMDL files bound to the lh_mfg_mvp lakehouse SQL endpoint via DirectLake.
  Pre-loads: tables, relationships, descriptions, synonyms, and the 16 CPG measures.
  Output: patterns/01-fabric-data-agent-semantic-readiness/assets/model/mfg/
#>
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# Fetch lakehouse SQL endpoint info
# ------------------------------------------------------------
$wsId = (Get-Content (Join-Path $PSScriptRoot '.workspace-id') -Raw).Trim()
$lhId = (Get-Content (Join-Path $PSScriptRoot '.lakehouse-id') -Raw).Trim()
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token" }
$detail = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses/$lhId" -Headers $headers
$sqlServer = $detail.properties.sqlEndpointProperties.connectionString
$sqlDb = $detail.displayName
if (-not $sqlServer) { throw "SQL endpoint not ready yet." }
Write-Host "SQL endpoint: $sqlServer / $sqlDb" -ForegroundColor Cyan

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
$repoRoot = Split-Path $PSScriptRoot -Parent
$modelRoot = Join-Path $repoRoot 'patterns\01-fabric-data-agent-semantic-readiness\assets\model'
$pbipName = 'mfg'
$smDir = Join-Path $modelRoot "$pbipName.SemanticModel"
$smDefDir = Join-Path $smDir 'definition'
$smTablesDir = Join-Path $smDefDir 'tables'
$smCulturesDir = Join-Path $smDefDir 'cultures'
$rptDir = Join-Path $modelRoot "$pbipName.Report"
$rptDefDir = Join-Path $rptDir 'definition'

if (Test-Path $modelRoot) { Remove-Item $modelRoot -Recurse -Force }
$null = New-Item -ItemType Directory -Path $smTablesDir, $smCulturesDir, $rptDefDir -Force

function New-Guid7 { [guid]::NewGuid().ToString() }

# ------------------------------------------------------------
# .pbip pointer
# ------------------------------------------------------------
@{
  version   = '1.0'
  artifacts = @(@{ report = @{ path = "$pbipName.Report" } })
  settings  = @{ enableAutoRecovery = $true }
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $modelRoot "$pbipName.pbip") -Encoding utf8

# ------------------------------------------------------------
# SemanticModel/.platform + definition.pbism
# ------------------------------------------------------------
@{
  '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json'
  metadata  = @{
    type        = 'SemanticModel'
    displayName = 'sm_mfg_agentready'
    description = 'Agent-ready Manufacturing/CPG semantic model (anonymized).'
  }
  config = @{ version = '2.0'; logicalId = (New-Guid7) }
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $smDir '.platform') -Encoding utf8

@{ version = '4.0'; settings = @{} } | ConvertTo-Json -Depth 3 |
  Set-Content -Path (Join-Path $smDir 'definition.pbism') -Encoding utf8

# ------------------------------------------------------------
# definition/database.tmdl
# ------------------------------------------------------------
@"
database
	compatibilityLevel: 1604
"@ | Set-Content -Path (Join-Path $smDefDir 'database.tmdl') -Encoding utf8

# ------------------------------------------------------------
# definition/expressions.tmdl — DirectLake source
# ------------------------------------------------------------
@"
expression DatabaseQuery =
		let
			database = Sql.Database("$sqlServer", "$sqlDb")
		in
			database
	lineageTag: $(New-Guid7)
	kind: m

	annotation PBI_NavigationStepName = Navigation
	annotation PBI_ResultType = Exposed
"@ | Set-Content -Path (Join-Path $smDefDir 'expressions.tmdl') -Encoding utf8

# ------------------------------------------------------------
# Helper to build a table TMDL
# ------------------------------------------------------------
function New-TableTmdl {
  param(
    [string]$Name,
    [string]$Description,
    [array]$Columns,           # @( @{ name; dataType; hidden; description; synonyms } )
    [string]$DateTable = $null # if 'true', mark date table on column
  )
  $tlt = New-Guid7
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("/// $Description")
  [void]$sb.AppendLine("table $Name")
  [void]$sb.AppendLine("`tlineageTag: $tlt")
  if ($DateTable) {
    [void]$sb.AppendLine("`tdataCategory: Time")
  }
  [void]$sb.AppendLine("")
  foreach ($c in $Columns) {
    $hidden = if ($c.hidden) { "`t`tisHidden`r`n" } else { "" }
    $isKey  = if ($c.isKey)  { "`t`tisKey`r`n" }  else { "" }
    $fmt    = if ($c.format) { "`t`tformatString: $($c.format)`r`n" } else { "" }
    $dataCat = if ($c.dataCategory) { "`t`tdataCategory: $($c.dataCategory)`r`n" } else { "" }
    $colLt = New-Guid7
    if ($c.description) { [void]$sb.AppendLine("`t/// $($c.description)") }
    [void]$sb.AppendLine("`tcolumn $($c.name)")
    [void]$sb.AppendLine("`t`tdataType: $($c.dataType)")
    [void]$sb.Append($hidden)
    [void]$sb.Append($isKey)
    [void]$sb.Append($fmt)
    [void]$sb.Append($dataCat)
    [void]$sb.AppendLine("`t`tsummarizeBy: none")
    [void]$sb.AppendLine("`t`tsourceColumn: $($c.name)")
    [void]$sb.AppendLine("`t`tlineageTag: $colLt")
    [void]$sb.AppendLine("")
  }
  # measures
  if ($Measures) {
    foreach ($m in $Measures) {
      $mlt = New-Guid7
      $singleDax = ($m.dax -replace "`r?`n", ' ') -replace '\s+', ' '
      if ($m.description) { [void]$sb.AppendLine("`t/// $($m.description)") }
      [void]$sb.AppendLine("`tmeasure '$($m.name)' = $singleDax")
      if ($m.format)        { [void]$sb.AppendLine("`t`tformatString: $($m.format)") }
      if ($m.displayFolder) { [void]$sb.AppendLine("`t`tdisplayFolder: $($m.displayFolder)") }
      [void]$sb.AppendLine("`t`tlineageTag: $mlt")
      [void]$sb.AppendLine("")
    }
  }
  # partition (DirectLake)
  $plt = New-Guid7
  [void]$sb.AppendLine("`tpartition $Name = entity")
  [void]$sb.AppendLine("`t`tmode: directLake")
  [void]$sb.AppendLine("`t`tsource")
  [void]$sb.AppendLine("`t`t`tentityName: $Name")
  [void]$sb.AppendLine("`t`t`tschemaName: dbo")
  [void]$sb.AppendLine("`t`t`texpressionSource: DatabaseQuery")
  return $sb.ToString()
}

# ============================================================
# TABLE DEFINITIONS
# ============================================================

# --- dim_date ---
$colsDate = @(
  @{ name='date';         dataType='dateTime'; description='Calendar date.'; dataCategory='PaddedDateTableDates' },
  @{ name='year';         dataType='int64';    description='Calendar year.' },
  @{ name='quarter';      dataType='string';   description='Quarter label (e.g. Q1-2025).' },
  @{ name='month_num';    dataType='int64';    description='Month number (1-12).'; hidden=$true },
  @{ name='month_name';   dataType='string';   description='Month label (e.g. Jan-2025).' },
  @{ name='week_of_year'; dataType='int64';    description='ISO week of year.' },
  @{ name='day_of_week';  dataType='string';   description='Day of week name.' },
  @{ name='is_weekend';   dataType='boolean';  description='TRUE on Saturday or Sunday.' }
)
$tmdlDate = New-TableTmdl -Name 'dim_date' -Description 'Date dimension. One row per day. Marked as date table.' -Columns $colsDate -DateTable 'true'
# Insert MarkAsDateTable annotation AFTER dataCategory: Time (TMDL requires lineageTag before annotations)
$tmdlDate = $tmdlDate -replace "(dataCategory: Time\r?\n)", "`$1`tannotation MarkAsDateTable = 1`r`n"
$tmdlDate | Set-Content -Path (Join-Path $smTablesDir 'dim_date.tmdl') -Encoding utf8

# --- dim_market ---
$colsMarket = @(
  @{ name='market_key'; dataType='int64';  description='Surrogate key for market.'; hidden=$true; isKey=$true },
  @{ name='country';    dataType='string'; description='Anonymized market label (e.g. Market_EU1). Never real country names.' },
  @{ name='channel';    dataType='string'; description='Trade channel (Modern Trade, Traditional Trade, eCommerce, Foodservice, Wholesale).' }
)
(New-TableTmdl -Name 'dim_market' -Description 'Market dimension. One row per country x channel.' -Columns $colsMarket) |
  Set-Content -Path (Join-Path $smTablesDir 'dim_market.tmdl') -Encoding utf8

# --- dim_product ---
$colsProduct = @(
  @{ name='sku';            dataType='string';  description='SKU code (anonymized, e.g. SKU_0001). Primary key.'; isKey=$true },
  @{ name='brand';          dataType='string';  description='Anonymized brand label (Brand_X..Brand_V). Never real brand names.' },
  @{ name='category';       dataType='string';  description='Product category (Beverages, Confectionery, Snacks, Dairy).' },
  @{ name='pack_size';      dataType='string';  description='Pack configuration label (e.g. 12x330ml).' },
  @{ name='units_per_case'; dataType='int64';   description='Consumer units per standard case.'; hidden=$true },
  @{ name='kg_per_unit';    dataType='double';  description='Mass in kg per consumer unit.'; hidden=$true }
)
(New-TableTmdl -Name 'dim_product' -Description 'Product dimension. One row per SKU.' -Columns $colsProduct) |
  Set-Content -Path (Join-Path $smTablesDir 'dim_product.tmdl') -Encoding utf8

# --- dim_plant ---
$colsPlant = @(
  @{ name='plant_line_key'; dataType='int64';  description='Surrogate key for plant x line.'; hidden=$true; isKey=$true },
  @{ name='plant_name';     dataType='string'; description='Anonymized plant label (Plant_A..Plant_D). Never real plant names.' },
  @{ name='line_name';      dataType='string'; description='Production line label (Line_01..Line_03).' }
)
(New-TableTmdl -Name 'dim_plant' -Description 'Plant dimension. One row per manufacturing line.' -Columns $colsPlant) |
  Set-Content -Path (Join-Path $smTablesDir 'dim_plant.tmdl') -Encoding utf8

# --- fact_sales_orders with inline measures ---
$colsSales = @(
  @{ name='order_line_id';       dataType='string';  description='Order line surrogate id.'; hidden=$true },
  @{ name='order_date';          dataType='dateTime';description='Order placement date. FK to dim_date.'; hidden=$true },
  @{ name='market_key';          dataType='int64';   description='FK to dim_market.'; hidden=$true },
  @{ name='sku';                 dataType='string';  description='FK to dim_product.'; hidden=$true },
  @{ name='net_sales_value_usd'; dataType='double';  description='Line NSV in USD. Use [NSV] measure.'; hidden=$true },
  @{ name='volume_cases';        dataType='double';  description='Standard equivalent cases. Use [Volume Cases].'; hidden=$true },
  @{ name='volume_tons';         dataType='double';  description='Volume in metric tons. Use [Volume Tons].'; hidden=$true },
  @{ name='is_on_time';          dataType='boolean'; description='Delivered on or before agreed date. Drives OTIF.' },
  @{ name='is_in_full';          dataType='boolean'; description='Delivered in full quantity. Drives OTIF.' }
)
$Measures = @(
  @{ name='NSV'; dax='SUM ( ''fact_sales_orders''[net_sales_value_usd] )'; format='"\$#,0;(\$#,0);\$0"'; displayFolder='01 Commercial\Headline'; description='Net Sales Value in USD: invoiced sales net of returns, discounts, and trade allowances.' },
  @{ name='Volume Cases'; dax='SUM ( ''fact_sales_orders''[volume_cases] )'; format='"#,0"'; displayFolder='01 Commercial\Headline'; description='Sales volume in standard equivalent cases.' },
  @{ name='Volume Tons'; dax='SUM ( ''fact_sales_orders''[volume_tons] )'; format='"#,0.0"'; displayFolder='01 Commercial\Headline'; description='Sales volume in metric tons.' },
  @{ name='NSV LY'; dax='CALCULATE ( [NSV], SAMEPERIODLASTYEAR ( ''dim_date''[date] ) )'; format='"\$#,0"'; displayFolder='02 Commercial\Time Intelligence'; description='NSV same period last year.' },
  @{ name='NSV YoY %'; dax="VAR _cur = [NSV]`nVAR _ly  = [NSV LY]`nRETURN DIVIDE ( _cur - _ly, _ly )"; format='"0.0%;-0.0%;0.0%"'; displayFolder='02 Commercial\Time Intelligence'; description='Year-over-year growth rate of NSV.' },
  @{ name='NSV MTD'; dax='TOTALMTD ( [NSV], ''dim_date''[date] )'; format='"\$#,0"'; displayFolder='02 Commercial\Time Intelligence'; description='NSV month-to-date.' },
  @{ name='NSV QTD'; dax='TOTALQTD ( [NSV], ''dim_date''[date] )'; format='"\$#,0"'; displayFolder='02 Commercial\Time Intelligence'; description='NSV quarter-to-date.' },
  @{ name='Volume Cases MAT'; dax="CALCULATE ( [Volume Cases], DATESINPERIOD ( 'dim_date'[date], MAX ( 'dim_date'[date] ), -12, MONTH ) )"; format='"#,0"'; displayFolder='02 Commercial\Time Intelligence'; description='Moving Annual Total Volume Cases - trailing 12 months.' },
  @{ name='Volume Cases YoY %'; dax="VAR _cur = [Volume Cases]`nVAR _ly  = CALCULATE ( [Volume Cases], SAMEPERIODLASTYEAR ( 'dim_date'[date] ) )`nRETURN DIVIDE ( _cur - _ly, _ly )"; format='"0.0%;-0.0%;0.0%"'; displayFolder='02 Commercial\Time Intelligence'; description='YoY growth rate of Volume Cases.' },
  @{ name='OTIF %'; dax="DIVIDE ( CALCULATE ( DISTINCTCOUNT ( 'fact_sales_orders'[order_line_id] ), 'fact_sales_orders'[is_on_time] = TRUE (), 'fact_sales_orders'[is_in_full] = TRUE () ), DISTINCTCOUNT ( 'fact_sales_orders'[order_line_id] ) )"; format='"0.0%"'; displayFolder='04 Operations\Supply Chain'; description='On-Time In-Full: share of order lines delivered both on time and in full.' },
  @{ name='Top Market by NSV'; dax="VAR _ranked = TOPN ( 1, VALUES ( 'dim_market'[country] ), [NSV], DESC ) RETURN CONCATENATEX ( _ranked, 'dim_market'[country], "", "" )"; displayFolder='05 Rankings'; description='Market with the highest NSV in the selected context.' },
  @{ name='Top 5 SKUs by Volume'; dax="VAR _t = TOPN ( 5, VALUES ( 'dim_product'[sku] ), [Volume Cases], DESC ) RETURN CONCATENATEX ( _t, 'dim_product'[sku], "", "" )"; displayFolder='05 Rankings'; description='Top 5 SKUs by Volume Cases.' }
)
(New-TableTmdl -Name 'fact_sales_orders' -Description 'Sales orders fact. One row per order line.' -Columns $colsSales) |
  Set-Content -Path (Join-Path $smTablesDir 'fact_sales_orders.tmdl') -Encoding utf8

# --- fact_production with manufacturing measures ---
$colsProduction = @(
  @{ name='production_event_id';      dataType='string';  description='Production event surrogate id.'; hidden=$true },
  @{ name='shift_date';               dataType='dateTime';description='Date of the manufacturing shift. FK to dim_date.'; hidden=$true },
  @{ name='plant_line_key';           dataType='int64';   description='FK to dim_plant.'; hidden=$true },
  @{ name='sku';                      dataType='string';  description='FK to dim_product.'; hidden=$true },
  @{ name='planned_production_hours'; dataType='double';  description='Scheduled hours. Used by [OEE].'; hidden=$true },
  @{ name='run_time_hours';           dataType='double';  description='Actual run hours. Used by [OEE].'; hidden=$true },
  @{ name='downtime_hours';           dataType='double';  description='Unplanned downtime hours. Use [Downtime Hours].'; hidden=$true },
  @{ name='units_produced';           dataType='int64';   description='Units produced (good + scrap). Used by [OEE] and [Scrap %].'; hidden=$true },
  @{ name='good_units';               dataType='int64';   description='Units passing quality. Used by [OEE] and [Scrap %].'; hidden=$true },
  @{ name='ideal_units';              dataType='int64';   description='Units at ideal cycle time. Used by [OEE] performance.'; hidden=$true }
)
$Measures = @(
  @{ name='OEE'; dax="VAR _avail = DIVIDE ( SUM ( 'fact_production'[run_time_hours] ), SUM ( 'fact_production'[planned_production_hours] ) )`nVAR _perf = DIVIDE ( SUM ( 'fact_production'[units_produced] ), SUM ( 'fact_production'[ideal_units] ) )`nVAR _qual = DIVIDE ( SUM ( 'fact_production'[good_units] ), SUM ( 'fact_production'[units_produced] ) )`nRETURN _avail * _perf * _qual"; format='"0.0%"'; displayFolder='03 Operations\Manufacturing'; description='Overall Equipment Effectiveness = Availability x Performance x Quality.' },
  @{ name='Downtime Hours'; dax="SUM ( 'fact_production'[downtime_hours] )"; format='"#,0.0"'; displayFolder='03 Operations\Manufacturing'; description='Total unplanned downtime in hours.' },
  @{ name='Scrap %'; dax="DIVIDE ( SUM ( 'fact_production'[units_produced] ) - SUM ( 'fact_production'[good_units] ), SUM ( 'fact_production'[units_produced] ) )"; format='"0.0%"'; displayFolder='03 Operations\Manufacturing'; description='Share of produced units rejected as scrap.' }
)
(New-TableTmdl -Name 'fact_production' -Description 'Production fact. One row per shift x line x SKU.' -Columns $colsProduction) |
  Set-Content -Path (Join-Path $smTablesDir 'fact_production.tmdl') -Encoding utf8

# --- fact_inventory with supply chain measure ---
$colsInv = @(
  @{ name='inventory_snapshot_id'; dataType='string';  description='Snapshot surrogate id.'; hidden=$true },
  @{ name='snapshot_date';         dataType='dateTime';description='Date of the inventory snapshot. FK to dim_date.'; hidden=$true },
  @{ name='market_key';            dataType='int64';   description='FK to dim_market.'; hidden=$true },
  @{ name='sku';                   dataType='string';  description='FK to dim_product.'; hidden=$true },
  @{ name='stock_units';           dataType='double';  description='On-hand inventory units at snapshot.'; hidden=$true },
  @{ name='daily_sell_out_units';  dataType='double';  description='Average daily sell-out units around snapshot.'; hidden=$true }
)
$Measures = @(
  @{ name='Days of Supply'; dax="DIVIDE ( AVERAGE ( 'fact_inventory'[stock_units] ), AVERAGE ( 'fact_inventory'[daily_sell_out_units] ) )"; format='"#,0.0"'; displayFolder='04 Operations\Supply Chain'; description='Average stock-on-hand divided by average daily sell-out. Target band: 14-28 days.' }
)
(New-TableTmdl -Name 'fact_inventory' -Description 'Inventory fact. Weekly snapshots per market x SKU.' -Columns $colsInv) |
  Set-Content -Path (Join-Path $smTablesDir 'fact_inventory.tmdl') -Encoding utf8

# Reset
$Measures = $null

# ------------------------------------------------------------
# definition/relationships.tmdl
# ------------------------------------------------------------
function Rel { param($from, $fromCol, $to, $toCol) @"
relationship $(New-Guid7)
	fromColumn: $from.$fromCol
	toColumn: $to.$toCol
	crossFilteringBehavior: oneDirection

"@ }

$rel = ""
$rel += Rel 'fact_sales_orders' 'order_date' 'dim_date' 'date'
$rel += Rel 'fact_sales_orders' 'market_key' 'dim_market' 'market_key'
$rel += Rel 'fact_sales_orders' 'sku' 'dim_product' 'sku'
$rel += Rel 'fact_production'   'shift_date' 'dim_date' 'date'
$rel += Rel 'fact_production'   'plant_line_key' 'dim_plant' 'plant_line_key'
$rel += Rel 'fact_production'   'sku' 'dim_product' 'sku'
$rel += Rel 'fact_inventory'    'snapshot_date' 'dim_date' 'date'
$rel += Rel 'fact_inventory'    'market_key' 'dim_market' 'market_key'
$rel += Rel 'fact_inventory'    'sku' 'dim_product' 'sku'
$rel | Set-Content -Path (Join-Path $smDefDir 'relationships.tmdl') -Encoding utf8

# ------------------------------------------------------------
# definition/model.tmdl  — top-level model glue
# ------------------------------------------------------------
@"
model Model
	culture: en-US
	defaultPowerBIDataSourceVersion: powerBI_V3
	sourceQueryCulture: en-US
	dataAccessOptions
		legacyRedirects
		returnErrorValuesAsNull

	annotation PBI_QueryOrder = ["DatabaseQuery"]
	annotation __PBI_TimeIntelligenceEnabled = 0
	annotation PBIDesktopVersion = 2.140
	annotation PBI_ProTooling = ["DevMode"]
"@ | Set-Content -Path (Join-Path $smDefDir 'model.tmdl') -Encoding utf8

# ------------------------------------------------------------
# cultures/en-US.tmdl  — synonyms for Q&A
# ------------------------------------------------------------
$linguistic = @{
  Version = '1.0.0'
  Language = 'en-US'
  Entities = @{
    'dim_market.country' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_market'; ConceptualProperty='country' } }; State='Generated'; Terms = @(@{country=@{}},@{market=@{}},@{geo=@{}},@{region=@{}},@{cluster=@{}},@{geography=@{}}) }
    'dim_market.channel' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_market'; ConceptualProperty='channel' } }; State='Generated'; Terms = @(@{channel=@{}},@{'trade channel'=@{}},@{RTM=@{}},@{'route to market'=@{}},@{'customer type'=@{}}) }
    'dim_product.brand' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_product'; ConceptualProperty='brand' } }; State='Generated'; Terms = @(@{brand=@{}},@{label=@{}},@{range=@{}},@{banner=@{}}) }
    'dim_product.sku' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_product'; ConceptualProperty='sku' } }; State='Generated'; Terms = @(@{SKU=@{}},@{item=@{}},@{'product code'=@{}},@{article=@{}},@{material=@{}}) }
    'dim_product.category' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_product'; ConceptualProperty='category' } }; State='Generated'; Terms = @(@{category=@{}},@{segment=@{}},@{'product group'=@{}}) }
    'dim_plant.plant_name' = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_plant'; ConceptualProperty='plant_name' } }; State='Generated'; Terms = @(@{plant=@{}},@{factory=@{}},@{site=@{}},@{facility=@{}},@{'manufacturing site'=@{}}) }
    'dim_plant.line_name'  = @{ Definition = @{ Binding = @{ ConceptualEntity='dim_plant'; ConceptualProperty='line_name' } }; State='Generated'; Terms = @(@{line=@{}},@{'production line'=@{}},@{'packaging line'=@{}},@{asset=@{}}) }
    'fact_sales_orders.is_on_time' = @{ Definition = @{ Binding = @{ ConceptualEntity='fact_sales_orders'; ConceptualProperty='is_on_time' } }; State='Generated'; Terms = @(@{'on time'=@{}},@{'on-time'=@{}},@{OT=@{}},@{'schedule adherence'=@{}}) }
    'fact_sales_orders.is_in_full' = @{ Definition = @{ Binding = @{ ConceptualEntity='fact_sales_orders'; ConceptualProperty='is_in_full' } }; State='Generated'; Terms = @(@{'in full'=@{}},@{'in-full'=@{}},@{IF=@{}},@{'case fill'=@{}}) }
  }
}
$lmJson = $linguistic | ConvertTo-Json -Depth 12 -Compress
@"
cultureInfo en-US
	linguisticMetadata = $lmJson
		contentType: json
"@ | Set-Content -Path (Join-Path $smCulturesDir 'en-US.tmdl') -Encoding utf8

# ------------------------------------------------------------
# Report (minimal)
# ------------------------------------------------------------
@{
  '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json'
  metadata  = @{ type = 'Report'; displayName = 'mfg_report' }
  config = @{ version = '2.0'; logicalId = (New-Guid7) }
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $rptDir '.platform') -Encoding utf8

@{
  version         = '1.0'
  datasetReference = @{
    byPath       = @{ path = "../$pbipName.SemanticModel" }
    byConnection = $null
  }
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $rptDir 'definition.pbir') -Encoding utf8

@{
  '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/1.0.0/schema.json'
  themeCollection = @{ baseTheme = @{ name = 'CY24SU10' } }
  resourcePackages = @()
  publicCustomVisuals = @()
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $rptDefDir 'report.json') -Encoding utf8

Write-Host "`nGenerated .pbip at: $modelRoot" -ForegroundColor Green
Get-ChildItem $modelRoot -Recurse -File | Select-Object FullName | Format-Table -AutoSize
