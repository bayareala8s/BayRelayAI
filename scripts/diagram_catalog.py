"""Titles and use-case descriptions for BayRelay sequence diagrams."""

from __future__ import annotations

# id -> (title suffix after UC-XX |, use_case one-liner; avoid semicolons in use_case)
DIAGRAM_CATALOG: dict[str, tuple[str, str]] = {
    "UC-00": (
        "Customer Journey Overview",
        "End-to-end path for a new trading partner from landing and onboarding through first transfer and status tracking.",
    ),
    "UC-P01": (
        "Operator Portal Sign-In",
        "Operator authenticates with Cognito and accesses the BayRelay operations portal with a validated JWT.",
    ),
    "UC-P02": (
        "Partner Portal Sign-In (Scoped API)",
        "Partner user signs in and sees only transfers and data scoped to their partner_id claim.",
    ),
    "UC-P03": (
        "Unauthenticated API Rejected",
        "API Gateway rejects control-plane calls that omit a valid Authorization JWT.",
    ),
    "UC-C01": (
        "Register Partner and Endpoints",
        "Operator registers a trading partner and one or more protocol endpoints in the control plane.",
    ),
    "UC-C02": (
        "Routing Policy DENY Blocks Transfer",
        "A DENY routing policy stops a submitted transfer during precheck before child workflow runs.",
    ),
    "UC-T00": (
        "Manual Transfer Submit (Common Path)",
        "Client submits a transfer with idempotency, precheck runs, then the type-specific child Step Functions workflow executes.",
    ),
    "UC-T01": (
        "S3 to S3 Transfer",
        "Verify source object in S3, copy to destination key, and mark execution succeeded.",
    ),
    "UC-T02": (
        "S3 to SFTP Transfer",
        "Stage file in S3 then SendFilePaths via Transfer Family connector to partner SFTP.",
    ),
    "UC-T03": (
        "SFTP to S3 Transfer",
        "Retrieve files from partner SFTP via connector into the BayRelay transfer bucket on S3.",
    ),
    "UC-T04": (
        "SFTP to SFTP Relay Transfer",
        "Retrieve from remote source to S3 staging, then send from staging to remote destination on same connector.",
    ),
    "UC-T05": (
        "Idempotent Transfer Resubmit",
        "Duplicate POST with the same Idempotency-Key returns the original request without starting a new workflow.",
    ),
    "UC-T06": (
        "Retry Failed Transfer",
        "Operator retries a failed transfer by submitting a new request copied from the original payload.",
    ),
    "UC-T07": (
        "Cancel In-Flight Transfer",
        "Operator or partner marks an active transfer request CANCELLED in DynamoDB (status marker, SFN may still run).",
    ),
    "UC-A01": (
        "Automation S3 to S3 on Object Created",
        "S3 Object Created event matches a transfer rule and auto-submits an S3 to S3 transfer.",
    ),
    "UC-A02": (
        "Automation Chain S3 to SFTP then SFTP to S3",
        "Two chained rules: outbound S3 to SFTP staging, then staging object triggers SFTP to S3 delivery.",
    ),
    "UC-A03": (
        "Automation SFTP to SFTP on Connector Staging",
        "Connector staging key under sftp-connector/flat-send-* triggers SFTP to SFTP relay workflow.",
    ),
    "UC-A04": (
        "Partner SFTP Inbound with S3 to S3 Automation",
        "Partner uploads to managed SFTP server, file lands in sftp-inbound/, S3 to S3 rule processes it.",
    ),
    "UC-O01": (
        "Partner Submits Onboarding Request",
        "Prospect or partner submits a self-service onboarding request stored as SUBMITTED in DynamoDB.",
    ),
    "UC-O02": (
        "Operator Approves Onboarding",
        "Operator approves request, provisions partner and endpoints, and links Cognito partner user if applicable.",
    ),
    "UC-O03": (
        "Onboarding Auto-Approve (Demo)",
        "Demo mode auto-approves onboarding immediately after submit for hands-on environments.",
    ),
    "UC-O04": (
        "Operator Rejects Onboarding",
        "Operator rejects onboarding with a reason and audit event, no partner provisioned.",
    ),
    "UC-PO01": (
        "Operator Operations Dashboard",
        "Portal loads ops summary KPIs, health, recent transfers, and onboarding counts for operators.",
    ),
    "UC-PO02": (
        "Operator Creates Transfer Rule",
        "Operator defines an EventBridge-backed automation rule with match pattern and payload template.",
    ),
    "UC-PO03": (
        "Portal Partner and Endpoint CRUD",
        "Operator searches partners, updates records, and soft-disables endpoints from the portal.",
    ),
    "UC-G01": (
        "Bedrock Agent Query with Tools",
        "Operator asks the Bedrock agent which invokes action-group tools against live platform data.",
    ),
    "UC-G02": (
        "KB-Grounded Policy Answer",
        "Agent retrieves knowledge-base chunks from OpenSearch and returns a grounded policy or runbook answer.",
    ),
    "UC-G03": (
        "Knowledge Base Sync and Ingestion",
        "Engineer syncs KB markdown to S3, runs ingestion job, and prepares agent alias for queries.",
    ),
    "UC-S01": (
        "Partner Upload via Managed SFTP Server",
        "Partner uploads via Transfer Family SFTP server, file maps to sftp-inbound/ prefix and audit fires.",
    ),
    "UC-M01": (
        "Audit Trail and List Audit Events",
        "Operator queries filtered audit events for transfers, onboarding, automation, and inbound activity.",
    ),
    "UC-M02": (
        "Ops Summary Dashboard Data",
        "API aggregates partner, endpoint, transfer, execution, and onboarding counts for dashboard widgets.",
    ),
}


def full_title(uc_id: str) -> str:
    suffix, _ = DIAGRAM_CATALOG[uc_id]
    return f"{uc_id} | {suffix}"


def use_case(uc_id: str) -> str:
    return DIAGRAM_CATALOG[uc_id][1]
