"""Self-service customer (partner) onboarding — submit, review, approve."""

from __future__ import annotations

import logging
import os
from typing import Any

import boto3
import ddb
from bayrelay import errors as err

_COGNITO = boto3.client("cognito-idp")
PARTNER_GROUP = "bayrelay-partners"
logger = logging.getLogger(__name__)


def _auto_approve_enabled() -> bool:
    return os.environ.get("ONBOARDING_AUTO_APPROVE", "").lower() in ("1", "true", "yes")


def _default_endpoints() -> list[dict[str, str]]:
    return [
        {"protocol": "S3", "direction": "OUTBOUND"},
        {"protocol": "S3", "direction": "INBOUND"},
    ]


def create_request(*, body: dict[str, Any], submitted_by: str) -> dict[str, Any]:
    company_name = (body.get("company_name") or body.get("name") or "").strip()
    if not company_name:
        return {
            "ok": False,
            "status_code": 400,
            "body": {"error": err.VALIDATION_ERROR, "message": "company_name required"},
        }

    contact_email = (body.get("contact_email") or "").strip()
    endpoints = body.get("endpoints") or _default_endpoints()
    if not isinstance(endpoints, list) or not endpoints:
        endpoints = _default_endpoints()

    normalized_eps: list[dict[str, str]] = []
    for ep in endpoints:
        if not isinstance(ep, dict):
            continue
        protocol = (ep.get("protocol") or "S3").strip().upper()
        direction = (ep.get("direction") or "OUTBOUND").strip().upper()
        if direction not in ("INBOUND", "OUTBOUND") or protocol not in ("S3", "SFTP"):
            return {
                "ok": False,
                "status_code": 400,
                "body": {
                    "error": err.VALIDATION_ERROR,
                    "message": "invalid endpoint protocol or direction",
                },
            }
        normalized_eps.append({"protocol": protocol, "direction": direction})

    if not normalized_eps:
        normalized_eps = _default_endpoints()

    request_id = ddb.new_id("ONB")
    now = ddb.now_iso()
    item = {
        "request_id": request_id,
        "status": "SUBMITTED",
        "company_name": company_name,
        "contact_email": contact_email,
        "notes": (body.get("notes") or "").strip(),
        "transfer_types": body.get("transfer_types") or ["S3_TO_S3"],
        "endpoints": normalized_eps,
        "submitted_by": submitted_by,
        "submitted_at": now,
        "updated_at": now,
        "partner_id": None,
        "rejection_reason": None,
    }
    ddb.onboarding_requests_table().put_item(Item=item)
    ddb.put_audit(
        action="onboarding_submitted",
        correlation_id=request_id,
        actor=submitted_by,
        detail={"request_id": request_id, "company_name": company_name},
    )

    if _auto_approve_enabled():
        approved = approve_request(
            request_id=request_id,
            reviewer="system-auto-approve",
            body={},
        )
        if approved.get("ok"):
            refreshed = (
                ddb.onboarding_requests_table().get_item(Key={"request_id": request_id}).get("Item")
                or item
            )
            return {
                "ok": True,
                "status_code": 201,
                "body": {
                    "onboarding_request": refreshed,
                    "auto_approved": True,
                    "partner_id": approved["body"].get("partner_id"),
                    "endpoint_ids": approved["body"].get("endpoint_ids"),
                },
            }

    return {"ok": True, "status_code": 201, "body": {"onboarding_request": item}}


def list_requests(*, status: str | None = None, limit: int = 50) -> dict[str, Any]:
    table = ddb.onboarding_requests_table()
    items: list[dict[str, Any]] = []

    if status:
        kwargs: dict[str, Any] = {
            "IndexName": "status-submitted_at",
            "KeyConditionExpression": "#s = :st",
            "ExpressionAttributeNames": {"#s": "status"},
            "ExpressionAttributeValues": {":st": status},
            "Limit": min(limit, 100),
            "ScanIndexForward": False,
        }
        while len(items) < limit:
            page = table.query(**kwargs)
            items.extend(page.get("Items", []))
            if "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    else:
        kwargs = {"Limit": min(limit, 100)}
        while len(items) < limit:
            page = table.scan(**kwargs)
            items.extend(page.get("Items", []))
            if len(items) >= limit or "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    items.sort(key=lambda x: str(x.get("submitted_at") or ""), reverse=True)
    return {
        "ok": True,
        "status_code": 200,
        "body": {"requests": items[:limit], "count": len(items[:limit])},
    }


def get_request(request_id: str) -> dict[str, Any]:
    item = ddb.onboarding_requests_table().get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return {
            "ok": False,
            "status_code": 404,
            "body": {"error": err.VALIDATION_ERROR, "message": "not found"},
        }
    return {"ok": True, "status_code": 200, "body": {"onboarding_request": item}}


def approve_request(
    *,
    request_id: str,
    reviewer: str,
    body: dict[str, Any],
) -> dict[str, Any]:
    table = ddb.onboarding_requests_table()
    item = table.get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return {
            "ok": False,
            "status_code": 404,
            "body": {"error": err.VALIDATION_ERROR, "message": "not found"},
        }
    if item.get("status") != "SUBMITTED":
        return {
            "ok": False,
            "status_code": 409,
            "body": {
                "error": err.VALIDATION_ERROR,
                "message": f"cannot approve status {item.get('status')}",
            },
        }

    partner_id = body.get("partner_id") or ddb.new_id("PRT")
    company_name = item.get("company_name") or "Partner"
    ddb.partners_table().put_item(
        Item={
            "partner_id": partner_id,
            "name": company_name,
            "metadata": {
                "contact_email": item.get("contact_email"),
                "onboarding_request_id": request_id,
                "transfer_types": item.get("transfer_types"),
            },
            "created_at": ddb.now_iso(),
            "status": "ACTIVE",
        }
    )

    endpoint_ids: list[str] = []
    for ep in item.get("endpoints") or _default_endpoints():
        eid = ddb.new_id("EPT")
        ddb.endpoints_table().put_item(
            Item={
                "endpoint_id": eid,
                "partner_id": partner_id,
                "protocol": ep.get("protocol", "S3"),
                "direction": ep.get("direction", "OUTBOUND"),
                "config_ref": "",
                "created_at": ddb.now_iso(),
                "status": "ACTIVE",
            }
        )
        endpoint_ids.append(eid)

    now = ddb.now_iso()
    table.update_item(
        Key={"request_id": request_id},
        UpdateExpression=(
            "SET #st = :ap, partner_id = :pid, reviewed_by = :rb, "
            "reviewed_at = :ra, updated_at = :ua"
        ),
        ExpressionAttributeNames={"#st": "status"},
        ExpressionAttributeValues={
            ":ap": "APPROVED",
            ":pid": partner_id,
            ":rb": reviewer,
            ":ra": now,
            ":ua": now,
        },
    )

    ddb.put_audit(
        action="onboarding_approved",
        correlation_id=request_id,
        actor=reviewer,
        detail={"partner_id": partner_id, "endpoint_ids": endpoint_ids},
    )

    _link_cognito_partner(
        username=(item.get("submitted_by") or item.get("contact_email") or "").strip(),
        partner_id=partner_id,
    )

    return {
        "ok": True,
        "status_code": 200,
        "body": {
            "request_id": request_id,
            "status": "APPROVED",
            "partner_id": partner_id,
            "endpoint_ids": endpoint_ids,
        },
    }


def _link_cognito_partner(*, username: str, partner_id: str) -> None:
    pool = (os.environ.get("COGNITO_USER_POOL_ID") or "").strip()
    if not pool or not username or "@" not in username:
        return
    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")
    try:
        _COGNITO.admin_update_user_attributes(
            UserPoolId=pool,
            Username=username,
            UserAttributes=[{"Name": "custom:partner_id", "Value": partner_id}],
        )
        _COGNITO.admin_add_user_to_group(
            UserPoolId=pool,
            Username=username,
            GroupName=PARTNER_GROUP,
        )
    except Exception as exc:
        logger.warning("Failed to link Cognito partner %s to %s: %s", username, partner_id, exc)


def reject_request(
    *,
    request_id: str,
    reviewer: str,
    body: dict[str, Any],
) -> dict[str, Any]:
    table = ddb.onboarding_requests_table()
    item = table.get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return {
            "ok": False,
            "status_code": 404,
            "body": {"error": err.VALIDATION_ERROR, "message": "not found"},
        }
    if item.get("status") != "SUBMITTED":
        return {
            "ok": False,
            "status_code": 409,
            "body": {
                "error": err.VALIDATION_ERROR,
                "message": f"cannot reject status {item.get('status')}",
            },
        }

    reason = (body.get("reason") or body.get("rejection_reason") or "").strip()
    now = ddb.now_iso()
    table.update_item(
        Key={"request_id": request_id},
        UpdateExpression=(
            "SET #st = :rj, rejection_reason = :rr, reviewed_by = :rb, "
            "reviewed_at = :ra, updated_at = :ua"
        ),
        ExpressionAttributeNames={"#st": "status"},
        ExpressionAttributeValues={
            ":rj": "REJECTED",
            ":rr": reason or None,
            ":rb": reviewer,
            ":ra": now,
            ":ua": now,
        },
    )

    ddb.put_audit(
        action="onboarding_rejected",
        correlation_id=request_id,
        actor=reviewer,
        detail={"reason": reason},
    )

    return {
        "ok": True,
        "status_code": 200,
        "body": {"request_id": request_id, "status": "REJECTED", "reason": reason},
    }
