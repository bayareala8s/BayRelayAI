import os
import time
import uuid
from typing import Any

import boto3

_ddb = boto3.resource("dynamodb")


def _table(name_env: str) -> Any:
    base = os.environ[name_env]
    return _ddb.Table(base)


def partners_table() -> Any:
    return _table("PARTNERS_TABLE")


def endpoints_table() -> Any:
    return _table("ENDPOINTS_TABLE")


def transfer_requests_table() -> Any:
    return _table("TRANSFER_REQUESTS_TABLE")


def transfer_executions_table() -> Any:
    return _table("TRANSFER_EXECUTIONS_TABLE")


def audit_events_table() -> Any:
    return _table("AUDIT_EVENTS_TABLE")


def routing_policies_table() -> Any:
    return _table("ROUTING_POLICIES_TABLE")


def idempotency_keys_table() -> Any:
    return _table("IDEMPOTENCY_KEYS_TABLE")


def onboarding_requests_table() -> Any:
    return _table("ONBOARDING_REQUESTS_TABLE")


def transfer_rules_table() -> Any:
    return _table("TRANSFER_RULES_TABLE")


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def new_id(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:12]}"


def put_audit(
    *,
    correlation_id: str,
    action: str,
    detail: dict[str, Any],
    actor: str = "system",
) -> None:
    aid = new_id("AUD")
    audit_events_table().put_item(
        Item={
            "audit_id": aid,
            "correlation_id": correlation_id,
            "action": action,
            "actor": actor,
            "timestamp": now_iso(),
            "detail": detail,
        }
    )
