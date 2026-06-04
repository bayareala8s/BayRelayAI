# BayRelay sequence diagrams — customer use cases & features

Complete sequence diagrams for BayRelay control plane, execution, automation, onboarding, portal, and agent flows.  
Companion: [ARCHITECTURE.md](ARCHITECTURE.md) · [DEMO_CATALOG.md](DEMO_CATALOG.md) · [SELF_SERVICE_AND_AUTOMATION.md](SELF_SERVICE_AND_AUTOMATION.md)

Render Mermaid in GitHub, VS Code, or [mermaid.live](https://mermaid.live).

**PNG exports:** all **31** diagrams are in [`sequence-diagrams/png/`](sequence-diagrams/png/) (regenerate: `./scripts/export_sequence_diagram_pngs.sh`).

---

## Index

| ID | Diagram | Use case (summary) | PNG | Category |
|----|---------|-------------------|-----|----------|
| [UC-00](#uc-00-customer-journey-overview) | Customer journey overview | End-to-end path for a new trading partner from landing and onboarding through... | [png](sequence-diagrams/png/UC-00.png) | Overview |
| [UC-P01](#uc-p01-operator-portal-sign-in) | Operator portal sign-in | Operator authenticates with Cognito and accesses the BayRelay operations port... | [png](sequence-diagrams/png/UC-P01.png) | Platform |
| [UC-P02](#uc-p02-partner-portal-sign-in-scoped-api) | Partner portal sign-in (scoped API) | Partner user signs in and sees only transfers and data scoped to their partne... | [png](sequence-diagrams/png/UC-P02.png) | Platform |
| [UC-P03](#uc-p03-api-call-without-jwt-rejected) | API call without JWT rejected | API Gateway rejects control-plane calls that omit a valid Authorization JWT. | [png](sequence-diagrams/png/UC-P03.png) | Platform |
| [UC-C01](#uc-c01-register-partner-and-endpoints) | Register partner and endpoints | Operator registers a trading partner and one or more protocol endpoints in th... | [png](sequence-diagrams/png/UC-C01.png) | Control plane |
| [UC-C02](#uc-c02-routing-policy-deny-blocks-transfer) | Routing policy DENY blocks transfer | A DENY routing policy stops a submitted transfer during precheck before child... | [png](sequence-diagrams/png/UC-C02.png) | Control plane |
| [UC-T00](#uc-t00-manual-transfer-submit-common-path) | Manual transfer submit (common path) | Client submits a transfer with idempotency, precheck runs, then the type-spec... | [png](sequence-diagrams/png/UC-T00.png) | Transfers |
| [UC-T01](#uc-t01-s3--s3-transfer) | S3 → S3 transfer | Verify source object in S3, copy to destination key, and mark execution succe... | [png](sequence-diagrams/png/UC-T01.png) | Transfers |
| [UC-T02](#uc-t02-s3--sftp-transfer) | S3 → SFTP transfer | Stage file in S3 then SendFilePaths via Transfer Family connector to partner ... | [png](sequence-diagrams/png/UC-T02.png) | Transfers |
| [UC-T03](#uc-t03-sftp--s3-transfer) | SFTP → S3 transfer | Retrieve files from partner SFTP via connector into the BayRelay transfer buc... | [png](sequence-diagrams/png/UC-T03.png) | Transfers |
| [UC-T04](#uc-t04-sftp--sftp-relay-transfer) | SFTP → SFTP relay transfer | Retrieve from remote source to S3 staging, then send from staging to remote d... | [png](sequence-diagrams/png/UC-T04.png) | Transfers |
| [UC-T05](#uc-t05-idempotent-transfer-resubmit) | Idempotent transfer resubmit | Duplicate POST with the same Idempotency-Key returns the original request wit... | [png](sequence-diagrams/png/UC-T05.png) | Transfers |
| [UC-T06](#uc-t06-retry-failed-transfer) | Retry failed transfer | Operator retries a failed transfer by submitting a new request copied from th... | [png](sequence-diagrams/png/UC-T06.png) | Transfers |
| [UC-T07](#uc-t07-cancel-in-flight-transfer) | Cancel in-flight transfer | Operator or partner marks an active transfer request CANCELLED in DynamoDB (s... | [png](sequence-diagrams/png/UC-T07.png) | Transfers |
| [UC-A01](#uc-a01-automation-s3--s3-on-object-created) | Automation S3→S3 on object created | S3 Object Created event matches a transfer rule and auto-submits an S3 to S3 ... | [png](sequence-diagrams/png/UC-A01.png) | Automation |
| [UC-A02](#uc-a02-automation-chain-s3--sftp--sftp--s3) | Automation chain S3→SFTP → SFTP→S3 | Two chained rules: outbound S3 to SFTP staging, then staging object triggers ... | [png](sequence-diagrams/png/UC-A02.png) | Automation |
| [UC-A03](#uc-a03-automation-sftp--sftp-on-connector-staging) | Automation SFTP→SFTP on connector staging | Connector staging key under sftp-connector/flat-send-* triggers SFTP to SFTP ... | [png](sequence-diagrams/png/UC-A03.png) | Automation |
| [UC-A04](#uc-a04-partner-sftp-inbound--s3--s3-automation) | Partner SFTP inbound → S3→S3 automation | Partner uploads to managed SFTP server, file lands in sftp-inbound/, S3 to S3... | [png](sequence-diagrams/png/UC-A04.png) | Automation |
| [UC-O01](#uc-o01-partner-submits-onboarding-request) | Partner submits onboarding request | Prospect or partner submits a self-service onboarding request stored as SUBMI... | [png](sequence-diagrams/png/UC-O01.png) | Onboarding |
| [UC-O02](#uc-o02-operator-approves-onboarding) | Operator approves onboarding | Operator approves request, provisions partner and endpoints, and links Cognit... | [png](sequence-diagrams/png/UC-O02.png) | Onboarding |
| [UC-O03](#uc-o03-onboarding-auto-approve-demo) | Onboarding auto-approve (demo) | Demo mode auto-approves onboarding immediately after submit for hands-on envi... | [png](sequence-diagrams/png/UC-O03.png) | Onboarding |
| [UC-O04](#uc-o04-operator-rejects-onboarding) | Operator rejects onboarding | Operator rejects onboarding with a reason and audit event, no partner provisi... | [png](sequence-diagrams/png/UC-O04.png) | Onboarding |
| [UC-PO01](#uc-po01-operator-operations-dashboard) | Operator operations dashboard | Portal loads ops summary KPIs, health, recent transfers, and onboarding count... | [png](sequence-diagrams/png/UC-PO01.png) | Portal |
| [UC-PO02](#uc-po02-operator-creates-transfer-rule) | Operator creates transfer rule | Operator defines an EventBridge-backed automation rule with match pattern and... | [png](sequence-diagrams/png/UC-PO02.png) | Portal |
| [UC-PO03](#uc-po03-portal-partner-endpoint-crud) | Portal partner/endpoint CRUD | Operator searches partners, updates records, and soft-disables endpoints from... | [png](sequence-diagrams/png/UC-PO03.png) | Portal |
| [UC-G01](#uc-g01-bedrock-agent-query-with-tools) | Bedrock agent query with tools | Operator asks the Bedrock agent which invokes action-group tools against live... | [png](sequence-diagrams/png/UC-G01.png) | Agent |
| [UC-G02](#uc-g02-kb-grounded-policy-answer) | KB-grounded policy answer | Agent retrieves knowledge-base chunks from OpenSearch and returns a grounded ... | [png](sequence-diagrams/png/UC-G02.png) | Agent |
| [UC-G03](#uc-g03-knowledge-base-sync-and-ingestion) | Knowledge base sync and ingestion | Engineer syncs KB markdown to S3, runs ingestion job, and prepares agent alia... | [png](sequence-diagrams/png/UC-G03.png) | Agent |
| [UC-S01](#uc-s01-partner-upload-via-managed-sftp-server) | Partner upload via managed SFTP server | Partner uploads via Transfer Family SFTP server, file maps to sftp-inbound/ p... | [png](sequence-diagrams/png/UC-S01.png) | SFTP inbound |
| [UC-M01](#uc-m01-audit-trail-and-list-audit-events) | Audit trail and list audit events | Operator queries filtered audit events for transfers, onboarding, automation,... | [png](sequence-diagrams/png/UC-M01.png) | Operations |
| [UC-M02](#uc-m02-ops-summary-dashboard-data) | Ops summary dashboard data | API aggregates partner, endpoint, transfer, execution, and onboarding counts ... | [png](sequence-diagrams/png/UC-M02.png) | Operations |

---

## UC-00: Customer journey overview

> **Use case:** End-to-end path for a new trading partner from landing and onboarding through first transfer and status tracking.

High-level path for a new trading partner through BayRelay.

```mermaid
---
title: UC-00 | Customer Journey Overview
---
sequenceDiagram
  autonumber
  participant Prospect as Prospect / Partner user
  participant Portal as Operator portal
  participant API as BayRelay API
  participant DDB as DynamoDB
  participant SFN as Step Functions
  participant S3 as Transfer bucket
  participant SFTP as Transfer Family
  Note over Prospect,SFTP: Use case: End-to-end path for a new trading partner from landing and onboarding through first transfer and status tracking.

  Prospect->>Portal: Visit landing / Apply as partner
  Prospect->>API: POST /v1/onboarding/requests
  API->>DDB: onboarding request SUBMITTED
  Note over API: Optional auto-approve (demo)
  API->>DDB: partner + endpoints provisioned

  Prospect->>Portal: Sign in (Cognito partner)
  Prospect->>API: POST /v1/transfers (or upload via SFTP)
  alt Manual transfer
    API->>SFN: Start precheck → child workflow
    SFN->>S3: verify / copy / connector I/O
  else Automation
    S3-->>API: S3 Object Created event
    API->>SFN: Rule match → submit_transfer
  end
  SFN->>DDB: execution SUCCEEDED / FAILED
  Prospect->>Portal: View transfers / status
```
---

## Platform & security

### UC-P01: Operator portal sign-in

> **Use case:** Operator authenticates with Cognito and accesses the BayRelay operations portal with a validated JWT.

```mermaid
---
title: UC-P01 | Operator Portal Sign-In
---
sequenceDiagram
  autonumber
  participant Op as Operator browser
  participant Portal as Portal SPA
  participant Cognito as Amazon Cognito
  participant APIGW as API Gateway (JWT)
  participant API as Lambda api
  Note over Op,API: Use case: Operator authenticates with Cognito and accesses the BayRelay operations portal with a validated JWT.

  Op->>Portal: Open /login
  Op->>Cognito: InitiateAuth (USER_PASSWORD_AUTH)
  Cognito-->>Op: ID token + access token
  Op->>Portal: Store tokens (localStorage)
  Op->>APIGW: GET /v1/me (Bearer JWT)
  APIGW->>APIGW: Validate JWT (bayrelay-operators)
  APIGW->>API: Invoke with claims
  API-->>Op: role=operator, groups, email
  Op->>Portal: Redirect /operations
```

### UC-P02: Partner portal sign-in (scoped API)

> **Use case:** Partner user signs in and sees only transfers and data scoped to their partner_id claim.

```mermaid
---
title: UC-P02 | Partner Portal Sign-In (Scoped API)
---
sequenceDiagram
  autonumber
  participant P as Partner browser
  participant Cognito as Amazon Cognito
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over P,DDB: Use case: Partner user signs in and sees only transfers and data scoped to their partner_id claim.

  P->>Cognito: Sign in (custom:partner_id set)
  P->>APIGW: GET /v1/transfers?limit=10
  APIGW->>API: JWT claims partner_id=PRT-xxx
  API->>API: enforce_partner_scope
  API->>DDB: Scan/filter requests by partner_id
  API-->>P: Only partner's transfers
  Note over API: Operators see all partners
```

### UC-P03: API call without JWT rejected

> **Use case:** API Gateway rejects control-plane calls that omit a valid Authorization JWT.

```mermaid
---
title: UC-P03 | Unauthenticated API Rejected
---
sequenceDiagram
  participant Client as Client (curl / script)
  participant APIGW as API Gateway
  Note over Client,APIGW: Use case: API Gateway rejects control-plane calls that omit a valid Authorization JWT.

  Client->>APIGW: POST /v1/partners (no Authorization)
  APIGW-->>Client: 401 Unauthorized
```
---

## Control plane

### UC-C01: Register partner and endpoints

> **Use case:** Operator registers a trading partner and one or more protocol endpoints in the control plane.

```mermaid
---
title: UC-C01 | Register Partner and Endpoints
---
sequenceDiagram
  autonumber
  participant Op as Operator (portal or API)
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator registers a trading partner and one or more protocol endpoints in the control plane.

  Op->>APIGW: POST /v1/partners {name}
  APIGW->>API: require_operator
  API->>DDB: PutItem partners (ACTIVE)
  API-->>Op: 201 partner_id

  Op->>APIGW: POST /v1/endpoints {partner_id, protocol, direction}
  APIGW->>API: require_operator
  API->>DDB: PutItem endpoints
  API-->>Op: 201 endpoint_id
```

### UC-C02: Routing policy DENY blocks transfer

> **Use case:** A DENY routing policy stops a submitted transfer during precheck before child workflow runs.

```mermaid
---
title: UC-C02 | Routing Policy DENY Blocks Transfer
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant API as Lambda api
  participant DDB as DynamoDB
  participant SFN as SFN precheck
  participant WF as Lambda workflow
  Note over Op,WF: Use case: A DENY routing policy stops a submitted transfer during precheck before child workflow runs.

  Op->>API: PUT /v1/routing-policies (effect=DENY)
  API->>DDB: policy default + partner_id

  Op->>API: POST /v1/transfers
  API->>DDB: request + execution SUBMITTED/QUEUED
  API->>SFN: StartExecution precheck
  SFN->>WF: precheck_all
  WF->>DDB: Get policy → DENY
  WF-->>SFN: ok=false POLICY_DENIED
  SFN-->>API: Failed
  API->>DDB: execution FAILED
```
---

## Transfers — manual submit

### UC-T00: Manual transfer submit (common path)

> **Use case:** Client submits a transfer with idempotency, precheck runs, then the type-specific child Step Functions workflow executes.

Applies to all four `transfer_type` values; child workflow differs after precheck route.

```mermaid
---
title: UC-T00 | Manual Transfer Submit (Common Path)
---
sequenceDiagram
  autonumber
  participant Client as Portal / API / Agent tools
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  participant SFN as SFN transfer-precheck
  participant WF as Lambda workflow
  participant Child as Child SFN (type-specific)
  participant EB as EventBridge
  Note over Client,EB: Use case: Client submits a transfer with idempotency, precheck runs, then the type-specific child Step Functions workflow executes.

  Client->>APIGW: POST /v1/transfers + Idempotency-Key
  APIGW->>API: JWT + body
  API->>DDB: Check idempotency_keys
  alt Duplicate idempotency key
    API-->>Client: 200 deduplicated request_id
  else New request
    API->>DDB: transfer_requests SUBMITTED
    API->>DDB: transfer_executions QUEUED
    API->>DDB: idempotency + audit transfer_submitted
    API->>SFN: StartExecution(input)
    API-->>Client: 202 request_id, execution_id, sfn_arn
    SFN->>WF: precheck_all (validate, policy, route)
    WF-->>SFN: child_state_machine_arn + child_input
    SFN->>Child: startExecution.sync
    Child->>WF: verify / transfer tasks
    Child->>DDB: update_execution_status
    Child->>EB: emit_event (transfer completed/failed)
  end
```

### UC-T01: S3 → S3 transfer

> **Use case:** Verify source object in S3, copy to destination key, and mark execution succeeded.

```mermaid
---
title: UC-T01 | S3 to S3 Transfer
---
sequenceDiagram
  autonumber
  participant Child as SFN s3-to-s3
  participant WF as Lambda workflow
  participant S3 as Amazon S3
  participant DDB as DynamoDB
  Note over Child,DDB: Use case: Verify source object in S3, copy to destination key, and mark execution succeeded.

  Note over Child: Input payload: source_bucket/key, dest_bucket/key
  Child->>WF: s3_verify_source
  WF->>S3: HeadObject(source)
  WF-->>Child: ok
  Child->>WF: s3_copy
  WF->>S3: CopyObject dest ← source
  WF-->>Child: ok
  Child->>WF: update_execution_status SUCCEEDED
  WF->>DDB: execution + request status
  Child->>WF: emit_event
```

### UC-T02: S3 → SFTP transfer

> **Use case:** Stage file in S3 then SendFilePaths via Transfer Family connector to partner SFTP.

Stages a flat key under the transfer bucket, then uses **Transfer Family connector** `SendFilePaths` to remote SFTP.

```mermaid
---
title: UC-T02 | S3 to SFTP Transfer
---
sequenceDiagram
  autonumber
  participant Child as SFN s3-to-sftp
  participant WF as Lambda workflow
  participant S3 as Amazon S3
  participant TF as Transfer connector API
  participant DDB as DynamoDB
  Note over Child,DDB: Use case: Stage file in S3 then SendFilePaths via Transfer Family connector to partner SFTP.

  Child->>WF: s3_verify_source
  WF->>S3: HeadObject
  Child->>WF: s3_to_sftp_send
  WF->>S3: CopyObject → flat-send-{execution_id}-{basename}
  Note over S3: Staging key triggers optional downstream rules
  WF->>TF: start_file_transfer(SendFilePaths=/bucket/staging-key)
  TF-->>WF: TransferId
  WF->>TF: Poll until COMPLETED
  WF->>DDB: audit s3_to_sftp_completed
  Child->>WF: update_execution_status SUCCEEDED
```

### UC-T03: SFTP → S3 transfer

> **Use case:** Retrieve files from partner SFTP via connector into the BayRelay transfer bucket on S3.

Typically triggered after S3→SFTP created a connector staging object; retrieves from remote `/basename` into S3 prefix.

```mermaid
---
title: UC-T03 | SFTP to S3 Transfer
---
sequenceDiagram
  autonumber
  participant Child as SFN sftp-to-s3
  participant WF as Lambda workflow
  participant TF as Transfer connector
  participant S3 as Amazon S3
  participant DDB as DynamoDB
  Note over Child,DDB: Use case: Retrieve files from partner SFTP via connector into the BayRelay transfer bucket on S3.

  Child->>WF: sftp_retrieve_to_s3
  WF->>TF: start_file_transfer(RetrieveFilePaths, LocalDirectoryPath=/bucket/prefix)
  TF->>S3: Connector writes retrieved files
  WF->>TF: Wait COMPLETED
  WF->>DDB: Update execution summary
  Child->>WF: update_execution_status SUCCEEDED
```

### UC-T04: SFTP → SFTP relay transfer

> **Use case:** Retrieve from remote source to S3 staging, then send from staging to remote destination on same connector.

Retrieve remote → S3 staging → send to remote destination directory (same connector).

```mermaid
---
title: UC-T04 | SFTP to SFTP Relay Transfer
---
sequenceDiagram
  autonumber
  participant Child as SFN sftp-to-sftp
  participant WF as Lambda workflow
  participant TF as Transfer connector
  participant S3 as Amazon S3
  Note over Child,S3: Use case: Retrieve from remote source to S3 staging, then send from staging to remote destination on same connector.

  Child->>WF: sftp_relay
  WF->>TF: Retrieve remote_source_paths → S3 sftp-staging/{execution_id}
  WF->>TF: Wait retrieve COMPLETED
  WF->>S3: ListObjects staging prefix
  WF->>TF: SendFilePaths (staging keys) → remote_dest_directory
  WF->>TF: Wait send COMPLETED
  WF-->>Child: ok retrieve_id + send_id
  Child->>WF: update_execution_status SUCCEEDED
```

### UC-T05: Idempotent transfer resubmit

> **Use case:** Duplicate POST with the same Idempotency-Key returns the original request without starting a new workflow.

```mermaid
---
title: UC-T05 | Idempotent Transfer Resubmit
---
sequenceDiagram
  autonumber
  participant Client as API client
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Client,DDB: Use case: Duplicate POST with the same Idempotency-Key returns the original request without starting a new workflow.

  Client->>API: POST /v1/transfers (same X-Idempotency-Key)
  API->>DDB: Get idempotency_keys
  DDB-->>API: existing transfer_request_id
  API-->>Client: 200 deduplicated=true (no new SFN)
```

### UC-T06: Retry failed transfer

> **Use case:** Operator retries a failed transfer by submitting a new request copied from the original payload.

```mermaid
---
title: UC-T06 | Retry Failed Transfer
---
sequenceDiagram
  autonumber
  participant Op as Operator portal
  participant API as Lambda api
  participant DDB as DynamoDB
  participant SFN as Step Functions
  Note over Op,SFN: Use case: Operator retries a failed transfer by submitting a new request copied from the original payload.

  Op->>API: POST /v1/transfers/{request_id}/retry
  API->>DDB: Load original request
  API->>API: submit_transfer (new idempotency key, new execution)
  Note over API: Payload copied from original request
  API->>SFN: New precheck execution
  API-->>Op: 202 new request_id (optional navigate)
```

### UC-T07: Cancel in-flight transfer

> **Use case:** Operator or partner marks an active transfer request CANCELLED in DynamoDB (status marker, SFN may still run).

```mermaid
---
title: UC-T07 | Cancel In-Flight Transfer
---
sequenceDiagram
  autonumber
  participant Op as Operator / Partner
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator or partner marks an active transfer request CANCELLED in DynamoDB (status marker, SFN may still run).

  Op->>API: POST /v1/transfers/{request_id}/cancel
  API->>DDB: Get request
  alt Terminal status (SUCCEEDED/FAILED/CANCELLED)
    API-->>Op: 409 cannot cancel
  else Active status
    API->>DDB: status=CANCELLED
    API->>DDB: audit transfer_cancelled
    API-->>Op: 200 CANCELLED
  end
  Note over API: Does not stop running SFN (status marker only)
```
---

## Automation (EventBridge)

### UC-A01: Automation S3→S3 on object created

> **Use case:** S3 Object Created event matches a transfer rule and auto-submits an S3 to S3 transfer.

```mermaid
---
title: UC-A01 | Automation S3 to S3 on Object Created
---
sequenceDiagram
  autonumber
  participant Uploader as Operator / system / SFTP→S3
  participant S3 as Transfer bucket
  participant EB as EventBridge
  participant Disp as Lambda transfer_dispatcher
  participant Rules as transfer_rules_service
  participant API as transfers_service
  participant SFN as Step Functions
  Note over Uploader,SFN: Use case: S3 Object Created event matches a transfer rule and auto-submits an S3 to S3 transfer.

  Uploader->>S3: PutObject demo/.../inbound/file.csv
  S3->>EB: Object Created
  EB->>Disp: Invoke
  Disp->>Rules: find_matching_rules(S3_OBJECT_CREATED, key)
  Rules->>Rules: glob match_pattern, enabled, priority
  Rules->>API: submit_transfer (idem auto-{rule}-{key})
  API->>SFN: UC-T01 child flow
  Disp->>DDB: audit transfer_automation_dispatched
```

### UC-A02: Automation chain S3→SFTP → SFTP→S3

> **Use case:** Two chained rules: outbound S3 to SFTP staging, then staging object triggers SFTP to S3 delivery.

```mermaid
---
title: UC-A02 | Automation Chain S3 to SFTP then SFTP to S3
---
sequenceDiagram
  autonumber
  participant S3 as Transfer bucket
  participant EB as EventBridge
  participant Disp as transfer_dispatcher
  participant SFN as Step Functions
  Note over S3,SFN: Use case: Two chained rules: outbound S3 to SFTP staging, then staging object triggers SFTP to S3 delivery.

  Note over S3: Rule 1: inbound/sftp/* → S3_TO_SFTP
  S3->>EB: Object Created (inbound file)
  EB->>Disp: dispatch
  Disp->>SFN: S3_TO_SFTP → staging flat-send-*

  Note over S3: Rule 2: sftp-connector/flat-send-* → SFTP_TO_S3
  S3->>EB: Object Created (staging key)
  EB->>Disp: dispatch
  Disp->>SFN: SFTP_TO_S3 → dest_prefix template
```

### UC-A03: Automation SFTP→SFTP on connector staging

> **Use case:** Connector staging key under sftp-connector/flat-send-* triggers SFTP to SFTP relay workflow.

```mermaid
---
title: UC-A03 | Automation SFTP to SFTP on Connector Staging
---
sequenceDiagram
  autonumber
  participant S3 as Transfer bucket
  participant EB as EventBridge
  participant Disp as transfer_dispatcher
  participant SFN as Step Functions
  Note over S3,SFN: Use case: Connector staging key under sftp-connector/flat-send-* triggers SFTP to SFTP relay workflow.

  S3->>EB: Object Created sftp-connector/flat-send-*
  EB->>Disp: dispatch (connector staging only for SFTP_* rules)
  Disp->>SFN: SFTP_TO_SFTP UC-T04
```

### UC-A04: Partner SFTP inbound → S3→S3 automation

> **Use case:** Partner uploads to managed SFTP server, file lands in sftp-inbound/, S3 to S3 rule processes it.

Partner uses **managed SFTP server** (not connector). Files land under `sftp-inbound/`; automate with **S3→S3**, not SFTP→S3.

```mermaid
---
title: UC-A04 | Partner SFTP Inbound with S3 to S3 Automation
---
sequenceDiagram
  autonumber
  participant Partner as Partner (FileZilla)
  participant SFTP as Transfer Family server
  participant S3 as Transfer bucket
  participant Audit as Lambda sftp_inbound
  participant EB as EventBridge
  participant Disp as transfer_dispatcher
  Note over Partner,Disp: Use case: Partner uploads to managed SFTP server, file lands in sftp-inbound/, S3 to S3 rule processes it.

  Partner->>SFTP: Upload file
  SFTP->>S3: Logical mapping → sftp-inbound/...
  S3->>EB: Object Created
  par Parallel paths
    EB->>Audit: sftp_inbound audit only
  and Automation path
    EB->>Disp: trigger SFTP_INBOUND or S3_OBJECT
    Disp->>Disp: Rule match demo/... (S3_TO_S3)
  end
```
---

## Onboarding (self-service)

### UC-O01: Partner submits onboarding request

> **Use case:** Prospect or partner submits a self-service onboarding request stored as SUBMITTED in DynamoDB.

```mermaid
---
title: UC-O01 | Partner Submits Onboarding Request
---
sequenceDiagram
  autonumber
  participant P as Partner (portal /onboarding/new)
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over P,DDB: Use case: Prospect or partner submits a self-service onboarding request stored as SUBMITTED in DynamoDB.

  P->>APIGW: POST /v1/onboarding/requests
  Note over APIGW: JWT partner or operator, or public if flag enabled
  APIGW->>API: create_request
  API->>DDB: onboarding SUBMITTED + audit
  API-->>P: 201 request_id
```

### UC-O02: Operator approves onboarding

> **Use case:** Operator approves request, provisions partner and endpoints, and links Cognito partner user if applicable.

```mermaid
---
title: UC-O02 | Operator Approves Onboarding
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant API as Lambda api
  participant DDB as DynamoDB
  participant Cognito as Cognito
  Note over Op,Cognito: Use case: Operator approves request, provisions partner and endpoints, and links Cognito partner user if applicable.

  Op->>API: POST /v1/onboarding/requests/{id}/approve
  API->>DDB: Create partner + endpoints
  API->>DDB: request APPROVED
  API->>Cognito: AdminLinkPartnerUser (if email matches user)
  Note over Cognito: Sets custom:partner_id, bayrelay-partners group
  API-->>Op: partner_id, endpoint_ids
```

### UC-O03: Onboarding auto-approve (demo)

> **Use case:** Demo mode auto-approves onboarding immediately after submit for hands-on environments.

```mermaid
---
title: UC-O03 | Onboarding Auto-Approve (Demo)
---
sequenceDiagram
  autonumber
  participant P as Applicant
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over P,DDB: Use case: Demo mode auto-approves onboarding immediately after submit for hands-on environments.

  P->>API: POST /v1/onboarding/requests
  API->>DDB: SUBMITTED
  API->>API: approve_request(reviewer=system-auto-approve)
  API->>DDB: partner + endpoints + APPROVED
  API-->>P: 201 auto_approved=true
```

### UC-O04: Operator rejects onboarding

> **Use case:** Operator rejects onboarding with a reason and audit event, no partner provisioned.

```mermaid
---
title: UC-O04 | Operator Rejects Onboarding
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator rejects onboarding with a reason and audit event, no partner provisioned.

  Op->>API: POST /v1/onboarding/requests/{id}/reject {reason}
  API->>DDB: status REJECTED, rejection_reason
  API->>DDB: audit onboarding_rejected
  API-->>Op: 200
```
---

## Portal (operator features)

### UC-PO01: Operator operations dashboard

> **Use case:** Portal loads ops summary KPIs, health, recent transfers, and onboarding counts for operators.

```mermaid
---
title: UC-PO01 | Operator Operations Dashboard
---
sequenceDiagram
  autonumber
  participant Op as Operator browser
  participant Portal as Portal SPA
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Portal loads ops summary KPIs, health, recent transfers, and onboarding counts for operators.

  Op->>Portal: /operations
  Portal->>APIGW: GET /v1/ops/summary
  APIGW->>API: require_operator
  API->>DDB: Scan/sample partners, endpoints, transfers, onboarding
  API-->>Portal: KPIs, by_status, recent_transfers, health
  Portal-->>Op: LIVE badge, charts / overview
```

### UC-PO02: Operator creates transfer rule

> **Use case:** Operator defines an EventBridge-backed automation rule with match pattern and payload template.

```mermaid
---
title: UC-PO02 | Operator Creates Transfer Rule
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant Portal as Portal
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator defines an EventBridge-backed automation rule with match pattern and payload template.

  Op->>Portal: /rules → Create rule form
  Portal->>API: POST /v1/transfer-rules
  API->>DDB: PutItem rule (enabled, priority, match_pattern, payload_template)
  API-->>Portal: 201 rule
  Note over S3: Next object match triggers UC-A01
```

### UC-PO03: Portal partner/endpoint CRUD

> **Use case:** Operator searches partners, updates records, and soft-disables endpoints from the portal.

```mermaid
---
title: UC-PO03 | Portal Partner and Endpoint CRUD
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant Portal as Portal
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator searches partners, updates records, and soft-disables endpoints from the portal.

  Op->>Portal: /partners search + Edit
  Portal->>API: PUT /v1/partners/{id}
  API->>DDB: Update partner
  Op->>Portal: Disable endpoint
  Portal->>API: DELETE /v1/endpoints/{id}
  API->>DDB: Soft delete status=DISABLED
```
---

## Agent & knowledge base

### UC-G01: Bedrock agent query with tools

> **Use case:** Operator asks the Bedrock agent which invokes action-group tools against live platform data.

```mermaid
---
title: UC-G01 | Bedrock Agent Query with Tools
---
sequenceDiagram
  autonumber
  participant Op as Operator portal
  participant APIGW as API Gateway
  participant API as Lambda api
  participant BR as Bedrock Agent
  participant Tools as Lambda agent_tools
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator asks the Bedrock agent which invokes action-group tools against live platform data.

  Op->>APIGW: POST /v1/agent/query {query, session_id}
  APIGW->>API: InvokeAgent
  BR->>Tools: Action group (planning / execution OpenAPI)
  Tools->>DDB: Read partners, transfers, policies
  Tools-->>BR: Tool results
  BR-->>API: Completion text (+ optional trace)
  API-->>Op: agent_response, session_id
```

### UC-G02: KB-grounded policy answer

> **Use case:** Agent retrieves knowledge-base chunks from OpenSearch and returns a grounded policy or runbook answer.

```mermaid
---
title: UC-G02 | KB-Grounded Policy Answer
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant API as Lambda api
  participant BR as Bedrock Agent
  participant KB as Bedrock Knowledge Base
  participant AOSS as OpenSearch Serverless
  Note over Op,AOSS: Use case: Agent retrieves knowledge-base chunks from OpenSearch and returns a grounded policy or runbook answer.

  Op->>API: POST /v1/agent/query (policy / retry question)
  API->>BR: InvokeAgent
  BR->>KB: Retrieve (vector search)
  KB->>AOSS: Query embeddings
  AOSS-->>KB: Chunks from customer runbooks
  KB-->>BR: Retrieved passages
  BR-->>Op: Grounded answer with citations
```

### UC-G03: Knowledge base sync and ingestion

> **Use case:** Engineer syncs KB markdown to S3, runs ingestion job, and prepares agent alias for queries.

```mermaid
---
title: UC-G03 | Knowledge Base Sync and Ingestion
---
sequenceDiagram
  autonumber
  participant Eng as Engineer / CI
  participant Script as kb_sync.sh + start_kb_ingestion.py
  participant S3 as KB source bucket
  participant KB as Bedrock KB
  participant BR as Bedrock Agent
  Note over Eng,BR: Use case: Engineer syncs KB markdown to S3, runs ingestion job, and prepares agent alias for queries.

  Eng->>Script: bootstrap_phase3.sh
  Script->>S3: Sync docs/kb/*.md
  Script->>KB: StartIngestionJob
  KB-->>Script: COMPLETE
  Script->>BR: PrepareAgent (alias)
  Note over BR: Agent queries use ingested docs (UC-G02)
```
---

## SFTP inbound (managed server)

### UC-S01: Partner upload via managed SFTP server

> **Use case:** Partner uploads via Transfer Family SFTP server, file maps to sftp-inbound/ prefix and audit fires.

```mermaid
---
title: UC-S01 | Partner Upload via Managed SFTP Server
---
sequenceDiagram
  autonumber
  participant Partner as Partner SFTP client
  participant Srv as Transfer Family SFTP server
  participant S3 as S3 (logical home)
  participant EB as EventBridge
  participant Audit as sftp_inbound Lambda
  Note over Partner,Audit: Use case: Partner uploads via Transfer Family SFTP server, file maps to sftp-inbound/ prefix and audit fires.

  Partner->>Srv: SFTP PUT /file.dat
  Srv->>S3: Object sftp-inbound/.../file.dat
  S3->>EB: Object Created
  EB->>Audit: Audit sftp_inbound_object_created
  Note over S3: Use S3→S3 automation on sftp-inbound prefix (UC-A04)
```
---

## Operations & observability

### UC-M01: Audit trail and list audit events

> **Use case:** Operator queries filtered audit events for transfers, onboarding, automation, and inbound activity.

```mermaid
---
title: UC-M01 | Audit Trail and List Audit Events
---
sequenceDiagram
  autonumber
  participant Op as Operator
  participant API as Lambda api
  participant DDB as DynamoDB
  Note over Op,DDB: Use case: Operator queries filtered audit events for transfers, onboarding, automation, and inbound activity.

  Note over DDB: Audits: transfer_submitted, onboarding_*, automation, sftp_inbound, cancel
  Op->>API: GET /v1/audit-events?q=&correlation_id=
  API->>DDB: Scan/filter audit_events
  API-->>Op: events[], count
```

### UC-M02: Ops summary dashboard data

> **Use case:** API aggregates partner, endpoint, transfer, execution, and onboarding counts for dashboard widgets.

```mermaid
---
title: UC-M02 | Ops Summary Dashboard Data
---
sequenceDiagram
  autonumber
  participant Portal as Portal
  participant API as ops_service
  participant DDB as DynamoDB
  Note over Portal,DDB: Use case: API aggregates partner, endpoint, transfer, execution, and onboarding counts for dashboard widgets.

  Portal->>API: GET /v1/ops/summary
  API->>DDB: Count partners, endpoints
  API->>DDB: Sample transfer_requests (status, type)
  API->>DDB: Sample executions (failed_recent)
  API->>DDB: Count onboarding SUBMITTED
  API-->>Portal: health, counts, recent_transfers
```
---

## Feature matrix (diagram coverage)

| Feature / use case | Diagram ID |
|--------------------|------------|
| Cognito operator login | UC-P01 |
| Cognito partner scoped access | UC-P02 |
| JWT enforcement | UC-P03 |
| Partner registry | UC-C01 |
| Routing policy DENY | UC-C02 |
| Manual S3→S3 / S3→SFTP / SFTP→S3 / SFTP→SFTP | UC-T00 + UC-T01–T04 |
| Idempotency | UC-T05 |
| Retry / cancel | UC-T06, UC-T07 |
| S3 event automation | UC-A01–A04 |
| Partner SFTP server upload | UC-S01, UC-A04 |
| Onboarding submit/approve/reject/auto | UC-O01–O04 |
| Portal ops dashboard | UC-PO01, UC-M02 |
| Automation rules UI | UC-PO02 |
| Partner/endpoint CRUD | UC-PO03 |
| Bedrock agent + tools | UC-G01 |
| RAG / KB | UC-G02, UC-G03 |
| Audit log API | UC-M01 |
| End-to-end customer story | UC-00 |

---

## Exporting diagrams

- **Regenerate all PNGs:** `./scripts/export_sequence_diagram_pngs.sh` (requires Node/npm; uses Chrome via Puppeteer, or falls back to [mermaid.ink](https://mermaid.ink)).
- **Output:** `docs/sequence-diagrams/png/UC-*.png` and source `.mmd` under `docs/sequence-diagrams/mmd/`.
- **Single diagram:** paste one ` ```mermaid ` block into [mermaid.live](https://mermaid.live) → Export PNG/SVG.
- **PDF pack:** attach PNGs or this file to proposals as a technical appendix (`export_sales_pdfs.sh` for one-pagers/SOWs).
- **Architecture deck:** UC-00, UC-T00, UC-A02, UC-O02 PNGs work well in executive + technical slides.

---

*Generated from BayRelay codebase (`app/lambdas/unified`, `modules/step_functions`, portal routes). Update when workflows or API contracts change.*
