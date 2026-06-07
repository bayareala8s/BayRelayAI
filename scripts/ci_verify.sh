#!/usr/bin/env bash
# Local / pipeline gate: unit tests + Terraform fmt check + validate (production stack).
# Usage: from repository root: ./scripts/ci_verify.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> pytest"
python3 -m pytest tests/ -v

echo "==> terraform fmt -check -recursive"
terraform fmt -check -recursive

for env in environments; do
  echo "==> terraform validate ($env)"
  terraform -chdir="$env" init -backend=false -input=false >/dev/null
  terraform -chdir="$env" validate
done

echo "==> Python script syntax (scripts/*.py)"
python3 -m py_compile \
  scripts/aoss_create_kb_index.py \
  scripts/prepare_bedrock_agent.py \
  scripts/start_kb_ingestion.py \
  scripts/test_retrieval.py \
  modules/bedrock_agent/scripts/disable_action_group.py

echo "==> bash syntax (lifecycle scripts)"
bash -n scripts/stack_lib.sh
bash -n scripts/preflight_prod.sh
bash -n scripts/bayrelay_demo.sh
bash -n scripts/demo_start.sh
bash -n scripts/demo_stop.sh
bash -n scripts/start_stack.sh
bash -n scripts/stop_stack.sh
bash -n scripts/demo_cycle.sh
bash -n scripts/create_cognito_operator.sh
bash -n scripts/production_ready.sh
bash -n scripts/prepare_customer_demo.sh

echo "==> operator portal build"
(
  cd portal
  if [[ ! -d node_modules ]]; then
    npm ci --no-audit --no-fund
  fi
  npm run build
)

echo "OK: ci_verify.sh passed"
