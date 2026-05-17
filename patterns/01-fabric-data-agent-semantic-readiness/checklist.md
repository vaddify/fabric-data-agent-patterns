# Go / No-Go Checklist — Semantic Readiness for Fabric Data Agent

Print this. Tick every box. **Any unchecked box = No-Go.**

## 1. Data foundation
- [ ] Star schema lives in a Fabric Warehouse or Lakehouse SQL endpoint
- [ ] Fact table has at least one date column joined to a proper date dimension
- [ ] No SELECT \* views; only typed columns exposed to the model
- [ ] Row counts validated against source (documented)

## 2. Semantic model — structure
- [ ] Model authored as `.pbip` (PBIP format) and committed to Git
- [ ] All relationships are single-direction unless explicitly justified
- [ ] No calculated columns where a measure would do
- [ ] Hidden columns: all foreign keys, all surrogate keys

## 3. Semantic model — descriptions (the #1 agent failure cause)
- [ ] **Every visible table** has a 1–2 sentence business description
- [ ] **Every visible column** has a description
- [ ] **Every measure** has a description that states the business meaning *and* the unit
- [ ] Descriptions use business language, not column names

## 4. Synonyms
- [ ] Every dimension attribute users will ask about has ≥ 2 synonyms
- [ ] Code values (e.g., `US`, `EMEA`) have human synonyms ("United States", "Europe")
- [ ] Date fields have synonyms ("month", "period", "quarter")

## 5. Measures
- [ ] At least one measure per KPI users mention in the question set
- [ ] All measures use explicit DAX (no implicit Sum/Average)
- [ ] Time-intelligence measures (YoY, MTD, QTD) exist where the question set demands them
- [ ] Measures grouped in **display folders**

## 6. Q&A linguistic schema
- [ ] Q&A opened at least once; suggested phrasings reviewed
- [ ] Linguistic schema exported (`.lsdl`) and committed
- [ ] At least 10 example phrasings added

## 7. Agent configuration
- [ ] Agent created and bound to the semantic model
- [ ] System instructions written (see `assets/agent-instructions.md`)
- [ ] ≥ 5 grounded example questions added to the agent

## 8. Validation gate
- [ ] BPA run is clean (`assets/validate-semantic-model.ps1` exits 0)
- [ ] Scored question set ≥ 80% pass (`assets/score-agent.ps1`)
- [ ] Failure log committed (`examples/failure-log.md`)

---
**All boxes ticked? → Ship it.**
**Anything unticked? → Return to `playbook.md`.**
