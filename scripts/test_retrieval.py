#!/usr/bin/env python3
"""
Smoke-test Bedrock Knowledge Base Retrieve / RetrieveAndGenerate (Phase 3).
Environment: KNOWLEDGE_BASE_ID, AWS_REGION; optional MODEL_ARN, KB_TEST_QUERY.
CLI: --expect-substring (if set, exit 2 when no chunk/text contains it, case-insensitive).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import boto3


def _flatten_chunks(results: list) -> str:
    parts: list[str] = []
    for item in results:
        loc = item.get("location", {}) or {}
        if "s3Location" in loc:
            parts.append(json.dumps(loc["s3Location"]))
        content = item.get("content", {}) or {}
        text = content.get("text", "")
        if text:
            parts.append(text)
    return "\n".join(parts)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--expect-substring", default=os.environ.get("KB_EXPECT_SUBSTRING"), help="Require this text in a retrieved chunk")
    p.add_argument("--region", default=os.environ.get("AWS_REGION"))
    args = p.parse_args()

    kb_id = os.environ.get("KNOWLEDGE_BASE_ID")
    region = args.region or "us-east-1"
    if not kb_id:
        print("Set KNOWLEDGE_BASE_ID", file=sys.stderr)
        return 1
    client = boto3.client("bedrock-agent-runtime", region_name=region)
    q = os.environ.get("KB_TEST_QUERY", "What is the retry policy for checksum failures?")
    r = client.retrieve(
        knowledgeBaseId=kb_id,
        retrievalQuery={"text": q},
        retrievalConfiguration={"vectorSearchConfiguration": {"numberOfResults": 8}},
    )
    results = r.get("retrievalResults", []) or []
    print("retrieve (first chunks):", json.dumps(results[:2], default=str)[:2000])
    combined = _flatten_chunks(results)
    if args.expect_substring:
        if args.expect_substring.lower() not in combined.lower():
            print(
                f"FAIL: expected substring not found in retrieval payload: {args.expect_substring!r}",
                file=sys.stderr,
            )
            return 2
    model_arn = os.environ.get("MODEL_ARN")
    if model_arn:
        rg = client.retrieve_and_generate(
            input={"text": q},
            retrieveAndGenerateConfiguration={
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": {
                    "knowledgeBaseId": kb_id,
                    "modelArn": model_arn,
                },
            },
        )
        text = rg.get("output", {}).get("text", "") or ""
        print("retrieve_and_generate output:", text[:800])
        if args.expect_substring and args.expect_substring.lower() not in text.lower():
            print("FAIL: expect_substring not in generated answer", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
