import { FormEvent, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { getToken, isLoggedIn, login, parseIdToken } from "../auth";
import { appHomePath, useRole, type PortalRole } from "../roleContext";
import MarketingBrand from "../components/MarketingBrand";
import Footer from "../components/Footer";
import { Alert, Card, Field } from "../components/ui";

export default function LoginPage() {
  const navigate = useNavigate();
  const { refresh, role, loading: roleLoading } = useRole();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (isLoggedIn() && !roleLoading) {
    return <Navigate to={appHomePath(role)} replace />;
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(username.trim(), password);
      await refresh();
      const token = getToken();
      let r: PortalRole = "operator";
      if (token) {
        const claims = parseIdToken(token);
        const gs = claims.groups;
        if (gs.includes("bayrelay-operators")) r = "operator";
        else if (gs.includes("bayrelay-partners")) r = "partner";
        else if (claims.sub) r = "operator";
      }
      navigate(appHomePath(r));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-frame">
      <header className="ba-header login-top-header">
        <div className="ba-header-inner">
          <MarketingBrand />
        </div>
      </header>

      <section className="login-hero ba-hero-gradient">
        <div className="login-hero-inner">
          <p className="login-hero-eyebrow">Innovate. Transform.</p>
          <h1>Enterprise file transfer operations</h1>
          <p>
            Governed B2B transfers, partner registry, and Bedrock-assisted policy
            guidance — deployed in your AWS account.
          </p>
        </div>
      </section>

      <section className="login-body">
        <div className="login-body-inner">
          <Card className="login-card" title="Operator sign in">
            <form onSubmit={onSubmit}>
              <Field label="Email" htmlFor="user">
                <input
                  id="user"
                  type="email"
                  autoComplete="username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                />
              </Field>
              <Field label="Password" htmlFor="pass">
                <input
                  id="pass"
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </Field>
              {error && <Alert variant="error">{error}</Alert>}
              <button type="submit" className="btn btn-gold" disabled={loading}>
                {loading ? "Signing in…" : "Sign in"}
              </button>
            </form>
          </Card>
        </div>
      </section>

      <Footer />
    </div>
  );
}
