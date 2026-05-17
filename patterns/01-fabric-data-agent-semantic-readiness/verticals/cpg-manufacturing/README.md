# CPG / Manufacturing — Data Agent vertical

The reference example for Pattern 01. The synthetic data, semantic model and 10-question score gate that ship in the pattern's `assets/` and `examples/` folders already implement this vertical.

## Domain

A multi-brand consumer goods business with plants, customers (chains + eCommerce), brands, products and markets. Daily sales, production and OTIF facts.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `Sales` | day · product · customer · market | NSV, gross sales, units |
| `Production` | day · plant · product | run-time, downtime, planned-time → OEE |
| `Shipments` | day · order | on-time, in-full → OTIF |
| `DimProduct` | product | brand, category, SKU attributes |
| `DimCustomer` | customer | channel (Retail / eCommerce / Foodservice) |
| `DimMarket` | market | APAC, EMEA, NA, LATAm sub-regions |
| `DimDate` | day | fiscal calendar, MAT helpers |

## Sample business questions

1. What was NSV last quarter and YoY?
2. Top 5 brands by MAT volume.
3. Market with highest NSV growth LY.
4. OEE by plant for the trailing 4 weeks.
5. OTIF % by channel last month.
6. Top 10 SKUs by gross sales contribution.
7. Promotional uplift on Brand X last campaign.
8. Cases shipped vs. planned by plant.
9. Customer concentration: top 10 customers share of NSV.
10. eCommerce vs. retail NSV mix trend (last 8 quarters).

## Candidate DAX measures

```dax
NSV          := SUMX( Sales, Sales[GrossSales] - Sales[Discounts] - Sales[Returns] )
NSV YoY %    := DIVIDE( [NSV] - CALCULATE( [NSV], SAMEPERIODLASTYEAR( DimDate[Date] ) ), CALCULATE( [NSV], SAMEPERIODLASTYEAR( DimDate[Date] ) ) )
MAT Volume   := CALCULATE( SUM( Sales[Units] ), DATESINPERIOD( DimDate[Date], MAX( DimDate[Date] ), -12, MONTH ) )
OEE %        := DIVIDE( SUM( Production[RunTimeMin] ), SUM( Production[PlannedTimeMin] ) )
OTIF %       := DIVIDE( CALCULATE( COUNTROWS( Shipments ), Shipments[OnTime] && Shipments[InFull] ), COUNTROWS( Shipments ) )
```

See [`../../examples/story.md`](../../examples/story.md) for the actual grounded answers this model returned at the 9/10 gate.
