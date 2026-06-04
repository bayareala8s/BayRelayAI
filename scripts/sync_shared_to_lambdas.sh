#!/usr/bin/env bash
# Copy app/shared/bayrelay into app/lambdas/unified/bayrelay after editing shared code.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rsync -a --delete "$ROOT/app/shared/bayrelay/" "$ROOT/app/lambdas/unified/bayrelay/"
echo "Synced bayrelay package into Lambda bundle."
