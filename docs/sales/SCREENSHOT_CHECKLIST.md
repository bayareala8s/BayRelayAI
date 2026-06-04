# BayRelay screenshot & video checklist

Use after the stack and portal are live:

```bash
./scripts/prepare_customer_demo.sh
# or: ./scripts/bayrelay_demo.sh start --yes && ./scripts/deploy_portal.sh
./scripts/bayrelay_demo.sh status   # copy Operator portal URL
```

Store captures under `docs/sales/screenshots/` using the filenames below.

---

## Capture settings

| Setting | Value |
|---------|--------|
| Resolution | **1920×1080** (or 1440×900) |
| Browser | Chrome or Safari, **100% zoom**, hide bookmarks bar |
| Mode | Portal default (light sidebar) |
| User | Operator: `demo@bayareala8s.com` from `environments/demo.env` |
| Data | At least one partner (e.g. Acme), mixed transfer statuses (SUBMITTED, SUCCEEDED, FAILED) |
| Privacy | No real passwords on screen; blur terminal windows if visible |

**macOS screenshot:** `Cmd + Shift + 4` → spacebar on window, or full screen.  
**Naming:** `bayrelay-NN-short-name.png` (zero-padded: `01`, `02`, …).

---

## Tier 1 — Must-have screenshots (8)

| File | Route | What to show | Used for |
|------|-------|--------------|----------|
| `bayrelay-01-landing.png` | `/` (signed out) | Hero, feature cards, CTAs | Website, GitHub, email |
| `bayrelay-02-operations.png` | `/operations` | **LIVE** badge, KPI tiles, recent transfers | Deck slide 3, one-pager |
| `bayrelay-03-transfers-list.png` | `/transfers` | Search box, status filter, 3+ rows | Product proof |
| `bayrelay-04-transfer-detail.png` | `/transfers/{id}` | **SUCCEEDED** request, payload, correlation ID | Technical buyers |
| `bayrelay-05-new-transfer.png` | `/transfers/new` | Form filled (S3→S3 or S3→SFTP) | “How operators work” |
| `bayrelay-06-automation-rules.png` | `/rules` | 2–3 rules (S3→S3, S3→SFTP, SFTP→S3) | Automation story |
| `bayrelay-07-onboarding-approve.png` | `/onboarding` | Detail panel + approve (or just approved row) | Self-service |
| `bayrelay-08-architecture.png` | — | Copy `docs/bayrelay-architecture.png` → this name | Every architecture slide |

---

## Tier 2 — Supporting screenshots (6)

| File | Route | What to show |
|------|-------|--------------|
| `bayrelay-09-partners.png` | `/partners` | Partner + endpoint tables with search |
| `bayrelay-10-policies.png` | `/policies` | At least one ALLOW policy |
| `bayrelay-11-audit.png` | `/audit` | Several audit rows, optional correlation filter |
| `bayrelay-12-assistant.png` | `/agent` | One policy question + grounded answer |
| `bayrelay-13-partner-home.png` | `/home` | Partner role login — scoped nav + transfers |
| `bayrelay-14-login.png` | `/login` | Hero + sign-in card (BayRelay branding) |

---

## Tier 3 — Optional (technical / depth)

| File | Route / source | Notes |
|------|----------------|--------|
| `bayrelay-15-transfer-retry.png` | `/transfers/{failed-id}` | **Retry** visible on FAILED/CANCELLED |
| `bayrelay-16-sftp-filezilla.png` | FileZilla + portal | Inbound upload → later S3 automation (composite OK) |
| `bayrelay-17-step-functions.png` | AWS Console | One execution graph (no account IDs) |
| `bayrelay-18-github.png` | github.com/bayareala8s/BayRelayAI | README above the fold |

---

## Video plan

### A. Hero reel (60–90 s) — website & social

| Sec | Scene |
|-----|--------|
| 0–5 | Landing `/` |
| 5–15 | Sign in → Operations **LIVE** |
| 15–30 | New transfer → Transfers list updates |
| 30–45 | Automation rules; upload **new** S3 key to trigger rule |
| 45–55 | Assistant — one KB question |
| 55–60 | End card: BayRelay logo + “Deployed in your AWS account” |

Export: `docs/sales/video/bayrelay-hero-90s.mp4` (1080p, 30 fps).

### B. PoC walkthrough (12–15 min) — pre-meeting link

Follow [CUSTOMER_DEMO_READY.md](../CUSTOMER_DEMO_READY.md) in order:

1. Architecture (30 s)  
2. Landing + login (1 min)  
3. Operations (2 min)  
4. Onboarding (2 min)  
5. Manual transfers S3→S3, S3→SFTP (3 min)  
6. Automation + new file (3 min)  
7. Partners / audit / policies (2 min)  
8. Assistant (1 min)  
9. Pricing flash + CTA (30 s)

Export: `docs/sales/video/bayrelay-poc-walkthrough.mp4`.

### C. Feature clips (30–45 s each)

| File | Content |
|------|---------|
| `clip-01-landing-signin.mp4` | Landing → operator sign-in |
| `clip-02-operations.mp4` | Dashboard KPIs + chart toggle |
| `clip-03-transfer-flow.mp4` | Submit → list → detail success |
| `clip-04-automation.mp4` | Rule list + one trigger |
| `clip-05-onboarding.mp4` | Approve application → partner |

Use clips on Wix, LinkedIn, or as GIFs (keep GIFs &lt; 5 MB).

---

## Pre-capture checklist

- [ ] `./scripts/bayrelay_demo.sh status` — stack **UP**
- [ ] `./scripts/bayrelay_demo.sh smoke` — **PASSED** (same day as capture)
- [ ] Portal URL opens landing at `/`
- [ ] Demo operator can sign in; Operations shows **LIVE**
- [ ] At least one **SUCCEEDED** and one **FAILED** transfer for detail/retry shots
- [ ] Automation rules exist; know match patterns for live trigger
- [ ] Browser tab shows BayRelay favicon; close unrelated tabs

---

## After capture

1. Drop PNGs into `docs/sales/screenshots/`.
2. Optional: commit to git (no secrets in images).
3. Embed in Wix from [BAYRELAY_MINI_PRODUCT_PAGE.md](../website/BAYRELAY_MINI_PRODUCT_PAGE.md).
4. Paste hero reel link into outreach email ([OUTREACH_EMAIL_POC_DEFAULT.md](OUTREACH_EMAIL_POC_DEFAULT.md)).
5. Regenerate one-pager PDF if copy changed: `./scripts/export_sales_pdfs.sh`.

---

## Minimum viable (half day)

**4 screenshots:** `01-landing`, `02-operations`, `03-transfers-list`, `06-automation-rules`.  
**1 video:** hero reel (90 s).

Enough for website hero, PoC email, and live-demo backup.
