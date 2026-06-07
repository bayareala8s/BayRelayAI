import type { HelpCategory, HelpSection } from "./types";

export const HELP_CATEGORIES: HelpCategory[] = [
  { id: "start", label: "Getting started" },
  { id: "operations", label: "Operations" },
  { id: "transfers", label: "Transfers" },
  { id: "automation", label: "Automation" },
  { id: "onboarding", label: "Onboarding & partners" },
  { id: "governance", label: "Policies & audit" },
  { id: "assistant", label: "AI assistant" },
  { id: "access", label: "Roles & access" },
  { id: "troubleshoot", label: "Troubleshooting" },
  { id: "faq", label: "FAQ" },
];

export const HELP_SECTIONS: HelpSection[] = [
  {
    id: "welcome",
    title: "Welcome to BayRelay",
    category: "start",
    audience: "all",
    summary:
      "BayRelay is an agentic B2B file transfer platform. Use this portal to submit transfers, manage partners, and monitor operations.",
    blocks: [
      {
        type: "p",
        text: "BayRelay runs in your organization's AWS account. Files move between Amazon S3 and partner SFTP endpoints using secure, auditable workflows orchestrated by AWS Step Functions. The operator portal is your day-to-day control plane.",
      },
      {
        type: "h3",
        text: "What you can do here",
      },
      {
        type: "ul",
        items: [
          "Monitor platform health and recent activity on the Operations dashboard.",
          "Submit and track file transfers (S3↔S3, S3↔SFTP, SFTP↔SFTP).",
          "Configure automation rules that trigger transfers when files land in S3.",
          "Onboard trading partners and manage endpoints.",
          "Define routing policies (ALLOW/DENY) per partner.",
          "Review the audit log for compliance and incident response.",
          "Ask the AI Assistant policy and runbook questions grounded in your knowledge base.",
        ],
      },
      {
        type: "note",
        title: "Operator vs partner",
        text: "Operators see the full navigation menu. Partners see a scoped view limited to their own partner_id and transfers. Your role is shown at the bottom of the sidebar.",
      },
      { type: "route", label: "Go to Operations dashboard", to: "/operations" },
    ],
  },
  {
    id: "sign-in",
    title: "Sign in and session",
    category: "start",
    audience: "all",
    summary: "How authentication works and what to do if you cannot access the portal.",
    blocks: [
      {
        type: "p",
        text: "Sign in with the email and password provided by your BayRelay administrator. Authentication uses Amazon Cognito; your session token is stored in the browser for the duration of your visit.",
      },
      {
        type: "h3",
        text: "First-time login",
      },
      {
        type: "ol",
        items: [
          "Open the operator portal URL provided by your team (CloudFront HTTPS endpoint).",
          "Enter your email and temporary password if prompted.",
          "Set a new password when Cognito requires a change.",
          "Confirm you see the correct role (Operator or Partner) in the sidebar footer.",
        ],
      },
      {
        type: "h3",
        text: "Sign out",
      },
      {
        type: "p",
        text: "Use Sign out at the bottom of the sidebar before leaving a shared workstation. This clears your local session token.",
      },
      {
        type: "note",
        title: "Security",
        text: "Never share passwords or API tokens. Production deployments require JWT on every API call; the portal attaches your token automatically.",
      },
    ],
  },
  {
    id: "operations-dashboard",
    title: "Operations dashboard",
    category: "operations",
    audience: "operator",
    summary: "Live KPIs, health status, charts, and recent transfers.",
    blocks: [
      {
        type: "p",
        text: "The Operations page is the operator home screen. It aggregates counts from partners, endpoints, transfers, and onboarding queues, and surfaces failures that need attention.",
      },
      { type: "route", label: "Open Operations", to: "/operations" },
      {
        type: "h3",
        text: "LIVE badge and refresh",
      },
      {
        type: "p",
        text: "When the stack is reachable, a LIVE indicator appears. Summary data refreshes automatically while you stay on the page. Use Overview for KPI cards and Charts for status distribution bars.",
      },
      {
        type: "h3",
        text: "Health states",
      },
      {
        type: "ul",
        items: [
          "All clear — no failed transfers or executions in the sampled window.",
          "Needs attention — one or more failures detected; open Transfers and filter by FAILED.",
          "High onboarding volume — many SUBMITTED onboarding requests awaiting operator review.",
        ],
      },
      {
        type: "h3",
        text: "KPI cards",
      },
      {
        type: "ul",
        items: [
          "Partners — registered trading partners (click through to Partners).",
          "Endpoints — S3 and SFTP connection points per partner.",
          "Transfers (sampled) — recent transfer requests in the ops sample.",
          "Onboarding pending — applications awaiting approve/reject.",
        ],
      },
      {
        type: "h3",
        text: "Recent transfers table",
      },
      {
        type: "p",
        text: "Shows the latest transfer requests with status badges. Click a row to open the transfer detail page for retry, cancel, or execution trace.",
      },
    ],
  },
  {
    id: "transfers-list",
    title: "Transfers list",
    category: "transfers",
    audience: "all",
    summary: "Search, filter, and open transfer requests.",
    blocks: [
      {
        type: "p",
        text: "The Transfers page lists file transfer requests. Operators see all partners; partners see only their scoped partner_id.",
      },
      { type: "route", label: "Open Transfers", to: "/transfers" },
      {
        type: "h3",
        text: "Table features",
      },
      {
        type: "ul",
        items: [
          "Search — filter by request ID, partner, type, or correlation ID.",
          "Status filter — SUBMITTED, IN_PROGRESS, SUCCEEDED, FAILED, CANCELLED.",
          "Sort — click column headers where supported.",
          "Detail — click a row to open the transfer detail view.",
        ],
      },
      {
        type: "h3",
        text: "Transfer statuses",
      },
      {
        type: "ul",
        items: [
          "SUBMITTED — accepted by the API; Step Functions precheck started.",
          "IN_PROGRESS — workflow executing (copy, connector send/retrieve, etc.).",
          "SUCCEEDED — destination verified or connector reported success.",
          "FAILED — workflow or connector error; see detail page and audit log.",
          "CANCELLED — operator cancelled before completion.",
        ],
      },
    ],
  },
  {
    id: "new-transfer",
    title: "Submit a new transfer",
    category: "transfers",
    audience: "all",
    summary: "Step-by-step guide for all four transfer types.",
    blocks: [
      {
        type: "p",
        text: "Use New transfer to submit a file movement job. Each submission creates a transfer request with a unique request_id and triggers an audited Step Functions workflow.",
      },
      { type: "route", label: "Open New transfer", to: "/transfers/new" },
      {
        type: "h3",
        text: "Common fields",
      },
      {
        type: "ul",
        items: [
          "Partner — trading partner owning this transfer.",
          "Source / Target endpoint — logical INBOUND or OUTBOUND endpoints registered for the partner.",
          "Transfer type — one of four supported flows (below).",
          "Operator summary — optional note stored on the request for audit.",
        ],
      },
      {
        type: "h3",
        text: "S3 → S3",
      },
      {
        type: "p",
        text: "Copies an object between keys in the transfer data bucket (or between buckets you specify). Fill source bucket/key and destination bucket/key. Use this for internal staging, outbound packaging, or multi-hop workflows.",
      },
      {
        type: "h3",
        text: "S3 → SFTP",
      },
      {
        type: "p",
        text: "Pushes an object from S3 to a partner SFTP location via the AWS Transfer Family connector. The source file must already exist in the transfer bucket. Remote directory defaults to the connector user's home; use / only when your SFTP mapping allows it.",
      },
      {
        type: "note",
        title: "Demo tip",
        text: "For connector self-demo, upload the source file to S3 first, then submit S3→SFTP. After success, the file appears under the connector's logical home on SFTP.",
      },
      {
        type: "h3",
        text: "SFTP → S3",
      },
      {
        type: "p",
        text: "Pulls one or more remote paths from SFTP into an S3 prefix. Enter paths like /filename.txt (comma or newline separated). Destination bucket and prefix define where files land in S3.",
      },
      {
        type: "h3",
        text: "SFTP → SFTP",
      },
      {
        type: "p",
        text: "Relays files from remote source paths to a remote destination directory on the same connector server. Useful for partner-side routing without storing in S3 long-term.",
      },
      {
        type: "h3",
        text: "After submit",
      },
      {
        type: "ol",
        items: [
          "You are redirected or can open Transfers to find your request_id.",
          "Poll the detail page — status updates every few seconds.",
          "On failure, use Retry (re-submits payload) or check Automation / Policies / RUNBOOK.",
        ],
      },
    ],
  },
  {
    id: "transfer-detail",
    title: "Transfer detail, retry, and cancel",
    category: "transfers",
    audience: "all",
    summary: "Monitor execution, retry failed jobs, cancel in-flight work.",
    blocks: [
      {
        type: "p",
        text: "Open any transfer from the list to see request metadata, latest execution, correlation ID, and payload summary.",
      },
      {
        type: "h3",
        text: "Retry",
      },
      {
        type: "p",
        text: "Available when status is FAILED or CANCELLED. Retry re-submits the stored payload as a new request (new request_id). Use after fixing endpoint config, policies, or connector issues.",
      },
      {
        type: "h3",
        text: "Cancel",
      },
      {
        type: "p",
        text: "Available for non-terminal statuses. Marks the request CANCELLED; does not delete S3 objects already written.",
      },
      {
        type: "h3",
        text: "Execution block",
      },
      {
        type: "p",
        text: "When present, latest_execution shows execution_id, workflow status, and Step Functions ARN for operator escalation to AWS Console or support.",
      },
    ],
  },
  {
    id: "automation-rules",
    title: "Automation rules",
    category: "automation",
    audience: "operator",
    summary: "Auto-submit transfers when objects appear in S3.",
    blocks: [
      {
        type: "p",
        text: "Automation rules watch the transfer data bucket via EventBridge. When a new object key matches your pattern, BayRelay submits a transfer automatically — no manual portal submit required.",
      },
      { type: "route", label: "Open Automation", to: "/rules" },
      {
        type: "h3",
        text: "Create a rule",
      },
      {
        type: "ol",
        items: [
          "Select Partner.",
          "Name — descriptive label for operators.",
          "Match pattern — glob on S3 key, e.g. demo/report-full/inbound/*.",
          "Transfer type — typically S3→S3 or SFTP→S3 for inbound drops.",
          "Payload template — use {bucket}, {key}, {basename} placeholders.",
          "Priority — lower numbers run first when multiple rules match.",
        ],
      },
      {
        type: "h3",
        text: "Edit and disable",
      },
      {
        type: "p",
        text: "Use Edit on an existing rule to change pattern, priority, or enabled flag. Disable instead of delete when pausing automation during maintenance.",
      },
      {
        type: "note",
        title: "Idempotency",
        text: "Automated submits use generated idempotency keys. Duplicate S3 events for the same object should not create duplicate business transfers.",
      },
    ],
  },
  {
    id: "onboarding-operator",
    title: "Onboarding queue (operators)",
    category: "onboarding",
    audience: "operator",
    summary: "Review, approve, or reject partner applications.",
    blocks: [
      {
        type: "p",
        text: "Partners (or your sales team) submit onboarding applications. Operators review them on the Onboarding page before partners receive endpoints and portal access.",
      },
      { type: "route", label: "Open Onboarding", to: "/onboarding" },
      {
        type: "h3",
        text: "Workflow",
      },
      {
        type: "ol",
        items: [
          "Filter by Pending review (SUBMITTED), Approved, or Rejected.",
          "Open a request to see company name, contact, and requested configuration.",
          "Approve — optionally set a custom partner_id; system provisions partner + default S3 endpoints and may link Cognito user.",
          "Reject — provide a reason stored on the request.",
        ],
      },
      {
        type: "h3",
        text: "Auto-approve",
      },
      {
        type: "p",
        text: "When onboarding_auto_approve is enabled in Terraform (common for demos), SUBMITTED requests immediately become APPROVED without manual review. Production customers should disable this and require operator approval.",
      },
      { type: "route", label: "New customer application form", to: "/onboarding/new" },
    ],
  },
  {
    id: "onboarding-partner",
    title: "Apply / onboard (partners)",
    category: "onboarding",
    audience: "partner",
    summary: "How trading partners submit an onboarding application.",
    blocks: [
      {
        type: "p",
        text: "Partners use Apply / onboard to submit company details. After operator approval you receive a partner_id and can submit transfers scoped to your account.",
      },
      { type: "route", label: "Open application form", to: "/onboarding/new" },
      {
        type: "h3",
        text: "After approval",
      },
      {
        type: "ul",
        items: [
          "Your sidebar shows Partner role and partner_id.",
          "Home summarizes your recent activity.",
          "New transfer and My transfers are scoped to your partner only.",
        ],
      },
    ],
  },
  {
    id: "partners-endpoints",
    title: "Partners and endpoints",
    category: "onboarding",
    audience: "operator",
    summary: "Manage the partner registry and connection endpoints.",
    blocks: [
      {
        type: "p",
        text: "Every transfer belongs to a partner. Endpoints describe logical S3 or SFTP connection points (INBOUND vs OUTBOUND) used when classifying transfer types.",
      },
      { type: "route", label: "Open Partners", to: "/partners" },
      {
        type: "h3",
        text: "Partner registry",
      },
      {
        type: "ul",
        items: [
          "Create partners with name and optional metadata.",
          "Soft-delete sets status DISABLED — historical transfers remain auditable.",
          "Search and sort the table for large registries.",
        ],
      },
      {
        type: "h3",
        text: "Endpoints",
      },
      {
        type: "p",
        text: "Each partner typically has INBOUND and OUTBOUND endpoints. New transfer picks defaults based on direction and transfer type. SFTP connector flows use endpoints tied to Transfer Family configuration deployed in your AWS account.",
      },
    ],
  },
  {
    id: "routing-policies",
    title: "Routing policies",
    category: "governance",
    audience: "operator",
    summary: "Partner-scoped ALLOW and DENY rules for transfer routing.",
    blocks: [
      {
        type: "p",
        text: "Routing policies gate whether transfers for a partner are allowed. They complement automation rules and agent-guided validation.",
      },
      { type: "route", label: "Open Policies", to: "/policies" },
      {
        type: "h3",
        text: "Create a policy",
      },
      {
        type: "ol",
        items: [
          "Partner — select the trading partner scope.",
          "Policy ID — identifier (default is fine for a single global rule).",
          "Effect — ALLOW or DENY.",
          "Description — document business intent for auditors.",
        ],
      },
      {
        type: "h3",
        text: "Edit and delete",
      },
      {
        type: "p",
        text: "Use Edit to change effect or description. Delete removes the policy row; ensure you are not leaving partners without required DENY safeguards in production.",
      },
      {
        type: "note",
        title: "Operator only",
        text: "Partners cannot access the Policies page. Policy changes are operator responsibilities.",
      },
    ],
  },
  {
    id: "audit-log",
    title: "Audit log",
    category: "governance",
    audience: "operator",
    summary: "Immutable-style event stream for compliance and debugging.",
    blocks: [
      {
        type: "p",
        text: "The audit log records significant actions: transfer lifecycle events, onboarding decisions, policy changes, and workflow milestones. Each event may include correlation_id for cross-system tracing.",
      },
      { type: "route", label: "Open Audit log", to: "/audit" },
      {
        type: "h3",
        text: "Searching",
      },
      {
        type: "ul",
        items: [
          "Free-text search across action, detail, and correlation fields.",
          "Filter by correlation_id when debugging a single customer incident.",
          "Sort by time descending for newest-first review.",
        ],
      },
      {
        type: "h3",
        text: "Compliance use",
      },
      {
        type: "p",
        text: "Export or screenshot audit entries for SOC reviews. For long-term retention, configure DynamoDB backups and CloudWatch alarms per your organization's policy.",
      },
    ],
  },
  {
    id: "assistant",
    title: "AI Assistant",
    category: "assistant",
    audience: "all",
    summary: "Knowledge-base-grounded help for policies, retries, and transfer types.",
    blocks: [
      {
        type: "p",
        text: "The Assistant uses Amazon Bedrock Agent with your curated knowledge base (runbooks, retry policies, SOPs). Ask natural-language questions about transfer types, checksum retries, or partner setup.",
      },
      { type: "route", label: "Open Assistant", to: "/agent" },
      {
        type: "h3",
        text: "Example questions",
      },
      {
        type: "ul",
        items: [
          "What should we do when a checksum validation fails?",
          "List the four BayRelay transfer types.",
          "What is the retry policy for transient network errors?",
          "How do I onboard a new SFTP partner?",
        ],
      },
      {
        type: "h3",
        text: "Limits",
      },
      {
        type: "p",
        text: "The assistant guides operators; it does not execute transfers without explicit API/portal actions. Responses are grounded in ingested KB documents — keep docs updated via your BayRelay administrator.",
      },
      {
        type: "note",
        title: "Production",
        text: "Use a published Bedrock agent alias (not draft) for customer-facing demos and production. See docs/PRODUCTION_CHECKLIST.md in the deployment repository.",
      },
    ],
  },
  {
    id: "roles-access",
    title: "Roles and access control",
    category: "access",
    audience: "all",
    summary: "Operator vs partner permissions and Cognito groups.",
    blocks: [
      {
        type: "h3",
        text: "Operator (bayrelay-operators)",
      },
      {
        type: "ul",
        items: [
          "Full portal navigation including Operations, Automation, Partners, Policies, Audit.",
          "Approve/reject onboarding.",
          "View all partners and transfers.",
          "Configure routing policies and automation rules.",
        ],
      },
      {
        type: "h3",
        text: "Partner (bayrelay-partners)",
      },
      {
        type: "ul",
        items: [
          "Scoped to custom:partner_id on Cognito user.",
          "Home, My transfers, New transfer, Apply/onboard, Assistant.",
          "Cannot access other partners' data or operator-only pages.",
        ],
      },
      {
        type: "h3",
        text: "Dual membership",
      },
      {
        type: "p",
        text: "If a user is in both groups, BayRelay treats them as an operator in the portal and API so internal demo accounts can perform full workflows after onboarding tests.",
      },
    ],
  },
  {
    id: "troubleshooting",
    title: "Troubleshooting",
    category: "troubleshoot",
    audience: "all",
    summary: "Common errors and how to resolve them.",
    blocks: [
      {
        type: "h3",
        text: "Transfer FAILED (S3→SFTP / connector)",
      },
      {
        type: "ul",
        items: [
          "Verify source object exists in the transfer bucket at the specified key.",
          "Confirm Transfer Family connector trusted host keys match the SFTP server (run sync_connector_trusted_host_key.sh after server recreate).",
          "Check partner SFTP path permissions and logical home mapping.",
        ],
      },
      {
        type: "h3",
        text: "403 Forbidden / operator role required",
      },
      {
        type: "p",
        text: "Your Cognito user may lack bayrelay-operators for operator pages. Ask an admin to run create_cognito_operator.sh or add you to the correct group. Sign out and sign in after group changes.",
      },
      {
        type: "h3",
        text: "Policies or API Internal Server Error",
      },
      {
        type: "p",
        text: "Hard-refresh the portal (Cmd+Shift+R). If errors persist, confirm the API Lambda was redeployed and you are using the CloudFront public URL, not the raw API Gateway endpoint.",
      },
      {
        type: "h3",
        text: "Assistant gives generic answers",
      },
      {
        type: "ul",
        items: [
          "Run KB sync and agent prepare (bootstrap_phase3.sh).",
          "Confirm knowledge base ingestion completed in AWS Bedrock console.",
          "Ask questions that reference content in docs/kb/ (e.g. checksum retry).",
        ],
      },
      {
        type: "h3",
        text: "Get support",
      },
      {
        type: "p",
        text: "For BayAreaLa8s implementation support, contact your project lead. Include request_id, correlation_id, and screenshots from Transfer detail and Audit log.",
      },
    ],
  },
  {
    id: "faq",
    title: "Frequently asked questions",
    category: "faq",
    audience: "all",
    summary: "Quick answers for customer demos and production operators.",
    blocks: [
      {
        type: "h3",
        text: "Where do files live?",
      },
      {
        type: "p",
        text: "In your AWS account: transfer data bucket (S3), partner SFTP via Transfer Family, and KB source bucket for runbooks. BayRelay does not host multi-tenant SaaS storage.",
      },
      {
        type: "h3",
        text: "Is data encrypted?",
      },
      {
        type: "p",
        text: "Yes — S3 and DynamoDB use KMS. HTTPS for API and portal via CloudFront. SFTP uses connector credentials in AWS Secrets Manager.",
      },
      {
        type: "h3",
        text: "Can partners use the API directly?",
      },
      {
        type: "p",
        text: "Yes. Partners with Cognito credentials can call the same REST API with JWT Bearer tokens. The portal is a reference UI on top of the API.",
      },
      {
        type: "h3",
        text: "What regions are supported?",
      },
      {
        type: "p",
        text: "Default deployment is us-west-2; Terraform variables allow other regions where Bedrock, Transfer Family, and OpenSearch Serverless are available in your account.",
      },
      {
        type: "h3",
        text: "How do I run a regression test?",
      },
      {
        type: "p",
        text: "Operators run ./scripts/bayrelay_demo.sh smoke from the deployment repo against the live stack. Expect S3→S3, connector flows, KB retrieval, and onboarding checks.",
      },
    ],
  },
];

export function filterHelpSections(
  sections: HelpSection[],
  audience: "operator" | "partner",
  query: string,
): HelpSection[] {
  const q = query.trim().toLowerCase();
  return sections.filter((s) => {
    if (s.audience !== "all" && s.audience !== audience) return false;
    if (!q) return true;
    const haystack = [
      s.title,
      s.summary,
      s.category,
      ...s.blocks.flatMap((b) => {
        if (b.type === "ul" || b.type === "ol") return b.items;
        if (b.type === "route") return [b.label];
        if (b.type === "note") return [b.title, b.text].filter(Boolean) as string[];
        return [b.text];
      }),
    ]
      .join(" ")
      .toLowerCase();
    return haystack.includes(q);
  });
}
