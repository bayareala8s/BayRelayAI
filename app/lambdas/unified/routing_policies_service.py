"""Routing policy CRUD (partner-scoped allow/deny)."""

from __future__ import annotations

from typing import Any

import ddb
from bayrelay import errors as err


def list_policies(*, partner_id: str | None = None, limit: int = 100) -> dict[str, Any]:
    table = ddb.routing_policies_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": min(limit, 200)}
    if partner_id:
        kwargs["FilterExpression"] = "partner_id = :p"
        kwargs["ExpressionAttributeValues"] = {":p": partner_id}
    while len(items) < limit:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if len(items) >= limit or "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    return {"ok": True, "status_code": 200, "body": {"policies": items[:limit], "count": len(items[:limit])}}


def get_policy(policy_id: str, partner_id: str) -> dict[str, Any]:
    item = (
        ddb.routing_policies_table()
        .get_item(Key={"policy_id": policy_id, "partner_id": partner_id})
        .get("Item")
    )
    if not item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    return {"ok": True, "status_code": 200, "body": {"policy": item}}


def create_policy(body: dict[str, Any]) -> dict[str, Any]:
    partner_id = (body.get("partner_id") or "").strip()
    if not partner_id:
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "partner_id required"},
        }
    policy_id = (body.get("policy_id") or "default").strip() or "default"
    effect = str(body.get("effect") or "ALLOW").upper()
    if effect not in ("ALLOW", "DENY"):
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "effect must be ALLOW or DENY"},
        }
    now = ddb.now_iso()
    item = {
        "policy_id": policy_id,
        "partner_id": partner_id,
        "effect": effect,
        "description": (body.get("description") or "").strip(),
        "created_at": now,
        "updated_at": now,
    }
    ddb.routing_policies_table().put_item(Item=item)
    return {"ok": True, "status_code": 201, "body": {"policy": item}}


def update_policy(policy_id: str, partner_id: str, body: dict[str, Any]) -> dict[str, Any]:
    table = ddb.routing_policies_table()
    existing = table.get_item(Key={"policy_id": policy_id, "partner_id": partner_id}).get("Item")
    if not existing:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    if "effect" in body:
        effect = str(body["effect"]).upper()
        if effect not in ("ALLOW", "DENY"):
            return {
                "ok": False,
                "status_code": 400,
                "body": {"error": err.VALIDATION_ERROR, "message": "effect must be ALLOW or DENY"},
            }
        existing["effect"] = effect
    if "description" in body:
        existing["description"] = body["description"]
    existing["updated_at"] = ddb.now_iso()
    table.put_item(Item=existing)
    return {"ok": True, "status_code": 200, "body": {"policy": existing}}


def delete_policy(policy_id: str, partner_id: str) -> dict[str, Any]:
    table = ddb.routing_policies_table()
    if not table.get_item(Key={"policy_id": policy_id, "partner_id": partner_id}).get("Item"):
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    table.delete_item(Key={"policy_id": policy_id, "partner_id": partner_id})
    return {
        "ok": True,
        "status_code": 200,
        "body": {"policy_id": policy_id, "partner_id": partner_id, "deleted": True},
    }
