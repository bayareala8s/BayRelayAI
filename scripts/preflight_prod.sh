#!/usr/bin/env bash
# Pre-flight checks before production deploy or demo start.
# Usage: ./scripts/preflight_prod.sh
# Exit 0 when ready; non-zero with actionable errors otherwise.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAYRELAY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

FAIL=0
warn() { echo "WARN: $*" >&2; }
fail() { echo "FAIL: $*" >&2; FAIL=1; }
ok()   { echo "OK:   $*"; }

echo "=== BayRelay preflight (TF_DIR=$BAYRELAY_TF_DIR) ==="

if ! bayrelay_require_cmds terraform aws python3 curl jq; then
  fail "Install missing CLI tools"
else
  ok "CLI tools present (terraform, aws, python3, curl, jq)"
fi

if ! python3 -c "import boto3" 2>/dev/null; then
  if [[ -x "$BAYRELAY_ROOT/.venv/bin/python3" ]] && "$BAYRELAY_ROOT/.venv/bin/python3" -c "import boto3" 2>/dev/null; then
    ok "Python boto3 available (.venv)"
  else
    fail "Python boto3 not installed (pip install -r tests/requirements.txt)"
  fi
else
  ok "Python boto3 available"
fi

if [[ ! -f "$BAYRELAY_TF_DIR/main.tf" ]]; then
  fail "Missing $BAYRELAY_TF_DIR/main.tf"
else
  ok "Terraform stack directory exists"
fi

if [[ ! -f "$BAYRELAY_TF_DIR/terraform.tfvars" ]]; then
  warn "No terraform.tfvars — copy terraform.tfvars.example before apply"
else
  ok "terraform.tfvars present"
  region="$(bayrelay_tfvars_region)"
  model=$(grep -E '^[[:space:]]*foundation_model[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || true)
  alias_id=$(grep -E '^[[:space:]]*bedrock_agent_alias_id[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || true)
  [[ -n "$region" ]] && ok "Configured region: $region"
  [[ -n "$model" ]] && ok "Foundation model: $model"
  if [[ "$alias_id" == "TSTALIASID" ]]; then
    warn "bedrock_agent_alias_id is TSTALIASID (draft) — publish a prod alias before customer demos"
  fi
fi

bayrelay_resolve_aws_region >/dev/null || true
if [[ -z "${AWS_REGION:-}" ]]; then
  fail "Set AWS_REGION or aws_region in terraform.tfvars"
else
  ok "AWS region resolved: $AWS_REGION"
fi

if [[ -f "$BAYRELAY_TF_DIR/terraform.tfvars" ]]; then
  model=$(grep -E '^[[:space:]]*foundation_model[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || true)
  if [[ -n "$model" ]]; then
    bayrelay_prepend_venv
    PY="${BAYRELAY_ROOT}/.venv/bin/python3"
    [[ -x "$PY" ]] || PY=python3
    if ! "$PY" -c "
import boto3, sys
model = sys.argv[1]
region = sys.argv[2]
rt = boto3.client('bedrock-runtime', region_name=region)
if model.startswith('anthropic'):
    import json
    body = json.dumps({'anthropic_version':'bedrock-2023-05-31','max_tokens':5,'messages':[{'role':'user','content':'hi'}]})
    rt.invoke_model(modelId=model, body=body)
elif model.startswith('meta.'):
    import json
    body = json.dumps({'prompt':'hi','max_gen_len':5})
    rt.invoke_model(modelId=model, body=body)
else:
    rt.converse(modelId=model, messages=[{'role':'user','content':[{'text':'hi'}]}], inferenceConfig={'maxTokens':5})
" "$model" "$AWS_REGION" 2>/dev/null; then
      fail "Bedrock model not invokable: $model — enable Model access in console or change foundation_model"
    else
      ok "Bedrock foundation model invokable: $model"
    fi
  fi
fi

if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  fail "AWS credentials not working (aws sts get-caller-identity failed)"
else
  acct=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")
  ok "AWS account: $acct"
fi

if [[ -f "$BAYRELAY_TF_DIR/terraform.tfvars" ]]; then
  if grep -qE '^[[:space:]]*enable_bedrock_vector_kb[[:space:]]*=[[:space:]]*true' "$BAYRELAY_TF_DIR/terraform.tfvars"; then
    ok "Phase 3 KB enabled — ensure Titan embed model access in Bedrock console"
  fi
  if grep -qE '^[[:space:]]*enable_api_jwt_auth[[:space:]]*=[[:space:]]*true' "$BAYRELAY_TF_DIR/terraform.tfvars"; then
    ok "JWT auth enabled — create demo user with create_cognito_operator.sh"
  fi
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Preflight FAILED — fix errors above before demo_start.sh or terraform apply." >&2
  exit 1
fi
echo "Preflight passed."
exit 0
