#!/usr/bin/env bash
# Stop the BayRelay demo stack: empty S3 buckets then terraform destroy.
#
# Usage (repo root):
#   ./scripts/demo_stop.sh --yes
#   ./scripts/demo_stop.sh              # interactive confirmation
#   EMPTY_BUCKETS=0 ./scripts/demo_stop.sh --yes   # skip S3 empty (destroy may fail)
#
# Sets BAYRELAY_CONFIRM_PROD_DESTROY=1 automatically (production stack teardown for demo).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

AUTO_APPROVE=false
EMPTY_BUCKETS="${EMPTY_BUCKETS:-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) AUTO_APPROVE=true; shift ;;
    --keep-buckets) EMPTY_BUCKETS=0; shift ;;
    -h | --help)
      cat <<'EOF'
Tear down the demo stack after emptying versioned S3 buckets (required when force_destroy=false).

  ./scripts/demo_stop.sh --yes
  EMPTY_BUCKETS=0 ./scripts/demo_stop.sh --yes

See docs/DEMO_LIFECYCLE.md
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

export BAYRELAY_TF_DIR

if ! bayrelay_stack_is_up; then
  if terraform -chdir="$BAYRELAY_TF_DIR" state list 2>/dev/null | grep -q .; then
    echo "WARN: http_api_endpoint gone but Terraform state still has resources — continuing destroy." >&2
  else
    echo "No deployed stack detected (missing http_api_endpoint output). Nothing to stop." >&2
    exit 0
  fi
fi

bayrelay_resolve_aws_region >/dev/null

if ! $AUTO_APPROVE; then
  echo "This will DESTROY the BayRelay stack in AWS (demo teardown)."
  echo "  TF_DIR: $BAYRELAY_TF_DIR"
  echo "  Region: ${AWS_REGION:-unknown}"
  read -r -p "Type destroy to continue: " confirm
  if [[ "$confirm" != "destroy" ]]; then
    echo "Aborted."
    exit 1
  fi
  AUTO_APPROVE=true
fi

if [[ "$EMPTY_BUCKETS" == "1" ]]; then
  echo "==> Emptying demo S3 buckets (versioned delete) before destroy"
  bayrelay_empty_demo_buckets
fi

export BAYRELAY_CONFIRM_PROD_DESTROY=1
TF_AUTO_APPROVE=1 "$BAYRELAY_ROOT/scripts/stop_stack.sh" --yes

echo "OK: demo_stop.sh finished — stack destroyed"
