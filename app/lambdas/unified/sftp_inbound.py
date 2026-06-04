"""S3 EventBridge → audit when partner uploads via Transfer Family (inbound prefix)."""

from __future__ import annotations

import urllib.parse
from typing import Any

import ddb
from bayrelay.logging_util import setup_logging, structured_log

setup_logging()


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    detail = event.get("detail") or {}
    bucket = (detail.get("bucket") or {}).get("name")
    raw_key = (detail.get("object") or {}).get("key")
    size = (detail.get("object") or {}).get("size")
    key = urllib.parse.unquote_plus(raw_key) if raw_key else ""

    structured_log(
        message="sftp_inbound_s3_event",
        bucket=bucket,
        key=key,
        size=size,
    )

    if bucket and key:
        ddb.put_audit(
            correlation_id=f"s3evt-{bucket}",
            action="sftp_inbound_object_created",
            detail={
                "bucket": bucket,
                "key": key,
                "size": size,
                "reason": detail.get("reason"),
            },
        )

    return {"ok": True, "bucket": bucket, "key": key}
