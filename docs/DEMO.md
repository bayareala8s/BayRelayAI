# Customer demo — BayRelay Phase 2 (Transfer Family + connectors)

**Start/stop the stack:** [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md) (`demo_start.sh`, `demo_stop.sh`, `demo_cycle.sh`).

**Full demo catalog (PoC vs Production):** [DEMO_CATALOG.md](DEMO_CATALOG.md).

## Environment

After `terraform apply` in `environments/`, read outputs (API URL, bucket, SFTP host, connector id, secret ARNs). Example shape:

| Item | Notes |
|------|--------|
| **HTTP API** | `terraform output http_api_endpoint` |
| **Transfer bucket** | `terraform output transfer_data_bucket` |
| **Bedrock Agent** | `terraform output bedrock_agent_id`; set `bedrock_agent_alias_id` (tfvars) to a **published** alias in prod (often `TSTALIASID` only in dev) |
| **SFTP server** | `terraform output sftp_server_endpoint` — hostname, **port 22** |
| **Inbound user** | `terraform output sftp_inbound_username` (default `bayrelay-demo`) |
| **Inbound private key** | `terraform output -raw sftp_inbound_private_key_secret_arn` then retrieve value in **Secrets Manager** (PEM for FileZilla / `sftp` CLI) |
| **Connector ID** | `terraform output transfer_connector_id` — used by workflow Lambda (`TRANSFER_CONNECTOR_ID`) |

**Connector prerequisites (Terraform module):** SFTP connectors need `trusted_host_keys` on the target server. By default the module runs `ssh-keyscan` at apply (requires outbound SSH; `hashicorp/external` in `versions.tf`). Override with module input `connector_trusted_host_keys` if apply runs in a locked-down network.

**Transfer IAM trust:** Inbound, connector-user, and connector-access roles trust `transfer.amazonaws.com` with `StringEquals` on `aws:SourceAccount` only. Tight `ArnLike` on `aws:SourceArn` caused **Unable to AssumeRole for user** for SFTP data access in verification; keep trust aligned with [AWS Transfer trust guidance](https://docs.aws.amazon.com/transfer/latest/userguide/requirements-roles.html) for your org.

Set `enable_transfer_family = false` in `terraform.tfvars` only if you want to skip Transfer Family hourly charges (S3→SFTP / SFTP flows will fail until a connector exists).

## SFTP model (important for the script)

- **Inbound user** (`bayrelay-demo`): logical `/` → S3 prefix `sftp-inbound/`. Partner uploads appear under that prefix; **EventBridge** invokes `bayrelay-dev-sftp-inbound` to write **audit** events.
- **Connector user** (`bayrelay-connector`): logical `/` → S3 prefix `sftp-connector/`. The **Transfer connector** authenticates as this user. **`StartFileTransfer` retrieve** can only see paths under **this** user’s SFTP home, not under `sftp-inbound/` (different Transfer user).
- **S3→SFTP**: Reads objects from the transfer bucket (IAM allows) and uploads via SFTP into the connector user’s tree (typically under `sftp-connector/` in S3).
- **External partners**: Point the connector `url` at their host (separate module fork / variable) and store credentials in Secrets Manager — same workflow code path.

## 1. Inbound SFTP (FileZilla)

1. Secrets Manager → secret `…-sftp-inbound-private-key` → copy **PEM** into a local file, e.g. `bayrelay-demo.pem`, `chmod 600`.
2. FileZilla: Protocol SFTP, host = `sftp_server_endpoint`, user = `sftp_inbound_username`, key file = PEM.
3. Upload `hello.txt` → object key `sftp-inbound/hello.txt` in the transfer bucket.
4. CloudWatch Logs: `/aws/lambda/<prefix>-sftp-inbound` and `…-audit-events` DynamoDB / audit trail.

## 2. S3 → S3 (unchanged)

Upload to `demo/inbound/…`, then `POST /v1/transfers` with `transfer_type` `S3_TO_S3` and `payload` `source_bucket`, `source_key`, `dest_bucket`, `dest_key`.

## 3. S3 → SFTP (connector)

Object must live in a key the **connector access role** can read (demo: anywhere under the transfer bucket). Remote directory is on the **SFTP server as seen by the connector user** (e.g. `/` drops under `sftp-connector/` in S3).

```bash
API="$(terraform output -raw http_api_endpoint)"
BUCKET="$(terraform output -raw transfer_data_bucket)"

# ensure source object exists, e.g. s3 cp demo/send-me.txt s3://$BUCKET/demo/send-me.txt

curl -sS -X POST "$API/v1/transfers" \
  -H "Content-Type: application/json" \
  -H "x-idempotency-key: demo-s3-sftp-$(date +%s)" \
  -d "{
    \"partner_id\":\"PRT-...\",
    \"source_endpoint_id\":\"EPT-...\",
    \"target_endpoint_id\":\"EPT-...\",
    \"transfer_type\":\"S3_TO_SFTP\",
    \"payload\":{
      \"source_bucket\":\"$BUCKET\",
      \"source_key\":\"demo/send-me.txt\",
      \"remote_directory\":\"/\"
    }
  }"
```

Poll `GET /v1/transfers/{request_id}`. Step Functions `…-sf-s3-to-sftp` runs verify + `StartFileTransfer` + completion polling.

## 4. SFTP → S3 (retrieve via connector)

`remote_paths` must be paths **visible to the connector user** (e.g. a file previously written under their home by an S3→SFTP send).

```bash
curl -sS -X POST "$API/v1/transfers" \
  -H "Content-Type: application/json" \
  -H "x-idempotency-key: demo-sftp-s3-$(date +%s)" \
  -d "{
    \"partner_id\":\"PRT-...\",
    \"source_endpoint_id\":\"EPT-...\",
    \"target_endpoint_id\":\"EPT-...\",
    \"transfer_type\":\"SFTP_TO_S3\",
    \"payload\":{
      \"remote_paths\":[\"/send-me.txt\"],
      \"dest_bucket\":\"$BUCKET\",
      \"dest_prefix\":\"demo/pulled\"
    }
  }"
```

## 5. SFTP → SFTP (relay: retrieve then send)

Stages under `sftp-staging/<execution_id>/` in the transfer bucket, then sends to `remote_dest_directory`.

```bash
curl -sS -X POST "$API/v1/transfers" \
  -H "Content-Type: application/json" \
  -H "x-idempotency-key: demo-sftp-sftp-$(date +%s)" \
  -d "{
    \"partner_id\":\"PRT-...\",
    \"source_endpoint_id\":\"EPT-...\",
    \"target_endpoint_id\":\"EPT-...\",
    \"transfer_type\":\"SFTP_TO_SFTP\",
    \"payload\":{
      \"remote_source_paths\":[\"/file-in-connector-home.txt\"],
      \"remote_dest_directory\":\"/archive/\"
    }
  }"
```

## 6. Agent (Bedrock)

Single action `executeAction` with `operation` + `parameters`.

**Traces (demo / debugging):** When the API Lambda has `BAYRELAY_ALLOW_AGENT_TRACE=true` (Terraform `allow_agent_trace_header`, default **true** in dev), send header **`x-enable-trace: true`** on `POST /v1/agent/query` so Bedrock returns orchestration trace data (may populate `tool_calls` in the JSON body). Set `allow_agent_trace_header = false` in production-style environments so clients cannot enable traces.

Examples:

- `listRecentFailures` — queries DynamoDB GSI `status-created_at` for `FAILED` executions.
- `retryTransferExecution` — resubmits from the original transfer request with a new idempotency key.

```bash
curl -sS -X POST "$API/v1/agent/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"List the two most recent failed transfer executions."}'
```

## 7. Console map

- **AWS Transfer Family**: SFTP server + connector + users.
- **Step Functions**: `…-sf-s3-to-sftp`, `…-sf-sftp-to-s3`, `…-sf-sftp-to-sftp`, `…-sf-transfer-precheck`.
- **DynamoDB**: `…-transfer-executions` (GSI `status-created_at`).
- **Lambda**: `…-workflow`, `…-sftp-inbound`, `…-agent-tools`, `…-api`.

## 8. Ops / cost / security

- **Transfer Family** bills per hour the server is **online**; disable with `enable_transfer_family = false` for idle sandboxes.
- **Bedrock IAM**: API Lambda allows `bedrock:InvokeAgent`, `GetAgent`, `ListAgentAliases` (not full `bedrock:*`).
- **Fargate**: Not provisioned here; add a worker cluster if you need long-running SFTP clients beyond Transfer connectors.
