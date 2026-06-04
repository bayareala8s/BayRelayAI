#!/usr/bin/env bash
# Full demo cycle — delegates to bayrelay_demo.sh (production demo controller).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
args=()
[[ "${NO_TEARDOWN:-0}" == "1" ]] && args+=(--no-teardown)
[[ "${NO_START:-0}" == "1" ]] && args+=(--no-start)
for a in "$@"; do
  case "$a" in
    -y | --yes) args+=(--yes) ;;
    --no-start) args+=(--no-start) ;;
    --no-teardown) args+=(--no-teardown) ;;
    *) args+=("$a") ;;
  esac
done
export SKIP_KB_PHASE="${SKIP_KB_PHASE:-0}"
exec "$SCRIPT_DIR/bayrelay_demo.sh" cycle "${args[@]}"
