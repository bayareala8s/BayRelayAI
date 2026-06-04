import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, OpsSummary } from "../api";
import {
  Alert,
  Card,
  formatDate,
  LoadingState,
  PageHeader,
  StatusBadge,
} from "../components/ui";

const HEALTH_LABELS: Record<string, { title: string; hint: string }> = {
  healthy: {
    title: "All clear",
    hint: "No failed transfers or executions in the sample.",
  },
  attention: {
    title: "Needs attention",
    hint: "One or more failures detected — review below.",
  },
  busy: {
    title: "High onboarding volume",
    hint: "Many pending customer applications awaiting review.",
  },
};

function StatCard({
  label,
  value,
  sub,
  to,
}: {
  label: string;
  value: number | string;
  sub?: string;
  to?: string;
}) {
  const inner = (
    <>
      <span className="ops-stat-label">{label}</span>
      <span className="ops-stat-value">{value}</span>
      {sub && <span className="ops-stat-sub">{sub}</span>}
    </>
  );
  return (
    <div className="ops-stat-card">
      {to ? (
        <Link to={to} className="ops-stat-link">
          {inner}
        </Link>
      ) : (
        inner
      )}
    </div>
  );
}

function StatusBars({
  title,
  data,
}: {
  title: string;
  data: Record<string, number>;
}) {
  const entries = Object.entries(data).filter(([, n]) => n > 0);
  const max = Math.max(...entries.map(([, n]) => n), 1);
  if (entries.length === 0) {
    return (
      <Card title={title}>
        <p className="muted">No data in current sample.</p>
      </Card>
    );
  }
  return (
    <Card title={title}>
      <ul className="ops-bars">
        {entries.map(([key, count]) => (
          <li key={key}>
            <div className="ops-bar-head">
              <span>{key}</span>
              <span className="mono">{count}</span>
            </div>
            <div className="ops-bar-track">
              <div
                className="ops-bar-fill"
                style={{ width: `${(count / max) * 100}%` }}
              />
            </div>
          </li>
        ))}
      </ul>
    </Card>
  );
}

type DashboardView = "overview" | "charts";

function ViewToggle({
  view,
  onChange,
}: {
  view: DashboardView;
  onChange: (v: DashboardView) => void;
}) {
  return (
    <div className="ops-view-toggle" role="tablist" aria-label="Dashboard view">
      <button
        type="button"
        role="tab"
        aria-selected={view === "overview"}
        className={`ops-view-toggle-btn${view === "overview" ? " ops-view-toggle-btn-active" : ""}`}
        onClick={() => onChange("overview")}
      >
        Overview
      </button>
      <button
        type="button"
        role="tab"
        aria-selected={view === "charts"}
        className={`ops-view-toggle-btn${view === "charts" ? " ops-view-toggle-btn-active" : ""}`}
        onClick={() => onChange("charts")}
      >
        Charts
      </button>
    </div>
  );
}

export default function OperationsDashboardPage() {
  const [summary, setSummary] = useState<OpsSummary | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [view, setView] = useState<DashboardView>("overview");

  const refresh = useCallback(async () => {
    const res = await api.getOpsSummary(200, 8);
    setSummary(res);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await api.getOpsSummary(200, 8);
        if (!cancelled) setSummary(res);
      } catch (e) {
        if (!cancelled)
          setError(e instanceof Error ? e.message : "Failed to load dashboard");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    const timer = window.setInterval(() => {
      refresh().catch(() => {});
    }, 60_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [refresh]);

  const health = summary?.health ?? "healthy";
  const healthMeta = HEALTH_LABELS[health] ?? HEALTH_LABELS.healthy;
  const succeeded =
    summary?.executions.by_status.SUCCEEDED ??
    summary?.transfers.by_status.SUCCEEDED ??
    0;
  const failedExec = summary?.executions.by_status.FAILED ?? 0;

  return (
    <>
      <div className="ops-dashboard-head">
        <PageHeader
          title="Operational Dashboard"
          description="Overview of transfer health, failures, and platform capacity."
          titleAddon={<span className="ops-live-pill">LIVE</span>}
          helpHref="https://www.bayareala8s.com/"
          action={
            <div className="ops-header-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => {
                  setLoading(true);
                  refresh()
                    .catch((e) =>
                      setError(
                        e instanceof Error ? e.message : "Refresh failed",
                      ),
                    )
                    .finally(() => setLoading(false));
                }}
              >
                Refresh
              </button>
              <Link to="/transfers/new" className="btn btn-gold">
                New transfer
              </Link>
            </div>
          }
        />
        <ViewToggle view={view} onChange={setView} />
      </div>
      {error && <Alert variant="error">{error}</Alert>}

      {loading && !summary ? (
        <LoadingState label="Loading operations summary" />
      ) : summary ? (
        <>
          <div
            className={`ops-health-banner ops-health-${health}`}
            role="status"
          >
            <div>
              <strong>{healthMeta.title}</strong>
              <p>{healthMeta.hint}</p>
            </div>
            <span className="ops-health-time">
              Updated {formatDate(summary.generated_at)}
            </span>
          </div>

          <div className="ops-stat-grid">
            <StatCard
              label="Partners"
              value={summary.counts.partners}
              to="/partners"
            />
            <StatCard
              label="Endpoints"
              value={summary.counts.endpoints}
              to="/partners"
            />
            <StatCard
              label="Succeeded"
              value={succeeded}
              sub="executions / requests"
            />
            <StatCard
              label="Failed executions"
              value={failedExec}
              sub={failedExec > 0 ? "Review failures" : undefined}
            />
            <StatCard
              label="Onboarding queue"
              value={summary.counts.onboarding_pending}
              sub="pending review"
              to="/onboarding"
            />
            <StatCard
              label="Transfers sampled"
              value={summary.counts.transfers_sampled}
              sub="last 200 requests"
              to="/transfers"
            />
          </div>

          {view === "charts" ? (
            <div className="ops-charts-grid">
              <StatusBars
                title="Transfer requests by status"
                data={summary.transfers.by_status}
              />
              <StatusBars
                title="Transfer types"
                data={summary.transfers.by_type}
              />
              <StatusBars
                title="Executions by status"
                data={summary.executions.by_status}
              />
              <Card title="Platform counts">
                <ul className="ops-bars">
                  {(
                    [
                      ["Partners", summary.counts.partners],
                      ["Endpoints", summary.counts.endpoints],
                      ["Onboarding pending", summary.counts.onboarding_pending],
                      ["Transfers sampled", summary.counts.transfers_sampled],
                    ] as const
                  ).map(([label, count]) => {
                    const max = Math.max(
                      summary.counts.partners,
                      summary.counts.endpoints,
                      summary.counts.onboarding_pending,
                      summary.counts.transfers_sampled,
                      1,
                    );
                    return (
                      <li key={label}>
                        <div className="ops-bar-head">
                          <span>{label}</span>
                          <span className="mono">{count}</span>
                        </div>
                        <div className="ops-bar-track">
                          <div
                            className="ops-bar-fill ops-bar-fill-gold"
                            style={{ width: `${(count / max) * 100}%` }}
                          />
                        </div>
                      </li>
                    );
                  })}
                </ul>
              </Card>
            </div>
          ) : (
            <>
          <div className="ops-panels">
            <StatusBars
              title="Transfer requests by status"
              data={summary.transfers.by_status}
            />
            <StatusBars
              title="Transfer types"
              data={summary.transfers.by_type}
            />
          </div>

          <div className="ops-panels">
            <Card title="Recent transfers" className="card-table">
              {summary.recent_transfers.length === 0 ? (
                <p className="muted">No transfers in sample.</p>
              ) : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Request</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th>Created</th>
                      </tr>
                    </thead>
                    <tbody>
                      {summary.recent_transfers.map((t) => (
                        <tr key={t.request_id}>
                          <td>
                            <Link
                              to={`/transfers/${t.request_id}`}
                              className="mono"
                            >
                              {t.request_id}
                            </Link>
                          </td>
                          <td>{t.transfer_type || "—"}</td>
                          <td>
                            <StatusBadge status={t.status} />
                          </td>
                          <td>{formatDate(t.created_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <p className="card-footer-link">
                <Link to="/transfers">View all transfers →</Link>
              </p>
            </Card>

            <Card title="Recent failures" className="card-table">
              {summary.executions.failed_recent.length === 0 ? (
                <p className="muted">No failed executions.</p>
              ) : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Execution</th>
                        <th>Request</th>
                        <th>Partner</th>
                        <th>When</th>
                      </tr>
                    </thead>
                    <tbody>
                      {summary.executions.failed_recent.map((ex) => (
                        <tr key={ex.execution_id}>
                          <td className="mono">{ex.execution_id}</td>
                          <td>
                            {ex.request_id ? (
                              <Link
                                to={`/transfers/${ex.request_id}`}
                                className="mono"
                              >
                                {ex.request_id}
                              </Link>
                            ) : (
                              "—"
                            )}
                          </td>
                          <td className="mono">{ex.partner_id || "—"}</td>
                          <td>{formatDate(ex.created_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          </div>

          <Card title="Quick actions">
            <div className="ops-quick-links">
              <Link to="/transfers/new" className="btn btn-gold">
                Submit transfer
              </Link>
              <Link to="/onboarding" className="btn btn-ghost">
                Review onboarding
              </Link>
              <Link to="/agent" className="btn btn-ghost">
                Ask assistant
              </Link>
              <Link to="/partners" className="btn btn-ghost">
                Manage partners
              </Link>
            </div>
          </Card>
            </>
          )}
        </>
      ) : null}
    </>
  );
}
