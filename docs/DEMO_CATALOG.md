# BayRelay demo catalog — PoC vs Production

Complete list of demos you can show customers, mapped to **PoC ($24k)** and **Production ($42k)** engagements. Use with [DEMO.md](DEMO.md) (hands-on commands) and [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md) (start/stop stack).

**Automated regression:** `./scripts/run_full_demo.sh` (set `COGNITO_*` for JWT).

---

## Quick comparison

| Dimension | PoC demo | Production demo |
|-----------|----------|-----------------|
| **Goal** | Prove fit in 60–90 min session | Prove go-live readiness + ops handoff |
| **Audience** | Architect, security, integration lead | Same + ops/on-call + sponsor sign-off |
| **Bedrock alias** | Draft (`TSTALIASID`) OK | **Published alias** required |
| **JWT / WAF** | Show Cognito login | Same + emphasize prod hardening |
| **SFTP** | Same-account demo server + connector | **1 external partner connector** (if in SOW) |
| **KB content** | Up to 10 docs (samples + customer samples) | Up to 20 curated customer runbooks |
| **Trace header** | Off in prod config (`allow_agent_trace_header = false`) | Do not demo client traces in prod story |
| **Teardown story** | Optional `demo_stop.sh` at PoC end | Stack retained; SNS alarms subscribed |
| **Duration** | 45–75 min live + optional 15 min architecture | 60–90 min live + 30 min ops/console deep-dive |
| **Operator UI** | **Operator portal** (landing, ops dashboard, API-backed) | Portal v2 + production hardening |

**Operator portal** is included in the reference stack: public landing (`/`), Cognito sign-in, operations dashboard, transfers, automation, onboarding, partners, policies, audit. See [OPERATOR_PORTAL_V2.md](OPERATOR_PORTAL_V2.md). Historical add-on SOW: [SOW_OPERATOR_PORTAL_ADDON.md](SOW_OPERATOR_PORTAL_ADDON.md).

## Demo map (all capabilities)

| # | Demo | Layer | PoC | Production | Automated in `run_full_demo.sh` |
|---|------|-------|:---:|:----------:|:--------------------------------:|
| A | Architecture walkthrough | Story | ✓ | ✓ | — |
| B | Security (JWT, WAF, KMS) | Platform | ✓ | ✓ | partial |
| C | Register partner & endpoints | API | ✓ | ✓ | ✓ steps 1–2 |
| D | S3 → S3 transfer | Execution | ✓ | ✓ | ✓ steps 3–6 |
| E | Idempotency replay | API | ✓ | ✓ | ✓ step 9 |
| F | Poll status / correlation IDs | API | ✓ | ✓ | ✓ step 5 |
| G | S3 → SFTP (connector) | Execution | ✓ | ✓* | ✓ steps 11–12 |
| H | SFTP → S3 (connector retrieve) | Execution | ✓ | ✓* | ✓ steps 13–14 |
| I | SFTP → SFTP (staged relay) | Execution | ✓ | ✓* | ✓ step 15 |
| J | Inbound SFTP (FileZilla) | Execution | ✓ | ✓ | — |
| K | Agent — transfer types (NL) | Agent | ✓ | ✓ | ✓ step 7 |
| L | Agent — tool / trace (debug) | Agent | PoC internal only | Skip in prod | ✓ step 8 |
| M | KB Retrieve smoke | RAG | ✓ | ✓ | ✓ step 19 |
| N | Agent — KB grounded policy Q | RAG | ✓ | ✓ | ✓ step 20 |
| O | KB sync + ingestion (live) | RAG | Optional | ✓ | ✓ steps 16–18 |
| P | Step Functions console | Ops | ✓ | ✓ | — |
| Q | DynamoDB audit trail | Ops | ✓ | ✓ | — |
| R | CloudWatch + SNS alarms | Ops | Brief | ✓ deep | — |
| S | Transfer Family console | Ops | ✓ | ✓ | ✓ step 10 |
| T | External partner SFTP | Integration | ✗ (CO) | ✓ if in SOW | — |
| U | Failure / retry story | Ops | Optional | ✓ | — |
| V | `demo_stop` teardown | Cost | PoC only | ✗ | — |
| W | **Operator portal** (landing + v2) | UI | ✓ | ✓ | [CUSTOMER_DEMO_READY.md](CUSTOMER_DEMO_READY.md) |

---

\*Same-account connector in default stack; Production SOW may include **one external partner** connector (Change Order for more).

---

## Part 1 — PoC demos (recommended flow)

**Total time:** ~60 minutes live (+ 15 min buffer).  
**Prep:** `./scripts/demo_start.sh --yes`, Cognito user, rehearse once.

### Block 0 — Before the meeting (5 min)

- Confirm stack up: `terraform -chdir=environments output http_api_endpoint`
- Export env:
  ```bash
  export COGNITO_CLIENT_ID=$(terraform -chdir=environments output -raw cognito_client_id)
  export COGNITO_USERNAME=... COGNITO_PASSWORD=...
  export AWS_REGION=us-west-2
  ```
- Optional: run `./scripts/run_full_demo.sh` morning-of; keep `DEMO_LOG` path handy if something fails.

---

### Demo A — Architecture (8 min) — **Always start here**

**Show:** [bayrelay-architecture.png](bayrelay-architecture.png)

**Talk track:**

1. Four layers: Agent → RAG → Execution → Production (IaC).
2. **Files move through Step Functions + Lambda**, not through the LLM.
3. Everything in **customer AWS account**; BayAreaLa8s deploys, customer owns data and bill.
4. PoC runs in sandbox account; 90-day evaluation.

**PoC message:** “We’re validating this architecture in your account—not asking you to trust our hosting.”

---

### Demo B — Security: JWT + WAF (5 min)

**Show:**

1. Attempt API call **without** token → 401.
2. Cognito `initiate-auth` → call with `Authorization: Bearer …` → 200.
3. (Optional) WAF console → Web ACL on API stage.

```bash
API=$(terraform -chdir=environments output -raw http_api_endpoint)
# No auth — expect 401
curl -sS -o /dev/null -w "%{http_code}\n" -X POST "$API/v1/partners" -H "Content-Type: application/json" -d '{"name":"test"}'
```

**PoC message:** “Production-style API from day one; PoC uses draft Bedrock alias only.”

**Skip in PoC:** Do not promise SOC2/HIPAA unless Change Order.

---

### Demo C — Control plane: partner & endpoints (5 min)

**Show:** `POST /v1/partners`, `POST /v1/endpoints` (with JWT).

**Talk track:** Partners and endpoints are persisted in DynamoDB; transfers reference them.

**Matches script:** steps 1–2.

---

### Demo D — S3 → S3 (10 min) — **Core “it works” demo**

**Show:**

1. Upload file to transfer bucket (or script stages it).
2. `POST /v1/transfers` with `transfer_type: S3_TO_S3`, `x-idempotency-key`.
3. Poll `GET /v1/transfers/{id}` until `SUCCEEDED`.
4. Show destination object in S3 (Console or CLI).

**Talk track:** Precheck Step Function → child workflow → `CopyObject` → audit in DynamoDB.

**Matches script:** steps 3–6.

---

### Demo E — Idempotency (3 min)

**Show:** Resubmit **same** `x-idempotency-key` → same `request_id`, `deduplicated: true`.

**Matches script:** step 9.

**PoC message:** Safe for automation and retries at the API layer.

---

### Demo G — S3 → SFTP (10 min) — **Phase 2 headline**

**Show:**

1. Object in transfer bucket.
2. Submit `S3_TO_SFTP`.
3. Poll to `SUCCEEDED`.
4. Show file under `sftp-connector/` prefix in S3 (connector user’s logical home).

**Matches script:** steps 11–12.

**PoC caveat:** “This demo uses **same-account** Transfer server; Production SOW includes wiring **your partner’s** SFTP endpoint.”

---

### Demo H — SFTP → S3 (5 min)

**Show:** Pull file from connector SFTP home back into S3 prefix.

**Matches script:** steps 13–14.

---

### Demo I — SFTP → SFTP (5 min) — **Optional if time tight**

**Show:** Staged relay (retrieve → stage in S3 → send).

**Matches script:** step 15.

**PoC tip:** Skip live if running long; mention it’s in automated smoke.

---

### Demo J — Inbound SFTP / FileZilla (8 min) — **High visual impact**

**Show:**

1. Secrets Manager → inbound private key PEM.
2. FileZilla → `sftp_server_endpoint`, user `bayrelay-demo`.
3. Upload `hello.txt` → appears as `sftp-inbound/hello.txt` in S3.
4. CloudWatch log for `sftp-inbound` Lambda (audit event).

**Not in automated script** — prepare FileZilla beforehand.

**Talk track:** Two SFTP users—inbound partner uploads vs connector outbound path.

---

### Demo K + N — Agent & knowledge base (10 min)

**Show:**

1. **K:** “What transfer types does BayRelay support?” → natural language answer (step 7).
2. **M/N:** “For checksum failures, should we auto-retry without operator confirmation?” → grounded **No** from KB (step 20).
3. (Optional) Bedrock console → Knowledge base → data source.

**PoC message:** RAG over **your** documents (up to 10 in PoC); not generic ChatGPT.

**Skip in customer-facing PoC:** Demo L (trace / forced tool calls)—internal debugging only; prod has traces disabled for clients.

---

### Demo P + Q — Console: Step Functions & DynamoDB (5 min)

**Show:**

1. Step Functions → execution graph for S3→S3 or S3→SFTP.
2. DynamoDB → `transfer_requests`, `transfer_executions`, `audit_events`.
3. Point out `correlation_id` from API response.

**PoC message:** Full audit trail for support—not black box.

---

### Demo V — PoC exit options (3 min) — **Close the PoC story**

**Show slide, not live destroy in meeting:**

| Option | Action |
|--------|--------|
| **Teardown** | `./scripts/demo_stop.sh --yes` — stop AWS burn |
| **Retain** | Keep stack; pay AWS; decide later |
| **Upgrade** | Production $34k (with $8k credit) within 60 days |

---

### PoC demos **not** typically shown live

| Demo | Why |
|------|-----|
| External partner SFTP (T) | Out of PoC SOW — quote Change Order |
| Full ingestion live (O) | Slow; show pre-ingested KB unless technical audience |
| Agent trace (L) | Confusing; disabled in prod config |
| Failure injection (U) | Optional appendix for deep technical sessions |

---

### PoC — Minimum viable demo (30 min)

If time is short:

1. Architecture (A)  
2. JWT (B)  
3. S3→S3 (D) + status poll (F)  
4. S3→SFTP (G)  
5. Agent + KB (K + N)  
6. Upgrade path (V)

Run `./scripts/run_full_demo.sh` the night before to validate.

---

## Part 2 — Production demos (additional / different)

Production demos = **everything in PoC**, plus production-only proof points.

### Production-only additions

| # | Demo | What to show | Why it matters |
|---|------|-------------|----------------|
| P1 | **Published Bedrock alias** | Console → Agent → Aliases → version ≠ draft-only | Non-draft AI for live traffic |
| P2 | **Customer KB (20 docs)** | S3 KB bucket with **their** runbooks; re-ingestion | Real RAG, not samples |
| P3 | **External partner connector** | Connector `url` → partner host; Secrets Manager creds | Real B2B path |
| P4 | **SNS alarm subscription** | Email confirmed on `alarm_topic_arn` | Ops readiness |
| P5 | **Third Cognito operator** | Extra user for customer ops team | Handoff complete |
| P6 | **Runbook walkthrough** | [RUNBOOK.md](RUNBOOK.md) — failed transfer triage | On-call enablement |
| P7 | **Handoff package** | `./scripts/customer_handoff.sh` output | Contract acceptance |
| P8 | **Change control** | How Terraform updates roll out | Production governance |
| P9 | **Cost dashboard** | AWS Cost Explorer — Transfer + OpenSearch + Bedrock | FinOps expectation |
| P10 | **Security review pack** | KMS, WAF, IAM summary (no secrets) | Enterprise sign-off |

---

### Production demo flow (~90 min)

| Block | Time | Content |
|-------|------|---------|
| 1 | 10 min | Architecture + **production** differences (alias, partner SFTP, alarms) |
| 2 | 10 min | Security deep-dive (JWT, WAF, KMS, data residency) |
| 3 | 25 min | Full transfer path: S3→S3, S3→SFTP, optional SFTP→S3, FileZilla inbound |
| 4 | 15 min | Agent + **customer** KB citations |
| 5 | 15 min | Ops: Step Functions, DynamoDB, CloudWatch, **SNS** |
| 6 | 10 min | Handoff doc, runbook, hypercare, Care retainer |
| 7 | 5 min | Q&A |

---

### Production — Partner SFTP demo (Demo T)

**When:** Customer signed Production SOW with external connector.

**Show:**

1. Connector points to **partner hostname** (not same-account server).
2. Credentials in Secrets Manager (show ARN, not secret value).
3. `trusted_host_keys` configured.
4. Test file lands on partner-visible path.

**Prep:** Partner firewall allows Transfer connector egress; test file agreed with partner.

**Not available** in default Terraform-only same-account demo.

---

### Production — Failure & recovery (Demo U)

**When:** Technical ops audience.

**Show:**

1. Submit transfer with bad key → `FAILED`.
2. Step Functions → failing state.
3. CloudWatch `workflow` Lambda logs.
4. Agent: “List recent failures” (optional).
5. Correct payload → new idempotency key → `SUCCEEDED`.

**Do not** demo in executive PoC unless asked.

---

## Part 3 — Automated smoke (`run_full_demo.sh`)

Single command regression covering **20 steps**:

| Step | Demo |
|------|------|
| 1–2 | Partner + endpoints |
| 3–6 | S3→S3 + verify object |
| 7 | Agent catalog query |
| 8 | Agent trace prompt (skip narrating in prod) |
| 9 | Idempotency |
| 10 | List connectors |
| 11–12 | S3→SFTP |
| 13–14 | SFTP→S3 |
| 15 | SFTP→SFTP |
| 16–18 | KB sync, ingestion, PrepareAgent |
| 19 | Retrieve smoke |
| 20 | Agent KB policy question |

```bash
export COGNITO_CLIENT_ID=... COGNITO_USERNAME=... COGNITO_PASSWORD=...
AWS_REGION=us-west-2 ./scripts/run_full_demo.sh
# PoC rehearsal with traces internally: same command
# Skip KB during transfer-only debug: SKIP_KB_PHASE=1 ./scripts/run_full_demo.sh
```

**PoC acceptance:** script exits **0**.  
**Production acceptance:** script exits **0** + published alias + customer KB ingested.

---

## Part 4 — Demo matrix by audience

| Audience | PoC focus | Production focus |
|----------|-----------|------------------|
| **CTO / sponsor** | A, B, D, K, V (cost/upgrade) | + P1, P4, P9 |
| **Security** | B, data-in-customer-account, KMS | + P10, IAM review |
| **Integration** | C, D, G, H, T (if available) | + P3 partner connector |
| **Operations** | F, P, Q, J | + P4, P6, U |
| **Business / partner mgr** | D, G, J, K | + handoff P7 |

---

## Part 5 — Prep checklist

### PoC demo day

- [ ] `./scripts/demo_start.sh --yes` or stack already up  
- [ ] `./scripts/run_full_demo.sh` green once  
- [ ] Cognito credentials in env  
- [ ] FileZilla + PEM ready  
- [ ] Architecture PNG on screen  
- [ ] Customer KB samples uploaded (if showing N)  
- [ ] Slide: PoC → Production $34k credit  

### Production demo / handoff

- [ ] Published Bedrock alias in tfvars + applied  
- [ ] 20 KB docs ingested  
- [ ] SNS subscription confirmed  
- [ ] `./scripts/customer_handoff.sh` run  
- [ ] External connector tested (if in scope)  
- [ ] `./scripts/run_full_demo.sh` green  
- [ ] RUNBOOK.md reviewed with customer ops  

---

## Part 6 — What not to promise

| Claim | PoC | Production |
|-------|-----|------------|
| 24/7 SLA | ✗ | Only with Care SOW + higher tier |
| Multi-tenant SaaS | ✗ | ✗ |
| Unlimited partners | ✗ | 1 connector in base SOW |
| Compliance certification | ✗ | Separate engagement |
| AI moves files without workflows | ✗ | ✗ (always show Step Functions) |

---

## Related docs

- [DEMO.md](DEMO.md) — curl/FileZilla commands  
- [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md) — start/stop stack  
- [DEMO_REPORT.md](DEMO_REPORT.md) — sample successful run evidence  
- [PRICING.md](PRICING.md) — PoC vs Production packages  
- [SOW_POC_24K.md](SOW_POC_24K.md) · [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md)
