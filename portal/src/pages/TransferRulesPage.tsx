import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, Partner, TransferRule } from "../api";
import DataTable from "../components/DataTable";
import {
  Alert,
  Card,
  Field,
  FormSection,
  LoadingState,
  PageHeader,
} from "../components/ui";

export default function TransferRulesPage() {
  const [rules, setRules] = useState<TransferRule[]>([]);
  const [partners, setPartners] = useState<Partner[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [partnerId, setPartnerId] = useState("");
  const [name, setName] = useState("Inbound to outbound");
  const [matchPattern, setMatchPattern] = useState("demo/report-full/inbound/*");
  const [transferType, setTransferType] = useState("S3_TO_S3");
  const [destKeyTemplate, setDestKeyTemplate] = useState(
    "demo/report-full/outbound/{basename}",
  );
  const [destPrefixTemplate, setDestPrefixTemplate] = useState(
    "demo/acme/report-full/sftp-pulled/auto",
  );
  const [remoteDestDirectory, setRemoteDestDirectory] = useState("/outbound");
  const [q, setQ] = useState("");
  const [editRule, setEditRule] = useState<TransferRule | null>(null);
  const [editName, setEditName] = useState("");
  const [editPattern, setEditPattern] = useState("");
  const [editEnabled, setEditEnabled] = useState(true);
  const [editPriority, setEditPriority] = useState(100);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [r, p] = await Promise.all([
        api.listTransferRules({ q: q || undefined, sort: "priority", order: "asc" }),
        api.listPartners(),
      ]);
      setRules(r.rules);
      setPartners(p.partners);
      if (p.partners[0] && !partnerId) setPartnerId(p.partners[0].partner_id);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
    } finally {
      setLoading(false);
    }
  }, [q]);

  useEffect(() => {
    const t = setTimeout(() => load(), q ? 300 : 0);
    return () => clearTimeout(t);
  }, [load, q]);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await api.createTransferRule({
        partner_id: partnerId,
        name,
        enabled: true,
        priority: 100,
        trigger_type: "S3_OBJECT_CREATED",
        match_pattern: matchPattern,
        transfer_type: transferType,
        payload_template:
          transferType === "S3_TO_S3"
            ? {
                source_bucket: "{bucket}",
                source_key: "{key}",
                dest_bucket: "{bucket}",
                dest_key: destKeyTemplate,
              }
            : transferType === "SFTP_TO_S3"
              ? {
                  remote_paths: ["/{basename}"],
                  dest_bucket: "{bucket}",
                  dest_prefix: destPrefixTemplate,
                }
              : transferType === "SFTP_TO_SFTP"
                ? {
                    remote_source_paths: ["/{basename}"],
                    remote_dest_directory: remoteDestDirectory,
                  }
                : {
                  source_bucket: "{bucket}",
                  source_key: "{key}",
                  remote_directory: "/",
                },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Create failed");
    }
  }

  async function onSaveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editRule) return;
    setError("");
    try {
      await api.updateTransferRule(editRule.rule_id, {
        name: editName,
        match_pattern: editPattern,
        enabled: editEnabled,
        priority: editPriority,
      });
      setEditRule(null);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  }

  if (loading && rules.length === 0) return <LoadingState label="Loading rules" />;

  return (
    <>
      <PageHeader
        title="Transfer automation"
        description="When a new object matches a pattern in the transfer bucket, BayRelay submits a transfer automatically. SFTP → S3 and SFTP → SFTP run after S3 → SFTP (connector staging under sftp-connector/). Partner SFTP uploads land in sftp-inbound/ — use S3 → S3 instead."
      />
      {error && <Alert variant="error">{error}</Alert>}
      <Card>
        <form onSubmit={onCreate}>
          <FormSection
            title="New rule"
            description={
              transferType === "SFTP_TO_S3"
                ? "Connector staging object created → pull from SFTP into S3"
                : transferType === "SFTP_TO_SFTP"
                  ? "Connector staging object created → move file on SFTP server"
                  : "S3 object created → auto transfer"
            }
          >
            <Field label="Partner" htmlFor="rule-partner">
              <select
                id="rule-partner"
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
            <Field label="Rule name" htmlFor="rule-name">
              <input
                id="rule-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </Field>
            <Field
              label="Match pattern (S3 key glob)"
              htmlFor="rule-pattern"
              hint={
                transferType === "SFTP_TO_S3" || transferType === "SFTP_TO_SFTP"
                  ? "Match flat-send-* keys under sftp-connector/ after S3 → SFTP."
                  : undefined
              }
            >
              <input
                id="rule-pattern"
                value={matchPattern}
                onChange={(e) => setMatchPattern(e.target.value)}
                required
              />
            </Field>
            <Field label="Transfer type" htmlFor="rule-type">
              <select
                id="rule-type"
                value={transferType}
                onChange={(e) => {
                  const t = e.target.value;
                  setTransferType(t);
                  if (t === "SFTP_TO_S3") {
                    setName("Connector pull to S3");
                    setMatchPattern("sftp-connector/flat-send-*");
                  } else if (t === "SFTP_TO_SFTP") {
                    setName("Connector relay on SFTP");
                    setMatchPattern("sftp-connector/flat-send-*");
                  } else if (t === "S3_TO_SFTP") {
                    setMatchPattern("demo/report-full/inbound/sftp/*");
                  } else {
                    setMatchPattern("demo/report-full/inbound/*");
                  }
                }}
              >
                <option value="S3_TO_S3">S3 → S3</option>
                <option value="S3_TO_SFTP">S3 → SFTP</option>
                <option value="SFTP_TO_S3">SFTP → S3</option>
                <option value="SFTP_TO_SFTP">SFTP → SFTP</option>
              </select>
            </Field>
            {transferType === "S3_TO_S3" && (
              <Field label="Destination key template" htmlFor="rule-dest">
                <input
                  id="rule-dest"
                  value={destKeyTemplate}
                  onChange={(e) => setDestKeyTemplate(e.target.value)}
                  required
                />
              </Field>
            )}
            {transferType === "SFTP_TO_S3" && (
              <Field
                label="Destination S3 prefix"
                htmlFor="rule-dest-prefix"
                hint="Use {basename} or {stem}; remote path is built as /{basename} from the staging key."
              >
                <input
                  id="rule-dest-prefix"
                  value={destPrefixTemplate}
                  onChange={(e) => setDestPrefixTemplate(e.target.value)}
                  required
                />
              </Field>
            )}
            {transferType === "SFTP_TO_SFTP" && (
              <Field
                label="Remote destination directory"
                htmlFor="rule-sftp-dest-dir"
                hint="Directory on the connector SFTP server (e.g. /outbound). Source path is /{basename} from staging."
              >
                <input
                  id="rule-sftp-dest-dir"
                  value={remoteDestDirectory}
                  onChange={(e) => setRemoteDestDirectory(e.target.value)}
                  required
                />
              </Field>
            )}
          </FormSection>
          <button type="submit" className="btn btn-primary">
            Create rule
          </button>
        </form>
      </Card>
      {editRule && (
        <Card title={`Edit rule ${editRule.rule_id}`}>
          <form onSubmit={onSaveEdit}>
            <Field label="Name" htmlFor="edit-rule-name">
              <input
                id="edit-rule-name"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                required
              />
            </Field>
            <Field label="Match pattern" htmlFor="edit-rule-pattern">
              <input
                id="edit-rule-pattern"
                value={editPattern}
                onChange={(e) => setEditPattern(e.target.value)}
                required
              />
            </Field>
            <div className="form-grid">
              <Field label="Priority" htmlFor="edit-rule-priority">
                <input
                  id="edit-rule-priority"
                  type="number"
                  value={editPriority}
                  onChange={(e) => setEditPriority(Number(e.target.value))}
                />
              </Field>
              <Field label="Enabled" htmlFor="edit-rule-enabled">
                <select
                  id="edit-rule-enabled"
                  value={editEnabled ? "1" : "0"}
                  onChange={(e) => setEditEnabled(e.target.value === "1")}
                >
                  <option value="1">Yes</option>
                  <option value="0">No</option>
                </select>
              </Field>
            </div>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary">
                Save
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setEditRule(null)}
              >
                Cancel
              </button>
            </div>
          </form>
        </Card>
      )}

      <Card title="Active rules" className="card-table">
        <DataTable
          columns={[
            { key: "name", header: "Name", sortable: true },
            { key: "partner_id", header: "Partner", className: "mono" },
            { key: "match_pattern", header: "Pattern" },
            { key: "transfer_type", header: "Type" },
            {
              key: "enabled",
              header: "On",
              render: (r) => (r.enabled === false ? "No" : "Yes"),
            },
            {
              key: "_actions",
              header: "",
              render: (r) => (
                <span style={{ display: "flex", gap: "0.35rem" }}>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => {
                      setEditRule(r);
                      setEditName(r.name || "");
                      setEditPattern(r.match_pattern || "");
                      setEditEnabled(r.enabled !== false);
                      setEditPriority(r.priority ?? 100);
                    }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={async () => {
                      await api.deleteTransferRule(r.rule_id);
                      await load();
                    }}
                  >
                    Delete
                  </button>
                </span>
              ),
            },
          ]}
          rows={rules}
          rowKey={(r) => r.rule_id}
          search={q}
          onSearchChange={setQ}
          searchPlaceholder="Search rules…"
          emptyMessage="No rules configured."
        />
      </Card>
    </>
  );
}
