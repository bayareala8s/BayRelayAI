"""Endpoint registry CRUD."""

from __future__ import annotations

from typing import Any

import ddb
from bayrelay import errors as err

_ALLOWED_PROTOCOL = frozenset({"S3", "SFTP"})
_ALLOWED_DIRECTION = frozenset({"INBOUND", "OUTBOUND"})


def get_endpoint(endpoint_id: str) -> dict[str, Any]:
    item = ddb.endpoints_table().get_item(Key={"endpoint_id": endpoint_id}).get("Item")
    if not item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    return {"ok": True, "status_code": 200, "body": {"endpoint": item}}


def update_endpoint(endpoint_id: str, body: dict[str, Any]) -> dict[str, Any]:
    table = ddb.endpoints_table()
    existing = table.get_item(Key={"endpoint_id": endpoint_id}).get("Item")
    if not existing:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    if "protocol" in body:
        p = str(body["protocol"] or "").upper()
        if p not in _ALLOWED_PROTOCOL:
            return {
                "ok": False,
                "status_code": 400,
                "body": {"error": err.VALIDATION_ERROR, "message": "invalid protocol"},
            }
        existing["protocol"] = p
    if "direction" in body:
        d = str(body["direction"] or "").upper()
        if d not in _ALLOWED_DIRECTION:
            return {
                "ok": False,
                "status_code": 400,
                "body": {"error": err.VALIDATION_ERROR, "message": "invalid direction"},
            }
        existing["direction"] = d
    for field in ("config_ref", "status"):
        if field in body:
            existing[field] = body[field]
    existing["updated_at"] = ddb.now_iso()
    table.put_item(Item=existing)
    return {"ok": True, "status_code": 200, "body": {"endpoint": existing}}


def delete_endpoint(endpoint_id: str) -> dict[str, Any]:
    return update_endpoint(endpoint_id, {"status": "DISABLED"})
