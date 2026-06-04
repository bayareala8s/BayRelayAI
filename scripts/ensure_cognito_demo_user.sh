#!/usr/bin/env bash
# Ensure demo Cognito user exists and is in the correct group (idempotent).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$ROOT/scripts/stack_lib.sh"

USERNAME="${COGNITO_DEMO_USERNAME:-${COGNITO_USERNAME:-}}"
PASSWORD="${COGNITO_DEMO_PASSWORD:-${COGNITO_PASSWORD:-}}"
EMAIL="${COGNITO_DEMO_EMAIL:-$USERNAME}"
ROLE="${COGNITO_DEMO_ROLE:-operator}"
PARTNER_ID="${COGNITO_DEMO_PARTNER_ID:-}"
PERMANENT="${COGNITO_DEMO_PERMANENT:-1}"

[[ -n "$USERNAME" && -n "$PASSWORD" ]] || {
  echo "Set COGNITO_DEMO_USERNAME and COGNITO_DEMO_PASSWORD (or use demo.env)." >&2
  exit 1
}

extra=()
[[ "$PERMANENT" == "1" ]] && extra=(--permanent-password)
[[ -n "$PARTNER_ID" ]] && extra+=(--partner-id "$PARTNER_ID")

exec "$ROOT/scripts/create_cognito_operator.sh" \
  --username "$USERNAME" \
  --email "$EMAIL" \
  --temporary-password "$PASSWORD" \
  --role "$ROLE" \
  "${extra[@]}"
