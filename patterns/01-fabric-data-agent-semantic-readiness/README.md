# Pattern 01 — Fabric Data Agent: Semantic Readiness

> **Vertical focus:** Manufacturing / Consumer Packaged Goods (CPG).
> **Confidentiality:** all examples use anonymized labels (`Market_EU1`, `Plant_A`, `Brand_X`, `SKU_0001`). No real customer, brand, plant, supplier, or employee names appear in this repository. Maintain this rule in every contribution.

## Outcome
A Fabric Data Agent that answers **≥ 8 of 10** business questions correctly **without rephrasing**, grounded on a Power BI semantic model built to enterprise readiness standards. The shipped example set covers commercial KPIs (NSV, volume, YoY, MAT) and operational KPIs (OEE, downtime, scrap, OTIF, days of supply).

## When to use this pattern
- You are exposing a Fabric Data Agent (or Copilot in Power BI) to business users in a manufacturing or CPG context.
- Your model is the *only* grounding the agent has (no RAG, no external tools).
- Users phrase questions in business language ("OEE by plant last month", "top market by NSV") rather than column names.

## When NOT to use this pattern
- Your scenario needs unstructured-document Q&A → use a RAG pattern instead.
- You only have raw bronze tables and no curated star schema → fix that first.
- Single-user ad-hoc exploration → Copilot in Power BI Desktop is sufficient; skip the agent.

## What "good" looks like (non-negotiables)
1. Star schema in a Fabric Warehouse or Lakehouse SQL endpoint.
2. Every table and column has a **business-language description**.
3. Every dimension attribute users will ask about has **synonyms**.
4. Measures (not implicit aggregations) for every KPI, with explicit DAX + description.
5. Q&A linguistic schema reviewed and exported.
6. Agent has 5+ grounded example questions.
7. A scored question set proves ≥ 80% accuracy before go-live.

## Order of files in this folder
1. `prerequisites.md` — verify access first
2. `checklist.md` — 15-minute Go/No-Go
3. `playbook.md` — execute end to end
4. `assets/` — drop-in artifacts
5. `examples/` — sample question sets + failure log template
