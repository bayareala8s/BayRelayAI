"""Shared transfer submission logic for API and agent tools."""

from __future__ import annotations

import json
import os
import uuid
from typing import Any

import boto3

import ddb

_SFN = boto3.client("stepfunctions")


def _state_machine_arn(suffix: str) -> str:
    account = os.environ["AWS_ACCOUNT_ID"]
    region = os.environ["AWS_REGION"]
    prefix = os.environ["BAYRELAY_PREFIX"]
    name = f"{prefix}-{suffix}"
    return f"arn:aws:states:{region}:{account}:stateMachine:{name}"


def submit_transfer(
    *,
    body: dict[str, Any],
    correlation_id: str,
    idempotency_key: str,
) -> dict[str, Any]:
    from bayrelay import errors as err
    from bayrelay import models

    required = ("partner_id", "source_endpoint_id", "target_endpoint_id", "transfer_type")
    missing = [k for k in required if not body.get(k)]
    if missing:
        return {"ok": False, "status_code": 400, "body": {"error": err.VALIDATION_ERROR, "message": f"missing {missing}"}}

    if not models.is_allowed_transfer_type(str(body["transfer_type"])):
        return {"ok": False, "status_code": 400, "body": {"error": err.VALIDATION_ERROR, "message": "invalid transfer_type"}}

    existing = ddb.idempotency_keys_table().get_item(Key={"idempotency_key": idempotency_key}).get("Item")
    if existing:
        return {
            "ok": True,
            "status_code": 200,
            "body": {
                "request_id": existing["transfer_request_id"],
                "deduplicated": True,
                "correlation_id": existing.get("correlation_id", correlation_id),
            },
        }

    request_id = ddb.new_id("REQ")
    execution_id = ddb.new_id("EX")

    ddb.transfer_requests_table().put_item(
        Item={
            "request_id": request_id,
            "partner_id": body["partner_id"],
            "source_endpoint_id": body["source_endpoint_id"],
            "target_endpoint_id": body["target_endpoint_id"],
            "transfer_type": body["transfer_type"],
            "status": "SUBMITTED",
            "created_at": ddb.now_iso(),
            "correlation_id": correlation_id,
            "payload": body.get("payload") or {},
            "operator_summary": body.get("operator_summary") or "",
        }
    )

    ddb.transfer_executions_table().put_item(
        Item={
            "execution_id": execution_id,
            "request_id": request_id,
            "partner_id": body["partner_id"],
            "source_endpoint_id": body["source_endpoint_id"],
            "target_endpoint_id": body["target_endpoint_id"],
            "transfer_type": body["transfer_type"],
            "status": "QUEUED",
            "created_at": ddb.now_iso(),
            "correlation_id": correlation_id,
            "retry_count": 0,
            "checksum_status": "PENDING",
        }
    )

    ddb.idempotency_keys_table().put_item(
        Item={
            "idempotency_key": idempotency_key,
            "transfer_request_id": request_id,
            "execution_id": execution_id,
            "correlation_id": correlation_id,
            "created_at": ddb.now_iso(),
        }
    )

    ddb.put_audit(
        correlation_id=correlation_id,
        action="transfer_submitted",
        detail={"request_id": request_id, "execution_id": execution_id},
    )

    machine = _state_machine_arn("sf-transfer-precheck")
    out = _SFN.start_execution(
        stateMachineArn=machine,
        name=f"{execution_id}-{uuid.uuid4().hex[:8]}",
        input=json.dumps(
            {
                "correlation_id": correlation_id,
                "request_id": request_id,
                "execution_id": execution_id,
                "transfer_type": body["transfer_type"],
                "partner_id": body["partner_id"],
                "source_endpoint_id": body["source_endpoint_id"],
                "target_endpoint_id": body["target_endpoint_id"],
                "payload": body.get("payload") or {},
            }
        ),
    )

    return {
        "ok": True,
        "status_code": 202,
        "body": {
            "request_id": request_id,
            "execution_id": execution_id,
            "correlation_id": correlation_id,
            "step_functions_execution_arn": out["executionArn"],
        },
    }


def _latest_execution_for_request(request_id: str) -> dict[str, Any] | None:
    table = ddb.transfer_executions_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {
        "FilterExpression": "request_id = :r",
        "ExpressionAttributeValues": {":r": request_id},
        "Limit": 50,
    }
    while True:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    if not items:
        return None
    items.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
    return items[0]


def retry_transfer_by_request(
    *,
    request_id: str,
    correlation_id: str,
    idempotency_key: str,
) -> dict[str, Any]:
    from bayrelay import errors as err

    req_item = ddb.transfer_requests_table().get_item(Key={"request_id": request_id}).get("Item")
    if not req_item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    ex = _latest_execution_for_request(request_id)
    summary = str(req_item.get("operator_summary") or "")
    if ex:
        summary = (summary + f" (retry of {ex.get('execution_id')})").strip()
    body = {
        "partner_id": req_item["partner_id"],
        "source_endpoint_id": req_item["source_endpoint_id"],
        "target_endpoint_id": req_item["target_endpoint_id"],
        "transfer_type": req_item["transfer_type"],
        "payload": req_item.get("payload") or {},
        "operator_summary": summary,
    }
    return submit_transfer(body=body, correlation_id=correlation_id, idempotency_key=idempotency_key)


def cancel_transfer_request(request_id: str) -> dict[str, Any]:
    from bayrelay import errors as err

    table = ddb.transfer_requests_table()
    item = table.get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return {"ok": False, "status_code": 404, "body": {"error": err.VALIDATION_ERROR, "message": "not found"}}
    status = str(item.get("status") or "").upper()
    if status in ("SUCCEEDED", "FAILED", "CANCELLED"):
        return {
            "ok": False,
            "status_code": 409,
            "body": {
                "error": err.VALIDATION_ERROR,
                "message": f"cannot cancel transfer in status {status}",
            },
        }
    item["status"] = "CANCELLED"
    item["updated_at"] = ddb.now_iso()
    table.put_item(Item=item)
    ddb.put_audit(
        correlation_id=str(item.get("correlation_id") or request_id),
        action="transfer_cancelled",
        detail={"request_id": request_id},
        actor="api-operator",
    )
    return {"ok": True, "status_code": 200, "body": {"request_id": request_id, "status": "CANCELLED"}}
