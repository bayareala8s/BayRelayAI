#!/usr/bin/env bash
# Shared helpers for start_stack / stop_stack / demo_start / demo_stop / demo_cycle.
# shellcheck disable=SC2034  # BAYRELAY_ROOT used by callers after source

BAYRELAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BAYRELAY_TF_DIR="${BAYRELAY_TF_DIR:-$BAYRELAY_ROOT/environments}"
if [[ "$BAYRELAY_TF_DIR" != /* ]]; then
  BAYRELAY_TF_DIR="$BAYRELAY_ROOT/$BAYRELAY_TF_DIR"
fi

bayrelay_tf_raw() {
  local v
  v="$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw "$1" 2>/dev/null)" || true
  # Terraform prints warning banners to stdout when state/outputs are missing.
  if [[ -z "$v" || "$v" == "null" || "$v" == *$'\n'* || "$v" == *'Warning:'* || "$v" == *'╷'* ]]; then
    return 0
  fi
  echo "$v"
}

bayrelay_stack_env_name() {
  local f="$BAYRELAY_TF_DIR/terraform.tfvars"
  if [[ -f "$f" ]]; then
    grep -E '^[[:space:]]*environment[[:space:]]*=' "$f" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*environment[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/' || true
  fi
}

bayrelay_tfvars_region() {
  local f="$BAYRELAY_TF_DIR/terraform.tfvars"
  if [[ -f "$f" ]]; then
    grep -E '^[[:space:]]*aws_region[[:space:]]*=' "$f" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*aws_region[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/' || true
  fi
}

bayrelay_resolve_aws_region() {
  local r="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  if [[ -z "$r" ]]; then
    r="$(bayrelay_tf_raw aws_deployment_region)"
  fi
  if [[ -z "$r" || "$r" == "null" ]]; then
    r="$(bayrelay_tfvars_region)"
  fi
  if [[ -n "$r" && "$r" != "null" ]]; then
    export AWS_REGION="$r"
    export AWS_DEFAULT_REGION="$r"
  fi
  echo "${AWS_REGION:-}"
}

bayrelay_prepend_venv() {
  if [[ -x "$BAYRELAY_ROOT/.venv/bin" ]]; then
    export PATH="$BAYRELAY_ROOT/.venv/bin:$PATH"
  fi
}

bayrelay_require_cmds() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]} > 0)); then
    echo "Missing required commands: ${missing[*]}" >&2
    return 1
  fi
}

bayrelay_stack_is_up() {
  local api
  api="$(bayrelay_tf_raw http_api_public_endpoint)"
  if [[ -z "$api" || "$api" == "null" ]]; then
    api="$(bayrelay_tf_raw http_api_endpoint)"
  fi
  [[ -n "$api" && "$api" != "null" ]]
}

# True when API is deployed AND Step Functions precheck exists (avoids false "up" after partial apply).
bayrelay_stack_is_ready() {
  bayrelay_stack_is_up || return 1
  local precheck
  precheck="$(bayrelay_tf_raw step_function_precheck_arn 2>/dev/null || true)"
  if [[ -n "$precheck" && "$precheck" != "null" ]]; then
    return 0
  fi
  bayrelay_resolve_aws_region >/dev/null
  local prefix
  prefix="$(grep -E '^[[:space:]]*project[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || echo bayrelay)"
  local env
  env="$(bayrelay_stack_env_name)"
  env="${env:-prod}"
  aws stepfunctions describe-state-machine \
    --state-machine-arn "arn:aws:states:${AWS_REGION:-us-west-2}:$(aws sts get-caller-identity --query Account --output text):stateMachine:${prefix}-${env}-sf-transfer-precheck" \
    --region "${AWS_REGION:-us-west-2}" >/dev/null 2>&1
}

bayrelay_empty_s3_bucket() {
  local bucket="$1"
  local region
  region="$(bayrelay_resolve_aws_region)"
  [[ -n "$bucket" && "$bucket" != "null" ]] || return 0

  echo "==> Emptying s3://${bucket}/ (region=${region})"
  local token=""
  while true; do
    local page
    if [[ -n "$token" ]]; then
      page=$(aws s3api list-object-versions --bucket "$bucket" --region "$region" --starting-token "$token" --output json 2>/dev/null || echo '{}')
    else
      page=$(aws s3api list-object-versions --bucket "$bucket" --region "$region" --output json 2>/dev/null || echo '{}')
    fi
    local keys
    keys=$(echo "$page" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for section in ('Versions', 'DeleteMarkers'):
    for o in d.get(section) or []:
        print(o['Key'] + '\t' + o['VersionId'])
" 2>/dev/null || true)
    if [[ -n "$keys" ]]; then
      while IFS=$'\t' read -r key vid; do
        [[ -z "$key" ]] && continue
        aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$vid" --region "$region" >/dev/null
      done <<< "$keys"
    fi
    token=$(echo "$page" | python3 -c "import json,sys; print(json.load(sys.stdin).get('NextToken') or '')" 2>/dev/null || true)
    [[ -z "$token" ]] && break
  done
  aws s3 rm "s3://${bucket}/" --recursive --region "$region" 2>/dev/null || true
}

bayrelay_empty_demo_buckets() {
  bayrelay_resolve_aws_region >/dev/null
  local transfer kb
  transfer="$(bayrelay_tf_raw transfer_data_bucket)"
  kb="$(bayrelay_tf_raw kb_source_bucket)"
  [[ -n "$transfer" && "$transfer" != "null" ]] && bayrelay_empty_s3_bucket "$transfer"
  [[ -n "$kb" && "$kb" != "null" ]] && bayrelay_empty_s3_bucket "$kb"
}

bayrelay_print_demo_outputs() {
  bayrelay_resolve_aws_region >/dev/null
  local api public_api bucket kb_id cognito_client agent_id region alias rel
  public_api="$(bayrelay_tf_raw http_api_public_endpoint)"
  api="$(bayrelay_tf_raw http_api_endpoint)"
  if [[ -z "$public_api" || "$public_api" == "null" ]]; then
    public_api="$api"
  fi
  bucket="$(bayrelay_tf_raw transfer_data_bucket)"
  kb_id="$(bayrelay_tf_raw bedrock_knowledge_base_id)"
  cognito_client="$(bayrelay_tf_raw cognito_client_id)"
  agent_id="$(bayrelay_tf_raw bedrock_agent_id)"
  alias="$(bayrelay_tf_raw bedrock_agent_alias_id)"
  portal_url="$(bayrelay_tf_raw operator_portal_url)"
  [[ -z "$alias" || "$alias" == "null" ]] && alias="TSTALIASID"
  region="${AWS_REGION:-}"
  rel="${BAYRELAY_TF_DIR#"$BAYRELAY_ROOT/"}"

  cat <<EOF

=== BayRelay demo stack ready ===
Region:              ${region}
Public API:          ${public_api:-<not deployed>}
Direct API (debug):  ${api:-<n/a>}
Operator portal:     ${portal_url:-<run: ./scripts/deploy_portal.sh>}
Transfer bucket:     ${bucket:-<n/a>}
KB source bucket:    $(bayrelay_tf_raw kb_source_bucket)
Knowledge base ID:   ${kb_id:-<Phase 3 disabled>}
Bedrock agent ID:    ${agent_id:-<n/a>}
Bedrock alias:       ${alias} $( [[ "$alias" == "TSTALIASID" ]] && echo "(draft — PoC only)" || echo "(production)" )
Cognito client ID:   ${cognito_client:-<JWT disabled>}

Customer demo (portal):
  1. Open operator portal → sign in (demo user in environments/demo.env)
  2. Operational Dashboard — LIVE badge, Overview / Charts toggle
  3. Sidebar: Transfers, Automation, Onboarding, Partners, Assistant
  4. ./scripts/bayrelay_demo.sh smoke — API + all transfer types

Controller:
  ./scripts/bayrelay_demo.sh status
  ./scripts/production_ready.sh
  ./scripts/bayrelay_demo.sh smoke
  ./scripts/deploy_portal.sh
  ./scripts/bayrelay_demo.sh stop --yes

Automated smoke (or use environments/demo.env):
  export COGNITO_CLIENT_ID="${cognito_client}"
  export COGNITO_USERNAME="your-demo-user"
  export COGNITO_PASSWORD="your-password"
  BAYRELAY_TF_DIR=${rel} AWS_REGION=${region} ./scripts/run_full_demo.sh

EOF
}

bayrelay_demo_state_path() {
  echo "$BAYRELAY_TF_DIR/.bayrelay-demo-state"
}

bayrelay_write_demo_state() {
  local state="${1:-unknown}"
  local path
  path="$(bayrelay_demo_state_path)"
  bayrelay_resolve_aws_region >/dev/null
  cat >"$path" <<EOF
state=${state}
updated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
region=${AWS_REGION:-}
api=$(bayrelay_tf_raw http_api_endpoint)
EOF
}

bayrelay_export_cognito_env() {
  if [[ -z "${COGNITO_CLIENT_ID:-}" ]]; then
    local c
    c="$(bayrelay_tf_raw cognito_client_id)"
    [[ -n "$c" && "$c" != "null" ]] && export COGNITO_CLIENT_ID="$c"
  fi
}

bayrelay_production_readiness_hints() {
  local alias
  alias="$(bayrelay_tf_raw bedrock_agent_alias_id)"
  [[ -z "$alias" || "$alias" == "null" ]] && alias="TSTALIASID"
  echo
  echo "--- Readiness hints ---"
  [[ "$alias" == "TSTALIASID" ]] && echo "WARN: draft Bedrock alias — run ./scripts/production_ready.sh --apply"
  if [[ ! -f "$BAYRELAY_TF_DIR/demo.env" ]]; then
    echo "WARN: environments/demo.env missing — copy demo.env.example for smoke credentials."
  fi
  if bayrelay_stack_is_ready; then
    echo "OK:   Stack READY for transfers."
  elif bayrelay_stack_is_up; then
    echo "WARN: Stack partial — missing Step Functions; run start --force --yes"
  fi
  if [[ -n "$(bayrelay_tf_raw operator_portal_url)" ]] && [[ "$(bayrelay_tf_raw operator_portal_url)" != "null" ]]; then
    echo "OK:   Portal URL: $(bayrelay_tf_raw operator_portal_url)"
  else
    echo "WARN: Portal not deployed — run: DEPLOY_PORTAL=1 ./scripts/deploy_portal.sh"
  fi
  echo "Production gate: ./scripts/production_ready.sh"
  echo "PoC demo guide: docs/DEMO_CATALOG.md"
  echo "Portal UI: docs/CUSTOMER_DEMO_READY.md"
}
