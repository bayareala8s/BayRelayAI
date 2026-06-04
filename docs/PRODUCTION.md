# Production environment (`environments/`)

BayRelay ships a **single production Terraform stack** in `environments/`. There are no separate dev or test stacks in this repository.

## Stack defaults

| Setting | Default |
|---------|---------|
| `environment` | `prod` |
| `aws_region` | `us-west-2` |
| `enable_api_jwt_auth` | `true` (Cognito JWT on all routes) |
| `enable_waf` | `false` (regional WAF cannot attach to HTTP API v2) |
| `enable_cloudfront_waf` | `true` (edge WAF + public API URL) |
| `bedrock_agent_alias_id` | Published alias (not `TSTALIASID`; use `publish_bedrock_prod_alias.sh`) |
| `enable_bedrock_vector_kb` | `true` (Phase 3 RAG) |
| `enable_transfer_family` | `true` |
| `kb_force_destroy` / bucket force destroy | `false` |

Resource naming: `bayrelay-prod-*` (e.g. `bayrelay-prod-transfer-data-<account_id>`).

## HTTP API routes

All routes require `Authorization: Bearer <id_token>` when JWT is enabled:

- `POST /v1/partners`
- `POST /v1/endpoints`
- `POST /v1/transfers` (header `x-idempotency-key` required)
- `GET /v1/transfers/{id}`
- `POST /v1/agent/query`

## Prerequisites

1. **AWS account** for production workloads.
2. **Terraform** >= 1.5, **AWS CLI** configured.
3. **Remote state** (recommended before first apply):

   ```hcl
   # environments/versions.tf — add inside terraform { } block
   backend "s3" {
     bucket         = "YOUR-org-tf-state"
     key            = "bayrelay/terraform.tfstate"
     region         = "us-west-2"
     dynamodb_table = "terraform-locks"
     encrypt        = true
   }
   ```

4. **Bedrock model access** in `us-west-2`: chat model (`foundation_model`) and `amazon.titan-embed-text-v1`.
5. **Apply host** with outbound SSH for Transfer connector host-key scan, or set `connector_trusted_host_keys` on the Transfer module.

## Deploy

```bash
cd environments
cp terraform.tfvars.example terraform.tfvars
./scripts/demo_start.sh --yes
```

Or manually: `terraform init && terraform apply`, then `SYNC_KB_DOCS=1 ../scripts/bootstrap_phase3.sh`.

**Demo start/stop:** [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md).

## Post-apply (required)

### 1. Published Bedrock agent alias

With `bedrock_agent_alias_id` set to a **published** alias (not `TSTALIASID`), the API uses production agent routing. Create the alias:

```bash
./scripts/publish_bedrock_prod_alias.sh --write-tfvars
terraform -chdir=environments apply -auto-approve
./scripts/ensure_agent_model.sh --prepare
```

### 2. CloudFront + WAF (public API)

Customer traffic should use the CloudFront URL:

```bash
terraform -chdir=environments output -raw http_api_public_endpoint
```

Direct API Gateway URL (`http_api_endpoint`) is for debugging only.

### 3. Cognito operators

```bash
./scripts/create_cognito_operator.sh \
  --username prod-operator@yourcompany.com \
  --email prod-operator@yourcompany.com \
  --temporary-password 'ChangeMe!Temp123'
```

### 4. Phase 3 knowledge base

```bash
export BAYRELAY_TF_DIR=environments AWS_REGION=us-west-2
SYNC_KB_DOCS=1 ./scripts/bootstrap_phase3.sh

KNOWLEDGE_BASE_ID=$(terraform -chdir=environments output -raw bedrock_knowledge_base_id) \
  AWS_REGION=us-west-2 \
  python3 scripts/test_retrieval.py --expect-substring checksum
```

### 5. Observability

Subscribe to `alarm_topic_arn` (SNS). Set `alarm_subscription_emails` in `terraform.tfvars` and confirm inbox subscriptions. See [RUNBOOK.md](RUNBOOK.md).

### 6. Production gate

```bash
./scripts/production_ready.sh
./scripts/production_ready.sh --smoke
```

See [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md).

### 7. Smoke test

```bash
export COGNITO_CLIENT_ID="$(terraform -chdir=environments output -raw cognito_client_id)"
export COGNITO_USERNAME=... COGNITO_PASSWORD=...
BAYRELAY_TF_DIR=environments AWS_REGION=us-west-2 ./scripts/run_full_demo.sh
```

## Calling the API

```bash
API="$(terraform -chdir=environments output -raw http_api_endpoint)"
TOKEN=$(aws cognito-idp initiate-auth --region us-west-2 \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$COGNITO_CLIENT_ID" \
  --auth-parameters "USERNAME=$COGNITO_USERNAME,PASSWORD=$COGNITO_PASSWORD" \
  --query 'AuthenticationResult.IdToken' --output text)

curl -sS -X POST "${API}/v1/transfers" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "x-idempotency-key: $(uuidgen)" \
  -d @samples/transfer_s3_to_s3.json
```

## Customer demos

Use [DEMO.md](DEMO.md) for FileZilla/SFTP and curl examples. Rehearse after a green `run_full_demo.sh`. Do not run `demo_cycle.sh` teardown before customer meetings.

## Teardown (emergency only)

```bash
BAYRELAY_CONFIRM_PROD_DESTROY=1 ./scripts/stop_stack.sh --yes
```

Empty S3 buckets first; `force_destroy` is false by default.

**Customer AWS delivery:** [CUSTOMER_AWS_DEPLOYMENT.md](CUSTOMER_AWS_DEPLOYMENT.md) — prerequisites, phases, handoff, pricing guide.
- [ARCHITECTURE.md](ARCHITECTURE.md) — diagrams
- [DEMO.md](DEMO.md) — hands-on demo steps
