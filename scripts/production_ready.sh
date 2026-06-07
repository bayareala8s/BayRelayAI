#!/usr/bin/env bash
# Production readiness gate — run before customer go-live or Production Launch handoff.
#
# Usage:
#   ./scripts/production_ready.sh           # checklist only
#   ./scripts/production_ready.sh --apply   # terraform apply production flags + bootstrap
#   ./scripts/production_ready.sh --smoke   # checklist + full smoke test

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

DO_APPLY=false
DO_SMOKE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) DO_APPLY=true; shift ;;
    --smoke) DO_SMOKE=true; shift ;;
    -h | --help)
      cat <<'EOF'
Production readiness for BayRelay (environments/ stack).

  ./scripts/production_ready.sh              Report PASS/WARN/FAIL checks
  ./scripts/production_ready.sh --apply      terraform apply + agent model + Phase 3
  ./scripts/production_ready.sh --smoke        Checks then bayrelay_demo.sh smoke

Configure environments/terraform.tfvars:
  bedrock_create_production_alias = true
  enable_cloudfront_waf           = true
  alarm_subscription_emails       = ["ops@company.com"]

See docs/PRODUCTION_CHECKLIST.md
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

FAIL=0
warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; FAIL=1; }
ok()   { echo "OK:   $*"; }

echo "=== BayRelay production readiness ==="
echo "TF_DIR: $BAYRELAY_TF_DIR"
echo

"$SCRIPT_DIR/preflight_prod.sh" || FAIL=1

bayrelay_resolve_aws_region >/dev/null

if ! bayrelay_stack_is_ready; then
  fail "Stack not READY (deploy with: ./scripts/bayrelay_demo.sh start --yes)"
else
  ok "Stack READY (API + Step Functions)"
fi

tfvars="$BAYRELAY_TF_DIR/terraform.tfvars"
if [[ -f "$tfvars" ]]; then
  grep -qE '^[[:space:]]*enable_api_jwt_auth[[:space:]]*=[[:space:]]*true' "$tfvars" && ok "JWT auth enabled" || fail "enable_api_jwt_auth must be true"
  grep -qE '^[[:space:]]*enable_cloudfront_waf[[:space:]]*=[[:space:]]*true' "$tfvars" && ok "CloudFront + edge WAF enabled" || warn "enable_cloudfront_waf=false — no edge WAF (HTTP API cannot use regional WAF)"
  if grep -qE '^[[:space:]]*bedrock_agent_alias_id[[:space:]]*=[[:space:]]*"TSTALIASID"' "$tfvars" 2>/dev/null; then
    warn "bedrock_agent_alias_id is TSTALIASID — run: ./scripts/publish_bedrock_prod_alias.sh --write-tfvars"
  else
    ok "Non-draft Bedrock alias configured in terraform.tfvars"
  fi
  grep -qE '^[[:space:]]*allow_agent_trace_header[[:space:]]*=[[:space:]]*false' "$tfvars" && ok "Agent trace header disabled" || warn "allow_agent_trace_header should be false in production"
  if grep -qE '^[[:space:]]*onboarding_auto_approve[[:space:]]*=[[:space:]]*true' "$tfvars"; then
    warn "onboarding_auto_approve=true — use false for customer production (demo only)"
  else
    ok "Manual onboarding approval (onboarding_auto_approve=false or unset)"
  fi
  if grep -qE '^[[:space:]]*enable_public_onboarding_submit[[:space:]]*=[[:space:]]*true' "$tfvars"; then
    warn "enable_public_onboarding_submit=true — keep false in production"
  else
    ok "Public onboarding submit disabled"
  fi
  grep -qE '^[[:space:]]*enable_operator_portal[[:space:]]*=[[:space:]]*true' "$tfvars" && ok "Operator portal enabled" || warn "enable_operator_portal=false — no customer portal URL"
  grep -qE '^[[:space:]]*enable_transfer_automation[[:space:]]*=[[:space:]]*true' "$tfvars" && ok "Transfer automation enabled" || warn "enable_transfer_automation=false"
  grep -qE '^[[:space:]]*enable_self_service_onboarding[[:space:]]*=[[:space:]]*true' "$tfvars" && ok "Self-service onboarding enabled" || warn "enable_self_service_onboarding=false"
  if grep -qE '^[[:space:]]*transfer_data_bucket_force_destroy[[:space:]]*=[[:space:]]*true' "$tfvars"; then
    fail "transfer_data_bucket_force_destroy must be false in production"
  else
    ok "Transfer bucket force_destroy disabled"
  fi
fi

alias_id="$(bayrelay_tf_raw bedrock_agent_alias_id)"
if [[ "$alias_id" == "TSTALIASID" ]]; then
  warn "Bedrock alias is still TSTALIASID — enable bedrock_create_production_alias and apply"
elif [[ -n "$alias_id" && "$alias_id" != "null" ]]; then
  ok "Bedrock agent alias: $alias_id"
fi

public_api="$(bayrelay_tf_raw http_api_public_endpoint)"
direct_api="$(bayrelay_tf_raw http_api_endpoint)"
if [[ -n "$public_api" && "$public_api" != "null" ]]; then
  ok "Public API: $public_api"
  [[ "$public_api" != "$direct_api" ]] && ok "Edge URL differs from direct API Gateway (WAF path)"
fi

alarm_arn="$(bayrelay_tf_raw alarm_topic_arn)"
[[ -n "$alarm_arn" && "$alarm_arn" != "null" ]] && ok "SNS alarms topic: $alarm_arn" || warn "No alarm topic output"

if [[ -f "$BAYRELAY_TF_DIR/demo.env" ]]; then
  ok "demo.env present (smoke credentials)"
else
  warn "environments/demo.env missing — copy demo.env.example for smoke"
fi

agent_id="$(bayrelay_tf_raw bedrock_agent_id)"
if [[ -n "$agent_id" && "$agent_id" != "null" ]]; then
  bayrelay_prepend_venv
  if "$BAYRELAY_ROOT/.venv/bin/python3" "$SCRIPT_DIR/ensure_agent_model.py" \
    --agent-id "$agent_id" \
    --model "$(grep -E '^[[:space:]]*foundation_model' "$tfvars" | head -1 | sed -E 's/.*"([^"]*)".*/\1/')" \
    --region "${AWS_REGION:-us-west-2}" 2>/dev/null; then
    ok "Bedrock InvokeAgent smoke passed"
  else
    warn "Bedrock InvokeAgent smoke failed — run: ./scripts/ensure_agent_model.sh --prepare"
  fi
fi

echo
if [[ "$DO_APPLY" == true ]]; then
  echo "==> Applying production Terraform (CloudFront WAF, prod alias, alarms)..."
  terraform -chdir="$BAYRELAY_TF_DIR" init -input=false
  terraform -chdir="$BAYRELAY_TF_DIR" apply -auto-approve
  "$SCRIPT_DIR/ensure_agent_model.sh" --prepare || true
  if [[ -f "$tfvars" ]] && grep -qE 'enable_bedrock_vector_kb[[:space:]]*=[[:space:]]*true' "$tfvars"; then
    SYNC_KB_DOCS=1 BAYRELAY_TF_DIR="$BAYRELAY_TF_DIR" AWS_REGION="${AWS_REGION:-}" \
      "$BAYRELAY_ROOT/scripts/bootstrap_phase3.sh"
  fi
  echo "==> Re-run: ./scripts/production_ready.sh"
fi

if [[ "$DO_SMOKE" == true ]]; then
  echo "==> Sync prod Bedrock alias before smoke..."
  agent_id="$(bayrelay_tf_raw bedrock_agent_id)"
  if [[ -n "$agent_id" && "$agent_id" != "null" ]]; then
    bayrelay_prepend_venv
    "$BAYRELAY_ROOT/.venv/bin/python3" "$SCRIPT_DIR/publish_bedrock_prod_alias.py" \
      --agent-id "$agent_id" --alias-name prod --region "${AWS_REGION:-us-west-2}" >/dev/null || true
    sleep 8
  fi
  echo "==> Running full smoke..."
  "$SCRIPT_DIR/bayrelay_demo.sh" smoke || FAIL=1
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Production readiness: FAILED — fix items above." >&2
  exit 1
fi
echo "Production readiness: PASSED (review WARN lines before external go-live)."
exit 0
