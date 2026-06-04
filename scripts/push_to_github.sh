#!/usr/bin/env bash
# Create github.com/bayareala8s/BayRelayAI (if needed) and push main.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:bayareala8s/BayRelayAI.git

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if ! gh repo view bayareala8s/BayRelayAI >/dev/null 2>&1; then
    gh repo create BayRelayAI --public \
      --description "Agentic B2B file transfer on AWS — Terraform, API, operator portal" \
      --remote=origin
  fi
  git push -u origin main
  echo "OK: https://github.com/bayareala8s/BayRelayAI"
  exit 0
fi

if [[ -n "${GH_TOKEN:-}" ]]; then
  if ! curl -fsS "https://api.github.com/repos/bayareala8s/BayRelayAI" >/dev/null 2>&1; then
    curl -fsS -X POST -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/user/repos \
      -d '{"name":"BayRelayAI","description":"Agentic B2B file transfer on AWS","private":false}'
    echo
  fi
  git push -u origin main
  echo "OK: https://github.com/bayareala8s/BayRelayAI"
  exit 0
fi

echo "GitHub CLI not authenticated. Run one of:" >&2
echo "  gh auth login && ./scripts/push_to_github.sh" >&2
echo "  GH_TOKEN=<pat> ./scripts/push_to_github.sh" >&2
echo "" >&2
echo "Or create an empty repo at https://github.com/new (name: BayRelayAI) then:" >&2
echo "  git push -u origin main" >&2
exit 1
