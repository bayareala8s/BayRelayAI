import { useCallback, useEffect, useState } from "react";
import { api, AuditEvent } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  formatDate,
  LoadingState,
  PageHeader,
} from "../components/ui";

export default function AuditPage() {
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [correlationId, setCorrelationId] = useState("");
  const [sort, setSort] = useState("timestamp");
  const [order, setOrder] = useState<"asc" | "desc">("desc");

  const refresh = useCallback(async () => {
    const res = await api.listAuditEvents({
      limit: 100,
      q: q || undefined,
      correlation_id: correlationId || undefined,
      sort,
      order,
    });
    setEvents(res.events);
  }, [q, correlationId, sort, order]);

  useEffect(() => {
    const t = setTimeout(() => {
      setLoading(true);
      refresh()
        .catch((err) =>
          setError(err instanceof Error ? err.message : "Load failed"),
        )
        .finally(() => setLoading(false));
    }, q ? 300 : 0);
    return () => clearTimeout(t);
  }, [refresh, q]);

  function onSortChange(key: string) {
    if (sort === key) setOrder((o) => (o === "asc" ? "desc" : "asc"));
    else {
      setSort(key);
      setOrder("desc");
    }
  }

  return (
    <>
      <PageHeader
        title="Audit log"
        description="Operator view of control-plane actions (transfers, onboarding, cancellations)."
      />
      {error && <Alert variant="error">{error}</Alert>}

      {loading ? (
        <LoadingState label="Loading audit events" />
      ) : (
        <Card className="card-table">
          <DataTable
            columns={[
              {
                key: "timestamp",
                header: "Time",
                sortable: true,
                render: (e) => formatDate(e.timestamp),
              },
              { key: "action", header: "Action", sortable: true },
              { key: "actor", header: "Actor" },
              {
                key: "correlation_id",
                header: "Correlation",
                className: "mono",
              },
              {
                key: "detail",
                header: "Detail",
                render: (e) =>
                  e.detail ? (
                    <span className="mono" style={{ fontSize: "0.75rem" }}>
                      {JSON.stringify(e.detail)}
                    </span>
                  ) : (
                    "—"
                  ),
              },
            ]}
            rows={events}
            rowKey={(e) =>
              e.audit_id || `${e.correlation_id}-${e.timestamp}-${e.action}`
            }
            search={q}
            onSearchChange={setQ}
            searchPlaceholder="Search audit events…"
            sort={sort}
            order={order}
            onSortChange={onSortChange}
            toolbarExtra={
              <input
                type="text"
                className="data-table-search"
                placeholder="Correlation ID"
                value={correlationId}
                onChange={(e) => setCorrelationId(e.target.value)}
                style={{ maxWidth: "14rem" }}
              />
            }
            emptyMessage="No audit events found."
          />
        </Card>
      )}
    </>
  );
}
