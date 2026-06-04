#!/usr/bin/env bash
# Regenerate portal PNG from bayrelay-icon.svg (MerchantOS-style chevron mark).
# Reference: https://dis5hqod6s1g8.cloudfront.net/merchantos-icon.png
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT/portal/public/bayrelay-icon.svg"
PNG="$ROOT/portal/public/bayrelay-icon.png"
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Install librsvg: brew install librsvg" >&2
  exit 1
fi
rsvg-convert -w 512 -h 512 "$SVG" -o "$PNG"
echo "Wrote $PNG ($(wc -c < "$PNG" | tr -d ' ') bytes)"
