#!/usr/bin/env python3
"""Ensure Bedrock agent alias 'prod' exists for the prepared agent version."""

from __future__ import annotations

import argparse
import sys
import time

import boto3
from botocore.exceptions import ClientError


def _wait_agent_prepared(client, agent_id: str, *, attempts: int = 30, sleep_sec: int = 2) -> dict:
    agent = None
    for _ in range(attempts):
        agent = client.get_agent(agentId=agent_id)["agent"]
        if agent.get("agentStatus") == "PREPARED":
            return agent
        if agent.get("agentStatus") == "FAILED":
            break
        time.sleep(sleep_sec)
    status = (agent or {}).get("agentStatus", "unknown")
    print(f"Agent not PREPARED (status={status}) — run prepare_bedrock_agent.py first", file=sys.stderr)
    raise SystemExit(1)


def _latest_numeric_version(client, agent_id: str) -> str | None:
    numeric: list[int] = []
    for summary in client.list_agent_versions(agentId=agent_id, maxResults=25).get(
        "agentVersionSummaries", []
    ):
        version = summary.get("agentVersion", "")
        if version.isdigit():
            numeric.append(int(version))
    return str(max(numeric)) if numeric else None


def _wait_alias_prepared(client, agent_id: str, alias_id: str, *, attempts: int = 30) -> dict:
    alias = None
    for _ in range(attempts):
        alias = client.get_agent_alias(agentId=agent_id, agentAliasId=alias_id)["agentAlias"]
        status = alias.get("agentAliasStatus", "")
        if status == "PREPARED":
            return alias
        if status == "FAILED":
            break
        time.sleep(2)
    status = (alias or {}).get("agentAliasStatus", "unknown")
    print(f"Agent alias not PREPARED (status={status})", file=sys.stderr)
    raise SystemExit(1)


def _ensure_numeric_version(client, agent_id: str) -> str:
    """Return latest numbered agent version, creating one via alias snapshot if needed."""
    version = _latest_numeric_version(client, agent_id)
    if version:
        return version

    # Creating an alias without routingConfiguration snapshots DRAFT into version 1.
    scratch_name = "__bayrelay_version_bootstrap__"
    for summary in client.list_agent_aliases(agentId=agent_id).get("agentAliasSummaries", []):
        if summary.get("agentAliasName") == scratch_name:
            client.delete_agent_alias(
                agentId=agent_id,
                agentAliasId=summary["agentAliasId"],
            )
            time.sleep(2)
            break

    resp = client.create_agent_alias(
        agentId=agent_id,
        agentAliasName=scratch_name,
        description="BayRelay internal bootstrap alias (creates version 1)",
    )
    bootstrap_id = resp["agentAlias"]["agentAliasId"]
    _wait_alias_prepared(client, agent_id, bootstrap_id)
    version = _latest_numeric_version(client, agent_id)
    client.delete_agent_alias(
        agentId=agent_id,
        agentAliasId=bootstrap_id,
    )
    if not version:
        print("Failed to create numbered agent version from prepared DRAFT", file=sys.stderr)
        raise SystemExit(1)
    return version


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--agent-id", required=True)
    p.add_argument("--alias-name", default="prod")
    p.add_argument("--region", required=True)
    args = p.parse_args()

    client = boto3.client("bedrock-agent", region_name=args.region)
    _wait_agent_prepared(client, args.agent_id)
    version = _ensure_numeric_version(client, args.agent_id)

    for summary in client.list_agent_aliases(agentId=args.agent_id).get("agentAliasSummaries", []):
        if summary.get("agentAliasName") != args.alias_name:
            continue
        alias_id = summary["agentAliasId"]
        client.update_agent_alias(
            agentAliasId=alias_id,
            agentId=args.agent_id,
            agentAliasName=args.alias_name,
            routingConfiguration=[{"agentVersion": version}],
        )
        _wait_alias_prepared(client, args.agent_id, alias_id)
        print(alias_id)
        return 0

    try:
        resp = client.create_agent_alias(
            agentId=args.agent_id,
            agentAliasName=args.alias_name,
            description="BayRelay production alias",
            routingConfiguration=[{"agentVersion": version}],
        )
        alias_id = resp["agentAlias"]["agentAliasId"]
        _wait_alias_prepared(client, args.agent_id, alias_id)
        print(alias_id)
        return 0
    except ClientError as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
