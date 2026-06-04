#!/usr/bin/env bash
# Build operator portal SPA with stack outputs baked into Vite env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$ROOT/scripts/stack_lib.sh"

bayrelay_require_cmds node npm terraform

API_URL="${VITE_API_URL:-$(bayrelay_tf_raw http_api_public_endpoint)}"
CLIENT_ID="${VITE_COGNITO_CLIENT_ID:-$(bayrelay_tf_raw cognito_client_id)}"
REGION="${VITE_COGNITO_REGION:-$(bayrelay_tf_raw aws_deployment_region)}"
TRANSFER_BUCKET="${VITE_TRANSFER_BUCKET:-$(bayrelay_tf_raw transfer_data_bucket)}"

if [[ -z "$API_URL" || "$API_URL" == "null" ]]; then
  echo "Stack not deployed or http_api_public_endpoint missing. Run terraform apply first." >&2
  exit 1
fi
if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
  echo "enable_api_jwt_auth must be true (cognito_client_id output)." >&2
  exit 1
fi
if [[ -z "$REGION" || "$REGION" == "null" ]]; then
  REGION="${AWS_REGION:-us-west-2}"
fi

export VITE_API_URL="$API_URL"
export VITE_COGNITO_CLIENT_ID="$CLIENT_ID"
export VITE_COGNITO_REGION="$REGION"
if [[ -n "$TRANSFER_BUCKET" && "$TRANSFER_BUCKET" != "null" ]]; then
  export VITE_TRANSFER_BUCKET="$TRANSFER_BUCKET"
fi

ENV_FILE="$ROOT/portal/.env.production"
{
  echo "VITE_API_URL=$API_URL"
  echo "VITE_COGNITO_CLIENT_ID=$CLIENT_ID"
  echo "VITE_COGNITO_REGION=$REGION"
  if [[ -n "${VITE_TRANSFER_BUCKET:-}" ]]; then
    echo "VITE_TRANSFER_BUCKET=$VITE_TRANSFER_BUCKET"
  fi
} > "$ENV_FILE"
echo "Wrote $ENV_FILE"

PUBLIC_DIR="$ROOT/portal/public"
ICON_SVG="$PUBLIC_DIR/bayrelay-icon.svg"
ICON_PNG="$PUBLIC_DIR/bayrelay-icon.png"
mkdir -p "$PUBLIC_DIR"
if [[ ! -f "$ICON_SVG" || ! -f "$ICON_PNG" ]]; then
  echo "WARN: portal/public/bayrelay-icon.svg and bayrelay-icon.png required (BayRelay brand, not BayLearn)." >&2
fi

echo "Building portal: API=$VITE_API_URL region=$VITE_COGNITO_REGION"

cd "$ROOT/portal"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

echo "Portal build complete: $ROOT/portal/dist"
