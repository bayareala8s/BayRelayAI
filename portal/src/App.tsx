import { Navigate, Route, Routes } from "react-router-dom";
import { isLoggedIn } from "./auth";
import { isOperator, useRole } from "./roleContext";
import Layout from "./components/Layout";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import OperationsDashboardPage from "./pages/OperationsDashboardPage";
import TransferDetailPage from "./pages/TransferDetailPage";
import NewTransferPage from "./pages/NewTransferPage";
import AgentPage from "./pages/AgentPage";
import PartnersPage from "./pages/PartnersPage";
import OnboardingPage from "./pages/OnboardingPage";
import OnboardingNewPage from "./pages/OnboardingNewPage";
import TransferRulesPage from "./pages/TransferRulesPage";
import PoliciesPage from "./pages/PoliciesPage";
import AuditPage from "./pages/AuditPage";
import PartnerHomePage from "./pages/PartnerHomePage";
import LandingPage from "./pages/LandingPage";

function RequireAuth({ children }: { children: React.ReactNode }) {
  if (!isLoggedIn()) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

function RequireOperator({ children }: { children: React.ReactNode }) {
  const { role, loading } = useRole();
  if (loading) return null;
  if (!isOperator(role)) return <Navigate to="/home" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route
          path="operations"
          element={
            <RequireOperator>
              <OperationsDashboardPage />
            </RequireOperator>
          }
        />
        <Route path="home" element={<PartnerHomePage />} />
        <Route path="transfers" element={<DashboardPage />} />
        <Route path="transfers/:id" element={<TransferDetailPage />} />
        <Route path="transfers/new" element={<NewTransferPage />} />
        <Route path="agent" element={<AgentPage />} />
        <Route
          path="rules"
          element={
            <RequireOperator>
              <TransferRulesPage />
            </RequireOperator>
          }
        />
        <Route
          path="partners"
          element={
            <RequireOperator>
              <PartnersPage />
            </RequireOperator>
          }
        />
        <Route
          path="policies"
          element={
            <RequireOperator>
              <PoliciesPage />
            </RequireOperator>
          }
        />
        <Route
          path="audit"
          element={
            <RequireOperator>
              <AuditPage />
            </RequireOperator>
          }
        />
        <Route
          path="onboarding"
          element={
            <RequireOperator>
              <OnboardingPage />
            </RequireOperator>
          }
        />
        <Route path="onboarding/new" element={<OnboardingNewPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
