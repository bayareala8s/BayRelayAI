# Architecture

A consolidated **PNG diagram** of the AWS components and data flows: [bayrelay-architecture.png](bayrelay-architecture.png).

## Layered view

| Layer | Responsibility | AWS services in this repo |
|-------|----------------|---------------------------|
| A — Agent | NL understanding, tool use, policy prompts | Bedrock Agent + Lambda action groups |
| B — RAG | Curated policies, runbooks, SOPs | S3 KB source + OpenSearch Serverless + Bedrock Knowledge Base (`modules/bedrock_vector_kb`) |
| C — Execution | Transfers, orchestration, state | API Gateway, Lambda, Step Functions, DynamoDB, S3, EventBridge |
| D — Production | IaC, encryption, observability | Terraform, KMS, CloudWatch, SNS |

## End-to-end execution (Phase 1)

```mermaid
sequenceDiagram
  participant Client
  participant APIGW as API Gateway
  participant API as Lambda api
  participant DDB as DynamoDB
  participant SFN as Step Functions precheck
  participant WF as Lambda workflow
  participant Child as Step Functions child
  participant S3 as Amazon S3
  participant EB as EventBridge

  Client->>APIGW: POST /v1/transfers
  APIGW->>API: invoke
  API->>DDB: put request, execution, idempotency
  API->>SFN: StartExecution (precheck)
  SFN->>WF: precheck_all
  WF->>DDB: audit / policy
  SFN->>Child: startExecution.sync (S3_TO_S3 / S3_TO_SFTP)
  Child->>WF: verify / copy / stub send
  WF->>S3: HeadObject / CopyObject
  WF->>DDB: update status
  WF->>EB: PutEvents
```

## Agent query path

```mermaid
sequenceDiagram
  participant Op as Operator
  participant APIGW as API Gateway
  participant API as Lambda api
  participant BR as Bedrock Agent
  participant Tools as Lambda agent_tools
  participant KB as Knowledge Base (optional)

  Op->>APIGW: POST /v1/agent/query
  APIGW->>API: invoke
  API->>BR: InvokeAgent (TSTALIASID)
  BR->>Tools: action group Lambda
  Tools->>Tools: DynamoDB / planning
  BR->>KB: Retrieve (when associated)
  BR-->>API: completion stream
  API-->>Op: JSON response + traces
```

## SFTP staging pattern (spec default for SFTP→SFTP)

Partner SFTP → S3 staging → validate/transform → S3 → partner SFTP. Direct opaque relay is intentionally not the default.

## Guardrails note

Bedrock Guardrails apply to user input and model output, not to raw retrieved KB chunks at runtime. Curate KB content and enforce bucket IAM accordingly.
