# Failure log — Pattern 01

Append one entry per failing question encountered during scoring.
Goal: turn every failure into a model fix, not a prompt hack.

## Template

### YYYY-MM-DD — Q<n>: <question text>
- **Symptom**: what the agent returned
- **Root cause**: one of [missing description | missing synonym | missing measure | ambiguous relationship | data gap | other]
- **Fix applied**: exact change made to the model (table/column/measure)
- **Re-test result**: pass / fail
- **Notes**: anything that would help the next implementer

---

## Entries

### 2026-MM-DD — Q3: Show me year-over-year NSV growth by market.
- **Symptom**: Agent returned "I don't know what YoY means." and grouped by `dim_plant[plant_name]` instead of `dim_market[country]`.
- **Root cause**: missing synonym on both measure and dimension — `market` was not mapped to `dim_market[country]`.
- **Fix applied**:
  1. Added synonyms `year over year, yoy, growth, annual change` on measure `[NSV YoY %]`.
  2. Added synonyms `market, geo, region, cluster` on `dim_market[country]`.
- **Re-test result**: pass
- **Notes**: Confirmed BPA SYN-DIMENSION-REQUIRED rule does not cover measures — consider extending the rule set.
