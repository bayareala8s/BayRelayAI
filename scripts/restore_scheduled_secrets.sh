#!/usr/bin/env bash
# Restore Secrets Manager secrets left in pending deletion after terraform destroy.
# Run before re-deploy if apply fails with "already scheduled for deletion".
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"
bayrelay_resolve_aws_region >/dev/null
REGION="${AWS_REGION:-us-west-2}"
PREFIX="$(grep -E '^[[:space:]]*project[[:space:]]*=' "$BAYRELAY_TF_DIR/terraform.tfvars" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/' || echo bayrelay)"
ENV="$(bayrelay_stack_env_name)"
ENV="${ENV:-prod}"
for name in "${PREFIX}-${ENV}-sftp-inbound-private-key" "${PREFIX}-${ENV}-sftp-connector-secret"; do
  if aws secretsmanager restore-secret --secret-id "$name" --region "$REGION" 2>/dev/null; then
    echo "Restored: $name"
  else
    echo "Skip (not pending deletion or missing): $name"
  fi
done
if aws secretsmanager describe-secret --secret-id "${PREFIX}-${ENV}-sftp-inbound-private-key" --region "$REGION" &>/dev/null; then
  terraform -chdir="$BAYRELAY_TF_DIR" import \
    'module.transfer_family[0].aws_secretsmanager_secret.inbound_private_key' \
    "$(aws secretsmanager describe-secret --secret-id "${PREFIX}-${ENV}-sftp-inbound-private-key" --region "$REGION" --query ARN --output text)" \
    2>/dev/null && echo "Imported inbound secret into Terraform state" || true
  terraform -chdir="$BAYRELAY_TF_DIR" import \
    'module.transfer_family[0].aws_secretsmanager_secret.connector_creds[0]' \
    "$(aws secretsmanager describe-secret --secret-id "${PREFIX}-${ENV}-sftp-connector-secret" --region "$REGION" --query ARN --output text)" \
    2>/dev/null && echo "Imported connector secret into Terraform state" || true
fi
