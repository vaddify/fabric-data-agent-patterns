# Quickstart — end-to-end in ~60 minutes

This is the hands-on path we actually ran to produce the 9 / 10 score in [`patterns/01-…/examples/story.md`](patterns/01-fabric-data-agent-semantic-readiness/examples/story.md). Follow top to bottom; every step has a **done =** check. Scripts referenced live in [`scripts/`](scripts/) and pattern assets in [`patterns/01-fabric-data-agent-semantic-readiness/`](patterns/01-fabric-data-agent-semantic-readiness/).

> Time: ~60 min once prerequisites are in place. Cost: an F64 hour or two — **pause the capacity as soon as the gate passes** (Step 11).

---

## 0. Prerequisites (one-time)

**Tenant settings** (Fabric Admin Portal — needs Fabric Admin):
- *Copilot and Azure OpenAI* → **On**
- *AI and Copilot features for Fabric* → **On**
- *Users can create Fabric items* → **On**
- *Service principals can use Fabric APIs* → **On**

**Licensing & identity:**
- Fabric capacity **F64 or higher** (Data Agents require F-SKU; trial is fine for the gate run, but pause it after).
- Power BI Pro for every author.
- Your signed-in user has **Contributor** on the target subscription / RG that holds the capacity.

**Local tooling:**

```powershell
winget install Microsoft.PowerShell      # PowerShell 7+
winget install Microsoft.AzureCLI
winget install Microsoft.VisualStudioCode
winget install GitHub.cli
# Tabular Editor 2 (free): https://tabulareditor.com/downloads
```

Power BI Desktop (latest): https://aka.ms/pbidesktop → File → Options → Preview features → enable **Power BI Project (.pbip)**.

**Sign in:**

```powershell
az login --tenant <your-tenant-id>
az account set --subscription <your-subscription-id>
gh auth login            # only needed if you'll publish your run to a repo
```

**done =** `az account show` returns the right tenant + subscription.

---

## 1. Clone this repo

```powershell
git clone https://github.com/vaddify/fabric-data-agent-patterns.git
cd fabric-data-agent-patterns
```

---

## 2. Create (or reuse) a Fabric capacity — **manual**

In the Azure Portal:
1. **Create resource → Microsoft Fabric**.
2. Name: `<your-capacity-name>` (lowercase, no dashes). Region: pick one with Data Agent availability (East US, West Europe, etc.).
3. SKU: **F64**. Capacity admin: your user.
4. Create. Wait for `Succeeded`.

Cache the capacity id locally so scripts can find it:

```powershell
az resource show `
  --resource-type "Microsoft.Fabric/capacities" `
  --name <your-capacity-name> `
  --resource-group <your-rg> `
  --query id -o tsv > scripts/.capacity-id
```

> `scripts/.capacity-id` and friends are in `.gitignore` — they are environment-specific.

**done =** capacity state is `Active` in the portal.

---

## 3. Create the workspace + bind it to the capacity

```powershell
pwsh -NoProfile -File scripts/create-workspace.ps1 `
  -DisplayName "ws-coe-mvp" `
  -CapacityName "<your-capacity-name>"
```

The script writes `scripts/.workspace-id`. The Fabric REST API used:
`POST https://api.fabric.microsoft.com/v1/workspaces` then `POST .../workspaces/{id}/assignToCapacity`.

**done =** `scripts/.workspace-id` contains a GUID; the workspace is visible in https://app.fabric.microsoft.com.

---

## 4. Create a Lakehouse in the workspace

```powershell
pwsh -NoProfile -File scripts/create-lakehouse.ps1 -DisplayName "lh_mfg"
```

Writes `scripts/.lakehouse-id`.

**done =** Lakehouse appears in the workspace, *Files* and *Tables* folders empty.

---

## 5. Generate synthetic CPG data + upload to the Lakehouse

```powershell
pwsh -NoProfile -File scripts/generate-synthetic-data.ps1 -OutDir data/synthetic
pwsh -NoProfile -File scripts/upload-to-lakehouse.ps1 -Source data/synthetic
```

This drops six CSVs (`dim_date`, `dim_product`, `dim_plant`, `dim_market`, `fact_sales_orders`, `fact_production`, `fact_inventory`) into Files, then loads them as Delta tables via the Lakehouse load-table API.

**done =** Lakehouse → **Tables** shows all 6 tables; row counts ≥ a few thousand on facts.

---

## 6. Generate the `.pbip` semantic model and deploy it

```powershell
pwsh -NoProfile -File scripts/generate-pbip.ps1 `
  -OutDir patterns/01-fabric-data-agent-semantic-readiness/assets/model
```

The generator produces a DirectLake `.pbip` with descriptions on every visible object, synonyms on dimension attributes, and explicit measures from [`assets/measures.dax`](patterns/01-fabric-data-agent-semantic-readiness/assets/measures.dax) (NSV, NSV YoY, MAT volume, OEE %, OTIF %, etc.).

Deploy the model to the workspace via the Fabric Items API:

```powershell
pwsh -NoProfile -File scripts/deploy-semantic-model.ps1 `
  -PbipPath patterns/01-fabric-data-agent-semantic-readiness/assets/model
```

Refresh once (DirectLake auto-frames, but trigger to seed):

```powershell
pwsh -NoProfile -File scripts/refresh-and-test-model.ps1
```

**done =** semantic model appears in workspace; refresh completes without errors; `scripts/.dataset-id` populated.

---

## 7. BPA gate — fix the model, not the agent

Install Tabular Editor 2 CLI path if not already on PATH:

```powershell
pwsh -NoProfile -File scripts/install-tabular-editor.ps1
pwsh -NoProfile -File scripts/run-bpa.ps1
```

`run-bpa.ps1` runs [`assets/bpa-rules.json`](patterns/01-fabric-data-agent-semantic-readiness/assets/bpa-rules.json) against the local `.pbip`. Exit 0 = pass; the rules enforce descriptions on visible objects, synonyms on dimensions, hidden numeric fact columns, explicit measures, etc.

**done =** BPA exits 0; output saved to `patterns/01-…/examples/bpa-report.txt`.

---

## 8. Create the Data Agent — **manual** in the Fabric portal

The Data Agent create API is not GA at time of writing, so this step is UI:

1. Open the workspace → **+ New item → Data Agent**.
2. Name it (e.g. `agent-mfg`).
3. **Add data source** → pick the semantic model from Step 6.
4. **Instructions**: paste the contents of [`assets/agent-instructions.md`](patterns/01-fabric-data-agent-semantic-readiness/assets/agent-instructions.md).
5. **Example questions**: add 5+ from [`examples/questions.md`](patterns/01-fabric-data-agent-semantic-readiness/examples/questions.md), each with the expected answer shape.
6. Click **Publish**.
7. Copy the agent GUID from the URL: `…/dataagents/<agent-id>/…` → save:

```powershell
'<agent-id>' | Set-Content scripts/.agent-id
```

**done =** the agent answers a smoke test in the chat pane (e.g. "What was NSV last quarter?") and returns a number, not an apology.

---

## 9. Score gate — the bit that catches ungrounded answers

```powershell
$env:PATH = "$env:ProgramFiles\PowerShell\7;$env:PATH"
pwsh -NoProfile -File patterns/01-fabric-data-agent-semantic-readiness/assets/score-agent.ps1 `
  -WorkspaceId (Get-Content scripts/.workspace-id) `
  -AgentId     (Get-Content scripts/.agent-id) `
  -QuestionsPath patterns/01-fabric-data-agent-semantic-readiness/examples/questions.md `
  -OutputPath    patterns/01-fabric-data-agent-semantic-readiness/examples/agent-score-report.md
```

Pass = **≥ 8 / 10** with the ungrounded-deflection guard satisfied.

The script does two things most Data Agent demos get wrong — this is why it works:

### Gotcha A — token audience

The OpenAI-compatible gateway is hosted on `api.fabric.microsoft.com`, but it requires a **Power BI workload** token, not a Fabric one:

```powershell
# in score-agent.ps1
az account get-access-token --resource "https://analysis.windows.net/powerbi/api"
```

A Fabric-audience token authenticates fine and silently bypasses grounding — you'll get polite English with zero numbers.

### Gotcha B — multi-step run flow

Do **not** use the consolidated `POST /threads/runs`. It returns ungrounded answers. Use:

```
POST   /threads
POST   /threads/{tid}/messages          { role: user, content: <question> }
POST   /threads/{tid}/runs              { assistant_id: <aid> }
# then poll:
GET    /threads/{tid}/messages?run_id=<rid>     # every 5s, up to 240s
```

Both behaviors are baked into [`assets/score-agent.ps1`](patterns/01-fabric-data-agent-semantic-readiness/assets/score-agent.ps1) — keep them if you fork.

**done =** `examples/agent-score-report.md` shows ≥ 8 / 10 PASS with real numeric answers (not deflections).

---

## 10. If the score is below 80% — fix the **model**, not the agent

In order of likelihood:

1. Missing or weak **description** on the table/column the question touches → fix in Tabular Editor, re-deploy.
2. Missing **synonym** on a dimension attribute → add 2+ synonyms, re-deploy.
3. The question requires a **measure that doesn't exist** → add to `assets/measures.dax`, re-deploy.
4. **Ambiguous relationship** or wrong cardinality → fix schema.

Re-run Step 7 → Step 9 until the gate passes. **Resist tuning the agent prompt to mask a weak model** — that is the most common Data Agent failure mode.

---

## 11. Pause the capacity — do this immediately

The Data Agent answers stay queryable for a short window after pause for testing, but you should not leave F64 running.

```powershell
$capId = Get-Content scripts/.capacity-id
az rest --method post --url "https://management.azure.com$capId/suspend?api-version=2023-11-01"
az resource show --ids $capId --query "properties.state" -o tsv   # → Paused
```

Resume later with `/resume`.

**done =** capacity state = `Paused`.

---

## 12. Commit your story

Drop a copy of the run into `patterns/01-…/examples/` (sanitize identifiers!):

- `agent-score-report.md` — what you got
- `story.md` — domain, table count, top 3 fixes that moved the score, gotchas you hit
- `failure-log.md` — anything that didn't pass and why

See [`examples/story.md`](patterns/01-fabric-data-agent-semantic-readiness/examples/story.md) for the shape.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent returns "I don't have access to that data" | Wrong token audience | Use `https://analysis.windows.net/powerbi/api` (Step 9, gotcha A) |
| Agent returns generic English with no numbers | Consolidated `/threads/runs` was used | Switch to multi-step flow (Step 9, gotcha B) |
| Score script reports 10 / 10 but answers are deflections | Keyword-only pass logic | Use the version in this repo — it has the `ungrounded` regex guard |
| `GET /runs/{id}` returns 400 / 404 | The runs lookup endpoint is unreliable | Poll `GET /threads/{tid}/messages?run_id=…` instead |
| BPA fails on `OBJECT_DESCRIPTION_REQUIRED` | Tables/columns added without descriptions | Run `assets/scripts/find-missing-descriptions.csx` in Tabular Editor → fill them in |
| `deploy-semantic-model.ps1` 401 | Stale token | `az account clear; az login` |
| `create-lakehouse.ps1` 403 | User not Member on the workspace | Add yourself as **Admin** on the workspace |

---

## What's next

- Pick a **vertical** under [`patterns/01-…/verticals/`](patterns/01-fabric-data-agent-semantic-readiness/verticals/) and adapt the synthetic-data generator + measures.
- Wire `score-agent.ps1` into CI on `main` so the gate runs on every model change.
- Add a second pattern under `patterns/` following the same `README → prerequisites → playbook → checklist → assets → examples` layout.
