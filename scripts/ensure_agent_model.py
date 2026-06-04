#!/usr/bin/env python3
"""Sync Bedrock agent foundation model and verify InvokeAgent works."""

from __future__ import annotations

import argparse
import pathlib
import sys
import time

import boto3
from botocore.exceptions import ClientError


def _invoke_smoke(runtime, agent_id: str, alias_id: str) -> str:
    resp = runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId=alias_id,
        sessionId="ensure-agent-model-smoke",
        inputText="Reply with exactly: OK",
    )
    text = ""
    for event in resp.get("completion", []):
        if "chunk" in event and "bytes" in event["chunk"]:
            text += event["chunk"]["bytes"].decode("utf-8", errors="replace")
    return text.strip()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--agent-id", required=True)
    p.add_argument("--model", required=True)
    p.add_argument("--region", required=True)
    p.add_argument("--alias-id", default="TSTALIASID")
    p.add_argument("--prepare", action="store_true")
    args = p.parse_args()

    agent_client = boto3.client("bedrock-agent", region_name=args.region)
    runtime = boto3.client("bedrock-agent-runtime", region_name=args.region)

    agent = agent_client.get_agent(agentId=args.agent_id)["agent"]
    current = agent.get("foundationModel", "")
    role_arn = agent["agentResourceRoleArn"]
    name = agent["agentName"]

    instruction_path = (
        pathlib.Path(__file__).resolve().parent.parent
        / "modules/bedrock_agent/instruction.txt"
    )
    instruction = instruction_path.read_text(encoding="utf-8")

    if current != args.model or agent.get("agentStatus") == "FAILED":
        if current != args.model:
            print(f"Updating agent model: {current} -> {args.model}")
        else:
            print("Re-applying agent instruction (agent was FAILED)")
        agent_client.update_agent(
            agentId=args.agent_id,
            agentName=name,
            foundationModel=args.model if current != args.model else current,
            agentResourceRoleArn=role_arn,
            instruction=instruction,
        )
        args.prepare = True

    if args.prepare:
        agent_client.prepare_agent(agentId=args.agent_id)
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            st = agent_client.get_agent(agentId=args.agent_id)["agent"]["agentStatus"]
            print("agentStatus=", st, sep="")
            if st == "PREPARED":
                break
            if st == "FAILED":
                print("Agent prepare FAILED", file=sys.stderr)
                return 1
            time.sleep(3)

    try:
        out = _invoke_smoke(runtime, args.agent_id, args.alias_id)
        print("InvokeAgent smoke OK:", out[:120])
        return 0
    except ClientError as e:
        print("InvokeAgent failed:", e, file=sys.stderr)
        print(
            "Enable model access in Bedrock console (Model access) for:",
            args.model,
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
