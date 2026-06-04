#!/usr/bin/env bash
# Create or reuse Bedrock agent alias "prod" and print alias ID for terraform.tfvars.
#
# Usage:
#   ./scripts/publish_bedrock_prod_alias.sh
#   ./scripts/publish_bedrock_prod_alias.sh --write-tfvars   # set bedrock_agent_alias_id in terraform.tfvars

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

WRITE_TFVARS=false
ALIAS_NAME="${BEDROCK_PROD_ALIAS_NAME:-prod}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --write-tfvars) WRITE_TFVARS=true; shift ;;
    -h | --help)
      echo "Usage: $0 [--write-tfvars]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

bayrelay_prepend_venv
bayrelay_resolve_aws_region >/dev/null
AGENT_ID="$(bayrelay_tf_raw bedrock_agent_id)"
[[ -n "$AGENT_ID" && "$AGENT_ID" != "null" ]] || { echo "No bedrock_agent_id — apply stack first." >&2; exit 1; }

ALIAS_ID="$("$BAYRELAY_ROOT/.venv/bin/python3" "$SCRIPT_DIR/publish_bedrock_prod_alias.py" \
  --agent-id "$AGENT_ID" \
  --alias-name "$ALIAS_NAME" \
  --region "${AWS_REGION:-us-west-2}")"

echo "Production Bedrock alias: $ALIAS_NAME -> $ALIAS_ID"
echo "Set in environments/terraform.tfvars:"
echo "  bedrock_agent_alias_id = \"$ALIAS_ID\""

if $WRITE_TFVARS; then
  TFVARS="$BAYRELAY_TF_DIR/terraform.tfvars"
  if grep -qE '^[[:space:]]*bedrock_agent_alias_id[[:space:]]*=' "$TFVARS"; then
    sed -i.bak -E "s|^[[:space:]]*bedrock_agent_alias_id[[:space:]]*=.*|bedrock_agent_alias_id = \"$ALIAS_ID\"|" "$TFVARS"
    rm -f "${TFVARS}.bak"
  else
    echo "bedrock_agent_alias_id = \"$ALIAS_ID\"" >>"$TFVARS"
  fi
  echo "Updated $TFVARS"
fi
