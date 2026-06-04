import { FormEvent, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { api, Endpoint, newIdempotencyKey, Partner } from "../api";
import {
  Alert,
  Card,
  Field,
  FormSection,
  PageHeader,
} from "../components/ui";
import {
  buildTransferSubmitBody,
  pickDefaultEndpoints,
  TRANSFER_TYPE_HINTS,
  TRANSFER_TYPE_LABELS,
  TRANSFER_TYPES,
  TransferType,
  validateTransferForm,
} from "../transferTypes";
import { isPartner, useRole } from "../roleContext";

const DEFAULT_BUCKET =
  import.meta.env.VITE_TRANSFER_BUCKET?.trim() || "";

export default function NewTransferPage() {
  const navigate = useNavigate();
  const { role, partnerId: scopedPartnerId } = useRole();
  const [partners, setPartners] = useState<Partner[]>([]);
  const [endpoints, setEndpoints] = useState<Endpoint[]>([]);
  const [partnerId, setPartnerId] = useState("");
  const [sourceId, setSourceId] = useState("");
  const [targetId, setTargetId] = useState("");
  const [transferType, setTransferType] = useState<TransferType>("S3_TO_S3");
  const [sourceBucket, setSourceBucket] = useState(DEFAULT_BUCKET);
  const [sourceKey, setSourceKey] = useState("");
  const [destBucket, setDestBucket] = useState(DEFAULT_BUCKET);
  const [destKey, setDestKey] = useState("");
  const [remotePaths, setRemotePaths] = useState("");
  const [destPrefix, setDestPrefix] = useState("demo/report-full/sftp-pulled/portal");
  const [remoteDirectory, setRemoteDirectory] = useState("/");
  const [remoteDestDirectory, setRemoteDestDirectory] = useState("/");
  const [summary, setSummary] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const p = await api.listPartners();
        setPartners(p.partners);
        if (isPartner(role) && scopedPartnerId) {
          setPartnerId(scopedPartnerId);
        } else if (p.partners[0]) {
          setPartnerId(p.partners[0].partner_id);
        }
      } catch {
        /* empty list ok */
      }
    })();
  }, [role, scopedPartnerId]);

  useEffect(() => {
    if (!partnerId) {
      setEndpoints([]);
      return;
    }
    (async () => {
      try {
        const e = await api.listEndpoints({ partner_id: partnerId });
        setEndpoints(e.endpoints);
        const { sourceId: s, targetId: t } = pickDefaultEndpoints(
          e.endpoints,
          transferType,
        );
        if (s) setSourceId(s);
        if (t) setTargetId(t);
      } catch {
        setEndpoints([]);
      }
    })();
  }, [partnerId, transferType]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    const values = {
      partnerId,
      sourceId,
      targetId,
      transferType,
      sourceBucket,
      sourceKey,
      destBucket,
      destKey,
      remotePaths,
      destPrefix,
      remoteDirectory,
      remoteDestDirectory,
      summary,
    };
    const validationError = validateTransferForm(values);
    if (validationError) {
      setError(validationError);
      return;
    }
    setLoading(true);
    try {
      const res = await api.submitTransfer(
        buildTransferSubmitBody(values),
        newIdempotencyKey(),
      );
      const rid = res.request_id;
      if (rid) navigate(`/transfers/${rid}`);
      else navigate("/transfers");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Submit failed");
    } finally {
      setLoading(false);
    }
  }

  const showS3Source =
    transferType === "S3_TO_S3" || transferType === "S3_TO_SFTP";
  const showS3Dest = transferType === "S3_TO_S3";
  const showSftpPaths =
    transferType === "SFTP_TO_S3" || transferType === "SFTP_TO_SFTP";
  const showS3DestPrefix = transferType === "SFTP_TO_S3";
  const showRemoteDir = transferType === "S3_TO_SFTP";
  const showRemoteDestDir = transferType === "SFTP_TO_SFTP";

  return (
    <>
      <PageHeader
        title="New transfer"
        description="Submit a file transfer for the selected partner. All four transfer types are supported."
      />
      {partners.length === 0 && (
        <Alert variant="info">
          Register a <Link to="/partners">partner and endpoints</Link> before
          submitting a transfer.
        </Alert>
      )}
      <Card>
        <form onSubmit={onSubmit}>
          <FormSection
            title="Transfer type"
            description={TRANSFER_TYPE_HINTS[transferType]}
          >
            <Field label="Type" htmlFor="transfer-type">
              <select
                id="transfer-type"
                value={transferType}
                onChange={(e) =>
                  setTransferType(e.target.value as TransferType)
                }
                required
              >
                {TRANSFER_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {TRANSFER_TYPE_LABELS[t]}
                  </option>
                ))}
              </select>
            </Field>
          </FormSection>

          <FormSection
            title="Routing"
            description="Partner and endpoints (defaults adjust by transfer type)."
          >
            <Field label="Partner" htmlFor="partner">
              {isPartner(role) && scopedPartnerId ? (
                <input id="partner" value={scopedPartnerId} readOnly />
              ) : (
                <select
                  id="partner"
                  value={partnerId}
                  onChange={(e) => setPartnerId(e.target.value)}
                  required
                >
                  <option value="">Select partner</option>
                  {partners.map((p) => (
                    <option key={p.partner_id} value={p.partner_id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              )}
            </Field>
            <Field label="Source endpoint" htmlFor="source">
              <select
                id="source"
                value={sourceId}
                onChange={(e) => setSourceId(e.target.value)}
                required
              >
                <option value="">Select endpoint</option>
                {endpoints.map((ep) => (
                  <option key={ep.endpoint_id} value={ep.endpoint_id}>
                    {ep.endpoint_id} · {ep.direction} / {ep.protocol}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Target endpoint" htmlFor="target">
              <select
                id="target"
                value={targetId}
                onChange={(e) => setTargetId(e.target.value)}
                required
              >
                <option value="">Select endpoint</option>
                {endpoints.map((ep) => (
                  <option key={ep.endpoint_id} value={ep.endpoint_id}>
                    {ep.endpoint_id} · {ep.direction} / {ep.protocol}
                  </option>
                ))}
              </select>
            </Field>
          </FormSection>

          {showS3Source && (
            <FormSection
              title="S3 source"
              description="Object must already exist in the transfer bucket."
            >
              <Field
                label="Source bucket"
                htmlFor="src-bucket"
                hint="Transfer data bucket in your account"
              >
                <input
                  id="src-bucket"
                  value={sourceBucket}
                  onChange={(e) => setSourceBucket(e.target.value)}
                  placeholder="bayrelay-prod-transfer-data-…"
                  required
                />
              </Field>
              <Field label="Source key" htmlFor="src-key">
                <input
                  id="src-key"
                  value={sourceKey}
                  onChange={(e) => setSourceKey(e.target.value)}
                  placeholder="demo/report-full/inbound/file.txt"
                  required
                />
              </Field>
            </FormSection>
          )}

          {showS3Dest && (
            <FormSection
              title="S3 destination"
              description="Key where the copied object will be written."
            >
              <Field label="Destination bucket" htmlFor="dst-bucket">
                <input
                  id="dst-bucket"
                  value={destBucket}
                  onChange={(e) => setDestBucket(e.target.value)}
                  required
                />
              </Field>
              <Field label="Destination key" htmlFor="dst-key">
                <input
                  id="dst-key"
                  value={destKey}
                  onChange={(e) => setDestKey(e.target.value)}
                  placeholder="demo/report-full/outbound/file.txt"
                  required
                />
              </Field>
            </FormSection>
          )}

          {showRemoteDir && (
            <FormSection
              title="SFTP destination"
              description="Remote directory on the connector server (e.g. / drops under sftp-connector/ in S3)."
            >
              <Field
                label="Remote directory"
                htmlFor="remote-dir"
                hint="Path on SFTP as seen by the connector user"
              >
                <input
                  id="remote-dir"
                  value={remoteDirectory}
                  onChange={(e) => setRemoteDirectory(e.target.value)}
                  placeholder="/"
                  required
                />
              </Field>
            </FormSection>
          )}

          {showSftpPaths && (
            <FormSection
              title="SFTP source paths"
              description="Files on connector SFTP home (use leading /). List one per line."
            >
              <Field
                label="Remote paths"
                htmlFor="remote-paths"
                hint="Example: /flat-send-EX-abc-sftp-2026-06-03.txt"
                fullWidth
              >
                <textarea
                  id="remote-paths"
                  rows={3}
                  value={remotePaths}
                  onChange={(e) => setRemotePaths(e.target.value)}
                  placeholder="/flat-send-EX-....txt"
                  required
                />
              </Field>
            </FormSection>
          )}

          {showS3DestPrefix && (
            <FormSection
              title="S3 destination"
              description="Retrieved files are written under this bucket prefix."
            >
              <Field label="Destination bucket" htmlFor="dst-bucket-sftp">
                <input
                  id="dst-bucket-sftp"
                  value={destBucket}
                  onChange={(e) => setDestBucket(e.target.value)}
                  required
                />
              </Field>
              <Field
                label="Destination prefix"
                htmlFor="dest-prefix"
                hint="Folder prefix without leading slash"
              >
                <input
                  id="dest-prefix"
                  value={destPrefix}
                  onChange={(e) => setDestPrefix(e.target.value)}
                  placeholder="demo/report-full/sftp-pulled/my-run"
                  required
                />
              </Field>
            </FormSection>
          )}

          {showRemoteDestDir && (
            <FormSection
              title="SFTP destination"
              description="Target directory on the connector SFTP server. Use / unless that folder already exists (e.g. /archive/)."
            >
              <Field
                label="Remote destination directory"
                htmlFor="remote-dest-dir"
                hint="Invalid or missing paths cause send phase to fail"
              >
                <input
                  id="remote-dest-dir"
                  value={remoteDestDirectory}
                  onChange={(e) => setRemoteDestDirectory(e.target.value)}
                  placeholder="/"
                  required
                />
              </Field>
            </FormSection>
          )}

          <FormSection title="Notes">
            <Field label="Summary (optional)" htmlFor="summary" fullWidth>
              <input
                id="summary"
                value={summary}
                onChange={(e) => setSummary(e.target.value)}
                placeholder="Brief description for operators"
              />
            </Field>
          </FormSection>

          {transferType !== "S3_TO_S3" && (
            <Alert variant="info">
              {transferType === "S3_TO_SFTP" && (
                <>
                  Stage the source object in S3 before submit. After success,
                  check <code>sftp-connector/</code> in the transfer bucket.
                </>
              )}
              {transferType === "SFTP_TO_S3" && (
                <>
                  Remote files must already exist on SFTP (often from a prior
                  S3→SFTP transfer). List basenames under{" "}
                  <code>sftp-connector/</code> in S3, then use{" "}
                  <code>/filename</code> here.
                </>
              )}
              {transferType === "SFTP_TO_SFTP" && (
                <>
                  Source paths must exist on connector SFTP home. Files are
                  staged in S3 then sent to the destination directory.
                </>
              )}
            </Alert>
          )}

          {error && <Alert variant="error">{error}</Alert>}
          <div className="form-actions">
            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading || !partnerId}
            >
              {loading ? "Submitting…" : "Submit transfer"}
            </button>
            <Link to="/transfers" className="btn btn-ghost">
              Cancel
            </Link>
          </div>
        </form>
      </Card>
    </>
  );
}
