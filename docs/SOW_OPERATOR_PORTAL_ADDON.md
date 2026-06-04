# Change Order — BayRelay Operator Portal MVP

**Template for BayAreaLa8s.** Attach to an executed PoC or Production Launch SOW. Customize bracketed fields before signature.

---

## Parties

Same as parent SOW (Provider: BayAreaLa8s; Customer: [Customer legal name]).

**Parent engagement:** [PoC $24k / Production Launch $42k] dated [Date]  
**This Change Order effective:** [Date]

---

## 1. Purpose

Provider will design, build, and deploy a **minimal Operator Portal** (web UI) in Customer’s AWS account. The portal is a **thin client** over the existing BayRelay HTTP API and Cognito — not a replacement control plane.

Technical scope: [OPERATOR_PORTAL_MVP.md](OPERATOR_PORTAL_MVP.md)

---

## 2. Fixed fee

| Item | Amount (USD) |
|------|----------------|
| **Operator Portal MVP** | **$22,000** |
| **Prerequisite** | BayRelay stack deployed and smoke-tested (PoC or Production acceptance) |

**Payment:** 40% on CO signature · 40% on Phase 1 UAT · 20% on final acceptance.

If Customer has **not** completed Production Launch, Provider may bundle portal work after PoC at Provider’s discretion; portal still requires a working API + Cognito.

---

## 3. Included deliverables

| # | Deliverable | Acceptance |
|---|-------------|------------|
| 1 | **Wireframes** | 6 core screens (login, dashboard, transfer detail, submit, agent chat, partners) |
| 2 | **React SPA** | TypeScript, Vite; hosted S3 + CloudFront in Customer account |
| 3 | **Terraform** | `operator_portal` module; `enable_operator_portal` integration |
| 4 | **API extensions** | `GET /v1/transfers` (list recent), `GET /v1/partners` (list) — Option A in OPERATOR_PORTAL_MVP.md |
| 5 | **CORS** | API Gateway configured for portal origin |
| 6 | **Auth** | Uses existing Cognito user pool / app client |
| 7 | **E2E smoke** | Playwright: login → S3→S3 submit → success |
| 8 | **Handoff** | `OPERATOR_PORTAL_RUNBOOK.md` + 1-hour remote session |

---

## 4. Out of scope (unless separate Change Order)

- Partner **self-service** portal (external users)
- Per-partner API keys / OAuth for third parties
- Mobile-native apps
- Provider-hosted SaaS (multi-tenant)
- Custom domain + DNS (v1.1 — quote **$3,500**)
- Streaming agent UI (v1.1 — quote **$5,000**)
- WCAG 2.1 AA certification
- 24/7 support or SLA

---

## 5. Customer responsibilities

1. Parent BayRelay stack **UP** with `http_api_public_endpoint` and Cognito operators.
2. Provide **brand assets** (logo, colors) or accept Provider default theme.
3. Approve wireframes within **5 business days** of delivery.
4. For custom domain: supply ACM-validated DNS names and certificate approval.
5. One **UAT participant** for Phase 1 and final sign-off.

---

## 6. Timeline

| Milestone | Target (business days from CO + prerequisite met) |
|-----------|---------------------------------------------------|
| Kickoff + wireframes | Day 0–5 |
| Phase 1 — login, dashboard, S3→S3 | Day 6–20 |
| Phase 2 — agent chat, partners, list APIs | Day 21–27 |
| Hardening + E2E + handoff | Day 28–32 |

---

## 7. Acceptance

Change Order is **accepted** when:

1. Playwright E2E passes against Customer’s deployed portal URL.
2. S3→S3 transfer submitted from UI reaches **SUCCEEDED**.
3. Agent chat returns a response (no 5xx) for a sample policy question.
4. Handoff session completed.

---

## 8. AWS costs (incremental)

| Resource | Est. monthly |
|----------|----------------|
| S3 + CloudFront (portal) | $5–$30 |
| (API/Lambda unchanged) | — |

Customer pays AWS directly.

---

## 9. Relationship to parent SOW

Parent SOW §2.2 excludes “customer-facing portal UI.” **This Change Order** adds operator-facing UI only. Partner-facing UI remains out of scope unless separately quoted (**from $35,000**).

---

## 10. Optional follow-ons (list prices, not binding)

| SKU | Price (USD) | Summary |
|-----|-------------|---------|
| Portal v1.1 — custom domain | $3,500 | ACM + Route 53 / customer DNS |
| Portal v1.1 — streaming agent | $5,000 | SSE + BFF Lambda |
| Partner self-service MVP | $35,000 | Separate Cognito app, limited partner views |
| Portal + Production bundle | $58,000 | Production Launch $42k + Portal $22k − $6k bundle credit |

---

**Provider:** BayAreaLa8s · [himanshu.bhadra@bayareala8s.com](mailto:himanshu.bhadra@bayareala8s.com) · +1 925-758-1117

**Customer signature:** _________________________ **Date:** _________
