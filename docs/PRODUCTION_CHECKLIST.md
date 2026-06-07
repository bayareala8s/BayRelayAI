# Production readiness checklist

Use before **Production Launch** go-live or external customer access. Automated gate: `./scripts/production_ready.sh`.

## 1. Terraform (`environments/terraform.tfvars`)

| Setting | Production value |
|---------|------------------|
| `enable_api_jwt_auth` | `true` |
| `enable_cloudfront_waf` | `true` (edge WAF; required for API Gateway HTTP API) |
| `bedrock_agent_alias_id` | Published via `publish_bedrock_prod_alias.sh` (not `TSTALIASID`) |
| `allow_agent_trace_header` | `false` |
| `onboarding_auto_approve` | `false` |
| `enable_public_onboarding_submit` | `false` |
| `enable_operator_portal` | `true` |
| `kb_force_destroy` | `false` |
| `transfer_data_bucket_force_destroy` | `false` |
| `foundation_model` | Model enabled in Bedrock Model access (account-specific) |
| `alarm_subscription_emails` | Ops distribution list |

```bash
cd environments
terraform init
terraform apply -auto-approve
```

## 2. Bedrock

- [ ] **Model access** enabled in console for `foundation_model` and `amazon.titan-embed-text-v1`
- [ ] Agent **PREPARED** after KB changes: `./scripts/bootstrap_phase3.sh`
- [ ] Production alias (not `TSTALIASID`): `terraform output bedrock_agent_alias_id`
- [ ] `./scripts/ensure_agent_model.sh --prepare` exits 0

## 3. Cognito operators

```bash
./scripts/create_cognito_operator.sh \
  --username prod-operator@yourcompany.com \
  --email prod-operator@yourcompany.com \
  --temporary-password '...' \
  --permanent-password
```

## 4. Knowledge base

- [ ] Curated docs in `docs/kb/` (no secrets)
- [ ] `SYNC_KB_DOCS=1 ./scripts/bootstrap_phase3.sh`
- [ ] `python3 scripts/test_retrieval.py --expect-substring checksum`

## 5. Observability

- [ ] Confirm **SNS email** subscriptions for `alarm_subscription_emails`
- [ ] `terraform output alarm_topic_arn` subscribed in PagerDuty/Opsgenie (optional)

## 6. Validation

```bash
./scripts/production_ready.sh        # checklist
./scripts/production_ready.sh --smoke   # full E2E (exit 0)
./scripts/customer_handoff.sh      # handoff artifact
```

## 7. Customer-facing URL

Use **`http_api_public_endpoint`** (CloudFront + WAF), not the direct API Gateway URL:

```bash
terraform -chdir=environments output -raw http_api_public_endpoint
```

## PoC vs Production

| Item | PoC ($24k) | Production ($42k) |
|------|------------|---------------------|
| Draft alias `TSTALIASID` | OK | Replace with prod alias |
| Direct API Gateway URL | OK for internal demo | Use CloudFront public URL |
| Edge WAF | Optional | Required |
| SNS alarm emails | Optional | Required |
| Remote Terraform state | Recommended | Required for teams |

See [PRODUCTION.md](PRODUCTION.md), [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md).
