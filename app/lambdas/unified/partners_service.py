"""Partner registry CRUD."""

from __future__ import annotations

from typing import Any

import ddb
from bayrelay import errors as err


def get_partner(partner_id: str) -> dict[str, Any]:
    item = ddb.partners_table().get_item(Key={"partner_id": partner_id}).get("Item")
    if not item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    return {"ok": True, "status_code": 200, "body": {"partner": item}}


def update_partner(partner_id: str, body: dict[str, Any]) -> dict[str, Any]:
    table = ddb.partners_table()
    existing = table.get_item(Key={"partner_id": partner_id}).get("Item")
    if not existing:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    for field in ("name", "metadata", "status"):
        if field in body and body[field] is not None:
            existing[field] = body[field]
    existing["updated_at"] = ddb.now_iso()
    table.put_item(Item=existing)
    return {"ok": True, "status_code": 200, "body": {"partner": existing}}


def delete_partner(partner_id: str) -> dict[str, Any]:
    return update_partner(partner_id, {"status": "DISABLED"})
