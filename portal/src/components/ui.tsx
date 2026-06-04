import { Link } from "react-router-dom";

export function PageHeader({
  title,
  description,
  action,
  titleAddon,
  helpHref,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
  /** Badges or links rendered inline after the title (e.g. LIVE pill). */
  titleAddon?: React.ReactNode;
  helpHref?: string;
}) {
  return (
    <header className="page-header">
      <div className="page-header-main">
        <h1 className="page-title">
          {title}
          {titleAddon}
          {helpHref && (
            <a
              href={helpHref}
              className="page-help-link"
              target="_blank"
              rel="noopener noreferrer"
            >
              Need help?
            </a>
          )}
        </h1>
        {description && <p className="page-desc">{description}</p>}
      </div>
      {action && <div className="page-header-action">{action}</div>}
    </header>
  );
}

export function Card({
  title,
  children,
  className = "",
}: {
  title?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`card ${className}`.trim()}>
      {title && <h2 className="card-title">{title}</h2>}
      {children}
    </section>
  );
}

export function Alert({
  variant,
  children,
}: {
  variant: "error" | "success" | "info";
  children: React.ReactNode;
}) {
  return <div className={`alert alert-${variant}`}>{children}</div>;
}

export function LoadingState({ label = "Loading" }: { label?: string }) {
  return (
    <div className="loading-state" role="status">
      <span className="spinner" aria-hidden />
      {label}
    </div>
  );
}

export function EmptyState({
  title,
  description,
  actionLabel,
  actionTo,
}: {
  title: string;
  description?: string;
  actionLabel?: string;
  actionTo?: string;
}) {
  return (
    <div className="empty-state">
      <p className="empty-title">{title}</p>
      {description && <p className="empty-desc">{description}</p>}
      {actionLabel && actionTo && (
        <Link to={actionTo} className="btn btn-gold">
          {actionLabel}
        </Link>
      )}
    </div>
  );
}

export function StatusBadge({ status }: { status?: string }) {
  const s = (status || "unknown").toLowerCase();
  let variant = "neutral";
  if (s.includes("success") || s === "active") variant = "success";
  else if (s.includes("fail") || s.includes("error")) variant = "danger";
  else if (
    s.includes("submit") ||
    s.includes("queue") ||
    s.includes("run") ||
    s.includes("progress")
  )
    variant = "warning";

  return (
    <span className={`status-badge status-${variant}`}>
      {status || "Unknown"}
    </span>
  );
}

export function DetailGrid({ children }: { children: React.ReactNode }) {
  return <dl className="detail-grid">{children}</dl>;
}

export function DetailItem({
  label,
  value,
  mono,
}: {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <>
      <dt>{label}</dt>
      <dd className={mono ? "mono" : undefined}>{value ?? "—"}</dd>
    </>
  );
}

export function FormSection({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
}) {
  return (
    <fieldset className="form-section">
      <legend className="form-section-title">{title}</legend>
      {description && <p className="form-section-desc">{description}</p>}
      <div className="form-grid">{children}</div>
    </fieldset>
  );
}

export function Field({
  label,
  htmlFor,
  hint,
  children,
  fullWidth,
}: {
  label: string;
  htmlFor?: string;
  hint?: string;
  children: React.ReactNode;
  fullWidth?: boolean;
}) {
  return (
    <div className={`field ${fullWidth ? "field-full" : ""}`.trim()}>
      <label htmlFor={htmlFor}>{label}</label>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </div>
  );
}

export function formatDate(iso?: string): string {
  if (!iso) return "—";
  try {
    const d = new Date(iso);
    return d.toLocaleString(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    });
  } catch {
    return iso;
  }
}
