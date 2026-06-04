# BayRelay customer demo kit

Attach or link these assets for prospects and PoC buyers.

## PDFs (generate locally)

```bash
./scripts/export_sales_pdfs.sh
```

| File | Use |
|------|-----|
| `docs/sales/pdf/BayRelay_Proposal_One_Pager.pdf` | First email, exec summary |
| `docs/sales/pdf/BayRelay_SOW_PoC_24K.pdf` | Default PoC signature |
| `docs/sales/pdf/BayRelay_SOW_Production_42K.pdf` | Production path |

## Email

- Template: [OUTREACH_EMAIL_POC_DEFAULT.md](OUTREACH_EMAIL_POC_DEFAULT.md)

## Live demo

- Checklist: [CUSTOMER_DEMO_READY.md](../CUSTOMER_DEMO_READY.md)
- Catalog: [DEMO_CATALOG.md](../DEMO_CATALOG.md)
- Prep: `./scripts/prepare_customer_demo.sh`

## Technical leave-behinds

| Asset | Path |
|-------|------|
| Architecture diagram | `docs/bayrelay-architecture.png` |
| Architecture narrative | `docs/ARCHITECTURE.md` |
| Pricing | `docs/PRICING.md` |
| Portal v2 features | `docs/OPERATOR_PORTAL_V2.md` |

## Website

- Copy: [../website/BAYRELAY_MINI_PRODUCT_PAGE.md](../website/BAYRELAY_MINI_PRODUCT_PAGE.md)

## After deploy

```bash
./scripts/customer_handoff.sh
```

Shares portal URL, API endpoint, Cognito client ID, SFTP host (when enabled).
