#!/usr/bin/env bash
# Called by Terraform external data source. Reads JSON on stdin: {"endpoint":"host","port":"22"}.
# Emits JSON on stdout: {"key":"ssh-rsa AAAA..."} (OpenSSH format without hostname prefix).
set -euo pipefail
INPUT="$(cat)"
ENDPOINT="$(echo "$INPUT" | jq -r '.endpoint // empty')"
PORT="$(echo "$INPUT" | jq -r '.port // "22"')"
if [[ -z "$ENDPOINT" ]]; then
  echo "fetch_sftp_trusted_host_key: missing endpoint in stdin JSON" >&2
  exit 1
fi
LINE=""
for attempt in $(seq 1 36); do
  LINE="$(ssh-keyscan -t rsa -p "$PORT" "$ENDPOINT" 2>/dev/null | head -1 || true)"
  if [[ -n "$LINE" ]]; then
    break
  fi
  sleep 10
done
if [[ -z "$LINE" ]]; then
  echo "fetch_sftp_trusted_host_key: ssh-keyscan failed for ${ENDPOINT}:${PORT}" >&2
  exit 1
fi
KEY="$(echo "$LINE" | cut -d' ' -f2-)"
jq -n --arg k "$KEY" '{"key":$k}'
