#!/usr/bin/env bash
# Refresh Transfer Family connector trusted host keys after SFTP server recreate/redeploy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/stack_lib.sh
source "$SCRIPT_DIR/stack_lib.sh"
bayrelay_resolve_aws_region >/dev/null
bayrelay_prepend_venv

PY="${BAYRELAY_ROOT}/.venv/bin/python3"
[[ -x "$PY" ]] || PY=python3

CONNECTOR_ID="$(bayrelay_tf_raw transfer_connector_id)"
ENDPOINT="$(bayrelay_tf_raw sftp_server_endpoint)"
if [[ -z "$CONNECTOR_ID" || "$CONNECTOR_ID" == "null" || -z "$ENDPOINT" || "$ENDPOINT" == "null" ]]; then
  echo "SKIP: transfer connector or SFTP endpoint not in stack outputs." >&2
  exit 0
fi

echo "==> Syncing connector $CONNECTOR_ID trusted host key for $ENDPOINT"
"$PY" - "$CONNECTOR_ID" "$ENDPOINT" "${AWS_REGION:-us-west-2}" "$BAYRELAY_ROOT" <<'PY'
import json, subprocess, sys
import boto3

connector_id, endpoint, region, root = sys.argv[1:5]
key_json = subprocess.check_output(
    ["bash", f"{root}/modules/transfer_family/fetch_sftp_trusted_host_key.sh"],
    input=json.dumps({"endpoint": endpoint, "port": "22"}),
    text=True,
)
host_key = json.loads(key_json)["key"]
c = boto3.client("transfer", region_name=region)
conn = c.describe_connector(ConnectorId=connector_id)["Connector"]
secret = conn["SftpConfig"]["UserSecretId"]
c.update_connector(
    ConnectorId=connector_id,
    SftpConfig={"UserSecretId": secret, "TrustedHostKeys": [host_key]},
)
updated = c.describe_connector(ConnectorId=connector_id)["Connector"]["SftpConfig"].get(
    "TrustedHostKeys", []
)
if not updated or updated[0] != host_key:
    print("FAIL: connector trusted host key did not persist after update", file=sys.stderr)
    sys.exit(1)
print(f"OK: connector {connector_id} trusted host key updated")
PY
