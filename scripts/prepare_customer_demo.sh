#!/usr/bin/env bash
# One-shot customer demo prep: deploy stack, portal, Cognito demo user, smoke, handoff.
#
# Usage:
#   cp environments/demo.env.example environments/demo.env   # edit credentials
#   ./scripts/prepare_customer_demo.sh
#   ./scripts/prepare_customer_demo.sh --no-deploy            # stack already up
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

NO_DEPLOY=false
SKIP_SMOKE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-deploy) NO_DEPLOY=true; shift ;;
    --skip-smoke) SKIP_SMOKE=true; shift ;;
    -h | --help)
      cat <<'EOF'
Prepare BayRelay for a customer demo (production flags in environments/).

  ./scripts/prepare_customer_demo.sh              start --yes --smoke + handoff
  ./scripts/prepare_customer_demo.sh --no-deploy  portal + cognito + smoke only

Requires environments/demo.env (see demo.env.example).
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$BAYRELAY_TF_DIR/demo.env" ]]; then
  echo "FAIL: $BAYRELAY_TF_DIR/demo.env missing. Copy demo.env.example and set Cognito password." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$BAYRELAY_TF_DIR/demo.env"
set +a

export DEPLOY_PORTAL="${DEPLOY_PORTAL:-1}"
export CREATE_DEMO_USER="${CREATE_DEMO_USER:-1}"

if [[ "$NO_DEPLOY" != true ]]; then
  echo "=== Deploy stack + portal + demo user ==="
  "$SCRIPT_DIR/bayrelay_demo.sh" start --yes
else
  bayrelay_stack_is_up || { echo "FAIL: stack not up" >&2; exit 1; }
  "$SCRIPT_DIR/ensure_cognito_demo_user.sh"
  BAYRELAY_TF_DIR="$BAYRELAY_TF_DIR" "$SCRIPT_DIR/deploy_portal.sh"
fi

if [[ "$SKIP_SMOKE" != true ]]; then
  echo "=== Smoke test ==="
  "$SCRIPT_DIR/bayrelay_demo.sh" smoke
fi

echo "=== Production readiness ==="
"$SCRIPT_DIR/production_ready.sh" || true

echo "=== Customer handoff ==="
"$SCRIPT_DIR/customer_handoff.sh"

echo ""
echo "OK: BayRelay is ready for customer demo."
echo "    Docs: docs/CUSTOMER_DEMO_READY.md"
