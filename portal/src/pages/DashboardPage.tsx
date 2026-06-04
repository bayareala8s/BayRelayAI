import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, Transfer } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  EmptyState,
  formatDate,
  LoadingState,
  PageHeader,
  StatusBadge,
} from "../components/ui";

const STATUS_OPTIONS = [
  { value: "", label: "All statuses" },
  { value: "SUBMITTED", label: "Submitted" },
  { value: "RUNNING", label: "Running" },
  { value: "SUCCEEDED", label: "Succeeded" },
  { value: "FAILED", label: "Failed" },
  { value: "CANCELLED", label: "Cancelled" },
];

export default function DashboardPage() {
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [sort, setSort] = useState("created_at");
  const [order, setOrder] = useState<"asc" | "desc">("desc");

  const refresh = useCallback(async () => {
    const res = await api.listTransfers({
      limit: 100,
      q: q || undefined,
      status: status || undefined,
      sort,
      order,
    });
    setTransfers(res.transfers);
  }, [q, status, sort, order]);

  useEffect(() => {
    let cancelled = false;
    const timer = setTimeout(() => {
      setLoading(true);
      refresh()
        .catch((e) => {
          if (!cancelled)
            setError(e instanceof Error ? e.message : "Failed to load transfers");
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, q ? 300 : 0);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [refresh, q]);

  function onSortChange(key: string) {
    if (sort === key) {
      setOrder((o) => (o === "asc" ? "desc" : "asc"));
    } else {
      setSort(key);
      setOrder("desc");
    }
  }

  return (
    <>
      <PageHeader
        title="All transfers"
        description="Full list of file transfer requests and their status."
        action={
          <Link to="/transfers/new" className="btn btn-gold">
            New transfer
          </Link>
        }
      />
      {error && <Alert variant="error">{error}</Alert>}
      <Card className="card-table">
        {loading && transfers.length === 0 ? (
          <LoadingState label="Loading transfers" />
        ) : transfers.length === 0 && !q && !status ? (
          <EmptyState
            title="No transfers yet"
            description="Submit your first S3 transfer to get started."
            actionLabel="New transfer"
            actionTo="/transfers/new"
          />
        ) : (
          <DataTable
            columns={[
              {
                key: "request_id",
                header: "Request ID",
                sortable: true,
                render: (t) => (
                  <Link to={`/transfers/${t.request_id}`} className="mono">
                    {t.request_id}
                  </Link>
                ),
              },
              {
                key: "partner_id",
                header: "Partner",
                sortable: true,
                className: "mono",
              },
              {
                key: "transfer_type",
                header: "Type",
                sortable: true,
              },
              {
                key: "status",
                header: "Status",
                sortable: true,
                render: (t) => <StatusBadge status={t.status} />,
              },
              {
                key: "created_at",
                header: "Created",
                sortable: true,
                render: (t) => formatDate(t.created_at),
              },
            ]}
            rows={transfers}
            rowKey={(t) => t.request_id}
            search={q}
            onSearchChange={setQ}
            searchPlaceholder="Search transfers…"
            statusFilter={status}
            onStatusFilterChange={setStatus}
            statusOptions={STATUS_OPTIONS}
            sort={sort}
            order={order}
            onSortChange={onSortChange}
            emptyMessage="No transfers match your search."
          />
        )}
      </Card>
    </>
  );
}
