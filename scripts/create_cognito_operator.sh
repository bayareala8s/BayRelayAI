#!/usr/bin/env bash
# Create a Cognito user in the BayRelay API operator pool (prod/test when JWT is enabled).
#
# Usage:
#   BAYRELAY_TF_DIR=environments ./scripts/create_cognito_operator.sh \
#     --username demo@example.com --email demo@example.com \
#     --temporary-password 'TempPass!Change1'
#
# Requires: terraform outputs cognito_user_pool_id; AWS CLI; pool must exist.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${BAYRELAY_TF_DIR:-$ROOT/environments}"
if [[ "$TF_DIR" != /* ]]; then
  TF_DIR="$ROOT/$TF_DIR"
fi

USERNAME=""
EMAIL=""
TEMP_PASSWORD=""
PERMANENT=false
ROLE="operator"
PARTNER_ID=""

usage() {
  echo "Usage: $0 --username USER --temporary-password PASS [--email EMAIL] [--permanent-password]" >&2
  echo "       [--role operator|partner] [--partner-id PRT-...]" >&2
  echo "  BAYRELAY_TF_DIR defaults to environments" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username) USERNAME="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --temporary-password) TEMP_PASSWORD="$2"; shift 2 ;;
    --permanent-password) PERMANENT=true; shift ;;
    --role) ROLE="$2"; shift 2 ;;
    --partner-id) PARTNER_ID="$2"; shift 2 ;;
    -h | --help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -n "$USERNAME" && -n "$TEMP_PASSWORD" ]] || usage
EMAIL="${EMAIL:-$USERNAME}"

POOL_ID="$(terraform -chdir="$TF_DIR" output -raw cognito_user_pool_id 2>/dev/null || true)"
if [[ -z "$POOL_ID" || "$POOL_ID" == "null" ]]; then
  echo "No cognito_user_pool_id output. Is enable_api_jwt_auth=true and stack applied?" >&2
  exit 1
fi

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [[ -z "$REGION" ]]; then
  REGION="$(terraform -chdir="$TF_DIR" output -raw aws_deployment_region 2>/dev/null || true)"
fi
if [[ -z "$REGION" || "$REGION" == "null" ]]; then
  echo "Set AWS_REGION or ensure aws_deployment_region output exists." >&2
  exit 1
fi

_assign_role() {
  local group="bayrelay-operators"
  if [[ "$ROLE" == "partner" ]]; then
    group="bayrelay-partners"
    aws cognito-idp admin-remove-user-from-group --region "$REGION" \
      --user-pool-id "$POOL_ID" --username "$USERNAME" --group-name "bayrelay-operators" \
      2>/dev/null || true
  else
    aws cognito-idp admin-remove-user-from-group --region "$REGION" \
      --user-pool-id "$POOL_ID" --username "$USERNAME" --group-name "bayrelay-partners" \
      2>/dev/null || true
  fi
  aws cognito-idp admin-add-user-to-group --region "$REGION" \
    --user-pool-id "$POOL_ID" --username "$USERNAME" --group-name "$group" \
    2>/dev/null || true
  if [[ "$ROLE" == "partner" && -n "$PARTNER_ID" ]]; then
    aws cognito-idp admin-update-user-attributes --region "$REGION" \
      --user-pool-id "$POOL_ID" --username "$USERNAME" \
      --user-attributes "Name=custom:partner_id,Value=$PARTNER_ID"
  fi
  echo "Assigned group $group${PARTNER_ID:+, partner_id=$PARTNER_ID}"
}

if aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$USERNAME" --region "$REGION" &>/dev/null; then
  echo "User already exists: $USERNAME in pool $POOL_ID — ensuring role/group."
  if $PERMANENT; then
    aws cognito-idp admin-set-user-password --region "$REGION" \
      --user-pool-id "$POOL_ID" \
      --username "$USERNAME" \
      --password "$TEMP_PASSWORD" \
      --permanent 2>/dev/null || true
  fi
  _assign_role
  exit 0
fi

USER_ATTRS=(
  "Name=email,Value=$EMAIL"
  "Name=email_verified,Value=true"
)
if $PERMANENT; then
  aws cognito-idp admin-create-user --region "$REGION" \
    --user-pool-id "$POOL_ID" \
    --username "$USERNAME" \
    --user-attributes "${USER_ATTRS[@]}" \
    --message-action SUPPRESS
  aws cognito-idp admin-set-user-password --region "$REGION" \
    --user-pool-id "$POOL_ID" \
    --username "$USERNAME" \
    --password "$TEMP_PASSWORD" \
    --permanent
  echo "Created user $USERNAME with permanent password (pool $POOL_ID, region $REGION)."
  _assign_role
else
  aws cognito-idp admin-create-user --region "$REGION" \
    --user-pool-id "$POOL_ID" \
    --username "$USERNAME" \
    --user-attributes "${USER_ATTRS[@]}" \
    --temporary-password "$TEMP_PASSWORD" \
    --message-action SUPPRESS
  echo "Created user $USERNAME with temporary password (must change on first login)."
  echo "Pool: $POOL_ID  Region: $REGION"
  echo "Client ID: $(terraform -chdir="$TF_DIR" output -raw cognito_client_id)"
  _assign_role
fi
