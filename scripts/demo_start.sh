#!/usr/bin/env bash
# Start the BayRelay stack for a customer demo (apply + Phase 3 bootstrap + output cheat sheet).
#
# Usage (repo root):
#   ./scripts/demo_start.sh --yes
#   CREATE_DEMO_USER=1 COGNITO_DEMO_USERNAME=demo@example.com \
#     COGNITO_DEMO_PASSWORD='DemoPass!Change1' ./scripts/demo_start.sh --yes
#
# Skips terraform apply if stack is already up (http_api_endpoint exists). Force re-apply:
#   FORCE_APPLY=1 ./scripts/demo_start.sh --yes
#
# Env:
#   BOOTSTRAP_PHASE3=1 (default) — KB sync + ingest + PrepareAgent after apply
#   SYNC_KB_DOCS=1 (default when bootstrapping) — sync ./docs/kb before ingestion
#   SKIP_PREFLIGHT=1 — skip preflight_prod.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

AUTO_APPROVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) AUTO_APPROVE=true; shift ;;
    -h | --help)
      cat <<'EOF'
Start BayRelay for a demo: preflight → terraform apply → Phase 3 bootstrap → print outputs.

  ./scripts/demo_start.sh --yes
  FORCE_APPLY=1 ./scripts/demo_start.sh --yes
  CREATE_DEMO_USER=1 COGNITO_DEMO_USERNAME=demo@co.com COGNITO_DEMO_PASSWORD='...' ./scripts/demo_start.sh --yes

See docs/DEMO_LIFECYCLE.md
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

export BAYRELAY_TF_DIR
BOOTSTRAP_PHASE3="${BOOTSTRAP_PHASE3:-1}"
SYNC_KB_DOCS="${SYNC_KB_DOCS:-$([[ "$BOOTSTRAP_PHASE3" == "1" ]] && echo 1 || echo 0)}"

if [[ -f "$BAYRELAY_TF_DIR/demo.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$BAYRELAY_TF_DIR/demo.env"
  set +a
fi

bayrelay_prepend_venv

if [[ "${SKIP_PREFLIGHT:-0}" != "1" ]]; then
  "$BAYRELAY_ROOT/scripts/preflight_prod.sh"
fi

bayrelay_resolve_aws_region >/dev/null
if [[ "${RESTORE_SFTP_SECRETS:-1}" == "1" ]]; then
  "$BAYRELAY_ROOT/scripts/restore_scheduled_secrets.sh" 2>/dev/null || true
fi

if bayrelay_stack_is_ready && [[ "${FORCE_APPLY:-0}" != "1" ]]; then
  echo "==> Stack ready (API + Step Functions). Skipping terraform apply."
  echo "    Use FORCE_APPLY=1 or --force to re-apply."
elif bayrelay_stack_is_up && [[ "${FORCE_APPLY:-0}" != "1" ]]; then
  echo "==> Stack partially deployed (API up, Step Functions missing). Running terraform apply..."
  export BOOTSTRAP_PHASE3=0
  export SYNC_KB_DOCS=0
  if $AUTO_APPROVE; then
    TF_AUTO_APPROVE=1 "$BAYRELAY_ROOT/scripts/start_stack.sh" --yes
  else
    "$BAYRELAY_ROOT/scripts/start_stack.sh"
  fi
else
  if $AUTO_APPROVE; then
    TF_AUTO_APPROVE=1 BOOTSTRAP_PHASE3="${BOOTSTRAP_PHASE3:-1}" SYNC_KB_DOCS="${SYNC_KB_DOCS:-1}" \
      "$BAYRELAY_ROOT/scripts/start_stack.sh" --yes
  else
    BOOTSTRAP_PHASE3="${BOOTSTRAP_PHASE3:-1}" SYNC_KB_DOCS="${SYNC_KB_DOCS:-1}" \
      "$BAYRELAY_ROOT/scripts/start_stack.sh"
  fi
fi

if [[ "$BOOTSTRAP_PHASE3" == "1" ]]; then
  kb_id="$(bayrelay_tf_raw bedrock_knowledge_base_id)"
  if [[ -n "$kb_id" && "$kb_id" != "null" ]]; then
    echo "==> Phase 3 bootstrap (SYNC_KB_DOCS=${SYNC_KB_DOCS})"
    export SYNC_KB_DOCS
    BAYRELAY_TF_DIR="$BAYRELAY_TF_DIR" AWS_REGION="${AWS_REGION:-}" \
      "$BAYRELAY_ROOT/scripts/bootstrap_phase3.sh"
  else
    echo "WARN: enable_bedrock_vector_kb appears false — skipping Phase 3 bootstrap." >&2
  fi
fi

if [[ "${CREATE_DEMO_USER:-0}" == "1" ]]; then
  u="${COGNITO_DEMO_USERNAME:-demo-operator@example.com}"
  p="${COGNITO_DEMO_PASSWORD:-}"
  if [[ -z "$p" ]]; then
    echo "WARN: CREATE_DEMO_USER=1 but COGNITO_DEMO_PASSWORD unset — skipping user creation." >&2
  else
    export COGNITO_DEMO_USERNAME="$u"
    export COGNITO_DEMO_PASSWORD="$p"
    export COGNITO_DEMO_EMAIL="${COGNITO_DEMO_EMAIL:-$u}"
    export COGNITO_DEMO_ROLE="${COGNITO_DEMO_ROLE:-operator}"
    "$BAYRELAY_ROOT/scripts/ensure_cognito_demo_user.sh"
    echo "Demo Cognito user: $u (role=${COGNITO_DEMO_ROLE:-operator})"
  fi
fi

if [[ "${SYNC_CONNECTOR_HOST_KEY:-1}" == "1" ]] && bayrelay_stack_is_up; then
  conn="$(bayrelay_tf_raw transfer_connector_id)"
  if [[ -n "$conn" && "$conn" != "null" ]]; then
    synced=false
    for attempt in 1 2 3 4 5; do
      if "$BAYRELAY_ROOT/scripts/sync_connector_trusted_host_key.sh"; then
        synced=true
        break
      fi
      echo "WARN: connector host key sync attempt $attempt failed — retrying in 15s..." >&2
      sleep 15
    done
    if [[ "$synced" != true ]]; then
      echo "WARN: connector host key sync failed — S3→SFTP may fail until fixed." >&2
    fi
  fi
fi

DEPLOY_PORTAL="${DEPLOY_PORTAL:-1}"
if [[ "$DEPLOY_PORTAL" == "1" ]] && bayrelay_stack_is_up; then
  portal_enabled="$(grep -E '^[[:space:]]*enable_operator_portal[[:space:]]*=[[:space:]]*true' \
    "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null || true)"
  if [[ -n "$portal_enabled" ]]; then
    echo "==> Building and deploying operator portal (DEPLOY_PORTAL=1)"
    BAYRELAY_TF_DIR="$BAYRELAY_TF_DIR" "$BAYRELAY_ROOT/scripts/deploy_portal.sh"
  else
    echo "WARN: enable_operator_portal=false — skipping portal deploy." >&2
  fi
fi

bayrelay_print_demo_outputs
echo "OK: demo_start.sh finished"

if [[ "${ENSURE_AGENT_MODEL:-1}" == "1" ]]; then
  agent_id="$(bayrelay_tf_raw bedrock_agent_id)"
  if [[ -n "$agent_id" && "$agent_id" != "null" ]]; then
    echo "==> Ensure Bedrock agent foundation model (terraform.tfvars)"
    "$SCRIPT_DIR/ensure_agent_model.sh" --prepare || echo "WARN: ensure_agent_model failed — enable Bedrock model access" >&2
  fi
fi

alias_id="$(grep -E '^[[:space:]]*bedrock_agent_alias_id' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || true)"
if [[ "$alias_id" == "TSTALIASID" ]]; then
  echo "==> Publishing production Bedrock alias (replaces TSTALIASID)"
  "$SCRIPT_DIR/publish_bedrock_prod_alias.sh" --write-tfvars || true
  echo "==> Re-apply Lambda env with new alias: terraform apply (api lambda only)"
  terraform -chdir="$BAYRELAY_TF_DIR" apply -auto-approve -target=aws_lambda_function.api 2>/dev/null || true
fi
