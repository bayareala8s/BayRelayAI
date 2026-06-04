import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, Transfer } from "../api";
import { Alert, Card, LoadingState, PageHeader } from "../components/ui";
import { useRole } from "../roleContext";

export default function PartnerHomePage() {
  const { partnerId, loading: roleLoading } = useRole();
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    if (roleLoading) return;
    (async () => {
      try {
        const t = await api.listTransfers({ limit: 10 });
        setTransfers(t.transfers);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load");
      }
    })();
  }, [roleLoading, partnerId]);

  if (roleLoading) return <LoadingState label="Loading" />;

  if (!partnerId) {
    return (
      <>
        <PageHeader
          title="Welcome"
          description="Complete onboarding to activate your partner account."
        />
        <Alert variant="info">
          Submit an application under{" "}
          <Link to="/onboarding/new">Apply / onboard</Link>. When approved, your
          account will be linked automatically (auto-approve may apply).
        </Alert>
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="Partner home"
        description={`Transfers and files for ${partnerId}`}
        action={
          <Link to="/transfers/new" className="btn btn-gold">
            New transfer
          </Link>
        }
      />
      {error && <Alert variant="error">{error}</Alert>}
      <Card title="Recent transfers">
        {transfers.length === 0 ? (
          <p className="page-desc">No transfers yet.</p>
        ) : (
          <ul className="simple-list">
            {transfers.map((t) => (
              <li key={t.request_id}>
                <Link to={`/transfers/${t.request_id}`}>
                  {t.request_id} — {t.transfer_type} — {t.status}
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Card>
      <Alert variant="info">
        Files dropped in agreed S3 prefixes can run automatically via operator-configured rules.
      </Alert>
    </>
  );
}
