# Operations Dashboard

Operator-facing **health and capacity** view in the BayRelay portal. Aggregates transfer requests, Step Functions executions, partner counts, and onboarding queue depth in one screen.

---

## Portal

| Route | Screen |
|-------|--------|
| `/` | Operational Dashboard (default home for operators) |
| `/operations` | Same dashboard |
| `/transfers` | Full transfer list |

**Layout:** Left sidebar (BayRelay brand, icon nav, sign out, role status) + top bar (search placeholder, notifications, user avatar). BayRelay navy / teal / gold theme.

**Header:** **Operational Dashboard** title, green **LIVE** pill, **Need help?** link, **Overview** / **Charts** toggle (top right).

### Overview view

- **Health banner** — `healthy`, `attention` (failures), or `busy` (onboarding backlog)
- **KPI cards** — partners, endpoints, succeeded count, failed executions, onboarding queue, sampled transfers
- **Status bars** — transfer status and transfer type breakdown
- **Recent transfers** — links to detail
- **Recent failures** — failed executions from GSI `status-created_at`
- **Quick actions** — new transfer, onboarding, agent, partners

### Charts view

Same KPI row; main area is a 2×2 chart grid (transfer status, transfer types, execution status, platform counts).

Auto-refresh every **60 seconds** in the browser.

---

## API

`GET /v1/ops/summary`

| Query | Default | Max |
|-------|---------|-----|
| `transfer_sample` | 200 | 500 |
| `recent_limit` | 8 | 25 |

Requires JWT (same as other `/v1/*` routes).

Example:

```bash
curl -sS "$API_URL/v1/ops/summary" -H "Authorization: Bearer $TOKEN" | jq .
```

Response shape:

```json
{
  "generated_at": "2026-05-31T12:00:00Z",
  "health": "healthy",
  "counts": {
    "partners": 3,
    "endpoints": 6,
    "transfers_sampled": 42,
    "onboarding_pending": 1
  },
  "transfers": { "by_status": {}, "by_type": {} },
  "executions": { "by_status": {}, "failed_recent": [] },
  "recent_transfers": []
}
```

---

## Implementation

| File | Role |
|------|------|
| `app/lambdas/unified/ops_service.py` | DynamoDB aggregation |
| `app/lambdas/unified/api.py` | `get_ops_summary` handler |
| `portal/src/pages/OperationsDashboardPage.tsx` | UI (LIVE, Overview/Charts) |
| `portal/src/components/Layout.tsx` | Sidebar shell |
| `environments/main.tf` | Route `GET /v1/ops/summary` |

Execution failure queries use the existing **`status-created_at`** GSI on `transfer-executions` (same as agent tool `list_recent_failures`).

---

## Demo

After `./scripts/bayrelay_demo.sh start --yes` (deploys portal automatically):

1. Sign in → **Operational Dashboard** with LIVE badge.
2. Run `./scripts/bayrelay_demo.sh smoke` — KPIs and recent transfers populate.
3. Toggle **Charts** for breakdown view.
4. Open a failed row (if any) → transfer detail.

See also [CUSTOMER_DEMO_READY.md](CUSTOMER_DEMO_READY.md) and [OPERATOR_PORTAL_MVP.md](OPERATOR_PORTAL_MVP.md).
