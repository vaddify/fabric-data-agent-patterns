# Public Sector — Data Agent vertical

Adapts Pattern 01 to a citizen-services agency: case management, service-level performance, channel mix.

## Domain

A government services department handling permits, benefits applications and inquiries across digital and in-person channels.

## Data model (sketch)

| Table | Grain | Notes |
|---|---|---|
| `Cases` | case | type, channel, status, SLA target |
| `CaseEvents` | event · case | open, assigned, closed, escalated |
| `Staff` | staff | unit, role (no PII) |
| `Channels` | channel | web, phone, in-person, partner |
| `Offices` | office | region, type |
| `DimDate` | day | fiscal calendar |

## Sample business questions

1. Open case backlog by service type today.
2. Cases closed within SLA last month, by channel.
3. Median time-to-first-response by case type.
4. Escalation rate trend last 12 months.
5. Channel mix shift (digital vs. in-person) YoY.
6. Top 5 offices by volume last quarter.
7. Reopened-case rate by service type.
8. First-contact resolution % last quarter.
9. Cases breaching SLA, last week.
10. Average case age in backlog by unit.

## Candidate DAX measures

```dax
Open Backlog       := CALCULATE( COUNTROWS( Cases ), Cases[Status] IN { "Open", "InProgress" } )
SLA Met %          := DIVIDE( CALCULATE( COUNTROWS( Cases ), Cases[SLAStatus] = "Met" ), CALCULATE( COUNTROWS( Cases ), Cases[Status] = "Closed" ) )
Median TTR (hrs)   := MEDIANX( Cases, DATEDIFF( Cases[OpenedAt], Cases[FirstResponseAt], HOUR ) )
Escalation Rate %  := DIVIDE( DISTINCTCOUNT( FILTER( CaseEvents, CaseEvents[Type] = "Escalated" )[CaseId] ), DISTINCTCOUNT( Cases[CaseId] ) )
FCR %              := DIVIDE( CALCULATE( COUNTROWS( Cases ), Cases[ContactCount] = 1 ), COUNTROWS( Cases ) )
```
