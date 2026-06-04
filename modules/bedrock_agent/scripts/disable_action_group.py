#!/usr/bin/env python3
"""Disable a Bedrock Agent draft action group so Terraform can delete it (409 if still ENABLED)."""
from __future__ import annotations

import argparse
import copy
import sys

import boto3
from botocore.exceptions import ClientError


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--region", required=True)
    p.add_argument("--agent-id", required=True)
    p.add_argument("--action-group-id", required=True)
    args = p.parse_args()
    client = boto3.client("bedrock-agent", region_name=args.region)
    try:
        got = client.get_agent_action_group(
            agentId=args.agent_id,
            agentVersion="DRAFT",
            actionGroupId=args.action_group_id,
        )["agentActionGroup"]
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code in ("ResourceNotFoundException", "ValidationException"):
            return 0
        raise

    # State-only updates are ignored; send back executor + schema from Get.
    payload = {
        "agentId": args.agent_id,
        "agentVersion": "DRAFT",
        "actionGroupId": args.action_group_id,
        "actionGroupName": got["actionGroupName"],
        "actionGroupState": "DISABLED",
    }
    if got.get("description"):
        payload["description"] = got["description"]
    if got.get("parentActionGroupSignature"):
        payload["parentActionGroupSignature"] = got["parentActionGroupSignature"]
    if got.get("parentActionGroupSignatureParams"):
        payload["parentActionGroupSignatureParams"] = copy.deepcopy(got["parentActionGroupSignatureParams"])
    if got.get("actionGroupExecutor"):
        payload["actionGroupExecutor"] = copy.deepcopy(got["actionGroupExecutor"])
    if got.get("apiSchema"):
        payload["apiSchema"] = copy.deepcopy(got["apiSchema"])
    if got.get("functionSchema"):
        payload["functionSchema"] = copy.deepcopy(got["functionSchema"])

    try:
        client.update_agent_action_group(**payload)
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code in ("ResourceNotFoundException", "ValidationException"):
            return 0
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
