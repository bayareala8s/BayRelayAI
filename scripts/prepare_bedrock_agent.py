#!/usr/bin/env python3
"""Call Bedrock Agents PrepareAgent after knowledge-base or action-group changes."""

from __future__ import annotations

import argparse
import sys
import time

import boto3
from botocore.exceptions import ClientError


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--agent-id", required=True)
    p.add_argument("--region", default=None)
    p.add_argument("--wait", action="store_true", help="Poll until agent draft is PREPARED or timeout")
    p.add_argument("--timeout-sec", type=int, default=600)
    args = p.parse_args()
    region = args.region or boto3.session.Session().region_name
    if not region:
        print("Set --region or AWS_REGION", file=sys.stderr)
        return 1
    client = boto3.client("bedrock-agent", region_name=region)
    try:
        client.prepare_agent(agentId=args.agent_id)
    except ClientError as e:
        print(e, file=sys.stderr)
        return 1
    if not args.wait:
        print("prepare_agent accepted for", args.agent_id)
        return 0
    deadline = time.monotonic() + args.timeout_sec
    while time.monotonic() < deadline:
        resp = client.get_agent(agentId=args.agent_id)
        agent = resp.get("agent", {})
        status = agent.get("agentStatus", "")
        print("agentStatus=", status, sep="")
        if status == "FAILED":
            return 2
        if status == "PREPARED":
            return 0
        time.sleep(5)
    print("Timeout waiting for PREPARED", file=sys.stderr)
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
