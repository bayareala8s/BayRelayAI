#!/usr/bin/env bash
# Build portal assets and deploy via Terraform (S3 + CloudFront).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$ROOT/scripts/stack_lib.sh"
TF_DIR="${BAYRELAY_TF_DIR:-$ROOT/environments}"

"$ROOT/scripts/build_portal.sh"

cd "$TF_DIR"
terraform init -input=false
terraform apply -auto-approve "$@"

PORTAL_URL="$(terraform output -raw operator_portal_url 2>/dev/null || true)"
DIST_ID="$(terraform output -raw operator_portal_distribution_id 2>/dev/null || true)"
if [[ -n "$DIST_ID" && "$DIST_ID" != "null" ]]; then
  bayrelay_resolve_aws_region >/dev/null
  aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" >/dev/null 2>&1 || true
fi
if [[ -n "$PORTAL_URL" && "$PORTAL_URL" != "null" ]]; then
  echo ""
  echo "Operator portal: $PORTAL_URL"
fi
