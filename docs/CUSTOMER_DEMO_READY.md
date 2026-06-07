# Customer demo — production ready

Use this checklist before a live customer meeting. The stack uses **production flags** in `environments/terraform.tfvars` (JWT, CloudFront WAF, no bucket force-destroy).

**Operator portal v2** (searchable tables, partner/endpoint CRUD, rule edit, policies, audit, transfer retry/cancel): see [OPERATOR_PORTAL_V2.md](./OPERATOR_PORTAL_V2.md). Redeploy after pulling: `./scripts/bayrelay_demo.sh start --yes` and `./scripts/deploy_portal.sh`.

## Quick start (one command)

```bash
cp environments/demo.env.example environments/demo.env   # set Cognito password
./scripts/prepare_customer_demo.sh                        # deploy + portal + smoke + handoff
```

Or step by step:

```bash
./scripts/bayrelay_demo.sh start --yes --smoke   # ~15–25 min first deploy; includes portal build
./scripts/production_ready.sh
./scripts/customer_handoff.sh
```

After deploy, run `./scripts/bayrelay_demo.sh status` for live URLs (portal, API, Cognito client ID).

**Current stack (2026-06-04):**

| Item | Value |
|------|--------|
| Public API | `https://d5gqom1g1qt0k.cloudfront.net` |
| Operator portal | `https://d3s8ftcdqq6anp.cloudfront.net` |
| Cognito client ID | `1dh2v3sabuhjvv6mfvj58cm84j` |
| Demo user | `demo@bayareala8s.com` (`environments/demo.env`) |
| Smoke | `./scripts/bayrelay_demo.sh smoke` — PASSED |

## Before the meeting (2 min)

```bash
./scripts/bayrelay_demo.sh status
./scripts/production_ready.sh
```

Confirm **Operator portal** loads, demo user signs in, and **Operational Dashboard** shows **LIVE** + **Overview / Charts** toggle.

## Portal demo flow (10–15 min)

Sign in as **operator** (`bayrelay-operators` group — created automatically from `demo.env`).

| Step | Sidebar / screen | What to show |
|------|------------------|--------------|
| 1 | **Operations** (home) | LIVE badge, KPIs, Overview vs Charts, recent transfers |
| 2 | **New customer** → **Onboarding** | Submit application → approve (auto-approve on in demo tfvars) |
| 3 | **New transfer** | S3→S3, S3→SFTP, SFTP→S3, SFTP→SFTP |
| 4 | **Transfers** | Poll status → detail page |
| 5 | **Automation** | Transfer rules (S3 key → auto-submit) |
| 6 | **Partners** | Registry |
| 7 | **Assistant** | KB-grounded policy question (checksum retry) |

**Partner role (optional):** create with `./scripts/create_cognito_operator.sh --role partner --partner-id PRT-...` — same portal, scoped nav.

## Live demo script (15–20 min)

1. **Portal** — Operations dashboard + one transfer end-to-end.
2. **API + auth** — JWT, partner/endpoints (if showing API).
3. **All transfer types** — `./scripts/bayrelay_demo.sh smoke` (~2 min unattended).
4. **Architecture** — `docs/bayrelay-architecture.png` + PoC vs Production (`docs/PRICING.md`).

## Features enabled for demo

| Flag | Purpose |
|------|---------|
| `enable_operator_portal` | CloudFront SPA |
| `enable_transfer_automation` | S3 EventBridge → auto transfers |
| `enable_self_service_onboarding` | Portal onboarding flows |
| `onboarding_auto_approve` | Instant partner provision (set `true` in tfvars for demos only) |

See [SELF_SERVICE_AND_AUTOMATION.md](SELF_SERVICE_AND_AUTOMATION.md), [OPERATIONS_DASHBOARD.md](OPERATIONS_DASHBOARD.md).

## Do not run before customers

```bash
./scripts/bayrelay_demo.sh stop --yes   # destroys the stack
```

**Redeploy after destroy:** if Terraform fails on SFTP secrets, run `./scripts/restore_scheduled_secrets.sh` then import ARNs (see script output).

**Portal-only refresh** (UI changes, stack already up):

```bash
./scripts/deploy_portal.sh
```

**Re-ensure demo Cognito user / operator group:**

```bash
./scripts/ensure_cognito_demo_user.sh
```

## Handoff artifact

```bash
./scripts/customer_handoff.sh
```

Writes `customer-handoff-<date>.txt` with API, portal, Cognito, Bedrock, SFTP endpoints.

## Pricing reference

- PoC: $24k / 90 days — [SOW_POC_24K.md](SOW_POC_24K.md)
- Production Launch: $42k — [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md)
