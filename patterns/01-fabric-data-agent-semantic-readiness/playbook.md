# Playbook — Pattern 01

Execute top to bottom. Each step has a clear **done =** condition.

---

## Step 1 — Confirm prerequisites
Open `prerequisites.md`, verify every item.

**done =** all checks pass and you can run `az account show` in the target tenant.

---

## Step 2 — Define the question set FIRST
Before touching the model, write the 10 business questions the agent must answer. Use `examples/questions.md` as the template. Each entry must include:
- The business question (as a user would type it)
- The expected answer shape (single value, table, chart)
- The measure(s) and dimension(s) it should resolve to

**done =** `examples/questions.md` committed with ≥ 10 questions.

> Why first: this set defines what "ready" means. Without it, you tune the model toward nothing.

---

## Step 3 — Author the semantic model as `.pbip`
1. Open Power BI Desktop → File → Options → Preview features → **Power BI Project (.pbip)** → On.
2. Connect to the Warehouse/Lakehouse SQL endpoint via **DirectLake** (preferred) or Import.
3. Build the star schema: one fact, dimensions, single-direction relationships, date dim marked as date table.
4. Save as `.pbip` into `assets/model/` in this repo.

**done =** `.pbip` opens and refreshes without errors; folder structure committed.

---

## Step 4 — Enforce descriptions on every visible object
Open the model in **Tabular Editor**. For every visible table, column, and measure:
- Add a `Description` written in business language.
- See `assets/tmdl-snippets/table-with-descriptions.tmdl` for the exact pattern.

Tip: Tabular Editor → Advanced Scripting → run `assets/scripts/find-missing-descriptions.csx` (provided) to list gaps.

**done =** zero objects without descriptions.

---

## Step 5 — Add synonyms to every dimension attribute
For each dimension column users will reference:
1. Select the column → **Synonyms** → add ≥ 2 alternates.
2. For code columns, add the human label as a synonym.
3. Export the linguistic schema: Power BI Desktop → **Modeling → Language → Linguistic Schema → Export**. Save to `assets/qna/mfg.lsdl`.

**done =** `mfg.lsdl` committed, every dimension attribute has synonyms.

---

## Step 6 — Replace implicit aggregations with explicit measures
1. Hide all numeric columns on the fact table.
2. Create explicit measures using the patterns in `assets/measures.dax`.
3. Group measures using `Display Folder`.
4. Add **time-intelligence variants** (YoY %, MTD, QTD) for any KPI your question set demands.

**done =** every question in `examples/questions.md` maps to at least one explicit measure.

---

## Step 7 — Run Best Practice Analyzer (gate)
```powershell
cd patterns/01-fabric-data-agent-semantic-readiness/assets
pwsh ./validate-semantic-model.ps1 -PbipPath ./model
```
The script runs Tabular Editor CLI against `bpa-rules.json`. Exit code must be 0.

**done =** BPA exits 0, output committed to `examples/bpa-report.txt`.

---

## Step 8 — Publish the model to the Fabric workspace
1. Power BI Desktop → **Publish** → select `ws-coe-mvp`.
2. In the workspace → semantic model → **Settings** → confirm **Q&A is enabled**.

**done =** semantic model visible in the workspace.

---

## Step 9 — Create the Fabric Data Agent
1. Workspace → **New → Data Agent**.
2. Add the semantic model as a data source.
3. Paste the contents of `assets/agent-instructions.md` into **Instructions**.
4. Add ≥ 5 grounded example questions from `examples/questions.md` into **Example questions**, each with the expected interpretation.
5. Save and publish the agent.

**done =** agent responds to a smoke-test question with a valid result.

---

## Step 10 — Score the agent against the question set (gate)
```powershell
cd patterns/01-fabric-data-agent-semantic-readiness/assets
pwsh ./score-agent.ps1 `
  -WorkspaceId <guid> `
  -AgentId <guid> `
  -QuestionsPath ../examples/questions.md `
  -OutputPath ../examples/agent-score-report.md
```
Pass criterion: **≥ 8 / 10**.

**done =** report committed; failures logged in `examples/failure-log.md`.

---

## Step 11 — If score < 80%, fix the MODEL, not the agent
Common root causes (in order of likelihood):
1. Missing or weak description on the table/column the question touches → fix in Step 4
2. Missing synonym → fix in Step 5
3. Question requires a measure that doesn't exist → fix in Step 6
4. Ambiguous relationship → fix the schema

Re-run Step 7 → Step 10 until the gate passes.

> Resist tuning the agent prompt to compensate for a weak model. Prompt-patching a weak semantic layer is the most common Data Agent failure mode — every fix belongs in the model.

---

## Step 12 — Capture the story
Add an entry under `examples/` describing:
- Domain, fact/dim count, # measures
- Final score
- Top 3 failures and how they were fixed

**done =** PR merged, tag `pattern-01-v0.1`.
