# Demo lifecycle — start, run, and stop

BayRelay uses a **single production stack** in `environments/`. For **customer demos**, deploy once and keep the stack running until you explicitly stop it.

## Primary entry point: `bayrelay_demo.sh`

```bash
cp environments/demo.env.example environments/demo.env   # set Cognito demo user + password
./scripts/prepare_customer_demo.sh                     # recommended: start + portal + smoke + handoff
# or:
./scripts/bayrelay_demo.sh start --yes --smoke           # deploy (~15–25 min first time) + smoke
./scripts/bayrelay_demo.sh status                        # before customer meetings
./scripts/bayrelay_demo.sh stop --yes                    # tear down when finished
```

`start` builds and deploys the **operator portal** by default (`DEPLOY_PORTAL=1`) and ensures the demo user is in `bayrelay-operators`.

### Full cycle (regression / cost control)

```bash
# Start → smoke → destroy (unattended)
./scripts/bayrelay_demo.sh cycle --yes

# Start → smoke → keep running (recommended before customer week)
./scripts/bayrelay_demo.sh cycle --yes --no-teardown

# Smoke only (stack already up)
NO_START=1 ./scripts/bayrelay_demo.sh cycle --yes --no-teardown
# or: ./scripts/bayrelay_demo.sh smoke
```

## Scripts overview

| Script | Purpose |
|--------|---------|
| **[`prepare_customer_demo.sh`](../scripts/prepare_customer_demo.sh)** | **Customer go-live:** start + portal + smoke + handoff |
| **[`bayrelay_demo.sh`](../scripts/bayrelay_demo.sh)** | **Main controller:** start \| stop \| cycle \| status \| smoke \| handoff |
| [`deploy_portal.sh`](../scripts/deploy_portal.sh) | Rebuild SPA + S3/CloudFront + invalidation |
| [`ensure_cognito_demo_user.sh`](../scripts/ensure_cognito_demo_user.sh) | Idempotent demo user + operator/partner group |
| [`preflight_prod.sh`](../scripts/preflight_prod.sh) | Check CLI tools, AWS credentials, `terraform.tfvars` |
| [`demo_start.sh`](../scripts/demo_start.sh) | Preflight → `terraform apply` → Phase 3 KB bootstrap |
| [`run_full_demo.sh`](../scripts/run_full_demo.sh) | Automated API + S3 + SFTP + agent smoke test |
| [`demo_stop.sh`](../scripts/demo_stop.sh) | Empty S3 buckets → `terraform destroy` |
| [`demo_cycle.sh`](../scripts/demo_cycle.sh) | Wrapper → `bayrelay_demo.sh cycle` |

Lower-level (used by the above):

| Script | Purpose |
|--------|---------|
| [`start_stack.sh`](../scripts/start_stack.sh) | `terraform init` + `apply` only |
| [`stop_stack.sh`](../scripts/stop_stack.sh) | `terraform destroy` (requires `BAYRELAY_CONFIRM_PROD_DESTROY=1` for prod) |
| [`bootstrap_phase3.sh`](../scripts/bootstrap_phase3.sh) | KB ingestion + PrepareAgent |
| [`create_cognito_operator.sh`](../scripts/create_cognito_operator.sh) | Create Cognito user for JWT API calls |

---

## Before your first demo

1. **AWS CLI** configured for the target account (`aws sts get-caller-identity`).
2. **Tools:** Terraform >= 1.5, Python 3 + `boto3`, `curl`, `jq`.
   ```bash
   pip install -r tests/requirements.txt
   ```
3. **Bedrock model access** in **us-west-2** for:
   - Chat model in `foundation_model` (default `meta.llama3-1-8b-instruct-v1:0`; Claude 3 Sonnet is often LEGACY/denied)
   - `amazon.titan-embed-text-v1` (KB embeddings)
4. **Config:** `environments/terraform.tfvars` and **`environments/demo.env`** (copy from `demo.env.example`).
5. **Preflight:**
   ```bash
   ./scripts/preflight_prod.sh
   ```

---

## Start demo (provision stack)

### Quick start (recommended)

```bash
cp environments/demo.env.example environments/demo.env   # edit password
./scripts/bayrelay_demo.sh start --yes
```

Or with automated smoke after deploy:

```bash
./scripts/bayrelay_demo.sh start --yes --smoke
```

Legacy equivalent: `./scripts/demo_start.sh --yes`

This runs:

1. Preflight checks  
2. `terraform init` + `apply` (skipped if stack already up — use `FORCE_APPLY=1` to re-apply)  
3. Phase 3: sync `docs/kb` → ingest → PrepareAgent  
4. Prints API URL, buckets, Cognito client ID, and next commands  

**First-time apply** takes ~15–25 minutes (OpenSearch Serverless + Bedrock + Transfer Family).

### Start with a demo Cognito user

JWT is required on the API. Create an operator during start:

```bash
CREATE_DEMO_USER=1 \
  COGNITO_DEMO_USERNAME=demo@yourcompany.com \
  COGNITO_DEMO_PASSWORD='YourDemoPass!123' \
  COGNITO_DEMO_PERMANENT=1 \
  ./scripts/demo_start.sh --yes
```

Or after start:

```bash
./scripts/create_cognito_operator.sh \
  --username demo@yourcompany.com \
  --email demo@yourcompany.com \
  --temporary-password 'YourDemoPass!123' \
  --permanent-password
```

### Keep stack running (no destroy)

After start, the stack stays up until you run `demo_stop.sh`. For a multi-day demo window:

```bash
./scripts/demo_start.sh --yes
# ... customer meetings ...
./scripts/demo_stop.sh --yes
```

---

## Run the demo

### Automated smoke (regression gate)

```bash
export COGNITO_CLIENT_ID="$(terraform -chdir=environments output -raw cognito_client_id)"
export COGNITO_USERNAME="demo@yourcompany.com"
export COGNITO_PASSWORD="YourDemoPass!123"
export AWS_REGION=us-west-2

./scripts/run_full_demo.sh
```

Log file: `/tmp/bayrelay-demo-<timestamp>.log`. Exit code **0** = pass.

Skip Phase 3 checks only if KB is disabled:

```bash
SKIP_KB_PHASE=1 ./scripts/run_full_demo.sh
```

### Full unattended cycle (start → smoke → stop)

```bash
export COGNITO_CLIENT_ID=... COGNITO_USERNAME=... COGNITO_PASSWORD=...
./scripts/demo_cycle.sh --yes
```

Keep stack after automated demo:

```bash
NO_TEARDOWN=1 ./scripts/demo_cycle.sh --yes
```

Stack already running — run demo only:

```bash
NO_START=1 ./scripts/demo_cycle.sh --yes
```

### Customer-facing walkthrough

Use [DEMO.md](DEMO.md) for FileZilla SFTP, curl examples, and agent queries. Show [bayrelay-architecture.png](bayrelay-architecture.png) first.

**Talking order:** Architecture → secured JWT API → register partner → S3→S3 transfer → SFTP inbound → S3→SFTP → agent query with KB citation → CloudWatch / audit.

---

## Stop demo (tear down)

```bash
./scripts/demo_stop.sh --yes
```

This:

1. Empties **versioned** S3 buckets (transfer data + KB source) — required because `force_destroy = false` in prod  
2. Sets `BAYRELAY_CONFIRM_PROD_DESTROY=1`  
3. Runs `terraform destroy -auto-approve`  

Interactive (types `destroy` to confirm):

```bash
./scripts/demo_stop.sh
```

Skip bucket empty (destroy may fail if buckets are non-empty):

```bash
EMPTY_BUCKETS=0 ./scripts/demo_stop.sh --yes
```

---

## Production readiness checklist

Use this before **external customer** demos (not just internal smoke).

| # | Item | How to verify |
|---|------|----------------|
| 1 | Preflight passes | `./scripts/preflight_prod.sh` |
| 2 | Stack applies cleanly | `./scripts/demo_start.sh --yes` |
| 3 | Phase 3 KB ingested | `python3 scripts/test_retrieval.py --expect-substring checksum` |
| 4 | Cognito demo user works | JWT auth in `run_full_demo.sh` |
| 5 | Full smoke green | `./scripts/run_full_demo.sh` exits 0 |
| 6 | **Published Bedrock alias** | Replace `TSTALIASID` in `terraform.tfvars` → re-apply |
| 7 | SNS alarms subscribed | Confirm email on `alarm_topic_arn` |
| 8 | KB content curated | Add real runbooks under `docs/kb/` before `demo_start` |
| 9 | Rehearse live demo | [DEMO.md](DEMO.md) end-to-end once |
| 10 | Remote Terraform state | S3 backend in `environments/versions.tf` (recommended) |

See also [PRODUCTION.md](PRODUCTION.md) and [DEPLOYMENT.md](DEPLOYMENT.md).

---

## Cost notes

While the stack is **running** (`demo_start` without `demo_stop`):

| Service | Billing |
|---------|---------|
| Transfer Family SFTP | Hourly endpoint charge |
| OpenSearch Serverless | OCUs (Phase 3) |
| Bedrock | Per agent query + ingestion |
| Lambda / API Gateway / DynamoDB | Usage-based |

**Always run `demo_stop.sh`** after demo windows unless you intentionally keep prod running 24/7.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `terraform destroy` fails on S3 | Run `./scripts/demo_stop.sh --yes` (empties versioned objects first) |
| API 401 Unauthorized | Set `COGNITO_*` env vars; create user with `create_cognito_operator.sh` |
| Phase 3 / agent query empty | Re-run `SYNC_KB_DOCS=1 ./scripts/bootstrap_phase3.sh` |
| Transfer SFTP fails | See [DEMO_REPORT.md](DEMO_REPORT.md) — connector host keys, IAM trust |
| Stack already up | `demo_start.sh` skips apply; use `FORCE_APPLY=1` to refresh |
| Bedrock model access denied | Enable models in Bedrock console for **us-west-2** |

---

## Quick reference

```bash
# Start
./scripts/demo_start.sh --yes

# Smoke
export COGNITO_CLIENT_ID=$(terraform -chdir=environments output -raw cognito_client_id)
export COGNITO_USERNAME=... COGNITO_PASSWORD=...
AWS_REGION=us-west-2 ./scripts/run_full_demo.sh

# Stop
./scripts/demo_stop.sh --yes

# All-in-one
./scripts/demo_cycle.sh --yes
```
