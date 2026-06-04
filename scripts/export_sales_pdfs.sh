#!/usr/bin/env bash
# Export BayRelay sales PDFs via pandoc.
# Usage: ./scripts/export_sales_pdfs.sh
# Fallback: writes HTML if PDF engine unavailable.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/sales/pdf"
mkdir -p "$OUT"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "Install pandoc: brew install pandoc" >&2
  exit 1
fi

export_pdf() {
  local src="$1"
  local base="$2"
  local pdf="$OUT/${base}.pdf"
  local html="$OUT/${base}.html"
  if pandoc "$src" -o "$pdf" 2>/dev/null; then
    echo "OK PDF: $pdf"
  else
    pandoc "$src" -o "$html" --standalone
    echo "WARN: PDF failed; wrote HTML: $html (open → Print → Save as PDF)"
  fi
}

export_pdf "$ROOT/docs/sales/BAYRELAY_PROPOSAL_ONE_PAGER.md" "BayRelay_Proposal_One_Pager"
export_pdf "$ROOT/docs/SOW_POC_24K.md" "BayRelay_SOW_PoC_24K"
export_pdf "$ROOT/docs/SOW_PRODUCTION_LAUNCH_42K.md" "BayRelay_SOW_Production_42K"

echo
echo "Done. Attach for PoC outreach:"
echo "  $OUT/BayRelay_Proposal_One_Pager.pdf"
echo "  $OUT/BayRelay_SOW_PoC_24K.pdf"
