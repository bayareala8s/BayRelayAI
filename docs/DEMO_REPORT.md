# BayRelay — Full demo execution report

> **Historical note:** This run used `environments/dev` (removed). The repo now has a single production stack in `environments/`.

**Run ID:** `2026-04-01T07:30:16Z` (UTC)  
**Region:** `us-west-2`  
**Account (from CLI):** `277374794397`  
**API base URL:** `https://0wf4n2y4da.execute-api.us-west-2.amazonaws.com`  
**Automated script:** [`scripts/run_full_demo.sh`](../scripts/run_full_demo.sh)  
**Local log:** `/tmp/bayrelay-demo-2026-04-01T07-30-16Z.log` (runner host; not committed)

**Infra notes before this run:** `terraform apply` in `environments/dev` with Transfer module updates (connector `trusted_host_keys`, IAM trust for `transfer.amazonaws.com`, workflow Lambda path/timeout fixes). Re-run `terraform plan` in `environments/dev` before production cutover.

---

## Executive summary

| Area | Result |
|------|--------|
| Partner + endpoint registration | **Pass** (HTTP 201) |
| S3 staging + **S3→S3** transfer | **Pass** (HTTP 202 → **SUCCEEDED** ~10s) |
| Destination object readable | **Pass** (content matches source line) |
| Idempotent transfer resubmission | **Pass** (`deduplicated: true`) |
| Agent NL query (transfer types) | **Pass** |
| Agent + trace + strict tool prompt | **Inconclusive** (`x-enable-trace: true` honored; **no** tool invocations in API `tool_calls`; model did not validate via tool) |
| Transfer Family connector (`list-connectors`) | **Pass** (connector present) |
| **S3→SFTP** (connector + Step Functions) | **Pass** (**SUCCEEDED**; staging key `flat-send-*`, logical home `sftp-connector/`) |

**Bottom line:** Control plane, **S3→S3**, and **S3→SFTP** (Transfer connector → same-account Transfer server) are verified end-to-end. For **customer production**, still apply JWT/WAF (see prod variables), publish a **non-draft** Bedrock alias and set `bedrock_agent_alias_id`, and run `terraform apply` in **prod** after aligning `versions.tf` (includes `hashicorp/external` for optional host-key override).

---

## Environment under test

| Resource | Value |
|----------|--------|
| Transfer data bucket | `bayrelay-dev-transfer-data-277374794397` |
| Bedrock agent | `BLFJLANP8V` (alias from Terraform/env, often `TSTALIASID` in dev) |
| Sample precheck execution | `arn:aws:states:us-west-2:277374794397:execution:bayrelay-dev-sf-transfer-precheck:EX-d5755b3ce929-07aedb3c` |
| DynamoDB GSI | `status-created_at` on `bayrelay-dev-transfer-executions` |
| Transfer connector | `c-4ec606448c1e46339` (SFTP URL = managed server endpoint, `trusted_host_keys` populated) |

---

## Scenario results (detailed)

### 1. Register partner — **Pass**

- **Response:** HTTP **201**
- **`partner_id`:** `PRT-a27dee468cda`

### 2. Register endpoints — **Pass**

- **Endpoint IDs:** `EPT-36498521d595` (INBOUND), `EPT-796bc41939c0` (OUTBOUND)

### 3. Stage source object — **Pass**

- **Key:** `demo/report-full/inbound/demo-2026-04-01T07:30:16Z.txt`
- **SSE:** `aws:kms`, **35** bytes

### 4. Submit transfer (S3_TO_S3) — **Pass**

- **HTTP:** **202**
- **`request_id`:** `REQ-9b99aa594539`
- **`execution_id`:** `EX-d5755b3ce929`

### 5. Poll status — **Pass**

- **`transfer_request.status`:** **SUCCEEDED** (2nd poll)

### 6. Verify destination — **Pass**

- **Key:** `demo/report-full/outbound/demo-2026-04-01T07:30:16Z.txt`
- **Content:** `BayRelay demo 2026-04-01T07:30:16Z`

### 7. Agent query — catalog — **Pass**

- **`agent_response`:** `S3_TO_S3, S3_TO_SFTP, SFTP_TO_S3, SFTP_TO_SFTP`

### 8. Agent query — trace + validateTransferRequest — **Inconclusive**

- **Headers:** `x-enable-trace: true` (when `allow_agent_trace_header` is true on the API Lambda).
- **Observed:** Model did not return usable `tool_calls` for the strict prompt; treat as prompt/model variance; use Bedrock console trace for demos if needed.

### 9. Idempotency — **Pass**

- Same `x-idempotency-key` → HTTP **200**, `deduplicated: true`.

### 10–11. Transfer Family + S3_TO_SFTP — **Pass**

- **Connector ID:** `c-4ec606448c1e46339`
- **S3_TO_SFTP:** `REQ-d4262a0625da` / `EX-6e5235f5374a` → **SUCCEEDED**
- **Implementation notes:** Connector `sftp_config.trusted_host_keys` required for `StartFileTransfer`; workflow uses `/bucket/key` SendFilePaths, omits `RemoteDirectoryPath` when destination is home, stages via `copy_object` to a **slash-free** key `flat-send-{execution_id}-…` (avoids nested SFTP paths and double-prefix under logical home).

---

## Production readiness (delta from earlier reports)

| Item | Note |
|------|------|
| **Transfer IAM trust** | Use `StringEquals` on `aws:SourceAccount` only for `transfer.amazonaws.com` principals on **inbound**, **connector user**, and **connector access** roles. `ArnLike` on `aws:SourceArn` caused **Unable to AssumeRole for user** for SFTP data plane in this account. |
| **Connector host keys** | Module defaults: `ssh-keyscan` at apply via `hashicorp/external`, or set `connector_trusted_host_keys` when apply has no outbound SSH. |
| **Bedrock alias** | Set `bedrock_agent_alias_id` to a **published** alias in prod; avoid draft-only traffic. |
| **Workflow Lambda** | Timeout **300s** (connector polling); `SendFilePaths` must start with `/`. |

---

## Artifacts produced by this run

| Artifact | Location |
|----------|----------|
| S3 source | `s3://bayrelay-dev-transfer-data-277374794397/demo/report-full/inbound/demo-2026-04-01T07:30:16Z.txt` |
| S3 destination | `s3://bayrelay-dev-transfer-data-277374794397/demo/report-full/outbound/demo-2026-04-01T07:30:16Z.txt` |
| DynamoDB | Partner, endpoints, requests, executions, audit/idempotency rows for the run |
| Report | `docs/DEMO_REPORT.md` (this file) |

---

## Sign-off

- **Executed by:** Automated script on `2026-04-01T07:30:16Z` UTC (Cursor agent session).  
- **Re-run:** `AWS_REGION=us-west-2 ./scripts/run_full_demo.sh` (optional Cognito env vars if JWT is enabled). The script exits **1** if a connector exists and S3_TO_SFTP does not reach **SUCCEEDED**.
