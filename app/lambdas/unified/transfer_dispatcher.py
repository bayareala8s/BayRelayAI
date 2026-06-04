"""EventBridge dispatcher — evaluate transfer rules and auto-submit transfers."""

from __future__ import annotations

import os
import uuid
from typing import Any
from urllib.parse import unquote_plus

import ddb
import transfer_rules_service
from bayrelay.logging_util import setup_logging, structured_log

setup_logging()


def _enabled() -> bool:
    return os.environ.get("ENABLE_TRANSFER_AUTOMATION", "").lower() in ("1", "true", "yes")


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    if not _enabled():
        return {"ok": True, "skipped": "automation disabled"}

    detail = event.get("detail") or {}
    bucket = (detail.get("bucket") or {}).get("name") or ""
    raw_key = (detail.get("object") or {}).get("key") or ""
    key = unquote_plus(raw_key) if raw_key else ""
    correlation_id = f"auto-{uuid.uuid4().hex[:12]}"

    structured_log(message="transfer_dispatcher_event", bucket=bucket, key=key)

    if not bucket or not key:
        return {"ok": False, "message": "missing bucket or key"}

    default_bucket = (os.environ.get("TRANSFER_DATA_BUCKET") or "").strip()
    if default_bucket and bucket != default_bucket:
        return {"ok": True, "skipped": "foreign bucket"}

    trigger = transfer_rules_service.TRIGGER_S3_OBJECT
    if key.startswith("sftp-inbound/"):
        trigger = transfer_rules_service.TRIGGER_SFTP_INBOUND

    out = transfer_rules_service.dispatch_object_event(
        bucket=bucket,
        key=key,
        trigger_type=trigger,
        correlation_id=correlation_id,
    )

    if out.get("matched", 0) > 0:
        ddb.put_audit(
            correlation_id=correlation_id,
            action="transfer_automation_dispatched",
            actor="transfer_dispatcher",
            detail={"bucket": bucket, "key": key, "outcomes": out.get("outcomes")},
        )

    return out
