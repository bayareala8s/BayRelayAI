#!/usr/bin/env python3
"""Start a Bedrock Knowledge Base ingestion job and optionally wait for completion."""

from __future__ import annotations

import argparse
import sys
import time

import boto3
from botocore.exceptions import ClientError


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--knowledge-base-id", required=True)
    p.add_argument("--data-source-id", required=True)
    p.add_argument("--region", default=None)
    p.add_argument("--wait", action="store_true")
    p.add_argument("--timeout-sec", type=int, default=1800)
    args = p.parse_args()
    region = args.region or boto3.session.Session().region_name
    if not region:
        print("Set --region or AWS_REGION", file=sys.stderr)
        return 1
    client = boto3.client("bedrock-agent", region_name=region)
    try:
        out = client.start_ingestion_job(
            knowledgeBaseId=args.knowledge_base_id,
            dataSourceId=args.data_source_id,
        )
    except ClientError as e:
        print(e, file=sys.stderr)
        return 1
    job_id = out.get("ingestionJob", {}).get("ingestionJobId", "")
    print("ingestion_job_id=", job_id, sep="")
    if not args.wait or not job_id:
        return 0
    deadline = time.monotonic() + args.timeout_sec
    while time.monotonic() < deadline:
        job = client.get_ingestion_job(
            knowledgeBaseId=args.knowledge_base_id,
            dataSourceId=args.data_source_id,
            ingestionJobId=job_id,
        ).get("ingestionJob", {})
        status = job.get("status", "")
        print("ingestion_status=", status, sep="")
        if status in ("COMPLETE", "FAILED", "STOPPED"):
            return 0 if status == "COMPLETE" else 2
        time.sleep(10)
    print("Timeout waiting for ingestion", file=sys.stderr)
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
