#!/usr/bin/env bash
# Full BayRelay demo: API + S3 + optional Transfer connector checks.
# Usage: from repo root, with AWS CLI credentials for the target account:
#   AWS_REGION=us-west-2 ./scripts/run_full_demo.sh
# Optional: API_URL=... TRANSFER_BUCKET=... to override defaults.
# JWT (when API uses enable_api_jwt_auth): set COGNITO_CLIENT_ID, COGNITO_USERNAME, COGNITO_PASSWORD.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/.venv/bin/python3" ]]; then
  export PATH="$ROOT/.venv/bin:$PATH"
fi
BAYRELAY_TF_DIR="${BAYRELAY_TF_DIR:-$ROOT/environments}"
if [[ "$BAYRELAY_TF_DIR" != /* ]]; then
  BAYRELAY_TF_DIR="$ROOT/$BAYRELAY_TF_DIR"
fi
RUN_ID="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

_tf_out() {
  local v
  v="$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw "$1" 2>/dev/null)" || true
  if [[ -z "$v" || "$v" == "null" || "$v" == *$'\n'* || "$v" == *'Warning:'* || "$v" == *'╷'* ]]; then
    return 0
  fi
  echo "$v"
}

if [[ -z "${API_URL:-}" ]]; then
  API_URL="$(_tf_out http_api_public_endpoint)"
fi
if [[ -z "$API_URL" || "$API_URL" == "null" ]]; then
  API_URL="$(_tf_out http_api_endpoint)"
fi
if [[ -z "${TRANSFER_BUCKET:-}" ]]; then
  TRANSFER_BUCKET="$(_tf_out transfer_data_bucket)"
fi
if [[ -z "$API_URL" || "$API_URL" == "null" ]]; then
  echo "Set API_URL or deploy the stack (BAYRELAY_TF_DIR=$BAYRELAY_TF_DIR must expose http_api_endpoint)." >&2
  exit 1
fi
if [[ -z "$TRANSFER_BUCKET" || "$TRANSFER_BUCKET" == "null" ]]; then
  echo "Set TRANSFER_BUCKET or ensure Terraform output transfer_data_bucket exists." >&2
  exit 1
fi

if [[ -z "${AWS_REGION:-}" && -z "${AWS_DEFAULT_REGION:-}" ]]; then
  R="$(_tf_out aws_deployment_region)"
  if [[ -n "$R" && "$R" != "null" ]]; then
    export AWS_REGION="$R"
  fi
fi
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
DEMO_LOG="${DEMO_LOG:-/tmp/bayrelay-demo-${RUN_ID//:/-}.log}"
IDEM_BASE="demo-full-${RUN_ID}"

AUTH=()
if [[ -n "${COGNITO_CLIENT_ID:-}" && -n "${COGNITO_USERNAME:-}" && -n "${COGNITO_PASSWORD:-}" ]]; then
  TOKEN=$(aws cognito-idp initiate-auth --region "$REGION" --auth-flow USER_PASSWORD_AUTH \
    --client-id "$COGNITO_CLIENT_ID" \
    --auth-parameters "USERNAME=$COGNITO_USERNAME,PASSWORD=$COGNITO_PASSWORD" \
    --query "AuthenticationResult.IdToken" --output text)
  AUTH=( -H "Authorization: Bearer $TOKEN" )
  echo "(Using Cognito USER_PASSWORD_AUTH for API JWT.)" >&2
fi

exec > >(tee "$DEMO_LOG") 2>&1

echo "=== BayRelay full demo ==="
echo "RUN_ID=$RUN_ID"
echo "API_URL=$API_URL"
echo "TRANSFER_BUCKET=$TRANSFER_BUCKET"
echo "REGION=$REGION"
echo "LOG=$DEMO_LOG"
echo

json_post() {
  local url="$1"
  shift
  if ((${#AUTH[@]} > 0)); then
    curl -sS -X POST "$url" -H "Content-Type: application/json" -H "x-correlation-id: demo-$RUN_ID" "${AUTH[@]}" "$@"
  else
    curl -sS -X POST "$url" -H "Content-Type: application/json" -H "x-correlation-id: demo-$RUN_ID" "$@"
  fi
}

api_get() {
  if ((${#AUTH[@]} > 0)); then
    curl -sS "${AUTH[@]}" "$@"
  else
    curl -sS "$@"
  fi
}

echo "--- 1. Register partner ---"
PARTNER_BODY=$(json_post "$API_URL/v1/partners" -d "{\"name\":\"Demo Report Partner\",\"metadata\":{\"run_id\":\"$RUN_ID\"}}")
echo "$PARTNER_BODY" | jq .
PARTNER_ID=$(echo "$PARTNER_BODY" | jq -r .partner_id)
if [[ -z "$PARTNER_ID" || "$PARTNER_ID" == "null" ]]; then
  echo "FAIL: no partner_id"
  exit 1
fi

echo "--- 2. Register endpoints ---"
EP_IN=$(json_post "$API_URL/v1/endpoints" -d "{\"partner_id\":\"$PARTNER_ID\",\"protocol\":\"S3\",\"direction\":\"INBOUND\",\"config_ref\":\"demo-in\"}")
echo "$EP_IN" | jq .
EPT_IN=$(echo "$EP_IN" | jq -r .endpoint_id)

EP_OUT=$(json_post "$API_URL/v1/endpoints" -d "{\"partner_id\":\"$PARTNER_ID\",\"protocol\":\"S3\",\"direction\":\"OUTBOUND\",\"config_ref\":\"demo-out\"}")
echo "$EP_OUT" | jq .
EPT_OUT=$(echo "$EP_OUT" | jq -r .endpoint_id)

echo "--- 3. Stage S3 source object ---"
SRC_KEY="demo/report-full/inbound/demo-${RUN_ID}.txt"
DST_KEY="demo/report-full/outbound/demo-${RUN_ID}.txt"
echo "BayRelay demo $RUN_ID" | aws s3 cp - "s3://${TRANSFER_BUCKET}/${SRC_KEY}" --region "$REGION"
aws s3api head-object --bucket "$TRANSFER_BUCKET" --key "$SRC_KEY" --region "$REGION" | jq '{ContentLength,ServerSideEncryption}'

echo "--- 4. Submit S3_TO_S3 transfer ---"
SUBMIT=$(json_post "$API_URL/v1/transfers" \
  -H "x-idempotency-key: ${IDEM_BASE}-s3s3" \
  -d "{\"partner_id\":\"$PARTNER_ID\",\"source_endpoint_id\":\"$EPT_IN\",\"target_endpoint_id\":\"$EPT_OUT\",\"transfer_type\":\"S3_TO_S3\",\"payload\":{\"source_bucket\":\"$TRANSFER_BUCKET\",\"source_key\":\"$SRC_KEY\",\"dest_bucket\":\"$TRANSFER_BUCKET\",\"dest_key\":\"$DST_KEY\"}}")
echo "$SUBMIT" | jq .
REQ_ID=$(echo "$SUBMIT" | jq -r .request_id)
if [[ -z "$REQ_ID" || "$REQ_ID" == "null" ]]; then
  echo "FAIL: no request_id from transfer submit"
  exit 1
fi

echo "--- 5. Poll transfer status (max ~120s) ---"
for i in $(seq 1 24); do
  ST=$(api_get "$API_URL/v1/transfers/$REQ_ID" | jq -r '.transfer_request.status // empty')
  echo "poll $i: status=$ST"
  if [[ "$ST" == "SUCCEEDED" ]]; then
    break
  fi
  if [[ "$ST" == "FAILED" ]]; then
    echo "FAIL: transfer FAILED"
    api_get "$API_URL/v1/transfers/$REQ_ID" | jq .
    exit 1
  fi
  sleep 5
done
FINAL_STATUS=$(api_get "$API_URL/v1/transfers/$REQ_ID" | jq -r '.transfer_request.status')
echo "FINAL_STATUS=$FINAL_STATUS"

echo "--- 6. Verify destination object ---"
aws s3 cp "s3://${TRANSFER_BUCKET}/${DST_KEY}" - --region "$REGION" | od -c | head -5

echo "--- 7. Agent query (catalog) ---"
AG1=$(json_post "$API_URL/v1/agent/query" -d '{"query":"List the four BayRelay transfer_type values as a comma-separated list only, no other words."}')
echo "$AG1" | jq '{request_id, agent_response}'

echo "--- 8. Agent query with trace + tool-oriented prompt ---"
if ((${#AUTH[@]} > 0)); then
  AG2=$(curl -sS -X POST "$API_URL/v1/agent/query" \
    -H "Content-Type: application/json" \
    -H "x-correlation-id: demo-$RUN_ID" \
    -H "x-enable-trace: true" \
    "${AUTH[@]}" \
    -d "{\"query\":\"Use executeAction only. Call validateTransferRequest with parameters JSON: {\\\"partner_id\\\":\\\"$PARTNER_ID\\\",\\\"source_endpoint_id\\\":\\\"$EPT_IN\\\",\\\"target_endpoint_id\\\":\\\"$EPT_OUT\\\",\\\"transfer_type\\\":\\\"S3_TO_S3\\\"}. Reply with the tool JSON result only.\"}")
else
  AG2=$(curl -sS -X POST "$API_URL/v1/agent/query" \
    -H "Content-Type: application/json" \
    -H "x-correlation-id: demo-$RUN_ID" \
    -H "x-enable-trace: true" \
    -d "{\"query\":\"Use executeAction only. Call validateTransferRequest with parameters JSON: {\\\"partner_id\\\":\\\"$PARTNER_ID\\\",\\\"source_endpoint_id\\\":\\\"$EPT_IN\\\",\\\"target_endpoint_id\\\":\\\"$EPT_OUT\\\",\\\"transfer_type\\\":\\\"S3_TO_S3\\\"}. Reply with the tool JSON result only.\"}")
fi
echo "$AG2" | jq '{request_id, agent_response, tool_calls: (.tool_calls != null)}'

echo "--- 9. Idempotency replay ---"
IDEM=$(json_post "$API_URL/v1/transfers" \
  -H "x-idempotency-key: ${IDEM_BASE}-s3s3" \
  -d "{\"partner_id\":\"$PARTNER_ID\",\"source_endpoint_id\":\"$EPT_IN\",\"target_endpoint_id\":\"$EPT_OUT\",\"transfer_type\":\"S3_TO_S3\",\"payload\":{\"source_bucket\":\"$TRANSFER_BUCKET\",\"source_key\":\"$SRC_KEY\",\"dest_bucket\":\"$TRANSFER_BUCKET\",\"dest_key\":\"$DST_KEY\"}}")
echo "$IDEM" | jq .

echo "--- 10. Transfer Family connector probe (AWS CLI) ---"
CONNECTOR_ID=""
if aws transfer list-connectors --region "$REGION" --output json 2>/dev/null | jq -e '.Connectors | length > 0' >/dev/null 2>&1; then
  CONNECTOR_ID=$(aws transfer list-connectors --region "$REGION" --output json | jq -r '.Connectors[0].ConnectorId // empty')
  echo "CONNECTOR_ID=$CONNECTOR_ID"
else
  echo "No connectors listed (Transfer Family may not be deployed in this account/region)."
fi

S3SFTP_STATUS=skipped
SFTP_S3_STATUS=skipped
SFTP_SFTP_STATUS=skipped
# Avoid ':' in S3 keys (RUN_ID is ISO-8601). macOS /bin/bash 3.2 lacks ${var//:/-}; normalize with Python.
SAFE_RUN_ID=$(python3 -c "import sys; print(sys.argv[1].replace(':','-'))" "$RUN_ID")

if [[ -n "$CONNECTOR_ID" ]]; then
  echo "--- 11. S3_TO_SFTP (connector) ---"
  SFTP_SRC_KEY="demo/report-full/sftp-src/sftp-${SAFE_RUN_ID}.txt"
  echo "sftp payload $RUN_ID" | aws s3 cp - "s3://${TRANSFER_BUCKET}/${SFTP_SRC_KEY}" --region "$REGION"
  S3SFTP_STATUS=""
  for s3sftp_attempt in 1 2; do
    S3SFTP=$(json_post "$API_URL/v1/transfers" \
      -H "x-idempotency-key: ${IDEM_BASE}-s3sftp-${s3sftp_attempt}" \
      -d "{\"partner_id\":\"$PARTNER_ID\",\"source_endpoint_id\":\"$EPT_IN\",\"target_endpoint_id\":\"$EPT_OUT\",\"transfer_type\":\"S3_TO_SFTP\",\"payload\":{\"source_bucket\":\"$TRANSFER_BUCKET\",\"source_key\":\"$SFTP_SRC_KEY\",\"remote_directory\":\"/\"}}")
    echo "$S3SFTP" | jq .
    SFTP_REQ=$(echo "$S3SFTP" | jq -r .request_id)
    if [[ -z "$SFTP_REQ" || "$SFTP_REQ" == "null" ]]; then
      S3SFTP_STATUS=submit_failed
      break
    fi
    for i in $(seq 1 36); do
      SST=$(api_get "$API_URL/v1/transfers/$SFTP_REQ" | jq -r '.transfer_request.status // empty')
      echo "s3-sftp poll $i (attempt $s3sftp_attempt): status=$SST"
      if [[ "$SST" == "SUCCEEDED" || "$SST" == "FAILED" ]]; then
        S3SFTP_STATUS="$SST"
        break
      fi
      sleep 5
    done
    echo "S3SFTP_STATUS=$S3SFTP_STATUS"
    [[ "$S3SFTP_STATUS" == "SUCCEEDED" ]] && break
    [[ "$s3sftp_attempt" -lt 2 ]] && echo "WARN: S3_TO_SFTP failed — retrying once after 10s..." >&2 && sleep 10
  done

  if [[ "$S3SFTP_STATUS" != "SUCCEEDED" ]]; then
    echo "FAIL: S3_TO_SFTP did not succeed (connector present)." >&2
    exit 1
  fi

  SFTP_EXEC_ID=$(echo "$S3SFTP" | jq -r .execution_id)
  echo "--- 12. Locate file on connector SFTP home (S3 key under sftp-connector/) ---"
  CONNECTOR_REMOTE_BASENAME=""
  for j in $(seq 1 30); do
    K=$(aws s3api list-objects-v2 --bucket "$TRANSFER_BUCKET" --prefix "sftp-connector/flat-send-${SFTP_EXEC_ID}-" \
      --region "$REGION" --output json | jq -r '.Contents[0].Key // empty')
    if [[ -n "$K" && "$K" != "null" ]]; then
      CONNECTOR_REMOTE_BASENAME=$(basename "$K")
      echo "S3 object: s3://${TRANSFER_BUCKET}/${K}  ->  remote path /${CONNECTOR_REMOTE_BASENAME}"
      break
    fi
    sleep 2
  done
  if [[ -z "$CONNECTOR_REMOTE_BASENAME" ]]; then
    echo "FAIL: expected s3://${TRANSFER_BUCKET}/sftp-connector/flat-send-${SFTP_EXEC_ID}-*" >&2
    exit 1
  fi
  REMOTE_SLASH="/${CONNECTOR_REMOTE_BASENAME}"

  echo "--- 13. SFTP_TO_S3 (connector retrieve) ---"
  # Tie pull prefix to the S3→SFTP execution id (avoids RUN_ID colon edge cases; unique per demo).
  PULL_PREFIX="demo/report-full/sftp-pulled/${SFTP_EXEC_ID}"
  SFTP_S3_BODY=$(jq -n \
    --arg p "$PARTNER_ID" --arg ein "$EPT_IN" --arg eout "$EPT_OUT" \
    --arg rp "$REMOTE_SLASH" --arg b "$TRANSFER_BUCKET" --arg pre "$PULL_PREFIX" \
    '{partner_id:$p, source_endpoint_id:$ein, target_endpoint_id:$eout, transfer_type:"SFTP_TO_S3", payload:{remote_paths:[$rp], dest_bucket:$b, dest_prefix:$pre}}')
  SFTP_S3=$(json_post "$API_URL/v1/transfers" \
    -H "x-idempotency-key: ${IDEM_BASE}-sftps3" \
    -d "$SFTP_S3_BODY")
  echo "$SFTP_S3" | jq .
  SFTP_S3_REQ=$(echo "$SFTP_S3" | jq -r .request_id)
  if [[ -z "$SFTP_S3_REQ" || "$SFTP_S3_REQ" == "null" ]]; then
    echo "FAIL: no request_id from SFTP_TO_S3 submit" >&2
    exit 1
  fi
  for i in $(seq 1 36); do
    S3ST=$(api_get "$API_URL/v1/transfers/$SFTP_S3_REQ" | jq -r '.transfer_request.status // empty')
    echo "sftp-s3 poll $i: status=$S3ST"
    if [[ "$S3ST" == "SUCCEEDED" || "$S3ST" == "FAILED" ]]; then
      SFTP_S3_STATUS="$S3ST"
      break
    fi
    sleep 5
  done
  echo "SFTP_S3_STATUS=$SFTP_S3_STATUS"
  if [[ "$SFTP_S3_STATUS" != "SUCCEEDED" ]]; then
    echo "FAIL: SFTP_TO_S3 did not succeed." >&2
    api_get "$API_URL/v1/transfers/$SFTP_S3_REQ" | jq . >&2 || true
    exit 1
  fi

  echo "--- 14. Verify SFTP_TO_S3 wrote objects under prefix ${PULL_PREFIX}/ ---"
  PULL_COUNT=0
  for v in $(seq 1 20); do
    # S3 list-objects-v2 may omit KeyCount when only Contents is present; jq '.KeyCount // 0' then wrongly yields 0.
    PULL_COUNT=$(aws s3api list-objects-v2 --bucket "$TRANSFER_BUCKET" --prefix "${PULL_PREFIX}/" --region "$REGION" --output json | jq -r '(.Contents // []) | length')
    echo "object_count=$PULL_COUNT (try $v)"
    if [[ "${PULL_COUNT:-0}" -ge 1 ]]; then
      break
    fi
    sleep 1
  done
  if [[ "${PULL_COUNT:-0}" -lt 1 ]]; then
    echo "FAIL: expected at least one object under s3://${TRANSFER_BUCKET}/${PULL_PREFIX}/" >&2
    exit 1
  fi

  echo "--- 15. SFTP_TO_SFTP (retrieve + send via same connector / server) ---"
  SFTP_SFTP_BODY=$(jq -n \
    --arg p "$PARTNER_ID" --arg ein "$EPT_IN" --arg eout "$EPT_OUT" --arg rp "$REMOTE_SLASH" \
    '{partner_id:$p, source_endpoint_id:$ein, target_endpoint_id:$eout, transfer_type:"SFTP_TO_SFTP", payload:{remote_source_paths:[$rp]}}')
  SFTP_SFTP=$(json_post "$API_URL/v1/transfers" \
    -H "x-idempotency-key: ${IDEM_BASE}-sftpsftp" \
    -d "$SFTP_SFTP_BODY")
  echo "$SFTP_SFTP" | jq .
  SFTP_SFTP_REQ=$(echo "$SFTP_SFTP" | jq -r .request_id)
  if [[ -z "$SFTP_SFTP_REQ" || "$SFTP_SFTP_REQ" == "null" ]]; then
    echo "FAIL: no request_id from SFTP_TO_SFTP submit" >&2
    exit 1
  fi
  for i in $(seq 1 36); do
    RR=$(api_get "$API_URL/v1/transfers/$SFTP_SFTP_REQ" | jq -r '.transfer_request.status // empty')
    echo "sftp-sftp poll $i: status=$RR"
    if [[ "$RR" == "SUCCEEDED" || "$RR" == "FAILED" ]]; then
      SFTP_SFTP_STATUS="$RR"
      break
    fi
    sleep 5
  done
  echo "SFTP_SFTP_STATUS=$SFTP_SFTP_STATUS"
  if [[ "$SFTP_SFTP_STATUS" != "SUCCEEDED" ]]; then
    echo "FAIL: SFTP_TO_SFTP did not succeed." >&2
    api_get "$API_URL/v1/transfers/$SFTP_SFTP_REQ" | jq . >&2 || true
    exit 1
  fi
fi

# --- Phase 3: vector KB (OpenSearch Serverless + Bedrock Retrieve + agent RAG) ---
if [[ "${SKIP_KB_PHASE:-0}" != "1" ]]; then
  KB_ID="${KNOWLEDGE_BASE_ID:-}"
  DS_ID="${KB_DATA_SOURCE_ID:-}"
  KB_BUCKET="${KB_SOURCE_BUCKET:-}"
  AGENT_TERRAFORM_ID="${BEDROCK_AGENT_ID:-}"
  if [[ -z "$KB_ID" && -f "$BAYRELAY_TF_DIR/main.tf" ]]; then
    KB_ID=$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw bedrock_knowledge_base_id 2>/dev/null || true)
    DS_ID=$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw bedrock_kb_data_source_id 2>/dev/null || true)
    KB_BUCKET=$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw kb_source_bucket 2>/dev/null || true)
    AGENT_TERRAFORM_ID=$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw bedrock_agent_id 2>/dev/null || true)
  fi
  if [[ -z "$KB_ID" || "$KB_ID" == "null" ]]; then
    echo "--- Phase 3: skipped (no knowledge base id; apply Terraform with enable_bedrock_vector_kb or set KNOWLEDGE_BASE_ID) ---"
  elif [[ -z "$DS_ID" || "$DS_ID" == "null" ]]; then
    echo "FAIL: Phase 3 needs bedrock_kb_data_source_id (terraform output or KB_DATA_SOURCE_ID)." >&2
    exit 1
  else
    if [[ -z "$KB_BUCKET" || "$KB_BUCKET" == "null" ]]; then
      echo "FAIL: Phase 3 needs kb_source_bucket (terraform output kb_source_bucket or KB_SOURCE_BUCKET)." >&2
      exit 1
    fi
    echo "--- 16. Phase 3 — sync curated docs to KB source bucket ---"
    aws s3 sync "$ROOT/docs/kb" "s3://${KB_BUCKET}/demo-sync/kb-docs/" --region "$REGION" --sse aws:kms
    echo "--- 17. Phase 3 — start KB ingestion (wait) ---"
    python3 "$ROOT/scripts/start_kb_ingestion.py" \
      --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" --region "$REGION" --wait || {
      echo "FAIL: KB ingestion did not complete." >&2
      exit 1
    }
    echo "--- 18. Phase 3 — prepare Bedrock agent (draft picks up KB association) ---"
    AGENT_TERRAFORM_ID=$(terraform -chdir="$BAYRELAY_TF_DIR" output -raw bedrock_agent_id 2>/dev/null || true)
    if [[ -n "$AGENT_TERRAFORM_ID" && "$AGENT_TERRAFORM_ID" != "null" ]]; then
      python3 "$ROOT/scripts/prepare_bedrock_agent.py" \
        --agent-id "$AGENT_TERRAFORM_ID" --region "$REGION" --wait || {
        echo "FAIL: prepare_agent did not reach PREPARED." >&2
        exit 1
      }
      PY="${ROOT}/.venv/bin/python3"
      [[ -x "$PY" ]] || PY=python3
      echo "--- 18b. Sync production Bedrock alias to latest prepared version ---"
      PROD_ALIAS=$("$PY" "$ROOT/scripts/publish_bedrock_prod_alias.py" \
        --agent-id "$AGENT_TERRAFORM_ID" --alias-name prod --region "$REGION" 2>/dev/null || true)
      if [[ -n "$PROD_ALIAS" ]]; then
        echo "prod alias_id=$PROD_ALIAS"
        sleep 5
      fi
    else
      echo "--- 18. Phase 3 — prepare agent skipped (set BEDROCK_AGENT_ID or terraform outputs) ---"
    fi
    echo "--- 19. Phase 3 — Bedrock Retrieve smoke (expect checksum policy text) ---"
    KNOWLEDGE_BASE_ID="$KB_ID" AWS_REGION="$REGION" \
      python3 "$ROOT/scripts/test_retrieval.py" --expect-substring "checksum" || {
      echo "FAIL: KB retrieve did not return expected content." >&2
      exit 1
    }
    echo "--- 20. Phase 3 — agent query grounded on KB (checksum retry) ---"
    agent_kb_ok=false
    for attempt in 1 2 3; do
      AG_KB=$(json_post "$API_URL/v1/agent/query" -d '{"query":"According to the knowledge base retry policy only: for checksum failures on file transfers, is automatic retry allowed without operator confirmation? Reply with exactly one word, No or Yes."}')
      echo "$AG_KB" | jq '{request_id, agent_response, attempt: '"$attempt"'}'
      AR=$(echo "$AG_KB" | jq -r '.agent_response // empty' | tr '[:upper:]' '[:lower:]')
      if echo "$AR" | grep -qiE '(^|[^a-z])yes([^a-z]|$)'; then
        [[ "$attempt" -lt 3 ]] && echo "WARN: agent answered Yes (attempt $attempt) — retrying..." >&2
        continue
      fi
      if echo "$AR" | grep -qiE '(^|[^a-z])no([^a-z]|$)|do not auto-retry|operator confirmation'; then
        echo "OK: agent KB policy response acceptable"
        agent_kb_ok=true
        break
      fi
      echo "WARN: agent KB answer ambiguous (attempt $attempt): $AR" >&2
      agent_kb_ok=true
      break
    done
    if [[ "$agent_kb_ok" != true ]]; then
      echo "FAIL: agent should not approve automatic retry for checksum failures after 3 attempts (got: $AR)" >&2
      exit 1
    fi
  fi
else
  echo "--- Phase 3: skipped (SKIP_KB_PHASE=1) ---"
fi

echo "--- 21. Operations dashboard API ---"
OPS=$(api_get "$API_URL/v1/ops/summary")
echo "$OPS" | jq '{health, counts, transfer_status: .transfers.by_status}'
OPS_HEALTH=$(echo "$OPS" | jq -r '.health // empty')
if [[ -z "$OPS_HEALTH" ]]; then
  echo "FAIL: GET /v1/ops/summary returned no health field." >&2
  exit 1
fi
echo "OK: ops summary health=$OPS_HEALTH"

echo "--- 22. Self-service onboarding (submit + approve) ---"
ONB=$(json_post "$API_URL/v1/onboarding/requests" -d '{
  "company_name": "Demo Customer Corp",
  "contact_email": "onboarding-demo@bayareala8s.com",
  "transfer_types": ["S3_TO_S3"],
  "notes": "Automated smoke onboarding"
}')
echo "$ONB" | jq '{request_id: .onboarding_request.request_id, status: .onboarding_request.status}'
ONB_ID=$(echo "$ONB" | jq -r '.onboarding_request.request_id // empty')
ONB_STATUS=$(echo "$ONB" | jq -r '.onboarding_request.status // empty')
if [[ -z "$ONB_ID" ]]; then
  echo "FAIL: onboarding create did not return request_id." >&2
  exit 1
fi
ONB_PID=$(echo "$ONB" | jq -r '.partner_id // .onboarding_request.partner_id // empty')
if [[ -n "$ONB_PID" && "$ONB_PID" != "null" ]]; then
  echo "OK: onboarding auto-approved partner_id=$ONB_PID"
elif [[ "$ONB_STATUS" == "APPROVED" ]]; then
  echo "OK: onboarding already approved (status=$ONB_STATUS)"
else
  ONB_AP=$(json_post "$API_URL/v1/onboarding/requests/$ONB_ID/approve" -d '{}')
  echo "$ONB_AP" | jq '{status, partner_id, endpoint_ids}'
  ONB_PID=$(echo "$ONB_AP" | jq -r '.partner_id // empty')
  if [[ -z "$ONB_PID" || "$ONB_PID" == "null" ]]; then
    echo "FAIL: onboarding approve did not return partner_id." >&2
    exit 1
  fi
  echo "OK: onboarding approved partner_id=$ONB_PID"
fi

echo
echo "=== Demo finished RUN_ID=$RUN_ID ==="
echo "DEMO_LOG=$DEMO_LOG"
