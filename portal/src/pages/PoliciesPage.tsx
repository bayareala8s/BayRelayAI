import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, Partner, RoutingPolicy } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  Field,
  LoadingState,
  PageHeader,
} from "../components/ui";

export default function PoliciesPage() {
  const [policies, setPolicies] = useState<RoutingPolicy[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [partnerId, setPartnerId] = useState("");
  const [policyId, setPolicyId] = useState("default");
  const [effect, setEffect] = useState("ALLOW");
  const [description, setDescription] = useState("");
  const [editPolicy, setEditPolicy] = useState<RoutingPolicy | null>(null);
  const [editEffect, setEditEffect] = useState("ALLOW");
  const [editDescription, setEditDescription] = useState("");

  const refresh = useCallback(async () => {
    const [pol, p] = await Promise.all([
      api.listRoutingPolicies({
        q: q || undefined,
        partner_id: partnerId || undefined,
      }),
      api.listPartners({ sort: "name", order: "asc" }),
    ]);
    setPolicies(pol.policies);
    setPartners(p.partners);
    if (!partnerId && p.partners[0]) setPartnerId(p.partners[0].partner_id);
  }, [q, partnerId]);

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

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setError("");
    setMsg("");
    try {
      await api.createRoutingPolicy({
        partner_id: partnerId,
        policy_id: policyId.trim() || "default",
        effect,
        description: description.trim(),
      });
      setMsg("Policy created");
      setDescription("");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Create failed");
    }
  }

  async function onSaveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editPolicy) return;
    setError("");
    try {
      await api.updateRoutingPolicy(editPolicy.policy_id, editPolicy.partner_id, {
        effect: editEffect,
        description: editDescription,
      });
      setEditPolicy(null);
      setMsg("Policy updated");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  }

  return (
    <>
      <PageHeader
        title="Routing policies"
        description="Partner-scoped ALLOW/DENY rules for transfer routing (operator only)."
      />
      {error && <Alert variant="error">{error}</Alert>}
      {msg && <Alert variant="success">{msg}</Alert>}

      <Card title="New policy">
        <form onSubmit={onCreate}>
          <div className="form-grid">
            <Field label="Partner" htmlFor="pol-partner">
              <select
                id="pol-partner"
                value={partnerId}
                onChange={(e) => setPartnerId(e.target.value)}
                required
              >
                {partners.map((p) => (
                  <option key={p.partner_id} value={p.partner_id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Policy ID" htmlFor="pol-id">
              <input
                id="pol-id"
                value={policyId}
                onChange={(e) => setPolicyId(e.target.value)}
                placeholder="default"
              />
            </Field>
            <Field label="Effect" htmlFor="pol-effect">
              <select
                id="pol-effect"
                value={effect}
                onChange={(e) => setEffect(e.target.value)}
              >
                <option value="ALLOW">ALLOW</option>
                <option value="DENY">DENY</option>
              </select>
            </Field>
          </div>
          <Field label="Description" htmlFor="pol-desc">
            <input
              id="pol-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </Field>
          <div className="form-actions">
            <button type="submit" className="btn btn-primary">
              Create policy
            </button>
          </div>
        </form>
      </Card>

      {editPolicy && (
        <Card title={`Edit ${editPolicy.policy_id}`}>
          <form onSubmit={onSaveEdit}>
            <Field label="Effect" htmlFor="edit-pol-effect">
              <select
                id="edit-pol-effect"
                value={editEffect}
                onChange={(e) => setEditEffect(e.target.value)}
              >
                <option value="ALLOW">ALLOW</option>
                <option value="DENY">DENY</option>
              </select>
            </Field>
            <Field label="Description" htmlFor="edit-pol-desc">
              <input
                id="edit-pol-desc"
                value={editDescription}
                onChange={(e) => setEditDescription(e.target.value)}
              />
            </Field>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Save
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setEditPolicy(null)}
              >
                Cancel
              </button>
            </div>
          </form>
        </Card>
      )}

      {loading ? (
        <LoadingState label="Loading policies" />
      ) : (
        <Card title="Policies" className="card-table">
          <DataTable
            columns={[
              { key: "policy_id", header: "Policy", className: "mono" },
              { key: "partner_id", header: "Partner", className: "mono" },
              { key: "effect", header: "Effect" },
              { key: "description", header: "Description" },
              {
                key: "_actions",
                header: "",
                render: (pol) => (
                  <span style={{ display: "flex", gap: "0.35rem" }}>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => {
                        setEditPolicy(pol);
                        setEditEffect(pol.effect);
                        setEditDescription(pol.description || "");
                      }}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={async () => {
                        if (!confirm("Delete this policy?")) return;
                        await api.deleteRoutingPolicy(
                          pol.policy_id,
                          pol.partner_id,
                        );
                        await refresh();
                      }}
                    >
                      Delete
                    </button>
                  </span>
                ),
              },
            ]}
            rows={policies}
            rowKey={(p) => `${p.partner_id}:${p.policy_id}`}
            search={q}
            onSearchChange={setQ}
            searchPlaceholder="Search policies…"
            emptyMessage="No routing policies."
          />
        </Card>
      )}
    </>
  );
}
