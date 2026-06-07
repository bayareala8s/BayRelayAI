# Self-service, automation, and shared portal roles

BayRelay uses **one operator portal** (single CloudFront URL) with **role-based access**:

| Cognito group | Portal experience |
|---------------|-------------------|
| `bayrelay-operators` | Full ops: automation rules, onboarding approve, all partners |
| `bayrelay-partners` | Scoped to `custom:partner_id`: own transfers, submit onboarding, new transfer |

## Terraform flags (`environments/terraform.tfvars`)

| Variable | Default | Purpose |
|----------|---------|---------|
| `enable_transfer_automation` | `true` | S3 EventBridge → `transfer_dispatcher` Lambda |
| `onboarding_auto_approve` | `false` | Onboarding submit immediately provisions partner + endpoints (set `true` for internal demos) |
| `enable_public_onboarding_submit` | `false` | Unauthenticated onboarding (usually keep `false`; partners sign in) |
| `enable_self_service_onboarding` | `true` | Onboarding API + portal wizard |

## Automation

1. Operator creates a **transfer rule** (portal **Automation** or `POST /v1/transfer-rules`).
2. When a new object appears in the **transfer bucket**, EventBridge invokes `transfer_dispatcher`.
3. Matching rules call `submit_transfer` with a stable idempotency key (`auto-{rule_id}-{key}`).

Example S3→S3 rule payload template:

```json
{
  "source_bucket": "{bucket}",
  "source_key": "{key}",
  "dest_bucket": "{bucket}",
  "dest_key": "demo/report-full/outbound/{basename}"
}
```

Placeholders: `{bucket}`, `{key}`, `{basename}`, `{partner_id}`, `{stem}`.

Skipped prefixes (no auto-fire): `sftp-staging/`.

| Transfer type | Trigger | Match pattern example |
|---------------|---------|------------------------|
| S3 → S3 | Any new object in bucket (except skipped prefixes) | `demo/acme/inbound/s3/*` |
| S3 → SFTP | Same | `demo/acme/inbound/sftp/*` |
| SFTP → S3 | Staging object under `sftp-connector/` (after S3 → SFTP) | `sftp-connector/flat-send-*` |
| SFTP → SFTP | Same staging trigger — relay on connector SFTP home | `sftp-connector/flat-send-*` |

SFTP → S3 rules use `remote_paths: ["/{basename}"]` and a `dest_prefix` template. SFTP → SFTP uses `remote_source_paths: ["/{basename}"]` and `remote_dest_directory` (e.g. `/outbound`). Only **SFTP → S3** and **SFTP → SFTP** rules may fire on `sftp-connector/` keys.

Partner uploads via the BayRelay **SFTP server** already land in S3 as `sftp-inbound/…` — automate with **S3 → S3**, not SFTP → S3.

## Partner self-service (same portal)

1. Create partner user:
   ```bash
   ./scripts/create_cognito_operator.sh \
     --username partner@acme.com --email partner@acme.com \
     --temporary-password 'Pass!123' --permanent-password \
     --role partner --partner-id PRT-xxxx
   ```
2. Or: partner signs in → **Apply / onboard** → auto-approve links `custom:partner_id` when email matches Cognito username.
3. Partner uses **My transfers**, **New transfer** (partner locked), **Assistant**.

## API authorization

- `GET /v1/me` — role and `partner_id` for the portal.
- Operators only: ops summary, transfer rules CRUD, approve/reject onboarding, register partners/endpoints.
- Partners: list/get transfers and endpoints for their `partner_id` only; submit transfers for their partner.

## Redeploy

After pulling these changes:

```bash
./scripts/bayrelay_demo.sh start --yes
./scripts/create_cognito_operator.sh --username demo@... --role operator ...
./scripts/deploy_portal.sh
```

Existing demo users without a group are treated as **operators** until added to `bayrelay-operators`.
