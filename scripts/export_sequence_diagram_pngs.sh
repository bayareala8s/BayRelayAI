#!/usr/bin/env bash
# Export all Mermaid sequence diagrams from docs/SEQUENCE_DIAGRAMS.md to PNG.
# Usage: ./scripts/export_sequence_diagram_pngs.sh
#
# Prefers local mermaid-cli (scripts/node-tools). Installs on first run if npm is available.
# Falls back to mermaid.ink when mmdc is not installed.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/scripts/node-tools"

MMDC="$TOOLS/node_modules/.bin/mmdc"
if [[ ! -x "$MMDC" ]]; then
  if command -v npm >/dev/null 2>&1; then
    echo "Installing @mermaid-js/mermaid-cli in scripts/node-tools ..."
    PUPPETEER_SKIP_DOWNLOAD=true npm install --prefix "$TOOLS"
  else
    echo "WARN: npm not found; will try mermaid.ink API fallback" >&2
  fi
fi

if [[ -x "$MMDC" ]]; then
  for chrome in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    if [[ -x "$chrome" ]]; then
      export PUPPETEER_EXECUTABLE_PATH="$chrome"
      break
    fi
  done
fi

exec python3 "$ROOT/scripts/export_sequence_diagram_pngs.py"
