import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, Endpoint, Partner } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  Field,
  LoadingState,
  PageHeader,
  StatusBadge,
} from "../components/ui";

export default function PartnersPage() {
  const [partners, setPartners] = useState<Partner[]>([]);
  const [endpoints, setEndpoints] = useState<Endpoint[]>([]);
  const [name, setName] = useState("");
  const [epPartner, setEpPartner] = useState("");
  const [protocol, setProtocol] = useState("S3");
  const [direction, setDirection] = useState("OUTBOUND");
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);
  const [pq, setPq] = useState("");
  const [eq, setEq] = useState("");
  const [editPartner, setEditPartner] = useState<Partner | null>(null);
  const [editEndpoint, setEditEndpoint] = useState<Endpoint | null>(null);
  const [editName, setEditName] = useState("");
  const [editEpProtocol, setEditEpProtocol] = useState("S3");
  const [editEpDirection, setEditEpDirection] = useState("OUTBOUND");
  const [editEpConfig, setEditEpConfig] = useState("");

  const refresh = useCallback(async () => {
    const [p, e] = await Promise.all([
      api.listPartners({ q: pq || undefined, sort: "name", order: "asc" }),
      api.listEndpoints({ q: eq || undefined, sort: "partner_id", order: "asc" }),
    ]);
    setPartners(p.partners);
    setEndpoints(e.endpoints);
    setEpPartner((cur) => cur || p.partners[0]?.partner_id || "");
  }, [pq, eq]);

  useEffect(() => {
    const t = setTimeout(() => {
      setLoading(true);
      refresh()
        .catch((err) =>
          setError(err instanceof Error ? err.message : "Load failed"),
        )
        .finally(() => setLoading(false));
    }, pq || eq ? 300 : 0);
    return () => clearTimeout(t);
  }, [refresh, pq, eq]);

  async function addPartner(e: FormEvent) {
    e.preventDefault();
    setError("");
    setMsg("");
    try {
      const res = await api.createPartner({ name: name.trim() });
      setMsg(`Partner ${res.partner_id} created`);
      setName("");
      await refresh();
      setEpPartner(res.partner_id);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    }
  }

  async function addEndpoint(e: FormEvent) {
    e.preventDefault();
    setError("");
    setMsg("");
    try {
      const res = await api.createEndpoint({
        partner_id: epPartner,
        protocol,
        direction,
      });
      setMsg(`Endpoint ${res.endpoint_id} created`);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    }
  }

  async function savePartnerEdit(e: FormEvent) {
    e.preventDefault();
    if (!editPartner) return;
    setError("");
    try {
      await api.updatePartner(editPartner.partner_id, { name: editName.trim() });
      setMsg(`Partner ${editPartner.partner_id} updated`);
      setEditPartner(null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  }

  async function disablePartner(p: Partner) {
    if (!confirm(`Disable partner ${p.name}?`)) return;
    setError("");
    try {
      await api.deletePartner(p.partner_id);
      setMsg(`Partner ${p.partner_id} disabled`);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Disable failed");
    }
  }

  async function saveEndpointEdit(e: FormEvent) {
    e.preventDefault();
    if (!editEndpoint) return;
    setError("");
    try {
      await api.updateEndpoint(editEndpoint.endpoint_id, {
        protocol: editEpProtocol,
        direction: editEpDirection,
        config_ref: editEpConfig,
      });
      setMsg(`Endpoint ${editEndpoint.endpoint_id} updated`);
      setEditEndpoint(null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  }

  async function disableEndpoint(ep: Endpoint) {
    if (!confirm(`Disable endpoint ${ep.endpoint_id}?`)) return;
    setError("");
    try {
      await api.deleteEndpoint(ep.endpoint_id);
      setMsg(`Endpoint ${ep.endpoint_id} disabled`);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Disable failed");
    }
  }

  return (
    <>
      <PageHeader
        title="Partners"
        description="Manage trading partners and their transfer endpoints."
      />
      {error && <Alert variant="error">{error}</Alert>}
      {msg && <Alert variant="success">{msg}</Alert>}

      <div className="split-panels">
        <Card title="Add partner">
          <form onSubmit={addPartner}>
            <Field label="Partner name" htmlFor="partner-name">
              <input
                id="partner-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Acme Corp"
                required
              />
            </Field>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Create partner
              </button>
            </div>
          </form>
        </Card>

        <Card title="Add endpoint">
          <form onSubmit={addEndpoint}>
            <Field label="Partner" htmlFor="ep-partner">
              <select
                id="ep-partner"
                value={epPartner}
                onChange={(e) => setEpPartner(e.target.value)}
                required
              >
                <option value="">Select partner</option>
                {partners.map((p) => (
                  <option key={p.partner_id} value={p.partner_id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </Field>
            <div className="form-grid" style={{ marginTop: "0.75rem" }}>
              <Field label="Protocol" htmlFor="protocol">
                <select
                  id="protocol"
                  value={protocol}
                  onChange={(e) => setProtocol(e.target.value)}
                >
                  <option value="S3">S3</option>
                  <option value="SFTP">SFTP</option>
                </select>
              </Field>
              <Field label="Direction" htmlFor="direction">
                <select
                  id="direction"
                  value={direction}
                  onChange={(e) => setDirection(e.target.value)}
                >
                  <option value="OUTBOUND">Outbound</option>
                  <option value="INBOUND">Inbound</option>
                </select>
              </Field>
            </div>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Create endpoint
              </button>
            </div>
          </form>
        </Card>
      </div>

      {editPartner && (
        <Card title={`Edit partner ${editPartner.partner_id}`}>
          <form onSubmit={savePartnerEdit}>
            <Field label="Name" htmlFor="edit-partner-name">
              <input
                id="edit-partner-name"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                required
              />
            </Field>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Save
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setEditPartner(null)}
              >
                Cancel
              </button>
            </div>
          </form>
        </Card>
      )}

      {editEndpoint && (
        <Card title={`Edit endpoint ${editEndpoint.endpoint_id}`}>
          <form onSubmit={saveEndpointEdit}>
            <div className="form-grid">
              <Field label="Protocol" htmlFor="edit-ep-protocol">
                <select
                  id="edit-ep-protocol"
                  value={editEpProtocol}
                  onChange={(e) => setEditEpProtocol(e.target.value)}
                >
                  <option value="S3">S3</option>
                  <option value="SFTP">SFTP</option>
                </select>
              </Field>
              <Field label="Direction" htmlFor="edit-ep-direction">
                <select
                  id="edit-ep-direction"
                  value={editEpDirection}
                  onChange={(e) => setEditEpDirection(e.target.value)}
                >
                  <option value="OUTBOUND">Outbound</option>
                  <option value="INBOUND">Inbound</option>
                </select>
              </Field>
            </div>
            <Field label="Config ref" htmlFor="edit-ep-config">
              <input
                id="edit-ep-config"
                value={editEpConfig}
                onChange={(e) => setEditEpConfig(e.target.value)}
              />
            </Field>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Save
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setEditEndpoint(null)}
              >
                Cancel
              </button>
            </div>
          </form>
        </Card>
      )}

      {loading ? (
        <LoadingState label="Loading partners" />
      ) : (
        <>
          <Card title="All partners" className="card-table">
            <DataTable
              columns={[
                { key: "partner_id", header: "ID", className: "mono" },
                { key: "name", header: "Name", sortable: true },
                {
                  key: "status",
                  header: "Status",
                  render: (p) => <StatusBadge status={p.status} />,
                },
                {
                  key: "_actions",
                  header: "",
                  render: (p) => (
                    <span style={{ display: "flex", gap: "0.35rem" }}>
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setEditPartner(p);
                          setEditName(p.name);
                        }}
                      >
                        Edit
                      </button>
                      {p.status !== "DISABLED" && (
                        <button
                          type="button"
                          className="btn btn-ghost"
                          onClick={() => disablePartner(p)}
                        >
                          Disable
                        </button>
                      )}
                    </span>
                  ),
                },
              ]}
              rows={partners}
              rowKey={(p) => p.partner_id}
              search={pq}
              onSearchChange={setPq}
              searchPlaceholder="Search partners…"
              emptyMessage="No partners registered"
            />
          </Card>

          <Card title="All endpoints" className="card-table">
            <DataTable
              columns={[
                { key: "endpoint_id", header: "ID", className: "mono" },
                { key: "partner_id", header: "Partner", className: "mono" },
                { key: "protocol", header: "Protocol" },
                { key: "direction", header: "Direction" },
                {
                  key: "status",
                  header: "Status",
                  render: (ep) => <StatusBadge status={ep.status} />,
                },
                {
                  key: "_actions",
                  header: "",
                  render: (ep) => (
                    <span style={{ display: "flex", gap: "0.35rem" }}>
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setEditEndpoint(ep);
                          setEditEpProtocol(ep.protocol);
                          setEditEpDirection(ep.direction);
                          setEditEpConfig(ep.config_ref || "");
                        }}
                      >
                        Edit
                      </button>
                      {ep.status !== "DISABLED" && (
                        <button
                          type="button"
                          className="btn btn-ghost"
                          onClick={() => disableEndpoint(ep)}
                        >
                          Disable
                        </button>
                      )}
                    </span>
                  ),
                },
              ]}
              rows={endpoints}
              rowKey={(ep) => ep.endpoint_id}
              search={eq}
              onSearchChange={setEq}
              searchPlaceholder="Search endpoints…"
              emptyMessage="No endpoints registered"
            />
          </Card>
        </>
      )}
    </>
  );
}
