# Deploy BayRelay in the customer's AWS account

This is the recommended **mini-product delivery model**: all data and infrastructure stay in the **customer's AWS account**. You deliver the accelerator, implementation, and optional care; the customer pays AWS directly.

## Engagement summary

| You provide | Customer provides |
|-------------|-------------------|
| Terraform stack (`environments/`), modules, scripts | Dedicated AWS account or OU (prod workload) |
| Implementation / hardening / smoke test | IAM role or credentials for deploy window |
| KB curation support, runbooks, demo training | Bedrock model access in target region |
| Optional monthly care (updates, KB, alarms) | Partner SFTP endpoints, security review sign-off |
| Documentation and handoff package | Ongoing AWS invoice for Transfer, OpenSearch, Bedrock |

**You do not host** customer files or run multi-tenant SaaS in this model.

---

## Suggested commercial package (customer AWS)

| Package | Scope | Plan price (guide) | SOW |
|---------|--------|-------------------|-----|
| **PoC** | 90-day eval, smoke test, draft alias OK, teardown option, 10 KB docs | **$24,000** fixed | [SOW_POC_24K.md](SOW_POC_24K.md) |
| **Production Launch** | Full deploy, published alias, 20 KB docs, 30-day hypercare | **$42,000** fixed | [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md) |
| **PoC → Production** | Within 60 days of PoC acceptance | **$34,000** ($8k credit) | Production SOW |
| **Care** | Monthly apply support, KB refresh, alarm review | **$2.5k–$6k/mo** | Order Form |
| **Accelerator only** | Repo + 2-day workshop; customer self-deploys | **$8k–$15k** | Custom |

**Master pricing sheet:** [PRICING.md](PRICING.md)

**Customer AWS budget (24/7 prod, us-west-2, SFTP + KB on):** about **$500–1,500+/month** — pass through on their invoice, not yours.

**PoC AWS budget (90 days, full stack):** about **$1,500–$4,000** total — use `demo_stop.sh` between internal demos to reduce spend.

---

## Phase 0 — Customer prerequisites (before kickoff)

Send this checklist to the customer **before** scheduling `terraform apply`.

### Account and region

- [ ] AWS account ID: `____________`
- [ ] Region (default in repo: **us-west-2**): `____________`
- [ ] Separate account or OU for production (recommended)
- [ ] Service quotas OK for: Lambda, API Gateway, Step Functions, DynamoDB, Transfer Family, OpenSearch Serverless, Bedrock

### Access for your team (pick one)

**Option A — Cross-account role (recommended)**

Customer creates a role your deployer can assume, with trust to your account or SSO user. Attach a policy based on the services in `environments/main.tf` (KMS, S3, DDB, Lambda, IAM, API Gateway, WAF, Cognito, CloudWatch, SNS, Transfer, Bedrock, OpenSearch Serverless, Events).

**Option B — IAM user in customer account**

Limited-duration access keys; rotate after handoff.

**Option C — Customer runs apply**

You supply `terraform.tfvars` + runbook; their engineer runs `demo_start.sh` on a bastion with outbound SSH (for Transfer host keys).

### Bedrock (required)

In the **deployment region**, customer enables model access for:

- [ ] Agent model: `anthropic.claude-3-sonnet-20240229-v1:0` (or agreed substitute in `foundation_model`)
- [ ] Embeddings: `amazon.titan-embed-text-v1`

### Terraform state (customer-owned)

- [ ] S3 bucket + DynamoDB lock table for remote state (you configure `backend` in `environments/versions.tf`)
- [ ] State bucket encryption and least-privilege access

### Network

- [ ] Apply runner can reach **registry.terraform.io** and **AWS APIs**
- [ ] Outbound **SSH (port 22)** from apply host for `ssh-keyscan` (Transfer connector host keys), **or** customer supplies `connector_trusted_host_keys` for each partner SFTP host

### Partners (for full SFTP demo / prod)

- [ ] Partner SFTP hostname, port, username, auth (Secrets Manager will hold secrets)
- [ ] Partner allow-list includes Transfer Family connector egress IPs (if partner firewalls)

### Operations

- [ ] SNS email/SMS for `alarm_topic_arn` after deploy
- [ ] Named Cognito operators for API access (emails for `create_cognito_operator.sh`)
- [ ] Security / architecture review window (JWT, WAF, KMS, no public S3)

---

## Phase 1 — Configure for customer

1. Copy `environments/terraform.tfvars.example` → `environments/terraform.tfvars`.
2. Set customer values:

```hcl
aws_region       = "us-west-2"              # customer region
project          = "bayrelay"               # or customer prefix
environment      = "prod"
foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"

enable_api_jwt_auth      = true
enable_waf               = true
allow_agent_trace_header = false
enable_transfer_family   = true
enable_bedrock_vector_kb = true

kb_force_destroy                   = false
transfer_data_bucket_force_destroy = false

bedrock_agent_alias_id = "TSTALIASID"     # replace after publish (Phase 4)
```

3. Add S3 backend to `environments/versions.tf` (customer bucket/key).
4. Run `./scripts/preflight_prod.sh` using customer credentials.

---

## Phase 2 — Deploy

From repo root with customer `AWS_PROFILE` or assumed role:

```bash
./scripts/demo_start.sh --yes
```

Or step-by-step:

```bash
./scripts/preflight_prod.sh
./scripts/start_stack.sh --yes
SYNC_KB_DOCS=1 BAYRELAY_TF_DIR=environments AWS_REGION=<region> ./scripts/bootstrap_phase3.sh
```

**Duration:** first apply often **15–30 minutes** (OpenSearch Serverless + Bedrock + Transfer).

---

## Phase 3 — Harden and validate

| Step | Action |
|------|--------|
| Cognito | `./scripts/create_cognito_operator.sh` for each customer operator |
| Bedrock | Console: Prepare agent → version → **published alias** → update `bedrock_agent_alias_id` → `terraform apply` |
| KB | Customer runbooks under `docs/kb/` → `kb_sync` → `bootstrap_phase3.sh` |
| Alarms | Subscribe to `terraform -chdir=environments output -raw alarm_topic_arn` |
| Smoke | `./scripts/run_full_demo.sh` with customer `COGNITO_*` — **must exit 0** |

```bash
export COGNITO_CLIENT_ID="$(terraform -chdir=environments output -raw cognito_client_id)"
export COGNITO_USERNAME="..."
export COGNITO_PASSWORD="..."
AWS_REGION=<region> ./scripts/run_full_demo.sh
```

---

## Phase 4 — Handoff to customer

Deliver a handoff pack (run `./scripts/customer_handoff.sh` after deploy):

| Artifact | Source |
|----------|--------|
| API base URL | `http_api_endpoint` |
| Region | `aws_deployment_region` |
| Transfer bucket | `transfer_data_bucket` |
| SFTP endpoint / connector | `sftp_server_endpoint`, `transfer_connector_id` |
| Cognito pool / client | `cognito_user_pool_id`, `cognito_client_id` |
| Bedrock agent / KB IDs | `bedrock_agent_id`, `bedrock_knowledge_base_id` |
| Runbooks | [RUNBOOK.md](RUNBOOK.md), [DEMO.md](DEMO.md), [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md) |
| Architecture | [bayrelay-architecture.png](bayrelay-architecture.png) |

**Customer owns:** AWS billing, IAM long-term, partner credentials, KB content, alias lifecycle, production change control.

**You retain (if care contract):** advisory on upgrades, optional managed applies, KB ingestion reruns.

---

## Shared responsibility

| Area | Customer | You (implementer) |
|------|----------|-------------------|
| AWS account & billing | ✓ | |
| Data in S3 / SFTP | ✓ | |
| Bedrock model access approval | ✓ | Assist |
| Terraform apply in their account | ✓ (or jointly) | ✓ |
| Application code / modules | | ✓ (deliver via repo) |
| Partner SFTP connectivity | ✓ | Assist integration |
| 24/7 on-call (unless care SOW) | ✓ | |

---

## Teardown (PoC only)

For **proof-of-concept** in customer account (not long-term prod):

```bash
./scripts/demo_stop.sh --yes
```

Warn customer: destroys API, buckets (after empty), Transfer endpoint, OpenSearch collection.

---

## Pricing calculator (customer conversation)

See **[PRICING.md](PRICING.md)** for full detail.

```
PoC (90-day eval)          $24,000          (SOW_POC_24K.md)
Production Launch          $42,000          (or $34,000 after PoC credit)
Optional Care              $3,500/mo        (6-month minimum)

Monthly AWS (production)   $800 – $1,200+   (customer pays AWS)
PoC AWS (90 days, 24/7)    $1,500 – $4,000  (customer pays AWS)
```

Adjust Production up for: multiple partner connectors, private VPC, compliance documentation.

Adjust PoC down only via scope change (S3-only, no KB) — minimum **$18,000** custom quote.

---

## Related docs

- [PRICING.md](PRICING.md) — PoC vs Production comparison
- [SOW_POC_24K.md](SOW_POC_24K.md) · [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md)
- [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md) — start/stop demo scripts
- [PRODUCTION.md](PRODUCTION.md) — stack defaults and API usage
- [DEPLOYMENT.md](DEPLOYMENT.md) — rollback and CI
