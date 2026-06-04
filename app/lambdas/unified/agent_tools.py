"""Bedrock Agent action group Lambda executor — spec Layer A §3.4."""

from __future__ import annotations

import json
import os
import uuid
from decimal import Decimal
from typing import Any

from boto3.dynamodb.conditions import Key

from bayrelay import errors as err
from bayrelay import models
from bayrelay.logging_util import setup_logging, structured_log

import ddb

setup_logging()



def _bedrock_response(
    body: dict[str, Any],
    status_code: int = 200,
    event: dict[str, Any] | None = None,
) -> dict[str, Any]:
    ev = event or {}
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": ev.get("actionGroup") or "",
            "apiPath": ev.get("apiPath") or "",
            "httpMethod": ev.get("httpMethod") or "POST",
            "httpStatusCode": status_code,
            "responseBody": {"application/json": {"body": json.dumps(body)}},
        },
    }


def _parse_event(event: dict[str, Any]) -> tuple[str, str, dict[str, Any]]:
    api_path = event.get("apiPath") or ""
    method = event.get("httpMethod") or "POST"
    props: dict[str, Any] = {}
    rb = event.get("requestBody", {})
    content = rb.get("content", {}).get("application/json", {})
    if "body" in content:
        try:
            props = json.loads(content["body"])
        except (json.JSONDecodeError, TypeError):
            props = {}
    for k, v in event.get("parameters", []) or []:
        if isinstance(v, dict) and "value" in v:
            props[k] = v["value"]
        else:
            props[k] = v

    # Consolidated Bedrock action group: single OpenAPI path to stay within API limits
    if api_path == "/executeAction":
        op = (props.get("operation") or "").strip()
        params = props.get("parameters")
        if isinstance(params, str):
            try:
                params = json.loads(params)
            except (json.JSONDecodeError, TypeError):
                params = {}
        if not isinstance(params, dict):
            params = {}
        inner = f"/{op}" if op and not op.startswith("/") else op
        return inner, method, params

    return api_path, method, props


def validate_transfer_request(props: dict[str, Any]) -> dict[str, Any]:
    missing = [
        k
        for k in ("partner_id", "source_endpoint_id", "target_endpoint_id", "transfer_type")
        if not props.get(k)
    ]
    if missing:
        return {"ok": False, "error": err.VALIDATION_ERROR, "missing": missing}
    if not models.is_allowed_transfer_type(str(props["transfer_type"])):
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "invalid transfer_type"}
    return {"ok": True}


def classify_transfer_type(props: dict[str, Any]) -> dict[str, Any]:
    tt = props.get("transfer_type")
    if tt and models.is_allowed_transfer_type(str(tt)):
        return {"transfer_type": tt}
    return {"error": err.VALIDATION_ERROR, "message": "transfer_type required"}


def check_policy_compliance(props: dict[str, Any]) -> dict[str, Any]:
    partner_id = props.get("partner_id")
    if not partner_id:
        return {"allowed": False, "reason": err.VALIDATION_ERROR}
    # Minimal policy: default allow row or explicit deny
    pol_id = props.get("policy_id") or "default"
    item = (
        ddb.routing_policies_table()
        .get_item(Key={"policy_id": pol_id, "partner_id": partner_id})
        .get("Item")
    )
    if item and item.get("effect") == "DENY":
        return {"allowed": False, "reason": err.POLICY_DENIED, "policy_id": pol_id}
    return {"allowed": True, "policy_id": pol_id}


def build_execution_plan(props: dict[str, Any]) -> dict[str, Any]:
    tt = str(props.get("transfer_type", ""))
    method = "S3_COPY"
    if tt == "S3_TO_SFTP":
        method = "TRANSFER_FAMILY_CONNECTOR"
    elif tt in ("SFTP_TO_S3", "SFTP_TO_SFTP"):
        method = "STAGING_VIA_S3"
    return {
        "transfer_type": tt,
        "recommended_method": method,
        "step_function_precheck_name_suffix": "sf-transfer-precheck",
    }


def estimate_transfer_method(props: dict[str, Any]) -> dict[str, Any]:
    return build_execution_plan(props)


def submit_transfer_request(props: dict[str, Any]) -> dict[str, Any]:
    """Agent tool: same persistence path as POST /v1/transfers (no fabricated IDs)."""
    import transfers_service

    correlation_id = props.get("correlation_id") or str(uuid.uuid4())
    idem = props.get("idempotency_key") or str(uuid.uuid4())
    body = {
        "partner_id": props.get("partner_id"),
        "source_endpoint_id": props.get("source_endpoint_id"),
        "target_endpoint_id": props.get("target_endpoint_id"),
        "transfer_type": props.get("transfer_type"),
        "payload": props.get("payload") or {},
        "operator_summary": props.get("operator_summary") or "",
    }
    result = transfers_service.submit_transfer(
        body=body,
        correlation_id=correlation_id,
        idempotency_key=idem,
    )
    return {"result": result["body"], "ok": result["ok"], "status_code": result["status_code"]}


def start_transfer_execution(props: dict[str, Any]) -> dict[str, Any]:
    return {"message": "execution started via submit; use submit_transfer_request first", "props": props}


def retry_transfer_execution(props: dict[str, Any]) -> dict[str, Any]:
    import transfers_service

    eid = props.get("execution_id")
    if not eid:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "execution_id required"}
    ex_item = ddb.transfer_executions_table().get_item(Key={"execution_id": eid}).get("Item")
    if not ex_item:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "execution not found"}
    rid = ex_item.get("request_id")
    if not rid:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "missing request_id"}
    req_item = ddb.transfer_requests_table().get_item(Key={"request_id": rid}).get("Item")
    if not req_item:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "request not found"}
    correlation_id = props.get("correlation_id") or str(uuid.uuid4())
    idem = props.get("idempotency_key") or f"retry-{eid}-{uuid.uuid4().hex[:12]}"
    summary = str(req_item.get("operator_summary") or "")
    body = {
        "partner_id": req_item["partner_id"],
        "source_endpoint_id": req_item["source_endpoint_id"],
        "target_endpoint_id": req_item["target_endpoint_id"],
        "transfer_type": req_item["transfer_type"],
        "payload": req_item.get("payload") or {},
        "operator_summary": (summary + f" (retry of {eid})").strip(),
    }
    result = transfers_service.submit_transfer(
        body=body,
        correlation_id=correlation_id,
        idempotency_key=idem,
    )
    return {"retry": result["body"], "ok": result["ok"], "status_code": result["status_code"]}


def cancel_transfer_execution(props: dict[str, Any]) -> dict[str, Any]:
    eid = props.get("execution_id")
    return {
        "status": "manual_step",
        "execution_id": eid,
        "message": "Stop the running Step Functions execution in the console (search executions for this execution_id), or add stored sfn_execution_arn in a future release.",
    }


def get_transfer_status(props: dict[str, Any]) -> dict[str, Any]:
    rid = props.get("request_id")
    if not rid:
        return {"error": err.VALIDATION_ERROR}
    item = ddb.transfer_requests_table().get_item(Key={"request_id": rid}).get("Item")
    return {"transfer_request": item}


def list_recent_failures(props: dict[str, Any]) -> dict[str, Any]:
    gsi = (os.environ.get("TRANSFER_EXECUTIONS_STATUS_GSI") or "status-created_at").strip()
    try:
        limit = min(int(props.get("limit") or 20), 100)
    except (TypeError, ValueError):
        limit = 20
    partner_id = props.get("partner_id")
    tbl = ddb.transfer_executions_table()
    resp = tbl.query(
        IndexName=gsi,
        KeyConditionExpression=Key("status").eq("FAILED"),
        ScanIndexForward=False,
        Limit=limit * 3 if partner_id else limit,
    )
    items = list(resp.get("Items") or [])
    if partner_id:
        items = [i for i in items if i.get("partner_id") == partner_id][:limit]
    else:
        items = items[:limit]

    def _num(v: Any) -> Any:
        if isinstance(v, Decimal):
            return int(v) if v % 1 == 0 else float(v)
        return v

    safe = [{k: _num(v) for k, v in it.items()} for it in items]
    return {"items": safe, "count": len(safe), "index": gsi}


def summarize_failure(props: dict[str, Any]) -> dict[str, Any]:
    return {"summary": "Use Operations runbook + execution logs", "execution_id": props.get("execution_id")}


def generate_runbook_advice(props: dict[str, Any]) -> dict[str, Any]:
    return {"advice": "Consult knowledge base for grounded runbooks (Layer B).", "topic": props.get("topic")}


def register_partner(props: dict[str, Any]) -> dict[str, Any]:
    from api import post_partner

    r = post_partner(props)
    return json.loads(r["body"])


def register_endpoint(props: dict[str, Any]) -> dict[str, Any]:
    from api import post_endpoint

    r = post_endpoint(props)
    return json.loads(r["body"])


def disable_endpoint(props: dict[str, Any]) -> dict[str, Any]:
    eid = props.get("endpoint_id")
    if not eid:
        return {"error": err.VALIDATION_ERROR}
    ddb.endpoints_table().update_item(
        Key={"endpoint_id": eid},
        UpdateExpression="SET #s = :s",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "DISABLED"},
    )
    return {"endpoint_id": eid, "status": "DISABLED"}


def rotate_credential_reference(props: dict[str, Any]) -> dict[str, Any]:
    return {"status": "not_implemented", "endpoint_id": props.get("endpoint_id")}


DISPATCH = {
    "/validateTransferRequest": validate_transfer_request,
    "/classifyTransferType": classify_transfer_type,
    "/buildExecutionPlan": build_execution_plan,
    "/checkPolicyCompliance": check_policy_compliance,
    "/estimateTransferMethod": estimate_transfer_method,
    "/submitTransferRequest": submit_transfer_request,
    "/startTransferExecution": start_transfer_execution,
    "/retryTransferExecution": retry_transfer_execution,
    "/cancelTransferExecution": cancel_transfer_execution,
    "/getTransferStatus": get_transfer_status,
    "/listRecentFailures": list_recent_failures,
    "/summarizeFailure": summarize_failure,
    "/generateRunbookAdvice": generate_runbook_advice,
    "/registerPartner": register_partner,
    "/registerEndpoint": register_endpoint,
    "/disableEndpoint": disable_endpoint,
    "/rotateCredentialReference": rotate_credential_reference,
}


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    api_path, _method, props = _parse_event(event)
    correlation_id = props.get("correlation_id") or str(uuid.uuid4())
    structured_log(message="agent_tool_invoke", correlation_id=correlation_id, api_path=api_path)

    fn = DISPATCH.get(api_path)
    if not fn:
        return _bedrock_response(
            {"error": err.VALIDATION_ERROR, "message": f"unknown path {api_path}"},
            400,
            event,
        )
    try:
        result = fn(props)
    except Exception as e:  # noqa: BLE001
        structured_log(
            message="agent_tool_error",
            correlation_id=correlation_id,
            error=str(e),
        )
        return _bedrock_response({"error": err.INTERNAL_ERROR, "message": "tool failed"}, 500, event)

    return _bedrock_response(result, 200, event)
