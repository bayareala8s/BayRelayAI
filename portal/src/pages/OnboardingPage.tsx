import { FormEvent, useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, OnboardingRequest } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  EmptyState,
  Field,
  formatDate,
  LoadingState,
  PageHeader,
  StatusBadge,
} from "../components/ui";

const STATUS_FILTERS = [
  { value: "", label: "All" },
  { value: "SUBMITTED", label: "Pending review" },
  { value: "APPROVED", label: "Approved" },
  { value: "REJECTED", label: "Rejected" },
] as const;

export default function OnboardingPage() {
  const [requests, setRequests] = useState<OnboardingRequest[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [selected, setSelected] = useState<OnboardingRequest | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [customPartnerId, setCustomPartnerId] = useState("");
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);
  const [acting, setActing] = useState(false);
  const [q, setQ] = useState("");

  const refresh = useCallback(async () => {
    const res = await api.listOnboardingRequests({
      status: statusFilter || undefined,
      limit: 50,
      q: q || undefined,
      sort: "created_at",
      order: "desc",
    });
    setRequests(res.requests);
  }, [statusFilter, q]);

  useEffect(() => {
    setLoading(true);
    refresh()
      .catch((err) =>
        setError(err instanceof Error ? err.message : "Load failed"),
      )
      .finally(() => setLoading(false));
  }, [refresh]);

  async function openDetail(id: string) {
    setError("");
    try {
      const res = await api.getOnboardingRequest(id);
      setSelected(res.onboarding_request);
      setRejectReason("");
      setCustomPartnerId("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Load failed");
    }
  }

  async function approve(e: FormEvent) {
    e.preventDefault();
    if (!selected) return;
    setActing(true);
    setError("");
    setMsg("");
    try {
      const res = await api.approveOnboardingRequest(selected.request_id, {
        partner_id: customPartnerId.trim() || undefined,
      });
      setMsg(
        `Approved — partner ${res.partner_id} with ${res.endpoint_ids.length} endpoint(s)`,
      );
      setSelected(null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Approve failed");
    } finally {
      setActing(false);
    }
  }

  async function reject(e: FormEvent) {
    e.preventDefault();
    if (!selected) return;
    setActing(true);
    setError("");
    setMsg("");
    try {
      await api.rejectOnboardingRequest(
        selected.request_id,
        rejectReason.trim(),
      );
      setMsg(`Request ${selected.request_id} rejected`);
      setSelected(null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Reject failed");
    } finally {
      setActing(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Customer onboarding"
        description="Review self-service applications and provision partners when approved."
        action={
          <Link to="/onboarding/new" className="btn btn-gold">
            New application
          </Link>
        }
      />
      {error && <Alert variant="error">{error}</Alert>}
      {msg && <Alert variant="success">{msg}</Alert>}

      <Card className="card-table">
        {loading ? (
          <LoadingState label="Loading applications" />
        ) : requests.length === 0 && !q && !statusFilter ? (
          <EmptyState
            title="No onboarding requests"
            description="Submit a new customer application to start the review workflow."
            actionLabel="New application"
            actionTo="/onboarding/new"
          />
        ) : (
          <DataTable
            columns={[
              {
                key: "request_id",
                header: "Request",
                render: (r) => (
                  <button
                    type="button"
                    className="link-button mono"
                    onClick={() => openDetail(r.request_id)}
                  >
                    {r.request_id}
                  </button>
                ),
              },
              { key: "company_name", header: "Company", sortable: true },
              {
                key: "status",
                header: "Status",
                render: (r) => <StatusBadge status={r.status} />,
              },
              {
                key: "submitted_at",
                header: "Submitted",
                render: (r) => formatDate(r.submitted_at),
              },
              {
                key: "partner_id",
                header: "Partner",
                className: "mono",
                render: (r) =>
                  r.partner_id ? (
                    <Link to="/partners">{r.partner_id}</Link>
                  ) : (
                    "—"
                  ),
              },
            ]}
            rows={requests}
            rowKey={(r) => r.request_id}
            search={q}
            onSearchChange={setQ}
            searchPlaceholder="Search applications…"
            statusFilter={statusFilter}
            onStatusFilterChange={setStatusFilter}
            statusOptions={STATUS_FILTERS.map((f) => ({
              value: f.value,
              label: f.label,
            }))}
            emptyMessage="No applications match your filters."
          />
        )}
      </Card>

      {selected && (
        <Card title="Application detail">
          <dl className="detail-grid">
            <dt>Company</dt>
            <dd>{selected.company_name}</dd>
            <dt>Contact</dt>
            <dd>{selected.contact_email || "—"}</dd>
            <dt>Transfer types</dt>
            <dd>{(selected.transfer_types || []).join(", ") || "—"}</dd>
            <dt>Endpoints</dt>
            <dd>
              {(selected.endpoints || [])
                .map((e) => `${e.protocol} ${e.direction}`)
                .join(" · ") || "—"}
            </dd>
            <dt>Notes</dt>
            <dd>{selected.notes || "—"}</dd>
            <dt>Submitted by</dt>
            <dd>{selected.submitted_by || "—"}</dd>
            {selected.rejection_reason && (
              <>
                <dt>Rejection reason</dt>
                <dd>{selected.rejection_reason}</dd>
              </>
            )}
          </dl>

          {selected.status === "SUBMITTED" && (
            <div className="onboarding-actions">
              <form onSubmit={approve} className="onboarding-approve">
                <Field
                  label="Partner ID (optional)"
                  htmlFor="partner-id"
                  hint="Leave blank to auto-generate"
                >
                  <input
                    id="partner-id"
                    value={customPartnerId}
                    onChange={(e) => setCustomPartnerId(e.target.value)}
                    placeholder="PRT-…"
                  />
                </Field>
                <button
                  type="submit"
                  className="btn btn-gold"
                  disabled={acting}
                >
                  Approve & provision
                </button>
              </form>
              <form onSubmit={reject} className="onboarding-reject">
                <Field label="Rejection reason" htmlFor="reject-reason" fullWidth>
                  <textarea
                    id="reject-reason"
                    rows={2}
                    value={rejectReason}
                    onChange={(e) => setRejectReason(e.target.value)}
                  />
                </Field>
                <button
                  type="submit"
                  className="btn btn-outline-light"
                  disabled={acting}
                >
                  Reject
                </button>
              </form>
            </div>
          )}

          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => setSelected(null)}
          >
            Close
          </button>
        </Card>
      )}
    </>
  );
}
