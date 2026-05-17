# Energy / Utilities — Data Agent vertical

Adapts Pattern 01 to asset-heavy generation + distribution operations.

## Domain

A utility with generation assets (wind, solar, thermal), a distribution network, and a customer-billing system. The agent answers performance, downtime and demand questions.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `Generation` | hour · asset | MWh produced, capacity factor |
| `Downtime` | event · asset | reason code, duration |
| `Weather` | hour · site | wind speed, irradiance, temperature |
| `Demand` | hour · feeder | load MW |
| `Assets` | asset | type, nameplate MW, commissioning date, site |
| `WorkOrders` | wo | preventive vs. corrective, status |
| `DimDate` | hour | fiscal + ISO calendars |

## Sample business questions

1. Total generation MWh last month by asset type.
2. Capacity factor by wind farm last quarter.
3. Top 5 assets by unplanned downtime hours LTM.
4. Forced outage rate trend, last 8 quarters.
5. Peak demand hour last week by region.
6. Renewable share of generation YoY.
7. Average MTBF for thermal units, last year.
8. Work-order backlog by site.
9. Weather-correlated solar output deviation last month.
10. Heat-rate trend for gas units (where applicable).

## Candidate DAX measures

```dax
Generation MWh   := SUM( Generation[MWh] )
Capacity Factor %:= DIVIDE( [Generation MWh], SUMX( Assets, Assets[NameplateMW] * 24 * [DaysInPeriod] ) )
Forced Outage % := DIVIDE( CALCULATE( SUM( Downtime[Hours] ), Downtime[Type] = "Forced" ), [Period Hours] )
MTBF             := DIVIDE( [Operating Hours], CALCULATE( COUNTROWS( Downtime ), Downtime[Type] = "Forced" ) )
Renewable Share %:= DIVIDE( CALCULATE( [Generation MWh], Assets[Type] IN { "Wind", "Solar", "Hydro" } ), [Generation MWh] )
```
