# Operator Portal v2 (Customer — Recommended)

Three phases shipped for real-customer operator workflows.

## Phase 1 — Data tables and rule edit

- Reusable `DataTable` with search, status filter, and column sort.
- Applied to Transfers, Partners, Endpoints, Automation rules, and Onboarding lists.
- API list endpoints accept `q`, `status`, `partner_id`, `sort`, `order`.
- Transfer rules: **Edit** (name, pattern, priority, enabled) via `PUT /v1/transfer-rules/{id}`.

## Phase 2 — Registry CRUD and transfer actions

| Resource | GET | PUT | DELETE (soft) |
|----------|-----|-----|----------------|
| Partners | `/v1/partners/{id}` | `/v1/partners/{id}` | status → `DISABLED` |
| Endpoints | `/v1/endpoints/{id}` | `/v1/endpoints/{id}` | status → `DISABLED` |

- **Retry:** `POST /v1/transfers/{id}/retry` — resubmits from stored request payload.
- **Cancel:** `POST /v1/transfers/{id}/cancel` — marks non-terminal requests `CANCELLED`.
- Transfer detail shows `latest_execution` when available.

## Phase 3 — Policies and audit

- **Routing policies:** list/create/update/delete at `/v1/routing-policies` (composite key: `policy_id` + `partner_id` query on get/put/delete).
- **Audit log:** `GET /v1/audit-events` with `q`, `correlation_id`, `sort`, `order`.
- Portal routes: `/policies`, `/audit` (operator nav).

## Deploy

Stack must be up for live API tests:

```bash
./scripts/bayrelay_demo.sh start --yes
./scripts/deploy_portal.sh
```

Terraform adds all v2 routes in `environments/main.tf` `api_routes_base`.

## Tests

```bash
cd /path/to/BayRelayAI && PYTHONPATH=app/lambdas/unified pytest tests/test_list_utils.py tests/test_partners_service.py -q
```
