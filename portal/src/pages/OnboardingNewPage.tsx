import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { api, CreateOnboardingBody, OnboardingEndpoint } from "../api";
import {
  Alert,
  Card,
  Field,
  FormSection,
  PageHeader,
} from "../components/ui";

const TRANSFER_TYPES = [
  "S3_TO_S3",
  "S3_TO_SFTP",
  "SFTP_TO_S3",
  "SFTP_TO_SFTP",
] as const;

const DEFAULT_ENDPOINTS: OnboardingEndpoint[] = [
  { protocol: "S3", direction: "OUTBOUND" },
  { protocol: "S3", direction: "INBOUND" },
];

export default function OnboardingNewPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [companyName, setCompanyName] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [notes, setNotes] = useState("");
  const [transferTypes, setTransferTypes] = useState<string[]>(["S3_TO_S3"]);
  const [includeSftpOutbound, setIncludeSftpOutbound] = useState(false);
  const [includeSftpInbound, setIncludeSftpInbound] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  function toggleTransferType(t: string) {
    setTransferTypes((cur) =>
      cur.includes(t) ? cur.filter((x) => x !== t) : [...cur, t],
    );
  }

  function buildEndpoints(): OnboardingEndpoint[] {
    const eps = [...DEFAULT_ENDPOINTS];
    if (includeSftpOutbound) {
      eps.push({ protocol: "SFTP", direction: "OUTBOUND" });
    }
    if (includeSftpInbound) {
      eps.push({ protocol: "SFTP", direction: "INBOUND" });
    }
    return eps;
  }

  function canAdvance(): boolean {
    if (step === 1) return companyName.trim().length > 0;
    if (step === 2) return transferTypes.length > 0;
    return true;
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    const body: CreateOnboardingBody = {
      company_name: companyName.trim(),
      contact_email: contactEmail.trim() || undefined,
      notes: notes.trim() || undefined,
      transfer_types: transferTypes,
      endpoints: buildEndpoints(),
    };
    try {
      const res = await api.createOnboardingRequest(body);
      navigate("/onboarding", {
        state: { createdId: res.onboarding_request.request_id },
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Submit failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <PageHeader
        title="New customer application"
        description="Guided onboarding for a B2B trading partner. An operator reviews and approves before transfers can run."
        action={
          <Link to="/onboarding" className="btn btn-ghost">
            Back to inbox
          </Link>
        }
      />
      {error && <Alert variant="error">{error}</Alert>}

      <div className="wizard-steps" aria-label="Progress">
        {["Company", "Transfers", "Review"].map((label, i) => {
          const n = i + 1;
          const active = step === n;
          const done = step > n;
          return (
            <span
              key={label}
              className={`wizard-step${active ? " wizard-step-active" : ""}${done ? " wizard-step-done" : ""}`}
            >
              <span className="wizard-step-num">{n}</span>
              {label}
            </span>
          );
        })}
      </div>

      <Card>
        <form onSubmit={onSubmit}>
          {step === 1 && (
            <FormSection
              title="Company profile"
              description="Legal or trading name and primary contact for this partner."
            >
              <Field label="Company name" htmlFor="company" fullWidth>
                <input
                  id="company"
                  required
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                  placeholder="Acme Logistics Inc."
                />
              </Field>
              <Field label="Contact email" htmlFor="email" fullWidth>
                <input
                  id="email"
                  type="email"
                  value={contactEmail}
                  onChange={(e) => setContactEmail(e.target.value)}
                  placeholder="edi@acme.example"
                />
              </Field>
              <Field label="Notes" htmlFor="notes" fullWidth>
                <textarea
                  id="notes"
                  rows={3}
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Expected volume, compliance, or routing notes for reviewers."
                />
              </Field>
            </FormSection>
          )}

          {step === 2 && (
            <FormSection
              title="Transfer capabilities"
              description="Select which transfer patterns this partner will use. Endpoints are provisioned on approval."
            >
              <div className="field field-full">
                <span className="field-label">Transfer types</span>
                <div className="checkbox-group">
                  {TRANSFER_TYPES.map((t) => (
                    <label key={t} className="checkbox-row">
                      <input
                        type="checkbox"
                        checked={transferTypes.includes(t)}
                        onChange={() => toggleTransferType(t)}
                      />
                      {t.replace(/_/g, " → ")}
                    </label>
                  ))}
                </div>
              </div>
              <div className="field field-full">
                <span className="field-label">Optional SFTP endpoints</span>
                <label className="checkbox-row">
                  <input
                    type="checkbox"
                    checked={includeSftpOutbound}
                    onChange={(e) => setIncludeSftpOutbound(e.target.checked)}
                  />
                  SFTP outbound (in addition to default S3 pair)
                </label>
                <label className="checkbox-row">
                  <input
                    type="checkbox"
                    checked={includeSftpInbound}
                    onChange={(e) => setIncludeSftpInbound(e.target.checked)}
                  />
                  SFTP inbound
                </label>
              </div>
            </FormSection>
          )}

          {step === 3 && (
            <FormSection title="Review & submit">
              <dl className="detail-grid">
                <dt>Company</dt>
                <dd>{companyName}</dd>
                <dt>Contact</dt>
                <dd>{contactEmail || "—"}</dd>
                <dt>Transfer types</dt>
                <dd>{transferTypes.join(", ")}</dd>
                <dt>Endpoints on approve</dt>
                <dd>
                  {buildEndpoints()
                    .map((e) => `${e.protocol} ${e.direction}`)
                    .join(" · ")}
                </dd>
                <dt>Notes</dt>
                <dd>{notes || "—"}</dd>
              </dl>
              <Alert variant="info">
                After submit, status is <strong>SUBMITTED</strong>. An operator
                approves from the onboarding inbox to create the partner and
                endpoints.
              </Alert>
            </FormSection>
          )}

          <div className="form-actions">
            {step > 1 && (
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setStep((s) => s - 1)}
              >
                Back
              </button>
            )}
            {step < 3 && (
              <button
                type="button"
                className="btn btn-gold"
                disabled={!canAdvance()}
                onClick={() => setStep((s) => s + 1)}
              >
                Continue
              </button>
            )}
            {step === 3 && (
              <button
                type="submit"
                className="btn btn-gold"
                disabled={loading || !canAdvance()}
              >
                {loading ? "Submitting…" : "Submit application"}
              </button>
            )}
          </div>
        </form>
      </Card>
    </>
  );
}
