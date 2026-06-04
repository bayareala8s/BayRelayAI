# BayRelay — Agentic AI File Transfer Platform (AWS)

**Repository:** [github.com/bayareala8s/BayRelayAI](https://github.com/bayareala8s/BayRelayAI)

Production reference implementation: Bedrock agent + RAG knowledge base + Step Functions file transfer (S3 + SFTP), with an operator portal (landing page, operations dashboard, automation, onboarding).

## Demo lifecycle (start → run → stop)

**Primary controller:** `./scripts/bayrelay_demo.sh`

| Command | Purpose |
|---------|---------|
| `bayrelay_demo.sh start --yes` | Deploy prod stack for customer demos (keeps running) |
| `bayrelay_demo.sh smoke` | Automated regression / pre-meeting check |
| `bayrelay_demo.sh status` | Outputs + readiness hints |
| `bayrelay_demo.sh cycle --yes --no-teardown` | Start + smoke, keep stack |
| `bayrelay_demo.sh cycle --yes` | Full start → smoke → **destroy** |
| `bayrelay_demo.sh stop --yes` | Tear down |

```bash
cp environments/demo.env.example environments/demo.env   # edit Cognito password
./scripts/bayrelay_demo.sh start --yes --smoke             # deploy + validate (~20–30 min first time)
./scripts/bayrelay_demo.sh status                          # before customer call
./scripts/production_ready.sh --smoke                      # production gate (recommended)
./scripts/bayrelay_demo.sh stop --yes                      # when done (saves AWS cost)
```

**Customer demo cheat sheet:** [docs/CUSTOMER_DEMO_READY.md](docs/CUSTOMER_DEMO_READY.md)

Full guide: **[docs/DEMO_LIFECYCLE.md](docs/DEMO_LIFECYCLE.md)** · Demo catalog: **[docs/DEMO_CATALOG.md](docs/DEMO_CATALOG.md)**

## Repository layout

- `environments/` — production Terraform stack (`environment = "prod"`, region `us-west-2`)
- `modules/` — Terraform modules
- `app/lambdas/unified/` — API, workflow, agent_tools handlers
- `portal/` — React operator portal (Vite SPA)
- `docs/` — architecture, deployment, demo, sales
- `scripts/` — demo start/stop, bootstrap, smoke tests
- `tests/` — unit tests

## Quick deploy

```bash
cd environments && cp terraform.tfvars.example terraform.tfvars
./scripts/demo_start.sh --yes
```

Production checklist: [docs/PRODUCTION.md](docs/PRODUCTION.md) · **Customer AWS:** [docs/CUSTOMER_AWS_DEPLOYMENT.md](docs/CUSTOMER_AWS_DEPLOYMENT.md) · Demo: [docs/DEMO.md](docs/DEMO.md)

## Sales & website ([BayAreaLa8s](https://www.bayareala8s.com/))

| Asset | Doc |
|-------|-----|
| **Pricing** (PoC + Production) | [docs/PRICING.md](docs/PRICING.md) |
| **Demo kit index** | [docs/sales/CUSTOMER_DEMO_KIT.md](docs/sales/CUSTOMER_DEMO_KIT.md) |
| **Screenshot / video checklist** | [docs/sales/SCREENSHOT_CHECKLIST.md](docs/sales/SCREENSHOT_CHECKLIST.md) |
| **One-pager + outreach** | [docs/sales/](docs/sales/) — proposal PDF, email template |
| SOW — PoC $24k | [docs/SOW_POC_24K.md](docs/SOW_POC_24K.md) |
| SOW — Production $42k | [docs/SOW_PRODUCTION_LAUNCH_42K.md](docs/SOW_PRODUCTION_LAUNCH_42K.md) |
| Wix page copy | [docs/website/BAYRELAY_MINI_PRODUCT_PAGE.md](docs/website/BAYRELAY_MINI_PRODUCT_PAGE.md) |
| Site update steps | [docs/website/WIX_UPDATE_CHECKLIST.md](docs/website/WIX_UPDATE_CHECKLIST.md) |


## CI

`./scripts/ci_verify.sh` — pytest, `terraform fmt -check`, validate `environments/`.

## License

Reference implementation; apply your organization’s security review before production use.
