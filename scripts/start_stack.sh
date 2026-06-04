#!/usr/bin/env bash
# Provision the BayRelay stack with Terraform (terraform init + apply).
#
# Usage (repo root):
#   BAYRELAY_TF_DIR=environments ./scripts/start_stack.sh
#   ./scripts/start_stack.sh --yes                    # terraform apply -auto-approve
#   BOOTSTRAP_PHASE3=1 ./scripts/start_stack.sh --yes # after apply: KB ingest + PrepareAgent
#
# Requires: terraform, AWS credentials, terraform.tfvars where needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

AUTO_APPROVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes)
      AUTO_APPROVE=true
      shift
      ;;
    -h | --help)
      echo "Usage: $0 [--yes]  (set BAYRELAY_TF_DIR, BOOTSTRAP_PHASE3=1 optional)" >&2
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${TF_AUTO_APPROVE:-}" == "1" ]]; then
  AUTO_APPROVE=true
fi

echo "==> terraform init ($BAYRELAY_TF_DIR)"
terraform -chdir="$BAYRELAY_TF_DIR" init

if $AUTO_APPROVE; then
  echo "==> terraform apply -auto-approve ($BAYRELAY_TF_DIR)"
  terraform -chdir="$BAYRELAY_TF_DIR" apply -auto-approve
else
  echo "==> terraform apply ($BAYRELAY_TF_DIR)"
  terraform -chdir="$BAYRELAY_TF_DIR" apply
fi

if [[ "${BOOTSTRAP_PHASE3:-0}" == "1" ]]; then
  R="$(bayrelay_tf_raw aws_deployment_region)"
  if [[ -n "$R" && "$R" != "null" ]]; then
    export AWS_REGION="$R"
  fi
  if [[ -z "${AWS_REGION:-}" && -f "$BAYRELAY_TF_DIR/terraform.tfvars" ]]; then
    R=$(grep -E '^[[:space:]]*aws_region[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*aws_region[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/' || true)
    [[ -n "$R" ]] && export AWS_REGION="$R"
  fi
  echo "==> BOOTSTRAP_PHASE3: $BAYRELAY_ROOT/scripts/bootstrap_phase3.sh"
  export SYNC_KB_DOCS="${SYNC_KB_DOCS:-1}"
  BAYRELAY_TF_DIR="$BAYRELAY_TF_DIR" AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}" \
    "$BAYRELAY_ROOT/scripts/bootstrap_phase3.sh"
fi

echo "OK: start_stack.sh finished (TF_DIR=$BAYRELAY_TF_DIR)"
