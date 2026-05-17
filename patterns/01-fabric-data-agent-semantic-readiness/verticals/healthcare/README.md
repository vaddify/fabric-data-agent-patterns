# Healthcare — Data Agent vertical

Adapts Pattern 01 to a payer/provider claims + operations dataset.

## Domain

A regional health system with inpatient, outpatient and pharmacy claims, plus operations data on length-of-stay, readmissions and denials.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `Claims` | claim line | charged, allowed, paid, denial reason |
| `Encounters` | encounter | admit/discharge dates, DRG, LOS |
| `Readmissions` | flag per index encounter | 30-day window |
| `Members` | member | plan, age band, region (PHI-free) |
| `Providers` | provider | specialty, facility, network status |
| `DimDate` | day | fiscal year |

## Sample business questions

1. Total paid claims YTD by service line.
2. Denial rate trend last 12 months.
3. Top 5 denial reasons by claim volume last quarter.
4. Average LOS by DRG last month, vs. peer benchmark column.
5. 30-day readmission rate by facility.
6. Out-of-network spend last quarter.
7. Pharmacy spend per member per month (PMPM) YoY.
8. Top 10 providers by total paid amount.
9. Specialty mix of denied claims.
10. Allowed-to-charged ratio by service line.

## Candidate DAX measures

```dax
Paid          := SUM( Claims[PaidAmount] )
Denial Rate % := DIVIDE( CALCULATE( COUNTROWS( Claims ), Claims[Status] = "Denied" ), COUNTROWS( Claims ) )
Avg LOS       := AVERAGEX( Encounters, DATEDIFF( Encounters[AdmitDate], Encounters[DischargeDate], DAY ) )
Readmit Rate %:= DIVIDE( COUNTROWS( FILTER( Readmissions, Readmissions[Within30] ) ), COUNTROWS( Readmissions ) )
PMPM          := DIVIDE( [Paid], DISTINCTCOUNT( Members[MemberMonthId] ) )
```

> Even on synthetic data, treat all PHI fields as PHI — strip member identifiers before the agent ever sees the model.
