#!/usr/bin/env bash
# After `terraform apply` with enable_bedrock_vector_kb: ingest S3 documents, then PrepareAgent.
# Requires: AWS credentials, Python 3 + boto3, Terraform outputs populated.
# Usage: BAYRELAY_TF_DIR=environments AWS_REGION=us-west-2 ./scripts/bootstrap_phase3.sh
# Optional: SYNC_KB_DOCS=1 syncs ./docs/kb to kb_source_bucket before ingestion.
# Optional: BAYRELAY_TF_DIR=... (default: repo/environments)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/.venv/bin/python3" ]]; then
  export PATH="$ROOT/.venv/bin:$PATH"
fi
TF_DIR="${BAYRELAY_TF_DIR:-$ROOT/environments}"
if [[ "$TF_DIR" != /* ]]; then
  TF_DIR="$ROOT/$TF_DIR"
fi
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

if [[ -z "$REGION" ]]; then
  echo "Set AWS_REGION (or AWS_DEFAULT_REGION)" >&2
  exit 1
fi

KB_ID=$(terraform -chdir="$TF_DIR" output -raw bedrock_knowledge_base_id)
DS_ID=$(terraform -chdir="$TF_DIR" output -raw bedrock_kb_data_source_id)
AGENT_ID=$(terraform -chdir="$TF_DIR" output -raw bedrock_agent_id)
KB_BUCKET=$(terraform -chdir="$TF_DIR" output -raw kb_source_bucket 2>/dev/null || true)

if [[ "${SYNC_KB_DOCS:-}" == "1" && -n "$KB_BUCKET" && "$KB_BUCKET" != "null" ]]; then
  echo "Syncing $ROOT/docs/kb -> s3://${KB_BUCKET}/"
  KB_BUCKET="$KB_BUCKET" "$ROOT/scripts/kb_sync.sh" "$ROOT/docs/kb"
fi

echo "knowledge_base_id=$KB_ID data_source_id=$DS_ID agent_id=$AGENT_ID region=$REGION"
python3 "$ROOT/scripts/start_kb_ingestion.py" \
  --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" --region "$REGION" --wait
python3 "$ROOT/scripts/prepare_bedrock_agent.py" --agent-id "$AGENT_ID" --region "$REGION" --wait
if [[ -x "$ROOT/.venv/bin/python3" ]]; then
  PY="$ROOT/.venv/bin/python3"
else
  PY=python3
fi
"$PY" "$ROOT/scripts/publish_bedrock_prod_alias.py" --agent-id "$AGENT_ID" --alias-name prod --region "$REGION" >/dev/null 2>&1 || true
echo "Phase 3 bootstrap complete. Smoke: KNOWLEDGE_BASE_ID=$KB_ID AWS_REGION=$REGION python3 $ROOT/scripts/test_retrieval.py --expect-substring checksum"
