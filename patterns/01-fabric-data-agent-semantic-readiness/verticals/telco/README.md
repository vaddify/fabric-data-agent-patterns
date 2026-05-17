# Telco — Data Agent vertical

Adapts Pattern 01 to mobile-network operations + subscriber economics.

## Domain

A mobile operator with cell-site performance data, subscriber base, plan catalog and churn / ARPU history.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `CellMetrics` | hour · cell | availability %, accessibility, retainability, throughput |
| `Alarms` | event · cell | severity, duration |
| `Subscribers` | subscriber | plan, segment, tenure (no MSISDN) |
| `Usage` | day · subscriber | voice min, SMS, data GB |
| `Billing` | month · subscriber | charges, discounts, taxes |
| `Sites` | site | region, technology (4G/5G), vendor |
| `DimDate` | day | fiscal + ISO |

## Sample business questions

1. Network availability % by region last week.
2. Top 10 worst-performing cells by drop-call rate.
3. Mean alarm-resolution time by severity LTM.
4. ARPU trend by segment YoY.
5. 5G coverage share of total traffic this quarter.
6. Subscriber churn rate last month by plan.
7. Data usage per subscriber YoY.
8. Roaming revenue YoY.
9. Net adds (gross adds − churn) by region last quarter.
10. Customer lifetime value by acquisition channel (top 5).

## Candidate DAX measures

```dax
Availability %  := AVERAGEX( CellMetrics, CellMetrics[UpMinutes] / CellMetrics[PeriodMinutes] )
Drop Call Rate %:= DIVIDE( SUM( CellMetrics[DroppedCalls] ), SUM( CellMetrics[TotalCalls] ) )
ARPU            := DIVIDE( SUM( Billing[NetRevenue] ), DISTINCTCOUNT( Billing[SubscriberId] ) )
Churn Rate %    := DIVIDE( CALCULATE( DISTINCTCOUNT( Subscribers[SubscriberId] ), Subscribers[ChurnFlag] ), [Avg Subs] )
Net Adds        := [Gross Adds] - [Churned Subs]
```
