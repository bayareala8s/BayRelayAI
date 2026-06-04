# Deployment guide

Single **production** stack: `environments/`.

## Prerequisites

- Terraform >= 1.5, AWS CLI configured for the target account.
- Bedrock model access enabled in **us-west-2** for `foundation_model` and `amazon.titan-embed-text-v1`.
- IAM permissions for KMS, S3, DynamoDB, Lambda, Step Functions, API Gateway, Bedrock, OpenSearch Serverless, IAM, CloudWatch, SNS, Cognito, WAF, Transfer Family.

## Deploy

```bash
cd environments
cp terraform.tfvars.example terraform.tfvars
./scripts/demo_start.sh --yes
```

Manual apply: `terraform init && terraform apply`, then Phase 3 bootstrap — see [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md).

Full checklist: [PRODUCTION.md](PRODUCTION.md).

## Backend state (recommended)

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tf-state-bucket"
    key            = "bayrelay/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## After first Bedrock agent apply

If `InvokeAgent` fails with agent-not-ready, run **Prepare** in the Bedrock console or:

```bash
python3 scripts/prepare_bedrock_agent.py \
  --agent-id "$(terraform -chdir=environments output -raw bedrock_agent_id)" \
  --region us-west-2 --wait
```

Use a **published** alias in `bedrock_agent_alias_id` for live traffic (not `TSTALIASID`).

## Rollback

- **Terraform**: apply a known-good state revision; avoid destroying KMS keys without a migration plan.
- **Application**: redeploy previous Lambda zip via pinned `source_code_hash` or versioned S3 artifacts.

## CI/CD

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs `./scripts/ci_verify.sh`: pytest, `terraform fmt -check`, validate `environments/`. Extend with `terraform plan`, approval gates, `terraform apply`, and post-apply `run_full_demo.sh`.

## Knowledge base (Phase 3)

Enabled by default (`enable_bedrock_vector_kb = true`).

1. **`terraform apply`** — OpenSearch Serverless, KB, data source, agent association.
2. **Sync docs** — `KB_BUCKET=$(terraform -chdir=environments output -raw kb_source_bucket) ./scripts/kb_sync.sh ./docs/kb`
3. **Ingest + PrepareAgent** — `SYNC_KB_DOCS=1 BAYRELAY_TF_DIR=environments AWS_REGION=us-west-2 ./scripts/bootstrap_phase3.sh`
4. **Smoke** — `python3 scripts/test_retrieval.py` and `./scripts/run_full_demo.sh` (with Cognito JWT).

## Production readiness checklist

1. **State & CI**: Remote Terraform backend; `./scripts/ci_verify.sh` on every change.
2. **`terraform.tfvars`**: Published `bedrock_agent_alias_id`; JWT + WAF on; `force_destroy = false` on buckets.
3. **Phase 3**: `bootstrap_phase3.sh` after apply and after KB document changes.
4. **Smoke**: Green `run_full_demo.sh` with Cognito credentials.
5. **Observability**: SNS subscription on `alarm_topic_arn`; [RUNBOOK.md](RUNBOOK.md).

## Destroy

```bash
BAYRELAY_CONFIRM_PROD_DESTROY=1 ./scripts/stop_stack.sh --yes
```
