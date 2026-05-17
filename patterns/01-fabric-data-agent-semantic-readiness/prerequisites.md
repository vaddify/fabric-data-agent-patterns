# Prerequisites

## Tenant & licensing
- Microsoft Fabric capacity **F2 or higher** (trial is acceptable for MVP). F-SKU required for Data Agents in production.
- Power BI Pro license for every author.
- Fabric Admin Portal settings (enabled at tenant or capacity scope):
  - **Copilot and Azure OpenAI** → On
  - **AI and Copilot features for Fabric** → On
  - **Users can create Fabric items** → On
  - **Service principals can use Fabric APIs** → On (for CI validation)

## Identity
- Entra ID security group, e.g. `fabric-coe-mvp` — authors + reviewers.
- Service principal `sp-fabric-coe-mvp` with **Member** role on the workspace (for `score-agent.ps1`).
- Workspace role: authors = **Member**, reviewers = **Viewer**.

## Workspace
- One Fabric workspace, e.g. `ws-coe-mvp`, assigned to the F-SKU capacity.
- **Git integration** bound to this repo, branch `main`.

## Data
- A curated **star schema** already exists in a Lakehouse or Warehouse:
  - 1 fact table (≥ 10k rows recommended for realistic agent behavior)
  - 3+ dimension tables including a date dimension
- If you only have raw/bronze data, stop and build the star schema first.

## Local tooling (for authors)
| Tool | Why | Install |
|------|-----|---------|
| Power BI Desktop (latest) | Author `.pbip` semantic model | aka.ms/pbidesktop |
| Tabular Editor 2 (free) or 3 | Edit TMDL, run BPA | tabulareditor.com |
| PowerShell 7+ | Run validation scripts | `winget install Microsoft.PowerShell` |
| Azure CLI | Auth for REST calls | `winget install Microsoft.AzureCLI` |
| VS Code | Edit TMDL / markdown | `winget install Microsoft.VisualStudioCode` |

## Verify before continuing
```powershell
pwsh --version          # >= 7.4
az --version            # any recent
az account show         # signed into the right tenant
```
