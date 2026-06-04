#!/usr/bin/env python3
"""
Create the vector index Bedrock expects on an OpenSearch Serverless collection.
Uses requests + requests_aws4auth (botocore URLLib3Session PUT signing returns 403 on AOSS).
Install: pip install requests requests-aws4auth (see tests/requirements.txt).
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

import boto3

try:
    import requests
    from requests_aws4auth import AWS4Auth
except ImportError:
    print("Install: pip install requests requests-aws4auth", file=sys.stderr)
    raise


def _put_index(
    *,
    endpoint: str,
    region: str,
    index_name: str,
    dimension: int,
    vector_field: str,
    text_field: str,
    metadata_field: str,
) -> tuple[int, str]:
    base = endpoint.rstrip("/")
    url = f"{base}/{index_name}"
    body: dict[str, Any] = {
        "settings": {"index": {"knn": True}},
        "mappings": {
            "properties": {
                vector_field: {
                    "type": "knn_vector",
                    "dimension": dimension,
                    "method": {
                        "name": "hnsw",
                        "space_type": "l2",
                        "engine": "faiss",
                    },
                },
                text_field: {"type": "text"},
                metadata_field: {"type": "text"},
            }
        },
    }
    session = boto3.Session(region_name=region)
    creds = session.get_credentials()
    if creds is None:
        raise RuntimeError("No AWS credentials")
    auth = AWS4Auth(
        creds.access_key,
        creds.secret_key,
        region,
        "aoss",
        session_token=creds.token,
    )
    r = requests.put(
        url,
        data=json.dumps(body),
        auth=auth,
        headers={"Content-Type": "application/json"},
        timeout=120,
    )
    return r.status_code, r.text


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--endpoint", required=True)
    p.add_argument("--region", required=True)
    p.add_argument("--index-name", default="bedrock-knowledge-base-default-index")
    p.add_argument("--dimension", type=int, default=1536)
    p.add_argument("--vector-field", default="bedrock-knowledge-base-default-vector")
    p.add_argument("--text-field", default="AMAZON_BEDROCK_TEXT_CHUNK")
    p.add_argument("--metadata-field", default="AMAZON_BEDROCK_METADATA")
    args = p.parse_args()

    status, text = _put_index(
        endpoint=args.endpoint,
        region=args.region,
        index_name=args.index_name,
        dimension=args.dimension,
        vector_field=args.vector_field,
        text_field=args.text_field,
        metadata_field=args.metadata_field,
    )
    print(f"aoss_put_index status={status} body={text[:2000]}")
    if status in (200, 201):
        return 0
    if status == 400 and "resource_already_exists_exception" in text.lower():
        return 0
    if status == 400 and "already exists" in text.lower():
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
