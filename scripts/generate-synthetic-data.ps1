#requires -Version 7
<#
.SYNOPSIS
  Generates a synthetic, anonymized Manufacturing/CPG star schema as CSV.
.DESCRIPTION
  Pure PowerShell - no Python/Faker dependency. Deterministic via -Seed.
  Output columns match patterns/01-.../assets/tmdl-snippets/table-with-descriptions.tmdl.
  All labels anonymized: Market_*, Brand_*, SKU_*, Plant_*, Line_*. NEVER use real names.
.OUTPUT
  data/synthetic/dim_date.csv
  data/synthetic/dim_market.csv
  data/synthetic/dim_product.csv
  data/synthetic/dim_plant.csv
  data/synthetic/fact_sales_orders.csv
  data/synthetic/fact_production.csv
  data/synthetic/fact_inventory.csv
#>
param(
  [int]$Seed = 20260516,
  [datetime]$StartDate = '2024-01-01',
  [datetime]$EndDate   = '2026-05-31',
  [int]$SalesRows      = 20000,
  [int]$ProductionRows = 5000,
  [int]$InventoryRows  = 3000
)

$ErrorActionPreference = 'Stop'
$rng = [System.Random]::new($Seed)
function Get-RandInt  { param([int]$Min, [int]$Max) $rng.Next($Min, $Max + 1) }   # inclusive
function Get-RandDbl  { param([double]$Min, [double]$Max) $Min + ($Max - $Min) * $rng.NextDouble() }
function Get-RandPick { param([array]$Items) $Items[$rng.Next(0, $Items.Count)] }
function PickWeighted {
  param([array]$Items, [double[]]$Weights)
  $total = ($Weights | Measure-Object -Sum).Sum
  $roll = $rng.NextDouble() * $total
  $acc = 0.0
  for ($i = 0; $i -lt $Items.Count; $i++) {
    $acc += $Weights[$i]
    if ($roll -le $acc) { return $Items[$i] }
  }
  return $Items[-1]
}

$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\synthetic'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Write-Host "Output: $outDir" -ForegroundColor Cyan

# ============================================================
# DIM_DATE
# ============================================================
Write-Host "Generating dim_date..." -ForegroundColor Yellow
$dates = @()
$d = $StartDate
while ($d -le $EndDate) {
  $dates += [pscustomobject]@{
    date         = $d.ToString('yyyy-MM-dd')
    year         = $d.Year
    quarter      = "Q$([math]::Ceiling($d.Month/3.0))-$($d.Year)"
    month_num    = $d.Month
    month_name   = $d.ToString('MMM-yyyy')
    week_of_year = [System.Globalization.ISOWeek]::GetWeekOfYear($d)
    day_of_week  = $d.DayOfWeek.ToString()
    is_weekend   = ($d.DayOfWeek -eq 'Saturday' -or $d.DayOfWeek -eq 'Sunday')
  }
  $d = $d.AddDays(1)
}
$dates | Export-Csv -Path (Join-Path $outDir 'dim_date.csv') -NoTypeInformation -Encoding utf8
Write-Host "  dim_date rows: $($dates.Count)" -ForegroundColor Green

# ============================================================
# DIM_MARKET  (anonymized)
# ============================================================
Write-Host "Generating dim_market..." -ForegroundColor Yellow
$countries = @('Market_AM1','Market_AM2','Market_EU1','Market_EU2','Market_APAC1','Market_APAC2')
$channels  = @('Modern Trade','Traditional Trade','eCommerce','Foodservice','Wholesale')
$markets = @()
$mkey = 1
foreach ($c in $countries) {
  foreach ($ch in $channels) {
    # Not every combo exists - skip ~20% to make it realistic
    if ($rng.NextDouble() -lt 0.2) { continue }
    $markets += [pscustomobject]@{
      market_key = $mkey
      country    = $c
      channel    = $ch
    }
    $mkey++
  }
}
$markets | Export-Csv -Path (Join-Path $outDir 'dim_market.csv') -NoTypeInformation -Encoding utf8
Write-Host "  dim_market rows: $($markets.Count)" -ForegroundColor Green

# ============================================================
# DIM_PRODUCT  (anonymized)
# ============================================================
Write-Host "Generating dim_product..." -ForegroundColor Yellow
$brands     = @('Brand_X','Brand_Y','Brand_Z','Brand_W','Brand_V')
$categories = @('Beverages','Confectionery','Snacks','Dairy')
$packSizes  = @('12x330ml','6x1L','24x250ml','6x1kg','10x100g','4x500g')
$products = @()
for ($i = 1; $i -le 30; $i++) {
  $sku = "SKU_{0:0000}" -f $i
  $brand = Get-RandPick $brands
  $cat   = Get-RandPick $categories
  $pack  = Get-RandPick $packSizes
  $unitsPerCase = Get-RandInt 4 24
  $kgPerUnit    = [math]::Round((Get-RandDbl 0.1 1.5), 3)
  $products += [pscustomobject]@{
    sku            = $sku
    brand          = $brand
    category       = $cat
    pack_size      = $pack
    units_per_case = $unitsPerCase
    kg_per_unit    = $kgPerUnit
  }
}
$products | Export-Csv -Path (Join-Path $outDir 'dim_product.csv') -NoTypeInformation -Encoding utf8
Write-Host "  dim_product rows: $($products.Count)" -ForegroundColor Green

# ============================================================
# DIM_PLANT  (anonymized)
# ============================================================
Write-Host "Generating dim_plant..." -ForegroundColor Yellow
$plants = @()
$pkey = 1
foreach ($p in @('Plant_A','Plant_B','Plant_C','Plant_D')) {
  $lineCount = Get-RandInt 2 3
  for ($l = 1; $l -le $lineCount; $l++) {
    $plants += [pscustomobject]@{
      plant_line_key = $pkey
      plant_name     = $p
      line_name      = "Line_{0:00}" -f $l
    }
    $pkey++
  }
}
$plants | Export-Csv -Path (Join-Path $outDir 'dim_plant.csv') -NoTypeInformation -Encoding utf8
Write-Host "  dim_plant rows: $($plants.Count)" -ForegroundColor Green

# ============================================================
# FACT_SALES_ORDERS
#   - Mild upward trend Yo so YoY% is positive overall
#   - Brand_X overperforms in Market_EU1 (drives Q4 narrative)
#   - Some channels OTIF-worse than others
# ============================================================
Write-Host "Generating fact_sales_orders ($SalesRows rows)..." -ForegroundColor Yellow
$saleRows = New-Object System.Collections.Generic.List[object]
$dayCount = ($EndDate - $StartDate).Days + 1
# Brand weights: Brand_X largest
$brandWeights = @{ 'Brand_X' = 3.5; 'Brand_Y' = 2.5; 'Brand_Z' = 2.0; 'Brand_W' = 1.5; 'Brand_V' = 0.5 }
# OTIF profile per channel (probability of on-time AND in-full)
$onTimeProb = @{ 'Modern Trade'=0.94; 'Traditional Trade'=0.86; 'eCommerce'=0.91; 'Foodservice'=0.83; 'Wholesale'=0.88 }
$inFullProb = @{ 'Modern Trade'=0.95; 'Traditional Trade'=0.89; 'eCommerce'=0.93; 'Foodservice'=0.85; 'Wholesale'=0.90 }

for ($i = 1; $i -le $SalesRows; $i++) {
  $dayOffset = $rng.Next(0, $dayCount)
  $orderDate = $StartDate.AddDays($dayOffset)
  $market = Get-RandPick $markets
  # Product pick weighted by brand
  $product = PickWeighted -Items $products -Weights ($products | ForEach-Object { $brandWeights[$_.brand] })
  # YoY trend: +6% per year
  $yearsFromStart = ($orderDate - $StartDate).Days / 365.25
  $trend = 1 + (0.06 * $yearsFromStart)
  # Brand_X bonus in Market_EU1
  $bonus = 1.0
  if ($product.brand -eq 'Brand_X' -and $market.country -eq 'Market_EU1') { $bonus = 1.35 }
  # Cases ordered: lognormal-ish
  $cases = [math]::Max(1, [int]([math]::Round((Get-RandDbl 5 250) * $trend * $bonus)))
  $tons  = [math]::Round($cases * $product.units_per_case * $product.kg_per_unit / 1000.0, 4)
  # Unit price USD per case: brand premium
  $brandPremium = @{ 'Brand_X'=1.4; 'Brand_Y'=1.1; 'Brand_Z'=1.0; 'Brand_W'=0.9; 'Brand_V'=0.7 }
  $pricePerCase = [math]::Round((Get-RandDbl 8 28) * $brandPremium[$product.brand], 2)
  $nsv = [math]::Round($cases * $pricePerCase, 2)
  $onTime = ($rng.NextDouble() -lt $onTimeProb[$market.channel])
  $inFull = ($rng.NextDouble() -lt $inFullProb[$market.channel])
  $saleRows.Add([pscustomobject]@{
    order_line_id        = "OL{0:00000000}" -f $i
    order_date           = $orderDate.ToString('yyyy-MM-dd')
    market_key           = $market.market_key
    sku                  = $product.sku
    net_sales_value_usd  = $nsv
    volume_cases         = $cases
    volume_tons          = $tons
    is_on_time           = $onTime
    is_in_full           = $inFull
  })
}
$saleRows | Export-Csv -Path (Join-Path $outDir 'fact_sales_orders.csv') -NoTypeInformation -Encoding utf8
Write-Host "  fact_sales_orders rows: $($saleRows.Count)" -ForegroundColor Green

# ============================================================
# FACT_PRODUCTION
#   - Plant_C runs hot (OEE lower) so plant comparison is meaningful
#   - Downtime spikes mid-2025 on Plant_C Line_02 (drives Q6 narrative)
# ============================================================
Write-Host "Generating fact_production ($ProductionRows rows)..." -ForegroundColor Yellow
$prodRows = New-Object System.Collections.Generic.List[object]
$plantOeeProfile = @{
  'Plant_A' = @{ Avail=0.92; Perf=0.88; Qual=0.97 }
  'Plant_B' = @{ Avail=0.90; Perf=0.85; Qual=0.96 }
  'Plant_C' = @{ Avail=0.82; Perf=0.78; Qual=0.93 }   # underperformer
  'Plant_D' = @{ Avail=0.93; Perf=0.90; Qual=0.98 }
}
$spikeStart = [datetime]'2025-06-01'
$spikeEnd   = [datetime]'2025-07-31'
for ($i = 1; $i -le $ProductionRows; $i++) {
  $dayOffset = $rng.Next(0, $dayCount)
  $shiftDate = $StartDate.AddDays($dayOffset)
  $plant = Get-RandPick $plants
  $product = Get-RandPick $products
  $profile = $plantOeeProfile[$plant.plant_name]
  $plannedHours = [math]::Round((Get-RandDbl 7.5 8.0), 2)
  $availMul = 1.0
  # Downtime spike for Plant_C Line_02 in Jun-Jul 2025
  if ($plant.plant_name -eq 'Plant_C' -and $plant.line_name -eq 'Line_02' -and $shiftDate -ge $spikeStart -and $shiftDate -le $spikeEnd) {
    $availMul = 0.55
  }
  $availability = [math]::Min(1.0, [math]::Max(0.4, $profile.Avail * $availMul * (Get-RandDbl 0.92 1.05)))
  $performance  = [math]::Min(1.0, [math]::Max(0.5, $profile.Perf  * (Get-RandDbl 0.93 1.05)))
  $quality      = [math]::Min(1.0, [math]::Max(0.7, $profile.Qual  * (Get-RandDbl 0.96 1.02)))
  $runTime = [math]::Round($plannedHours * $availability, 2)
  $downtime = [math]::Round($plannedHours - $runTime, 2)
  $idealRatePerHour = Get-RandInt 200 500
  $idealUnits = [int]([math]::Round($runTime * $idealRatePerHour))
  $unitsProduced = [int]([math]::Round($idealUnits * $performance))
  $goodUnits = [int]([math]::Round($unitsProduced * $quality))
  $prodRows.Add([pscustomobject]@{
    production_event_id      = "PE{0:00000000}" -f $i
    shift_date               = $shiftDate.ToString('yyyy-MM-dd')
    plant_line_key           = $plant.plant_line_key
    sku                      = $product.sku
    planned_production_hours = $plannedHours
    run_time_hours           = $runTime
    downtime_hours           = $downtime
    units_produced           = $unitsProduced
    good_units               = $goodUnits
    ideal_units              = $idealUnits
  })
}
$prodRows | Export-Csv -Path (Join-Path $outDir 'fact_production.csv') -NoTypeInformation -Encoding utf8
Write-Host "  fact_production rows: $($prodRows.Count)" -ForegroundColor Green

# ============================================================
# FACT_INVENTORY  (weekly snapshots)
#   - Days of Supply varies by SKU and market
# ============================================================
Write-Host "Generating fact_inventory ($InventoryRows rows)..." -ForegroundColor Yellow
$invRows = New-Object System.Collections.Generic.List[object]
for ($i = 1; $i -le $InventoryRows; $i++) {
  $dayOffset = $rng.Next(0, $dayCount)
  $snapDate = $StartDate.AddDays($dayOffset)
  $market = Get-RandPick $markets
  $product = Get-RandPick $products
  $dailySellOut = [math]::Round((Get-RandDbl 5 80), 2)
  # Days of supply target band 10-45, with tail
  $targetDos = (Get-RandDbl 8 50)
  $stock = [math]::Round($dailySellOut * $targetDos, 0)
  $invRows.Add([pscustomobject]@{
    inventory_snapshot_id = "IS{0:00000000}" -f $i
    snapshot_date         = $snapDate.ToString('yyyy-MM-dd')
    market_key            = $market.market_key
    sku                   = $product.sku
    stock_units           = $stock
    daily_sell_out_units  = $dailySellOut
  })
}
$invRows | Export-Csv -Path (Join-Path $outDir 'fact_inventory.csv') -NoTypeInformation -Encoding utf8
Write-Host "  fact_inventory rows: $($invRows.Count)" -ForegroundColor Green

Write-Host "`nDone. Files in $outDir" -ForegroundColor Cyan
Get-ChildItem $outDir | Select-Object Name, Length | Format-Table -AutoSize
