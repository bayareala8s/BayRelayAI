#!/usr/bin/env bash
# Tear down the BayRelay stack (terraform destroy).
#
# Usage (repo root):
#   BAYRELAY_TF_DIR=environments ./scripts/stop_stack.sh
#   ./scripts/stop_stack.sh --yes    # non-interactive destroy
#
# Prod guard: destroying when terraform.tfvars has environment = "prod" requires
#   BAYRELAY_CONFIRM_PROD_DESTROY=1
#
# Requires: S3 buckets empty when force_destroy=false (demo_stop.sh handles this).

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
      echo "Usage: $0 [--yes]  (BAYRELAY_TF_DIR, BAYRELAY_CONFIRM_PROD_DESTROY for prod)" >&2
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

ENV_HINT="$(bayrelay_stack_env_name)"
if [[ "$ENV_HINT" == "prod" && "${BAYRELAY_CONFIRM_PROD_DESTROY:-}" != "1" ]]; then
  echo "Refusing destroy: environment in terraform.tfvars looks like prod." >&2
  echo "Set BAYRELAY_CONFIRM_PROD_DESTROY=1 if you really intend to destroy this stack." >&2
  exit 2
fi

if ! $AUTO_APPROVE; then
  echo "About to run: terraform -chdir=$BAYRELAY_TF_DIR destroy"
  read -r -p "Type yes to destroy: " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "==> terraform destroy -auto-approve ($BAYRELAY_TF_DIR)"
terraform -chdir="$BAYRELAY_TF_DIR" destroy -auto-approve

echo "OK: stop_stack.sh finished"
