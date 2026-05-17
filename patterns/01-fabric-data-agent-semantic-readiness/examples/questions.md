# Agent question set — Manufacturing / CPG

10 business questions the Data Agent must answer **without rephrasing**, covering commercial (NSV, volume, growth) and operational (OEE, OTIF, supply) KPIs typical for a CPG manufacturer.

Each block is parsed by `assets/score-agent.ps1` — keep the format exact.

Required keys per question:
- `expected_measure` — DAX measure the agent should resolve to (human reference)
- `expected_dimension` — dimension(s) the agent should slice by
- `expected_keyword` — a substring that **must** appear in the agent's answer for the question to pass

> All examples use anonymized placeholders (`Market_EU1`, `Plant_A`, `Brand_X`). Do not insert real customer, brand, plant, or product names anywhere in this file.

---

### Q1: What was NSV last quarter?
- expected_measure: NSV QTD
- expected_dimension: dim_date
- expected_keyword: NSV

### Q2: Which market had the highest net sales value last year?
- expected_measure: NSV LY
- expected_dimension: dim_market.country
- expected_keyword: market

### Q3: Show me year-over-year NSV growth by market.
- expected_measure: NSV YoY %
- expected_dimension: dim_market.country
- expected_keyword: Market_

### Q4: What is the MAT volume in cases for our top brand?
- expected_measure: Volume Cases MAT
- expected_dimension: dim_product.brand
- expected_keyword: MAT

### Q5: What is OEE by plant this month?
- expected_measure: OEE
- expected_dimension: dim_plant.plant_name
- expected_keyword: OEE

### Q6: How many downtime hours did we record last week by line?
- expected_measure: Downtime Hours
- expected_dimension: dim_plant.line_name
- expected_keyword: Downtime

### Q7: What is OTIF by trade channel month-to-date?
- expected_measure: OTIF %
- expected_dimension: dim_market.channel
- expected_keyword: OTIF

### Q8: What are days of supply by SKU in Market_EU1?
- expected_measure: Days of Supply
- expected_dimension: dim_product.sku, dim_market.country
- expected_keyword: Days of Supply

### Q9: Which SKUs are trending down YoY in volume in Market_EU1?
- expected_measure: Volume Cases YoY %
- expected_dimension: dim_market.country, dim_product.sku
- expected_keyword: Market_EU1

### Q10: What is the scrap percentage by plant quarter-to-date?
- expected_measure: Scrap %
- expected_dimension: dim_plant.plant_name
- expected_keyword: Scrap
