#!/usr/bin/env bash
# Sync local knowledge documents to the per-environment KB source bucket.
# Usage: KB_BUCKET=my-bucket AWS_PROFILE=... ./scripts/kb_sync.sh ./path/to/docs

set -euo pipefail
SRC=${1:?usage: kb_sync.sh <local-docs-dir>}
BUCKET=${KB_BUCKET:?set KB_BUCKET}
aws s3 sync "$SRC" "s3://${BUCKET}/" --sse aws:kms --delete
echo "Synced to s3://${BUCKET}/"
