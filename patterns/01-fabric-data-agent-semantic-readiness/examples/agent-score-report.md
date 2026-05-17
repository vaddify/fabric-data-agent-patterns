# Agent score report

- Workspace: `<workspace-id>`
- Agent: `<agent-id>`
- Run at: 2026-05-16T20:20:36.2132056-05:00
- Score: **9 / 10** (90%)
- Gate (>= 80%): **PASS**

| # | Result | Question | Expected keyword |
|---|--------|----------|------------------|
| 1 | ✅ | What was NSV last quarter? | `NSV` |
| 2 | ✅ | Which market had the highest net sales value last year? | `market` |
| 3 | ❌ | Show me year-over-year NSV growth by market. | `YoY` |
| 4 | ✅ | What is the MAT volume in cases for our top brand? | `MAT` |
| 5 | ✅ | What is OEE by plant this month? | `OEE` |
| 6 | ✅ | How many downtime hours did we record last week by line? | `Downtime` |
| 7 | ✅ | What is OTIF by trade channel month-to-date? | `OTIF` |
| 8 | ✅ | What are days of supply by SKU in Market_EU1? | `Days of Supply` |
| 9 | ✅ | Which SKUs are trending down YoY in volume in Market_EU1? | `Market_EU1` |
| 10 | ✅ | What is the scrap percentage by plant quarter-to-date? | `Scrap` |

## Raw answers
### What was NSV last quarter?
```json
NSV for the last completed quarter (Q2 2026, April 1–May 31): $4,169,233 USD.
```
### Which market had the highest net sales value last year?
```json
Market_APAC2 had the highest net sales value last year (2025) with $5,150,343 USD.
```
### Show me year-over-year NSV growth by market.
```json
Year-over-year NSV growth by market (2025, USD):

- Market_AM1: $1,334,747, up 17.9%
- Market_EU1: $1,948,227, up 15.9%
- Market_APAC1: $1,822,186, up 14.4%
- Market_APAC2: $2,320,245, up 9.9%
- Market_AM2: $1,367,754, up 7.6%
- Market_EU2: $1,707,067, up 4.1%

Strongest growth seen in Market_AM1 and Market_EU1.
```
### What is the MAT volume in cases for our top brand?
```json
MAT volume for the top brand (Brand_Y) is 535,775 cases. This covers the moving annual total for the latest 12 months.
```
### What is OEE by plant this month?
```json
OEE by plant for May 2026:

- Plant_D: 79.5%
- Plant_A: 76.8%
- Plant_B: 70.5%
- Plant_C: 57.6%

Plant_D led performance this month.
```
### How many downtime hours did we record last week by line?
```json
Last week, downtime hours by line were: Line_01: 13.7 hours, Line_02: 12.1 hours, Line_03: 2.5 hours.
```
### What is OTIF by trade channel month-to-date?
```json
OTIF by trade channel month-to-date (May 2026):

- eCommerce: 88.2%
- Modern Trade: 86.1%
- Wholesale: 78.4%
- Traditional Trade: 76.9%
- Foodservice: 64.5%

eCommerce is leading OTIF so far this month.
```
### What are days of supply by SKU in Market_EU1?
```json
Market_EU1: SKU_0022 currently has 22.8 days of supply.
```
### Which SKUs are trending down YoY in volume in Market_EU1?
```json
The following SKUs are trending down year-over-year in volume (cases) in Market_EU1: SKU_0028 (-40.7%), SKU_0015 (-39.8%), SKU_0027 (-19.2%), SKU_0021 (-18.2%), SKU_0014 (-17.4%), SKU_0009 (-13.9%), SKU_0006 (-12.1%), SKU_0003 (-7.9%), SKU_0004 (-7.8%), SKU_0007 (-7.0%), and SKU_0005 (-3.1%).
```
### What is the scrap percentage by plant quarter-to-date?
```json
Quarter-to-date scrap percentage by plant (Q2 2026, April 1–May 31):

- Plant_D: 2.6%
- Plant_A: 3.9%
- Plant_B: 4.9%
- Plant_C: 7.8%

Plant_D has the lowest scrap rate this quarter.
```

