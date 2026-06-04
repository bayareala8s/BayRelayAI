#!/usr/bin/env python3
"""Ensure Bedrock agent alias 'prod' exists for the prepared agent version."""

from __future__ import annotations

import argparse
import sys
import time

import boto3
from botocore.exceptions import ClientError


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--agent-id", required=True)
    p.add_argument("--alias-name", default="prod")
    p.add_argument("--region", required=True)
    args = p.parse_args()

    client = boto3.client("bedrock-agent", region_name=args.region)
    agent = None
    for _ in range(20):
        agent = client.get_agent(agentId=args.agent_id)["agent"]
        if agent.get("agentStatus") == "PREPARED":
            break
        time.sleep(2)
    if not agent or agent.get("agentStatus") != "PREPARED":
        print("Agent not PREPARED — run prepare_bedrock_agent.py first", file=sys.stderr)
        return 1
    version = agent.get("agentVersion")
    if not version or version == "DRAFT":
        numeric = []
        for summary in client.list_agent_versions(agentId=args.agent_id, maxResults=25).get(
            "agentVersionSummaries", []
        ):
            v = summary.get("agentVersion", "")
            if v.isdigit():
                numeric.append(int(v))
        version = str(max(numeric)) if numeric else None
    if not version:
        print("No prepared agent version found", file=sys.stderr)
        return 1

    for summary in client.list_agent_aliases(agentId=args.agent_id).get("agentAliasSummaries", []):
        if summary.get("agentAliasName") == args.alias_name:
            alias_id = summary["agentAliasId"]
            client.update_agent_alias(
                agentAliasId=alias_id,
                agentId=args.agent_id,
                agentAliasName=args.alias_name,
                routingConfiguration=[{"agentVersion": version}],
            )
            print(alias_id)
            return 0

    try:
        resp = client.create_agent_alias(
            agentId=args.agent_id,
            agentAliasName=args.alias_name,
            description="BayRelay production alias",
            routingConfiguration=[{"agentVersion": version}],
        )
        print(resp["agentAlias"]["agentAliasId"])
        return 0
    except ClientError as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
