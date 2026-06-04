#!/usr/bin/env bash
# BayRelay production demo — unified start / stop / full cycle / status / smoke.
#
# Customer demo (deploy and keep running):
#   cp environments/demo.env.example environments/demo.env   # edit credentials
#   ./scripts/bayrelay_demo.sh start --yes
#   ./scripts/bayrelay_demo.sh smoke
#
# Full regression cycle (start → smoke → stop):
#   ./scripts/bayrelay_demo.sh cycle --yes
#
# Tear down:
#   ./scripts/bayrelay_demo.sh stop --yes

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"

CMD="${1:-}"
shift || true

AUTO_YES=false
RUN_SMOKE="${RUN_SMOKE:-0}"
SKIP_SMOKE=false
FORCE_APPLY_FLAG=false
NO_START="${NO_START:-0}"

load_demo_env() {
  local f="$BAYRELAY_TF_DIR/demo.env"
  if [[ -f "$f" ]]; then
    echo "==> Loading $f"
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  fi
}

usage() {
  cat <<'EOF'
BayRelay production demo controller (repo root).

Commands:
  start [--yes] [--force] [--smoke]   Deploy stack, Phase 3 bootstrap, optional Cognito user + smoke
  stop [--yes]                        Empty S3 buckets and terraform destroy
  cycle [--yes] [--no-teardown]       start → smoke → stop (use --no-teardown to keep stack)
  status                              Stack up? key outputs and readiness hints
  smoke                               run_full_demo.sh (needs Cognito in demo.env or env)
  handoff                             customer_handoff.sh summary file
  prod-ready [--apply] [--smoke]      production readiness gate (see production_ready.sh)

Options (start / cycle):
  --yes           Non-interactive terraform and destroy
  --force         Force terraform apply even if stack appears up
  --smoke         Run smoke test after start (or set RUN_SMOKE=1)
  --skip-smoke    Cycle only: skip smoke step
  --no-teardown   Cycle only: keep stack after smoke
  --no-start      Cycle only: skip deploy (stack must be up)

Environment:
  BAYRELAY_TF_DIR=environments (default)
  environments/demo.env — COGNITO_DEMO_* , CREATE_DEMO_USER=1 (see demo.env.example)

Examples:
  ./scripts/bayrelay_demo.sh start --yes
  ./scripts/bayrelay_demo.sh start --yes --smoke
  ./scripts/bayrelay_demo.sh cycle --yes --no-teardown
  ./scripts/bayrelay_demo.sh status
  ./scripts/bayrelay_demo.sh stop --yes

Docs: docs/DEMO_LIFECYCLE.md
EOF
}

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y | --yes) AUTO_YES=true; shift ;;
      --force) FORCE_APPLY_FLAG=true; shift ;;
      --smoke) RUN_SMOKE=1; shift ;;
      --skip-smoke) SKIP_SMOKE=true; shift ;;
      --no-teardown) export NO_TEARDOWN=1; shift ;;
      --no-start) NO_START=1; shift ;;
      -h | --help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done
}

cmd_start() {
  parse_common_flags "$@"
  load_demo_env
  export BAYRELAY_TF_DIR
  export CREATE_DEMO_USER="${CREATE_DEMO_USER:-1}"
  if [[ "$FORCE_APPLY_FLAG" == true || "${FORCE_APPLY:-0}" == "1" ]]; then
    export FORCE_APPLY=1
  fi

  local start_args=()
  $AUTO_YES && start_args+=(--yes)

  "$SCRIPT_DIR/demo_start.sh" "${start_args[@]}"

  if [[ "$RUN_SMOKE" == "1" ]]; then
    cmd_smoke
  fi

  bayrelay_write_demo_state "running"
  echo "OK: bayrelay_demo.sh start — stack ready for customer demos (use: bayrelay_demo.sh status)"
}

cmd_stop() {
  parse_common_flags "$@"
  export BAYRELAY_TF_DIR
  local stop_args=()
  $AUTO_YES && stop_args+=(--yes)
  "$SCRIPT_DIR/demo_stop.sh" "${stop_args[@]}"
  bayrelay_write_demo_state "destroyed"
  echo "OK: bayrelay_demo.sh stop — stack destroyed"
}

cmd_cycle() {
  parse_common_flags "$@"
  load_demo_env
  export BAYRELAY_TF_DIR
  export CREATE_DEMO_USER="${CREATE_DEMO_USER:-1}"
  if [[ "$FORCE_APPLY_FLAG" == true || "${FORCE_APPLY:-0}" == "1" ]]; then
    export FORCE_APPLY=1
  fi
  NO_TEARDOWN="${NO_TEARDOWN:-0}"

  local start_args=()
  $AUTO_YES && start_args+=(--yes)

  if [[ "$NO_START" != "1" ]]; then
    echo "=== bayrelay_demo cycle: START ==="
    "$SCRIPT_DIR/demo_start.sh" "${start_args[@]}"
  else
    echo "=== bayrelay_demo cycle: skip START (--no-start) ==="
    bayrelay_resolve_aws_region >/dev/null
    bayrelay_stack_is_up || { echo "FAIL: stack not up" >&2; exit 1; }
  fi

  if [[ "$SKIP_SMOKE" != true ]]; then
    echo "=== bayrelay_demo cycle: SMOKE ==="
    cmd_smoke || { echo "FAIL: smoke test failed" >&2; exit 1; }
  fi

  if [[ "$NO_TEARDOWN" != "1" ]]; then
    echo "=== bayrelay_demo cycle: STOP ==="
    $AUTO_YES && "$SCRIPT_DIR/demo_stop.sh" --yes || "$SCRIPT_DIR/demo_stop.sh"
    bayrelay_write_demo_state "destroyed"
  else
    bayrelay_write_demo_state "running"
    bayrelay_print_demo_outputs
  fi

  echo "OK: bayrelay_demo.sh cycle finished"
}

cmd_status() {
  bayrelay_resolve_aws_region >/dev/null
  echo "=== BayRelay status ==="
  echo "TF_DIR:     $BAYRELAY_TF_DIR"
  echo "Region:     ${AWS_REGION:-unknown}"
  echo "State file: $(bayrelay_demo_state_path)"

  if bayrelay_stack_is_ready; then
    echo "Stack:      READY (API + Step Functions)"
    bayrelay_print_demo_outputs
    bayrelay_production_readiness_hints
  elif bayrelay_stack_is_up; then
    echo "Stack:      PARTIAL (API up; Step Functions missing — run: bayrelay_demo.sh start --force --yes)"
  else
    echo "Stack:      DOWN (no http_api_endpoint in terraform output)"
    echo "Deploy:     ./scripts/bayrelay_demo.sh start --yes"
    return 0
  fi
  if [[ -f "$BAYRELAY_TF_DIR/demo.env" ]]; then
    echo "demo.env:   present (source for smoke credentials)"
  else
    echo "demo.env:   missing — cp environments/demo.env.example environments/demo.env"
  fi
}

cmd_smoke() {
  load_demo_env
  bayrelay_prepend_venv
  bayrelay_resolve_aws_region >/dev/null
  # Always use current stack client ID (stale shell env breaks smoke after redeploy).
  local tf_client
  tf_client="$(bayrelay_tf_raw cognito_client_id)"
  if [[ -n "$tf_client" && "$tf_client" != "null" ]]; then
    export COGNITO_CLIENT_ID="$tf_client"
  else
    bayrelay_export_cognito_env
  fi
  if [[ -z "${COGNITO_USERNAME:-}" && -n "${COGNITO_DEMO_USERNAME:-}" ]]; then
    export COGNITO_USERNAME="$COGNITO_DEMO_USERNAME"
  fi
  if [[ -z "${COGNITO_PASSWORD:-}" && -n "${COGNITO_DEMO_PASSWORD:-}" ]]; then
    export COGNITO_PASSWORD="$COGNITO_DEMO_PASSWORD"
  fi
  if [[ -z "${COGNITO_CLIENT_ID:-}" || -z "${COGNITO_USERNAME:-}" || -z "${COGNITO_PASSWORD:-}" ]]; then
    echo "FAIL: Cognito required for smoke (JWT enabled). Set in environments/demo.env or env." >&2
    echo "  COGNITO_CLIENT_ID COGNITO_USERNAME COGNITO_PASSWORD" >&2
    exit 1
  fi
  export BAYRELAY_TF_DIR
  "$BAYRELAY_ROOT/scripts/run_full_demo.sh"
}

cmd_handoff() {
  load_demo_env
  export BAYRELAY_TF_DIR
  "$SCRIPT_DIR/customer_handoff.sh"
}

cmd_prod_ready() {
  local args=()
  [[ "${1:-}" == "--apply" ]] && args+=(--apply)
  [[ "${1:-}" == "--smoke" || "${2:-}" == "--smoke" ]] && args+=(--smoke)
  for a in "$@"; do
    [[ "$a" == "--apply" ]] && args+=(--apply)
    [[ "$a" == "--smoke" ]] && args+=(--smoke)
  done
  "$SCRIPT_DIR/production_ready.sh" "${args[@]}"
}

case "$CMD" in
  start)  cmd_start "$@" ;;
  stop)   cmd_stop "$@" ;;
  cycle)  cmd_cycle "$@" ;;
  status) cmd_status "$@" ;;
  smoke)  cmd_smoke "$@" ;;
  handoff) cmd_handoff "$@" ;;
  prod-ready | production-ready) cmd_prod_ready "$@" ;;
  "" | -h | --help) usage ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage >&2
    exit 1
    ;;
esac
