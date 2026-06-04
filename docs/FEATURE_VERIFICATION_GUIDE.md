# BayRelay — Feature verification guide (step-by-step)

Use this guide to **prove every implemented feature** works in your AWS account. It maps to `run_full_demo.sh`, the Operator Portal, and AWS Console checks.

**Time:** ~30 min automated smoke + ~60–90 min manual/portal/console (first time).

**Prerequisite:** Stack must be **up**. If you ran `bayrelay_demo.sh stop --yes`, start again first (Section 0).

Related: [DEMO_CATALOG.md](DEMO_CATALOG.md) · [CUSTOMER_DEMO_READY.md](CUSTOMER_DEMO_READY.md) · [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md)

---

## Verification map (quick reference)

| # | Feature | How to verify | Automated in smoke? |
|---|---------|---------------|---------------------|
| 0 | Stack deployed | `bayrelay_demo.sh status` | — |
| 1 | Terraform / IaC | `terraform state list` | — |
| 2 | JWT + Cognito | Token + API call | ✓ (smoke uses JWT) |
| 3 | WAF + CloudFront API | Public URL vs direct API GW | partial |
| 4 | Partners & endpoints | API steps 1–2 | ✓ |
| 5 | S3 → S3 transfer | API steps 3–6 | ✓ |
| 6 | Idempotency | API step 9 | ✓ |
| 7 | Correlation / poll status | API step 5 | ✓ |
| 8 | S3 → SFTP | API steps 11–12 | ✓ |
| 9 | SFTP → S3 | API steps 13–14 | ✓ |
| 10 | SFTP → SFTP | API step 15 | ✓ |
| 11 | Transfer Family connector | AWS CLI step 10 | ✓ |
| 12 | Bedrock agent (NL) | API step 7 | ✓ |
| 13 | Agent tools / trace | API step 8 | ✓ (PoC only if trace enabled) |
| 14 | KB ingest + retrieve | Steps 16–19 | ✓ |
| 15 | Agent + KB policy | API step 20 | ✓ (may WARN ambiguous) |
| 16 | Operations dashboard API | Step 21 | ✓ |
| 17 | Self-service onboarding | Step 22 | ✓ |
| 18 | Operator portal UI | Section 5 (manual) | — |
| 19 | Audit trail | Section 6 (DynamoDB) | — |
| 20 | CloudWatch / SNS | Section 6 (Console) | — |
| 21 | Inbound SFTP (FileZilla) | Section 7 (manual) | — |

---

## Section 0 — Deploy and baseline (required)

### 0.1 Tools and credentials

```bash
cd /path/to/BayRelayAI
aws sts get-caller-identity
./scripts/preflight_prod.sh
```

**Pass:** Account ID printed; preflight exits 0 (Bedrock model access may WARN on draft alias — OK for PoC).

### 0.2 Configure demo credentials

```bash
cp environments/demo.env.example environments/demo.env
# Edit: COGNITO_DEMO_USERNAME, COGNITO_DEMO_PASSWORD, COGNITO_USERNAME, COGNITO_PASSWORD
```

### 0.3 Start stack (first time ~20–30 min)

```bash
./scripts/bayrelay_demo.sh start --yes
```

If redeploying after a prior destroy and Terraform fails on **Secrets Manager** names:

```bash
./scripts/restore_scheduled_secrets.sh
# Import ARNs if script prints instructions, then re-run start
```

Optional: deploy + smoke in one command:

```bash
./scripts/bayrelay_demo.sh start --yes --smoke
```

### 0.4 Confirm stack is READY

```bash
BAYRELAY_TF_DIR=$PWD/environments ./scripts/bayrelay_demo.sh status
```

**Pass:**

- `Stack: READY (API + Step Functions)`
- `Public API:` `https://….cloudfront.net` (not empty)
- `Cognito client ID:` present

### 0.5 Production readiness gate

```bash
./scripts/production_ready.sh
```

**Pass:** `Production readiness: PASSED` (review WARN lines; `TSTALIASID` is OK for PoC).

### 0.6 Deploy Operator Portal (if `enable_operator_portal = true`)

```bash
./scripts/deploy_portal.sh
```

**Pass:** Prints `Operator portal: https://….cloudfront.net`

Save these for later steps:

```bash
export BAYRELAY_TF_DIR=environments
export API_URL=$(terraform -chdir=$BAYRELAY_TF_DIR output -raw http_api_public_endpoint)
export PORTAL_URL=$(terraform -chdir=$BAYRELAY_TF_DIR output -raw operator_portal_url)
export COGNITO_CLIENT_ID=$(terraform -chdir=$BAYRELAY_TF_DIR output -raw cognito_client_id)
export TRANSFER_BUCKET=$(terraform -chdir=$BAYRELAY_TF_DIR output -raw transfer_data_bucket)
export AWS_REGION=us-west-2
source environments/demo.env
```

### 0.7 Get JWT for API tests

```bash
export TOKEN=$(aws cognito-idp initiate-auth --region $AWS_REGION \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$COGNITO_CLIENT_ID" \
  --auth-parameters "USERNAME=$COGNITO_USERNAME,PASSWORD=$COGNITO_PASSWORD" \
  --query 'AuthenticationResult.IdToken' --output text)
echo "Token length: ${#TOKEN}"
```

**Pass:** Token length > 100.

**Fail:** `NotAuthorizedException` → reset password:

```bash
./scripts/create_cognito_operator.sh \
  --username "$COGNITO_USERNAME" \
  --email "$COGNITO_DEMO_EMAIL" \
  --temporary-password "$COGNITO_PASSWORD" \
  --permanent-password
```

---

## Section 1 — Automated full regression (fastest path)

Runs all API transfer paths, KB, ops, and onboarding.

```bash
cd /path/to/BayRelayAI
set -a && source environments/demo.env && set +a
export BAYRELAY_TF_DIR=environments
export COGNITO_CLIENT_ID=$(terraform -chdir=$BAYRELAY_TF_DIR output -raw cognito_client_id)
./scripts/run_full_demo.sh 2>&1 | tee /tmp/bayrelay-verify-smoke.log
echo "Exit code: $?"
```

**Pass:** Exit code **0** and log ends with `=== Demo finished RUN_ID=... ===`

**Inspect failures:**

```bash
grep -E 'FAIL|WARN' /tmp/bayrelay-verify-smoke.log
```

| Step | What it proves |
|------|----------------|
| 1–2 | Partner + endpoint registration |
| 3–6 | S3→S3 + destination object |
| 5 | Status polling → `SUCCEEDED` |
| 7–8 | Bedrock agent |
| 9 | Idempotency (`deduplicated` or same request) |
| 11–15 | Connector transfer types (if Transfer Family deployed) |
| 16–20 | KB sync, ingest, retrieve, agent policy |
| 21 | `GET /v1/ops/summary` |
| 22 | Onboarding create + approve |

**Known acceptable WARN:** Step 20 agent KB answer may be ambiguous while KB retrieve (step 19) passes.

---

## Section 2 — API verification (manual, feature-by-feature)

Use the same `API_URL`, `TOKEN`, `TRANSFER_BUCKET` from Section 0.

Helper (add to your shell):

```bash
api_post() { curl -sS -X POST "$1" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${@:2}"; }
api_get() { curl -sS -H "Authorization: Bearer $TOKEN" "$1"; }
```

### 2.1 Partners (`POST` / `GET /v1/partners`)

```bash
api_post "$API_URL/v1/partners" \
  -d '{"name":"Verify Partner Manual","metadata":{"test":"manual"}}' | jq .
api_get "$API_URL/v1/partners" | jq '{count, first: .partners[0].partner_id}'
```

**Pass:** `partner_id` like `PRT-…`; list returns `count >= 1`.

### 2.2 Endpoints (`POST` / `GET /v1/endpoints`)

```bash
export PARTNER_ID=<from above>
api_post "$API_URL/v1/endpoints" \
  -d "{\"partner_id\":\"$PARTNER_ID\",\"protocol\":\"S3\",\"direction\":\"INBOUND\"}" | jq .
api_get "$API_URL/v1/endpoints?partner_id=$PARTNER_ID" | jq .
```

**Pass:** Two endpoint IDs (INBOUND + OUTBOUND if you create both).

### 2.3 S3 → S3 transfer

```bash
export EPT_IN=<inbound endpoint_id>
export EPT_OUT=<outbound endpoint_id>
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
SRC="demo/verify/in-$RUN_ID.txt"
DST="demo/verify/out-$RUN_ID.txt"
echo "verify $RUN_ID" | aws s3 cp - "s3://$TRANSFER_BUCKET/$SRC" --region $AWS_REGION

SUBMIT=$(api_post "$API_URL/v1/transfers" \
  -H "X-Idempotency-Key: verify-s3-$RUN_ID" \
  -H "X-Correlation-Id: verify-$RUN_ID" \
  -d "{\"partner_id\":\"$PARTNER_ID\",\"source_endpoint_id\":\"$EPT_IN\",\"target_endpoint_id\":\"$EPT_OUT\",\"transfer_type\":\"S3_TO_S3\",\"payload\":{\"source_bucket\":\"$TRANSFER_BUCKET\",\"source_key\":\"$SRC\",\"dest_bucket\":\"$TRANSFER_BUCKET\",\"dest_key\":\"$DST\"}}")
echo "$SUBMIT" | jq .
export REQ_ID=$(echo "$SUBMIT" | jq -r .request_id)
```

Poll until `SUCCEEDED` (up to ~2 min):

```bash
for i in $(seq 1 24); do
  ST=$(api_get "$API_URL/v1/transfers/$REQ_ID" | jq -r '.transfer_request.status')
  echo "poll $i: $ST"
  [[ "$ST" == "SUCCEEDED" ]] && break
  [[ "$ST" == "FAILED" ]] && exit 1
  sleep 5
done
aws s3 cp "s3://$TRANSFER_BUCKET/$DST" - --region $AWS_REGION
```

**Pass:** Status `SUCCEEDED`; destination file content matches.

### 2.4 List transfers

```bash
api_get "$API_URL/v1/transfers?limit=10" | jq '{count, ids: [.transfers[].request_id]}'
```

**Pass:** `count >= 1` and includes `$REQ_ID`.

### 2.5 Idempotency

Repeat the **same** `POST /v1/transfers` with the **same** `X-Idempotency-Key` as step 2.3.

**Pass:** Response includes `deduplicated: true` or same `request_id` without a second execution.

### 2.6 Unauthorized access (JWT)

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "$API_URL/v1/transfers"
```

**Pass:** `401` (when JWT auth enabled).

### 2.7 Agent query

```bash
api_post "$API_URL/v1/agent/query" \
  -d '{"query":"What are the four BayRelay transfer_type values? Reply briefly."}' | jq '{request_id, agent_response}'
```

**Pass:** Non-empty `agent_response`.

### 2.8 Operations dashboard API

```bash
api_get "$API_URL/v1/ops/summary" | jq '{health, counts, recent: .recent_transfers | length}'
```

**Pass:** `health` is `healthy`, `attention`, or `busy`; `counts.partners >= 0`; not HTTP 500.

### 2.9 Self-service onboarding

```bash
ONB=$(api_post "$API_URL/v1/onboarding/requests" \
  -d '{"company_name":"Verify Co","contact_email":"verify@test.com","transfer_types":["S3_TO_S3"]}')
echo "$ONB" | jq .
export ONB_ID=$(echo "$ONB" | jq -r '.onboarding_request.request_id')

api_get "$API_URL/v1/onboarding/requests?status=SUBMITTED" | jq '.count'

APPROVE=$(api_post "$API_URL/v1/onboarding/requests/$ONB_ID/approve" -d '{}')
echo "$APPROVE" | jq '{status, partner_id, endpoint_ids}'
```

**Pass:** Create returns `status: SUBMITTED`; approve returns `APPROVED` + `partner_id` + `endpoint_ids`.

**Reject path (optional):**

```bash
ONB2=$(api_post "$API_URL/v1/onboarding/requests" -d '{"company_name":"Reject Test"}')
ID2=$(echo "$ONB2" | jq -r '.onboarding_request.request_id')
api_post "$API_URL/v1/onboarding/requests/$ID2/reject" \
  -d '{"reason":"Verification test"}' | jq .
```

### 2.10 Connector transfers (S3→SFTP, SFTP→S3, SFTP→SFTP)

Only if `enable_transfer_family = true` and smoke steps 11–15 passed. Re-run smoke or copy payloads from [DEMO.md](DEMO.md) / `run_full_demo.sh` steps 11–15.

---

## Section 3 — Operator Portal verification (UI)

Open `PORTAL_URL` from Section 0.6. Sign in with `demo.env` credentials.

| Step | Nav / route | Action | Pass criteria |
|------|-------------|--------|---------------|
| 3.1 | Login | `/login` | Lands on Operations home after sign-in |
| 3.2 | Operations | `/` | Health banner, KPI cards, status bars populate |
| 3.3 | Refresh | Operations → **Refresh** | Data updates; no error toast |
| 3.4 | Transfers | `/transfers` | Table shows prior smoke/manual transfers |
| 3.5 | Transfer detail | Click a request ID | Detail page loads; status badge |
| 3.6 | New transfer | `/transfers/new` | Select partner/endpoints, buckets/keys, submit |
| 3.7 | After submit | Redirect | Detail or transfers list; status progresses to Succeeded |
| 3.8 | New customer | `/onboarding/new` | Complete 3-step wizard → submit |
| 3.9 | Onboarding inbox | `/onboarding` | New request visible; **Approve** creates partner |
| 3.10 | Partners | `/partners` | Approved partner + endpoints listed |
| 3.11 | Assistant | `/agent` | Send policy question; agent reply appears |

**Browser devtools (optional):** Network tab shows API calls to `http_api_public_endpoint` with `Authorization: Bearer …` and 200 responses.

**Blank portal:** Re-run `./scripts/deploy_portal.sh` (build embeds API URL at compile time).

---

## Section 4 — AWS Console verification (infrastructure)

Region: **us-west-2** (unless you changed `terraform.tfvars`).

| Service | What to find | Proves |
|---------|--------------|--------|
| **CloudFormation / Resource Groups** | Tag `Project=bayrelay` | Resources tagged |
| **API Gateway** | HTTP API `bayrelay-prod` | Control plane API |
| **Lambda** | `bayrelay-prod-api`, `-workflow`, `-agent-tools` | Compute |
| **Step Functions** | `bayrelay-prod-sf-*` (5 state machines) | Orchestration |
| **DynamoDB** | Tables `bayrelay-prod-*` (partners, endpoints, transfers, audit, onboarding, …) | Data layer |
| **S3** | `bayrelay-prod-transfer-data-*`, `bayrelay-kb-source-*` | Storage |
| **Cognito** | User pool; demo user | Auth |
| **CloudFront** | Distributions for API + portal | Edge |
| **WAF** | Global Web ACL `bayrelay-prod-api-edge` (us-east-1) | Edge protection |
| **Transfer Family** | Server + connector | Phase 2 |
| **Bedrock** | Agent + Knowledge base | Phase 3 |
| **OpenSearch Serverless** | Collection `bayrelay-prod-vs` | Vector store |
| **SNS** | Topic `bayrelay-prod-alarms` | Alarms |
| **KMS** | Customer-managed key | Encryption |

### Step Functions (single transfer trace)

1. Step Functions → State machines → `bayrelay-prod-sf-transfer-precheck`.
2. Executions → find execution matching your `REQ_ID` / `EX-…` from API response.
3. **Pass:** Execution completes **Succeeded**; graph shows precheck → workflow path.

### DynamoDB audit (onboarding)

1. DynamoDB → `bayrelay-prod-audit-events` → Explore items.
2. **Pass:** Items with `action` = `onboarding_submitted` / `onboarding_approved` after portal/API onboarding tests.

---

## Section 5 — Security feature verification

| Check | Steps | Pass |
|-------|-------|------|
| JWT required | API call without `Authorization` → 401 | ✓ |
| WAF on public URL | Use `http_api_public_endpoint` (CloudFront), not raw API GW URL in production story | ✓ |
| KMS encryption | S3 object `head-object` shows `SSE` / KMS | ✓ |
| Trace header off in prod | `allow_agent_trace_header = false` in tfvars; trace step may be skipped in prod demos | ✓ |
| No secrets in portal | View page source / network — no AWS keys in JS bundle | ✓ |

---

## Section 6 — Inbound SFTP (FileZilla) — manual

From terraform outputs:

```bash
terraform -chdir=environments output sftp_server_endpoint
terraform -chdir=environments output sftp_inbound_username
# Private key: Secrets Manager (sensitive output sftp_inbound_private_key_secret_arn)
```

1. Retrieve private key from Secrets Manager (Console or CLI).
2. FileZilla: SFTP, server endpoint, username, key file.
3. Upload a test file.
4. **Pass:** Object appears under expected prefix in transfer bucket (see [DEMO_CATALOG.md](DEMO_CATALOG.md) Demo J).

---

## Section 7 — Feature flags (what is enabled in your deploy)

Check `environments/terraform.tfvars`:

| Variable | If `true` | Verify |
|----------|-----------|--------|
| `enable_api_jwt_auth` | Cognito JWT | Section 2.6 |
| `enable_transfer_family` | SFTP + connector | Smoke 11–15, Section 6 |
| `enable_bedrock_vector_kb` | KB + RAG | Smoke 16–20 |
| `enable_cloudfront_waf` | Edge WAF | CloudFront URL |
| `enable_operator_portal` | Portal | Section 3 |
| `enable_self_service_onboarding` | Onboarding API + UI | Section 2.9, 3.8–3.9 |

---

## Section 8 — Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `status` says READY but API 404 | Stale state / partial destroy | `terraform state list`; re-run `start --yes` |
| `GET /v1/ops/summary` 500 | Lambda not updated / IAM | `terraform apply`; check `/aws/lambda/bayrelay-prod-api` logs |
| Portal blank | Missing Vite env at build | `./scripts/deploy_portal.sh` |
| Smoke step 20 WARN | Agent phrasing | OK if step 19 retrieve passes |
| Transfer stays SUBMITTED | SFN/Lambda error | Step Functions execution → failed state; CloudWatch logs |
| Cognito auth fails | User not created / temp password | `create_cognito_operator.sh --permanent-password` |
| Destroy fails on secrets | Scheduled deletion | `./scripts/restore_scheduled_secrets.sh` |
| Destroy fails boto3 | Bedrock hook | Use repo `modules/bedrock_agent` with `.venv` python (fixed in repo) |

---

## Section 9 — Sign-off checklist

Print and tick when verifying for a customer demo:

```
[ ] 0. Stack READY + production_ready.sh PASSED
[ ] 1. run_full_demo.sh exit 0
[ ] 2. Manual: partner, endpoint, S3→S3, list, idempotency
[ ] 3. Portal: Operations, Transfers, New transfer, Onboarding, Partners, Agent
[ ] 4. Console: Step Functions execution Succeeded
[ ] 5. ops/summary + onboarding API OK
[ ] 6. (Optional) FileZilla inbound SFTP
[ ] 7. CUSTOMER_DEMO_READY.md URLs updated from terraform output
```

---

## Section 10 — After verification

- **Keep stack for demo:** Do not run `stop --yes`.
- **Save outputs:** `./scripts/customer_handoff.sh`
- **Teardown:** `./scripts/bayrelay_demo.sh stop --yes` (stops AWS charges)
