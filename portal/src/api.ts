import { getToken } from "./auth";
import { getPortalConfig } from "./config";

function apiBase(): string {
  return getPortalConfig().apiUrl.replace(/\/$/, "");
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public body?: unknown,
  ) {
    super(message);
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = getToken();
  if (!token) {
    throw new ApiError("Not authenticated", 401);
  }

  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${token}`);
  if (!headers.has("Content-Type") && init.body) {
    headers.set("Content-Type", "application/json");
  }

  const res = await fetch(`${apiBase()}${path}`, { ...init, headers });
  const text = await res.text();
  let body: unknown = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }

  if (!res.ok) {
    const msg =
      typeof body === "object" && body && "message" in body
        ? String((body as { message: string }).message)
        : res.statusText;
    throw new ApiError(msg, res.status, body);
  }

  return body as T;
}

export function newIdempotencyKey(): string {
  return crypto.randomUUID();
}

export function newCorrelationId(): string {
  return crypto.randomUUID();
}

export type ListQuery = {
  limit?: number;
  q?: string;
  status?: string;
  partner_id?: string;
  sort?: string;
  order?: "asc" | "desc";
  correlation_id?: string;
};

function listQuery(params: ListQuery = {}): string {
  const sp = new URLSearchParams();
  if (params.limit != null) sp.set("limit", String(params.limit));
  if (params.q) sp.set("q", params.q);
  if (params.status) sp.set("status", params.status);
  if (params.partner_id) sp.set("partner_id", params.partner_id);
  if (params.sort) sp.set("sort", params.sort);
  if (params.order) sp.set("order", params.order);
  if (params.correlation_id) sp.set("correlation_id", params.correlation_id);
  const qs = sp.toString();
  return qs ? `?${qs}` : "";
}

export type MeResponse = {
  role: string;
  partner_id: string | null;
  email: string | null;
  username: string | null;
  groups: string[];
};

export type TransferRule = {
  rule_id: string;
  partner_id: string;
  name?: string;
  enabled?: boolean;
  priority?: number;
  trigger_type?: string;
  match_pattern?: string;
  transfer_type?: string;
  source_endpoint_id?: string | null;
  target_endpoint_id?: string | null;
  payload_template?: Record<string, unknown>;
  created_at?: string;
  updated_at?: string;
};

export const api = {
  getMe: () => request<MeResponse>("/v1/me"),

  getOpsSummary: (transferSample = 200, recentLimit = 8) =>
    request<OpsSummary>(
      `/v1/ops/summary?transfer_sample=${transferSample}&recent_limit=${recentLimit}`,
    ),

  listTransfers: (query: ListQuery = {}) =>
    request<{ transfers: Transfer[]; count: number }>(
      `/v1/transfers${listQuery({ limit: 50, ...query })}`,
    ),

  getTransfer: (id: string) =>
    request<{ transfer_request: Transfer; latest_execution?: TransferExecution }>(
      `/v1/transfers/${encodeURIComponent(id)}`,
    ),

  retryTransfer: (id: string) =>
    request<TransferSubmitResult>(
      `/v1/transfers/${encodeURIComponent(id)}/retry`,
      {
        method: "POST",
        headers: {
          "X-Idempotency-Key": newIdempotencyKey(),
          "X-Correlation-Id": newCorrelationId(),
        },
      },
    ),

  cancelTransfer: (id: string) =>
    request<{ request_id: string; status: string }>(
      `/v1/transfers/${encodeURIComponent(id)}/cancel`,
      { method: "POST" },
    ),

  submitTransfer: (body: SubmitTransferBody, idempotencyKey: string) =>
    request<TransferSubmitResult>("/v1/transfers", {
      method: "POST",
      headers: {
        "X-Idempotency-Key": idempotencyKey,
        "X-Correlation-Id": newCorrelationId(),
      },
      body: JSON.stringify(body),
    }),

  listPartners: (query: ListQuery = {}) =>
    request<{ partners: Partner[]; count: number }>(
      `/v1/partners${listQuery(query)}`,
    ),

  getPartner: (id: string) =>
    request<{ partner: Partner }>(
      `/v1/partners/${encodeURIComponent(id)}`,
    ),

  updatePartner: (
    id: string,
    body: { name?: string; status?: string; metadata?: Record<string, unknown> },
  ) =>
    request<{ partner: Partner }>(
      `/v1/partners/${encodeURIComponent(id)}`,
      { method: "PUT", body: JSON.stringify(body) },
    ),

  deletePartner: (id: string) =>
    request<{ partner: Partner }>(
      `/v1/partners/${encodeURIComponent(id)}`,
      { method: "DELETE" },
    ),

  createPartner: (body: { name: string; partner_id?: string }) =>
    request<{ partner_id: string }>("/v1/partners", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  listEndpoints: (query: ListQuery = {}) =>
    request<{ endpoints: Endpoint[]; count: number }>(
      `/v1/endpoints${listQuery(query)}`,
    ),

  getEndpoint: (id: string) =>
    request<{ endpoint: Endpoint }>(
      `/v1/endpoints/${encodeURIComponent(id)}`,
    ),

  updateEndpoint: (
    id: string,
    body: {
      protocol?: string;
      direction?: string;
      config_ref?: string;
      status?: string;
    },
  ) =>
    request<{ endpoint: Endpoint }>(
      `/v1/endpoints/${encodeURIComponent(id)}`,
      { method: "PUT", body: JSON.stringify(body) },
    ),

  deleteEndpoint: (id: string) =>
    request<{ endpoint: Endpoint }>(
      `/v1/endpoints/${encodeURIComponent(id)}`,
      { method: "DELETE" },
    ),

  createEndpoint: (body: {
    partner_id: string;
    protocol: string;
    direction: string;
    config_ref?: string;
    endpoint_id?: string;
  }) =>
    request<{ endpoint_id: string }>("/v1/endpoints", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  agentQuery: (query: string, sessionId?: string) =>
    request<AgentResponse>("/v1/agent/query", {
      method: "POST",
      headers: { "X-Correlation-Id": newCorrelationId() },
      body: JSON.stringify({ query, session_id: sessionId }),
    }),

  listOnboardingRequests: (query: ListQuery & { status?: string } = {}) =>
    request<{ requests: OnboardingRequest[]; count: number }>(
      `/v1/onboarding/requests${listQuery({ limit: 50, ...query })}`,
    ),

  getOnboardingRequest: (id: string) =>
    request<{ onboarding_request: OnboardingRequest }>(
      `/v1/onboarding/requests/${encodeURIComponent(id)}`,
    ),

  createOnboardingRequest: (body: CreateOnboardingBody) =>
    request<{ onboarding_request: OnboardingRequest }>(
      "/v1/onboarding/requests",
      { method: "POST", body: JSON.stringify(body) },
    ),

  approveOnboardingRequest: (id: string, body?: { partner_id?: string }) =>
    request<OnboardingApproveResult>(
      `/v1/onboarding/requests/${encodeURIComponent(id)}/approve`,
      { method: "POST", body: JSON.stringify(body ?? {}) },
    ),

  rejectOnboardingRequest: (id: string, reason?: string) =>
    request<{ request_id: string; status: string; reason?: string }>(
      `/v1/onboarding/requests/${encodeURIComponent(id)}/reject`,
      { method: "POST", body: JSON.stringify({ reason: reason ?? "" }) },
    ),

  listTransferRules: (query: ListQuery = {}) =>
    request<{ rules: TransferRule[]; count: number }>(
      `/v1/transfer-rules${listQuery({ limit: 100, ...query })}`,
    ),

  getTransferRule: (ruleId: string) =>
    request<{ rule: TransferRule }>(
      `/v1/transfer-rules/${encodeURIComponent(ruleId)}`,
    ),

  createTransferRule: (body: Partial<TransferRule>) =>
    request<{ rule: TransferRule }>("/v1/transfer-rules", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  updateTransferRule: (ruleId: string, body: Partial<TransferRule>) =>
    request<{ rule: TransferRule }>(
      `/v1/transfer-rules/${encodeURIComponent(ruleId)}`,
      { method: "PUT", body: JSON.stringify(body) },
    ),

  deleteTransferRule: (ruleId: string) =>
    request<{ rule_id: string; deleted: boolean }>(
      `/v1/transfer-rules/${encodeURIComponent(ruleId)}`,
      { method: "DELETE" },
    ),

  listRoutingPolicies: (query: ListQuery = {}) =>
    request<{ policies: RoutingPolicy[]; count: number }>(
      `/v1/routing-policies${listQuery({ limit: 100, ...query })}`,
    ),

  createRoutingPolicy: (body: {
    partner_id: string;
    policy_id?: string;
    effect: string;
    description?: string;
  }) =>
    request<{ policy: RoutingPolicy }>("/v1/routing-policies", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  updateRoutingPolicy: (
    policyId: string,
    partnerId: string,
    body: { effect?: string; description?: string },
  ) =>
    request<{ policy: RoutingPolicy }>(
      `/v1/routing-policies/${encodeURIComponent(policyId)}?partner_id=${encodeURIComponent(partnerId)}`,
      { method: "PUT", body: JSON.stringify(body) },
    ),

  deleteRoutingPolicy: (policyId: string, partnerId: string) =>
    request<{ policy_id: string; partner_id: string; deleted: boolean }>(
      `/v1/routing-policies/${encodeURIComponent(policyId)}?partner_id=${encodeURIComponent(partnerId)}`,
      { method: "DELETE" },
    ),

  listAuditEvents: (query: ListQuery = {}) =>
    request<{ events: AuditEvent[]; count: number }>(
      `/v1/audit-events${listQuery({ limit: 50, ...query })}`,
    ),
};

export type Transfer = {
  request_id: string;
  partner_id?: string;
  transfer_type?: string;
  status?: string;
  created_at?: string;
  correlation_id?: string;
  payload?: Record<string, unknown>;
  operator_summary?: string;
};

export type TransferExecution = {
  execution_id?: string;
  request_id?: string;
  status?: string;
  created_at?: string;
  error_message?: string;
  step_functions_execution_arn?: string;
};

export type RoutingPolicy = {
  policy_id: string;
  partner_id: string;
  effect: string;
  description?: string;
  created_at?: string;
  updated_at?: string;
};

export type AuditEvent = {
  audit_id?: string;
  action?: string;
  actor?: string;
  correlation_id?: string;
  timestamp?: string;
  detail?: Record<string, unknown>;
};

export type Partner = {
  partner_id: string;
  name: string;
  status?: string;
  created_at?: string;
};

export type Endpoint = {
  endpoint_id: string;
  partner_id: string;
  protocol: string;
  direction: string;
  status?: string;
  config_ref?: string;
};

export type SubmitTransferBody = {
  partner_id: string;
  source_endpoint_id: string;
  target_endpoint_id: string;
  transfer_type: string;
  payload?: Record<string, unknown>;
  operator_summary?: string;
};

export type TransferSubmitResult = {
  request_id?: string;
  execution_id?: string;
  step_functions_execution_arn?: string;
  deduplicated?: boolean;
};

export type AgentResponse = {
  agent_response: string;
  session_id?: string;
  request_id?: string;
};

export type OnboardingEndpoint = {
  protocol: string;
  direction: string;
};

export type OnboardingRequest = {
  request_id: string;
  status: string;
  company_name: string;
  contact_email?: string;
  notes?: string;
  transfer_types?: string[];
  endpoints?: OnboardingEndpoint[];
  submitted_by?: string;
  submitted_at?: string;
  updated_at?: string;
  partner_id?: string | null;
  rejection_reason?: string | null;
  reviewed_by?: string;
  reviewed_at?: string;
};

export type CreateOnboardingBody = {
  company_name: string;
  contact_email?: string;
  notes?: string;
  transfer_types?: string[];
  endpoints?: OnboardingEndpoint[];
};

export type OpsSummary = {
  generated_at: string;
  health: "healthy" | "attention" | "busy";
  counts: {
    partners: number;
    endpoints: number;
    transfers_sampled: number;
    onboarding_pending: number;
  };
  transfers: {
    by_status: Record<string, number>;
    by_type: Record<string, number>;
  };
  executions: {
    by_status: Record<string, number>;
    failed_recent: OpsFailedExecution[];
  };
  recent_transfers: OpsRecentTransfer[];
};

export type OpsRecentTransfer = {
  request_id?: string;
  partner_id?: string;
  transfer_type?: string;
  status?: string;
  created_at?: string;
};

export type OpsFailedExecution = {
  execution_id?: string;
  request_id?: string;
  partner_id?: string;
  transfer_type?: string;
  status?: string;
  created_at?: string;
  error_message?: string;
};

export type OnboardingApproveResult = {
  request_id: string;
  status: string;
  partner_id: string;
  endpoint_ids: string[];
};
