import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api, Transfer, TransferExecution } from "../api";
import {
  Alert,
  Card,
  DetailGrid,
  DetailItem,
  formatDate,
  LoadingState,
  PageHeader,
  StatusBadge,
} from "../components/ui";

export default function TransferDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [transfer, setTransfer] = useState<Transfer | null>(null);
  const [execution, setExecution] = useState<TransferExecution | null>(null);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);
  const [acting, setActing] = useState(false);

  useEffect(() => {
    if (!id) return;
    const requestId = id;
    let cancelled = false;
    let timer: ReturnType<typeof setInterval>;

    async function load() {
      try {
        const res = await api.getTransfer(requestId);
        if (!cancelled) {
          setTransfer(res.transfer_request);
          setExecution(res.latest_execution ?? null);
          setError("");
        }
      } catch (e) {
        if (!cancelled)
          setError(e instanceof Error ? e.message : "Failed to load");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    timer = setInterval(load, 5000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [id]);

  const status = (transfer?.status || "").toUpperCase();
  const canCancel = status && !["SUCCEEDED", "FAILED", "CANCELLED"].includes(status);
  const canRetry = ["FAILED", "CANCELLED"].includes(status);

  async function onRetry() {
    if (!id) return;
    setActing(true);
    setError("");
    setMsg("");
    try {
      const res = await api.retryTransfer(id);
      setMsg(
        res.request_id
          ? `Retry submitted — new request ${res.request_id}`
          : "Retry submitted",
      );
      if (res.request_id) navigate(`/transfers/${res.request_id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Retry failed");
    } finally {
      setActing(false);
    }
  }

  async function onCancel() {
    if (!id) return;
    setActing(true);
    setError("");
    setMsg("");
    try {
      await api.cancelTransfer(id);
      setMsg("Transfer cancelled");
      const res = await api.getTransfer(id);
      setTransfer(res.transfer_request);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Cancel failed");
    } finally {
      setActing(false);
    }
  }

  if (loading) return <LoadingState label="Loading transfer" />;
  if (error && !transfer) return <Alert variant="error">{error}</Alert>;
  if (!transfer) return <Alert variant="error">Transfer not found</Alert>;

  const payload = transfer.payload as Record<string, string> | undefined;

  return (
    <>
      <Link to="/transfers" className="back-link">
        ← Back to transfers
      </Link>
      <PageHeader
        title="Transfer details"
        description={transfer.request_id}
        action={
          <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
            <StatusBadge status={transfer.status} />
            {canRetry && (
              <button
                type="button"
                className="btn btn-primary"
                disabled={acting}
                onClick={onRetry}
              >
                Retry
              </button>
            )}
            {canCancel && (
              <button
                type="button"
                className="btn btn-ghost"
                disabled={acting}
                onClick={onCancel}
              >
                Cancel
              </button>
            )}
          </div>
        }
      />
      {error && <Alert variant="error">{error}</Alert>}
      {msg && <Alert variant="success">{msg}</Alert>}
      <Card title="Overview">
        <DetailGrid>
          <DetailItem label="Request ID" value={transfer.request_id} mono />
          <DetailItem label="Status" value={transfer.status} />
          <DetailItem label="Type" value={transfer.transfer_type} />
          <DetailItem label="Partner" value={transfer.partner_id} mono />
          <DetailItem label="Created" value={formatDate(transfer.created_at)} />
          <DetailItem
            label="Correlation ID"
            value={transfer.correlation_id}
            mono
          />
          {transfer.operator_summary && (
            <DetailItem label="Summary" value={transfer.operator_summary} />
          )}
        </DetailGrid>
      </Card>
      {execution && (
        <Card title="Latest execution">
          <DetailGrid>
            <DetailItem label="Execution ID" value={execution.execution_id} mono />
            <DetailItem label="Status" value={execution.status} />
            <DetailItem label="Created" value={formatDate(execution.created_at)} />
            {execution.error_message && (
              <DetailItem label="Error" value={execution.error_message} />
            )}
          </DetailGrid>
        </Card>
      )}
      {payload && Object.keys(payload).length > 0 && (
        <Card title="Payload">
          <DetailGrid>
            {Object.entries(payload).map(([k, v]) => (
              <DetailItem
                key={k}
                label={k.replace(/_/g, " ")}
                value={
                  Array.isArray(v)
                    ? v.join(", ")
                    : typeof v === "object" && v !== null
                      ? JSON.stringify(v)
                      : String(v)
                }
                mono
              />
            ))}
          </DetailGrid>
        </Card>
      )}
    </>
  );
}
