# Financial Services — Data Agent vertical

Adapts Pattern 01 to a commercial-lending / retail-banking book. Same gates (BPA + 10-Q score), different semantic model and questions.

## Domain

A bank with a commercial loan book, retail deposits and a card portfolio. The agent answers credit-risk, exposure, NIM and fee-yield questions for finance and risk officers.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `Exposures` | day · account | EAD, drawn, undrawn, collateral value |
| `RiskRatings` | rating date · account | PD bucket, LGD, internal rating |
| `Losses` | event date · account | charge-offs, recoveries |
| `Revenue` | month · account | NII, fees, FX gains |
| `DimAccount` | account | product, segment, industry, region |
| `DimCustomer` | customer | KYC tier, relationship manager |
| `DimDate` | day | regulatory calendar |

## Sample business questions

1. Total EAD by industry as of last month-end.
2. Top 10 obligors by drawn exposure.
3. Expected Loss (PD × LGD × EAD) by segment last quarter.
4. NPL ratio trend, last 8 quarters.
5. Net interest margin by product YoY.
6. Fee yield on commercial cards last month.
7. Concentration: top 5 industries share of book.
8. New originations vs. paydowns last quarter.
9. Watchlist accounts that downgraded ≥ 2 notches LTM.
10. Provisioning coverage ratio by region.

## Candidate DAX measures

```dax
EAD          := SUM( Exposures[Drawn] ) + SUM( Exposures[Undrawn] ) * 0.5
Expected Loss := SUMX( Exposures, Exposures[EAD] * RELATED( RiskRatings[PD] ) * RELATED( RiskRatings[LGD] ) )
NPL Ratio %  := DIVIDE( CALCULATE( [EAD], RiskRatings[Status] = "NPL" ), [EAD] )
NIM %        := DIVIDE( SUM( Revenue[NII] ), AVERAGEX( VALUES( DimDate[MonthEnd] ), [EAD] ) )
Fee Yield %  := DIVIDE( SUM( Revenue[Fees] ), [EAD] )
```

> Don't ship without a synthetic-data review — credit numbers in demos are read as real.
