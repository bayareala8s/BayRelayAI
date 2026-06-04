# Export proposal & SOW PDFs

Generate signature-ready PDFs from the repo (macOS).

## Prerequisites

```bash
brew install pandoc basictex   # or mactex-no-gui for smaller install
# Restart terminal, then:
```

## One-command export (repo root)

```bash
./scripts/export_sales_pdfs.sh
```

Outputs in **`docs/sales/pdf/`**:

| File | Source |
|------|--------|
| `BayRelay_Proposal_One_Pager.pdf` | `BAYRELAY_PROPOSAL_ONE_PAGER.md` |
| `BayRelay_SOW_PoC_24K.pdf` | `../SOW_POC_24K.md` |
| `BayRelay_SOW_Production_42K.pdf` | `../SOW_PRODUCTION_LAUNCH_42K.md` |

## Manual (if script fails)

```bash
cd docs/sales
mkdir -p pdf
pandoc BAYRELAY_PROPOSAL_ONE_PAGER.md -o pdf/BayRelay_Proposal_One_Pager.pdf
pandoc ../SOW_POC_24K.md -o pdf/BayRelay_SOW_PoC_24K.pdf
pandoc ../SOW_PRODUCTION_LAUNCH_42K.md -o pdf/BayRelay_SOW_Production_42K.pdf
```

## HTML fallback (no LaTeX)

```bash
pandoc BAYRELAY_PROPOSAL_ONE_PAGER.md -o pdf/BayRelay_Proposal_One_Pager.html --standalone
# Open in browser → Print → Save as PDF
```

## Default outreach bundle

Attach to first email ([OUTREACH_EMAIL_POC_DEFAULT.md](OUTREACH_EMAIL_POC_DEFAULT.md)):

1. `BayRelay_Proposal_One_Pager.pdf`  
2. `BayRelay_SOW_PoC_24K.pdf`

Optional: add `bayrelay-architecture.png` inline or as third attachment.
