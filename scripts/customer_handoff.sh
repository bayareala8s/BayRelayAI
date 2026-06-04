#!/usr/bin/env bash
# Print customer handoff summary after deploy (for SOW close / runbook).
# Usage: ./scripts/customer_handoff.sh
# Writes: ./customer-handoff-<date>.txt in repo root (optional HANDOFF_FILE=path)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

if ! bayrelay_stack_is_up; then
  echo "Stack not detected (no http_api_endpoint). Run demo_start.sh first." >&2
  exit 1
fi

bayrelay_resolve_aws_region >/dev/null
DATE=$(date -u +%Y-%m-%d)
OUT="${HANDOFF_FILE:-$BAYRELAY_ROOT/customer-handoff-${DATE}.txt}"

acct=$(aws sts get-caller-identity --query Account --output text --region "${AWS_REGION:-us-west-2}" 2>/dev/null || echo "unknown")

{
  echo "BayRelay — Customer AWS handoff"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "========================================"
  echo
  echo "AWS account:     $acct"
  echo "Region:          ${AWS_REGION:-$(bayrelay_tf_raw aws_deployment_region)}"
  echo "Terraform dir:   $BAYRELAY_TF_DIR"
  echo
  echo "--- Endpoints ---"
  echo "HTTP API (public):  $(bayrelay_tf_raw http_api_public_endpoint)"
  echo "HTTP API (direct):  $(bayrelay_tf_raw http_api_endpoint)"
  echo "Transfer bucket: $(bayrelay_tf_raw transfer_data_bucket)"
  echo "KB source bucket:$(bayrelay_tf_raw kb_source_bucket)"
  portal="$(bayrelay_tf_raw operator_portal_url 2>/dev/null || true)"
  if [[ -n "$portal" && "$portal" != "null" ]]; then
    echo "Operator portal: $portal"
  fi
  echo
  echo "--- SFTP (if enabled) ---"
  echo "SFTP host:       $(bayrelay_tf_raw sftp_server_endpoint)"
  echo "Inbound user:    $(bayrelay_tf_raw sftp_inbound_username)"
  echo "Connector ID:    $(bayrelay_tf_raw transfer_connector_id)"
  echo
  echo "--- Auth ---"
  echo "Cognito pool:    $(bayrelay_tf_raw cognito_user_pool_id)"
  echo "Cognito client:  $(bayrelay_tf_raw cognito_client_id)"
  echo "Token issuer:    $(bayrelay_tf_raw cognito_token_issuer)"
  echo
  echo "--- Bedrock ---"
  echo "Agent ID:        $(bayrelay_tf_raw bedrock_agent_id)"
  echo "Agent alias:     $(bayrelay_tf_raw bedrock_agent_alias_id)"
  echo "Agent version:   $(bayrelay_tf_raw bedrock_agent_version)"
  echo "Knowledge base:  $(bayrelay_tf_raw bedrock_knowledge_base_id)"
  echo "KB data source:  $(bayrelay_tf_raw bedrock_kb_data_source_id)"
  echo
  echo "--- Operations ---"
  echo "Alarm SNS topic: $(bayrelay_tf_raw alarm_topic_arn)"
  echo "Precheck SFN:    $(bayrelay_tf_raw step_function_precheck_arn)"
  echo
  echo "--- Portal demo (operator) ---"
  echo "Sign in at operator portal URL; use environments/demo.env credentials."
  echo "Flow: Operations (LIVE) → New transfer → Transfers → Automation → Assistant"
  echo "Guide: docs/CUSTOMER_DEMO_READY.md"
  echo
  echo "--- Next steps for customer ---"
  echo "1. Subscribe operations to alarm SNS topic"
  echo "2. Replace TSTALIASID with published Bedrock alias if still draft"
  echo "3. Run: ./scripts/bayrelay_demo.sh smoke (regression)"
  echo "4. See docs/RUNBOOK.md and docs/DEMO.md"
  echo
  echo "--- Docs ---"
  echo "  docs/CUSTOMER_AWS_DEPLOYMENT.md"
  echo "  docs/DEMO_LIFECYCLE.md"
  echo "  docs/bayrelay-architecture.png"
} | tee "$OUT"

echo
echo "Handoff written to: $OUT"
