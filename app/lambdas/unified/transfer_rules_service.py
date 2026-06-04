"""Transfer automation rules — match S3/SFTP events and auto-submit transfers."""

from __future__ import annotations

import fnmatch
import os
import re
from typing import Any

import ddb
import transfers_service
from bayrelay import errors as err


TRIGGER_S3_OBJECT = "S3_OBJECT_CREATED"
TRIGGER_SFTP_INBOUND = "SFTP_INBOUND_OBJECT"

_SKIP_PREFIXES = ("sftp-staging/",)


def _enabled() -> bool:
    return os.environ.get("ENABLE_TRANSFER_AUTOMATION", "").lower() in ("1", "true", "yes")


def _resolve_endpoints(partner_id: str, transfer_type: str) -> tuple[str | None, str | None]:
    eps = []
    table = ddb.endpoints_table()
    kwargs: dict[str, Any] = {
        "FilterExpression": "partner_id = :p",
        "ExpressionAttributeValues": {":p": partner_id},
    }
    while True:
        page = table.scan(**kwargs)
        eps.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    inbound = [e for e in eps if (e.get("direction") or "").upper() == "INBOUND"]
    outbound = [e for e in eps if (e.get("direction") or "").upper() == "OUTBOUND"]
    if transfer_type == "S3_TO_S3":
        return (
            (outbound[0] or inbound[0] or eps[0] or {}).get("endpoint_id"),
            (inbound[0] or outbound[0] or eps[1] or eps[0] or {}).get("endpoint_id"),
        )
    return (
        (inbound[0] or eps[0] or {}).get("endpoint_id"),
        (outbound[0] or eps[1] or eps[0] or {}).get("endpoint_id"),
    )


def _render(template: Any, variables: dict[str, str]) -> Any:
    if isinstance(template, str):
        out = template
        for k, v in variables.items():
            out = out.replace("{" + k + "}", v)
        return out
    if isinstance(template, dict):
        return {k: _render(v, variables) for k, v in template.items()}
    if isinstance(template, list):
        return [_render(x, variables) for x in template]
    return template


def _match_key(pattern: str, key: str) -> bool:
    pattern = (pattern or "").strip()
    if not pattern:
        return False
    if pattern.endswith("/"):
        return key.startswith(pattern) or fnmatch.fnmatch(key, pattern + "*")
    return fnmatch.fnmatch(key, pattern)


def list_rules(*, partner_id: str | None = None, limit: int = 100) -> dict[str, Any]:
    table = ddb.transfer_rules_table()
    items: list[dict[str, Any]] = []
    if partner_id:
        kwargs: dict[str, Any] = {
            "IndexName": "partner_id-priority",
            "KeyConditionExpression": "partner_id = :p",
            "ExpressionAttributeValues": {":p": partner_id},
            "ScanIndexForward": True,
            "Limit": min(limit, 200),
        }
        while len(items) < limit:
            page = table.query(**kwargs)
            items.extend(page.get("Items", []))
            if "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    else:
        kwargs = {"Limit": min(limit, 200)}
        while len(items) < limit:
            page = table.scan(**kwargs)
            items.extend(page.get("Items", []))
            if len(items) >= limit or "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
        items.sort(key=lambda x: (str(x.get("partner_id") or ""), int(x.get("priority") or 100)))

    return {"ok": True, "status_code": 200, "body": {"rules": items[:limit], "count": len(items[:limit])}}


def get_rule(rule_id: str) -> dict[str, Any]:
    item = ddb.transfer_rules_table().get_item(Key={"rule_id": rule_id}).get("Item")
    if not item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    return {"ok": True, "status_code": 200, "body": {"rule": item}}


def create_rule(body: dict[str, Any]) -> dict[str, Any]:
    partner_id = (body.get("partner_id") or "").strip()
    if not partner_id:
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "partner_id required"},
        }
    transfer_type = (body.get("transfer_type") or "").strip()
    if not transfer_type:
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "transfer_type required"},
        }
    trigger_type = (body.get("trigger_type") or TRIGGER_S3_OBJECT).strip()
    match_pattern = (body.get("match_pattern") or "").strip()
    if not match_pattern:
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "match_pattern required"},
        }

    rule_id = ddb.new_id("RUL")
    now = ddb.now_iso()
    item = {
        "rule_id": rule_id,
        "partner_id": partner_id,
        "enabled": body.get("enabled", True),
        "priority": int(body.get("priority") or 100),
        "name": (body.get("name") or rule_id).strip(),
        "trigger_type": trigger_type,
        "match_pattern": match_pattern,
        "transfer_type": transfer_type,
        "source_endpoint_id": (body.get("source_endpoint_id") or "").strip() or None,
        "target_endpoint_id": (body.get("target_endpoint_id") or "").strip() or None,
        "payload_template": body.get("payload_template") or {},
        "created_at": now,
        "updated_at": now,
    }
    ddb.transfer_rules_table().put_item(Item=item)
    return {"ok": True, "status_code": 201, "body": {"rule": item}}


def update_rule(rule_id: str, body: dict[str, Any]) -> dict[str, Any]:
    table = ddb.transfer_rules_table()
    existing = table.get_item(Key={"rule_id": rule_id}).get("Item")
    if not existing:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}

    for field in (
        "enabled",
        "priority",
        "name",
        "match_pattern",
        "trigger_type",
        "transfer_type",
        "payload_template",
        "source_endpoint_id",
        "target_endpoint_id",
    ):
        if field in body:
            existing[field] = body[field]
    existing["updated_at"] = ddb.now_iso()
    table.put_item(Item=existing)
    return {"ok": True, "status_code": 200, "body": {"rule": existing}}


def delete_rule(rule_id: str) -> dict[str, Any]:
    table = ddb.transfer_rules_table()
    if not table.get_item(Key={"rule_id": rule_id}).get("Item"):
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    table.delete_item(Key={"rule_id": rule_id})
    return {"ok": True, "status_code": 200, "body": {"rule_id": rule_id, "deleted": True}}


def _automation_blocked(key: str) -> bool:
    if key.endswith("/"):
        return True
    return any(key.startswith(p) for p in _SKIP_PREFIXES)


def find_matching_rules(
    *,
    trigger_type: str,
    bucket: str,
    key: str,
) -> list[dict[str, Any]]:
    if not _enabled():
        return []
    if _automation_blocked(key):
        return []

    table = ddb.transfer_rules_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": 200}
    while True:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    matched = []
    for rule in items:
        if not rule.get("enabled", True):
            continue
        if (rule.get("trigger_type") or TRIGGER_S3_OBJECT) != trigger_type:
            continue
        rule_type = str(rule.get("transfer_type") or "")
        if key.startswith("sftp-connector/") and rule_type not in (
            "SFTP_TO_S3",
            "SFTP_TO_SFTP",
        ):
            continue
        if not _match_key(str(rule.get("match_pattern") or ""), key):
            continue
        matched.append(rule)
    matched.sort(key=lambda r: int(r.get("priority") or 100))
    return matched


def execute_rule(
    rule: dict[str, Any],
    *,
    bucket: str,
    key: str,
    correlation_id: str,
) -> dict[str, Any]:
    partner_id = str(rule.get("partner_id") or "")
    transfer_type = str(rule.get("transfer_type") or "")
    src_ep = rule.get("source_endpoint_id")
    tgt_ep = rule.get("target_endpoint_id")
    if not src_ep or not tgt_ep:
        src_ep, tgt_ep = _resolve_endpoints(partner_id, transfer_type)
    if not src_ep or not tgt_ep:
        return {
            "ok": False,
            "error": "endpoints not configured for partner",
            "rule_id": rule.get("rule_id"),
        }

    basename = key.split("/")[-1]
    variables = {
        "bucket": bucket,
        "key": key,
        "basename": basename,
        "partner_id": partner_id,
        "stem": basename.rsplit(".", 1)[0] if "." in basename else basename,
    }
    payload = _render(rule.get("payload_template") or {}, variables)
    if transfer_type in ("S3_TO_S3", "S3_TO_SFTP") and not payload.get("source_bucket"):
        payload.setdefault("source_bucket", bucket)
        payload.setdefault("source_key", key)
    if transfer_type == "SFTP_TO_S3":
        if not payload.get("remote_paths"):
            payload["remote_paths"] = [f"/{basename}"]
        payload.setdefault("dest_bucket", bucket)
    if transfer_type == "SFTP_TO_SFTP":
        if not payload.get("remote_source_paths"):
            payload["remote_source_paths"] = [f"/{basename}"]
        payload.setdefault("remote_dest_directory", "/")

    idem = f"auto-{rule.get('rule_id')}-{re.sub(r'[^a-zA-Z0-9_-]', '_', key)}"[:128]
    body = {
        "partner_id": partner_id,
        "source_endpoint_id": src_ep,
        "target_endpoint_id": tgt_ep,
        "transfer_type": transfer_type,
        "operator_summary": f"auto:{rule.get('name') or rule.get('rule_id')}",
        "payload": payload,
    }
    result = transfers_service.submit_transfer(
        body=body,
        correlation_id=correlation_id,
        idempotency_key=idem,
    )
    return {"ok": result.get("ok"), "rule_id": rule.get("rule_id"), "result": result}


def dispatch_object_event(
    *,
    bucket: str,
    key: str,
    trigger_type: str,
    correlation_id: str,
) -> dict[str, Any]:
    rules = find_matching_rules(trigger_type=trigger_type, bucket=bucket, key=key)
    outcomes = []
    for rule in rules:
        outcomes.append(execute_rule(rule, bucket=bucket, key=key, correlation_id=correlation_id))
    return {"ok": True, "matched": len(rules), "outcomes": outcomes}
