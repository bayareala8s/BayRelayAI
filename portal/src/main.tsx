import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { RoleProvider } from "./roleContext";
import { getPortalConfig } from "./config";
import "./index.css";

const root = document.getElementById("root")!;

try {
  getPortalConfig();
  createRoot(root).render(
    <StrictMode>
      <BrowserRouter>
        <RoleProvider>
          <App />
        </RoleProvider>
      </BrowserRouter>
    </StrictMode>,
  );
} catch (err) {
  const msg = err instanceof Error ? err.message : "Portal failed to start";
  root.innerHTML = `<div style="font-family:Inter,system-ui,sans-serif;padding:2rem;max-width:480px;color:#0f172a;background:#f4f6f9;min-height:100vh"><h2 style="font-weight:600">BayRelay</h2><p style="color:#b91c1c;font-size:0.9375rem">${msg}</p></div>`;
}
