import { Link, Navigate } from "react-router-dom";
import { isLoggedIn } from "../auth";
import MarketingBrand from "../components/MarketingBrand";
import { NavIcon } from "../components/icons";
import type { NavIconName } from "../components/icons";
import { appHomePath, useRole } from "../roleContext";

const FEATURES: {
  icon: NavIconName;
  title: string;
  desc: string;
}[] = [
  {
    icon: "partners",
    title: "Partners",
    desc: "Registry of trading partners, endpoints, and routing policies",
  },
  {
    icon: "transfers",
    title: "Transfers",
    desc: "Governed S3 and SFTP file exchange with full request lineage",
  },
  {
    icon: "automation",
    title: "Automation",
    desc: "Event-driven rules for inbound files and connector staging",
  },
  {
    icon: "dashboard",
    title: "Operations",
    desc: "Audit trail, onboarding workflow, and Bedrock policy assistant",
  },
];

export default function LandingPage() {
  const { role, loading } = useRole();

  if (isLoggedIn()) {
    if (loading) return null;
    return <Navigate to={appHomePath(role)} replace />;
  }

  return (
    <div className="landing-page">
      <header className="landing-header">
        <div className="landing-header-inner">
          <MarketingBrand />
          <div className="landing-header-actions">
            <Link to="/login" className="landing-link">
              Sign In
            </Link>
            <Link to="/onboarding/new" className="btn btn-primary landing-btn-cta">
              Get Started
            </Link>
          </div>
        </div>
      </header>

      <main className="landing-main">
        <section className="landing-hero">
          <h1 className="landing-hero-title">
            A calmer control plane
            <br />
            <span className="landing-hero-accent">for B2B file exchange</span>
          </h1>
          <p className="landing-hero-lead">
            Partner onboarding, S3 and SFTP orchestration, automation rules, and
            operator oversight — deployed in your AWS account.
          </p>
          <div className="landing-hero-actions">
            <Link to="/onboarding/new" className="btn btn-gold landing-hero-btn">
              Apply as partner
            </Link>
            <Link to="/login" className="btn landing-hero-btn-secondary">
              Operator sign in
            </Link>
          </div>
        </section>

        <section className="landing-features" aria-label="Capabilities">
          {FEATURES.map((f) => (
            <article key={f.title} className="landing-feature-card">
              <div className="landing-feature-icon" aria-hidden>
                <NavIcon name={f.icon} />
              </div>
              <h3>{f.title}</h3>
              <p>{f.desc}</p>
            </article>
          ))}
        </section>

        <section className="landing-cta">
          <div className="landing-cta-icon" aria-hidden>
            <NavIcon name="transfers" />
          </div>
          <h2>Ready to start?</h2>
          <p>
            Submit a partner application in minutes. Operators can sign in to
            provision endpoints, run transfers, and configure automation from day
            one.
          </p>
          <div className="landing-cta-actions">
            <Link to="/onboarding/new" className="btn btn-gold">
              Apply as partner
            </Link>
            <Link to="/login" className="btn btn-ghost landing-cta-signin">
              Operator sign in
            </Link>
          </div>
        </section>
      </main>

      <footer className="landing-footer">
        © BayAreaLa8s · BayRelay · Governed file transfer in your AWS account
      </footer>
    </div>
  );
}
