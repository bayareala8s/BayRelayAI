"""HTTP API Lambda (API Gateway v2) — Layer C control plane."""

from __future__ import annotations

import json
import os
import re
import uuid
from decimal import Decimal
from typing import Any

import boto3
from boto3.dynamodb.conditions import Attr

from bayrelay import errors as err
from bayrelay.logging_util import setup_logging, structured_log

import ddb
import transfers_service
import onboarding_service
import ops_service
import transfer_rules_service
import partners_service
import endpoints_service
import routing_policies_service
import audit_service
import auth_context
from auth_context import AuthContext
from list_utils import filter_items, sort_items

setup_logging()

_AGENT = boto3.client("bedrock-agent-runtime")

_CORS_ALLOW_HEADERS = (
    "Authorization,Content-Type,X-Idempotency-Key,X-Correlation-Id,X-Enable-Trace"
)


def _json_default(obj: Any) -> Any:
    if isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def _cors_origin(event: dict[str, Any]) -> str:
    headers = event.get("headers") or {}
    for key, val in headers.items():
        if key.lower() == "origin" and val:
            return val
    return "*"


def _resp(status: int, body: dict[str, Any], event: dict[str, Any] | None = None) -> dict[str, Any]:
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": _cors_origin(event) if event else "*",
        "Access-Control-Allow-Headers": _CORS_ALLOW_HEADERS,
        "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    }
    return {
        "statusCode": status,
        "headers": headers,
        "body": json.dumps(body, default=_json_default),
    }


def _json_body(event: dict[str, Any]) -> dict[str, Any]:
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        import base64

        raw = base64.b64decode(raw).decode("utf-8")
    try:
        return json.loads(raw) if isinstance(raw, str) else {}
    except json.JSONDecodeError:
        return {}


def _route_key(event: dict[str, Any]) -> str:
    return f"{event.get('requestContext', {}).get('http', {}).get('method', 'GET')} {event.get('rawPath', '')}"


def _query_params(event: dict[str, Any]) -> dict[str, str]:
    return event.get("queryStringParameters") or {}


def _public_onboarding_ok() -> bool:
    return os.environ.get("ENABLE_PUBLIC_ONBOARDING_SUBMIT", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def _rules_enabled() -> bool:
    return os.environ.get("ENABLE_TRANSFER_AUTOMATION", "").lower() in ("1", "true", "yes")


def _auth_result(result: dict[str, Any], event: dict[str, Any]) -> dict[str, Any]:
    return _resp(result["status_code"], result["body"], event)


def get_me(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    return _resp(
        200,
        {
            "role": ctx.role,
            "sub": ctx.sub,
            "email": ctx.email,
            "username": ctx.username,
            "partner_id": ctx.partner_id,
            "groups": list(ctx.groups),
        },
        event,
    )


def get_ops_summary(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    try:
        sample = min(int(q.get("transfer_sample") or "200"), 500)
    except ValueError:
        sample = 200
    try:
        recent = min(int(q.get("recent_limit") or "8"), 25)
    except ValueError:
        recent = 8
    result = ops_service.get_summary(transfer_sample=sample, recent_limit=recent)
    return _resp(result["status_code"], result["body"], event)


def list_transfers(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    try:
        limit = min(int(q.get("limit") or "50"), 200)
    except ValueError:
        limit = 50
    table = ddb.transfer_requests_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": min(limit * 2, 400)}
    while len(items) < limit * 2:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if len(items) >= limit * 2 or "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    partner_filter = ctx.partner_id if ctx.is_partner else q.get("partner_id")
    items = filter_items(
        items,
        q=q.get("q"),
        status=q.get("status"),
        partner_id=partner_filter,
        search_fields=(
            "request_id",
            "partner_id",
            "transfer_type",
            "status",
            "operator_summary",
            "correlation_id",
        ),
    )
    tt = q.get("transfer_type")
    if tt:
        items = [i for i in items if i.get("transfer_type") == tt]
    items = sort_items(items, sort=q.get("sort"), order=q.get("order"), default_sort="created_at")
    return _resp(200, {"transfers": items[:limit], "count": len(items[:limit])}, event)


def list_partners(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    table = ddb.partners_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": 200}
    while True:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    partner_filter = ctx.partner_id if ctx.is_partner else None
    items = filter_items(
        items,
        q=q.get("q"),
        status=q.get("status"),
        partner_id=partner_filter,
        search_fields=("partner_id", "name", "status"),
    )
    items = sort_items(items, sort=q.get("sort"), order=q.get("order"), default_sort="created_at")
    return _resp(200, {"partners": items, "count": len(items)}, event)


def list_endpoints(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    partner_id = q.get("partner_id")
    if ctx.is_partner and ctx.partner_id:
        partner_id = ctx.partner_id
    elif ctx.is_partner:
        return _auth_result(auth_context.forbid("partner not provisioned"), event)
    table = ddb.endpoints_table()
    items: list[dict[str, Any]] = []
    if partner_id:
        kwargs: dict[str, Any] = {
            "FilterExpression": Attr("partner_id").eq(partner_id),
            "Limit": 100,
        }
        while True:
            page = table.scan(**kwargs)
            items.extend(page.get("Items", []))
            if "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    else:
        kwargs = {"Limit": 100}
        while True:
            page = table.scan(**kwargs)
            items.extend(page.get("Items", []))
            if "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    items = filter_items(
        items,
        q=q.get("q"),
        status=q.get("status"),
        search_fields=("endpoint_id", "partner_id", "protocol", "direction", "config_ref", "status"),
    )
    items = sort_items(items, sort=q.get("sort"), order=q.get("order"), default_sort="created_at")
    return _resp(200, {"endpoints": items, "count": len(items)}, event)


def post_transfers(
    body: dict[str, Any],
    headers: dict[str, str],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    scoped_pid, err_result = auth_context.partner_id_for_create(ctx, body.get("partner_id"))
    if err_result:
        return _auth_result(err_result, event)
    if scoped_pid:
        body = {**body, "partner_id": scoped_pid}
    correlation_id = headers.get("x-correlation-id") or str(uuid.uuid4())
    idem = headers.get("x-idempotency-key") or body.get("idempotency_key")
    if not idem:
        return _resp(
            400,
            {"error": err.VALIDATION_ERROR, "message": "idempotency key required"},
            event,
        )

    result = transfers_service.submit_transfer(
        body=body,
        correlation_id=correlation_id,
        idempotency_key=idem,
    )
    if not result["ok"]:
        return _resp(result["status_code"], result["body"], event)
    if result["status_code"] == 202:
        b = result["body"]
        structured_log(
            message="transfer_submitted",
            correlation_id=correlation_id,
            request_id=b.get("request_id"),
            execution_id=b.get("execution_id"),
            sfn_execution_arn=b.get("step_functions_execution_arn"),
        )
    return _resp(result["status_code"], result["body"], event)


def get_transfer(request_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    item = ddb.transfer_requests_table().get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "not found"}, event)
    if ctx.is_partner:
        scope_err = auth_context.enforce_partner_scope(ctx, str(item.get("partner_id") or ""))
        if scope_err:
            return _auth_result(scope_err, event)
    ex = transfers_service._latest_execution_for_request(request_id)
    body: dict[str, Any] = {"transfer_request": item}
    if ex:
        body["latest_execution"] = ex
    return _resp(200, body, event)


def _agent_trace_enabled(headers: dict[str, str]) -> bool:
    if os.environ.get("BAYRELAY_ALLOW_AGENT_TRACE", "").lower() not in ("1", "true", "yes"):
        return False
    v = str(headers.get("x-enable-trace") or "").lower()
    return v in ("1", "true", "yes")


def post_agent_query(body: dict[str, Any], headers: dict[str, str], event: dict[str, Any]) -> dict[str, Any]:
    correlation_id = headers.get("x-correlation-id") or str(uuid.uuid4())
    query = (body.get("query") or "").strip()
    if not query:
        return _resp(400, {"error": err.VALIDATION_ERROR, "message": "query required"}, event)

    agent_id = os.environ.get("BEDROCK_AGENT_ID")
    alias = os.environ.get("BEDROCK_AGENT_ALIAS_ID")
    if not agent_id or not alias:
        return _resp(
            503,
            {
                "error": err.INTERNAL_ERROR,
                "message": "Bedrock agent not configured in this environment",
            },
            event,
        )

    session_id = body.get("session_id") or str(uuid.uuid4())
    request_id = ddb.new_id("ARQ")
    enable_trace = _agent_trace_enabled(headers)

    try:
        response = _AGENT.invoke_agent(
            agentId=agent_id,
            agentAliasId=alias,
            sessionId=session_id,
            inputText=query,
            enableTrace=enable_trace,
        )
    except Exception as exc:
        structured_log(
            message="agent_query_failed",
            correlation_id=correlation_id,
            request_id=request_id,
            error=str(exc),
        )
        return _resp(
            503,
            {
                "error": err.INTERNAL_ERROR,
                "message": "Bedrock agent invocation failed",
                "detail": str(exc),
                "request_id": request_id,
                "correlation_id": correlation_id,
            },
            event,
        )

    completion = ""
    citations: list[dict[str, Any]] = []
    tool_calls: list[dict[str, Any]] = []
    for ev in response.get("completion", []):
        if "chunk" in ev and "bytes" in ev["chunk"]:
            completion += ev["chunk"]["bytes"].decode("utf-8", errors="replace")
        if "trace" in ev:
            tr = ev["trace"]
            if "orchestrationTrace" in tr:
                orch = tr["orchestrationTrace"]
                if "invocationInput" in orch:
                    tool_calls.append({"invocation": orch["invocationInput"]})
                if "observation" in orch:
                    obs = orch["observation"]
                    if "knowledgeBaseLookupOutput" in obs:
                        citations.append({"kb": obs["knowledgeBaseLookupOutput"]})

    structured_log(
        message="agent_query",
        correlation_id=correlation_id,
        request_id=request_id,
        session_id=session_id,
    )

    return _resp(
        200,
        {
            "request_id": request_id,
            "correlation_id": correlation_id,
            "agent_response": completion,
            "citations": citations or None,
            "tool_calls": tool_calls or None,
            "confidence_notes": None,
            "linked_execution_ids": None,
            "session_id": session_id,
        },
        event,
    )


def _actor_from_headers(headers: dict[str, str]) -> str:
    auth = headers.get("authorization") or ""
    if auth.lower().startswith("bearer "):
        return "api-operator"
    return "api"


def _onboarding_enabled() -> bool:
    return os.environ.get("ENABLE_SELF_SERVICE_ONBOARDING", "").lower() in (
        "1",
        "true",
        "yes",
    )


def _onboarding_result(result: dict[str, Any], event: dict[str, Any]) -> dict[str, Any]:
    return _resp(result["status_code"], result["body"], event)


def post_onboarding_request(
    body: dict[str, Any],
    headers: dict[str, str],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    if not _onboarding_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "onboarding disabled"}, event)
    if ctx.role == "public" and not _public_onboarding_ok():
        return _auth_result(auth_context.forbid("authentication required"), event)
    actor = ctx.email or ctx.username or _actor_from_headers(headers)
    result = onboarding_service.create_request(body=body, submitted_by=actor)
    return _onboarding_result(result, event)


def list_onboarding_requests(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    if not _onboarding_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "onboarding disabled"}, event)
    if ctx.role == "public":
        return _auth_result(auth_context.forbid("authentication required"), event)
    q = _query_params(event)
    status = q.get("status")
    try:
        limit = min(int(q.get("limit") or "50"), 100)
    except ValueError:
        limit = 50
    result = onboarding_service.list_requests(status=status or None, limit=limit)
    if result.get("ok") and ctx.is_partner:
        email = (ctx.email or "").lower()
        reqs = result["body"].get("requests") or []
        filtered = [
            r
            for r in reqs
            if (r.get("contact_email") or "").lower() == email
            or (r.get("submitted_by") or "").lower() == email
            or r.get("partner_id") == ctx.partner_id
        ]
        result["body"]["requests"] = filtered
        result["body"]["count"] = len(filtered)
    if result.get("ok"):
        reqs = result["body"].get("requests") or []
        reqs = filter_items(
            reqs,
            q=q.get("q"),
            search_fields=("request_id", "company_name", "contact_email", "status", "submitted_by"),
        )
        reqs = sort_items(reqs, sort=q.get("sort"), order=q.get("order"), default_sort="created_at")
        result["body"]["requests"] = reqs
        result["body"]["count"] = len(reqs)
    return _onboarding_result(result, event)


def get_onboarding_request(request_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    if not _onboarding_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "onboarding disabled"}, event)
    if ctx.role == "public":
        return _auth_result(auth_context.forbid("authentication required"), event)
    result = onboarding_service.get_request(request_id)
    if result.get("ok") and ctx.is_partner:
        item = result["body"].get("onboarding_request") or {}
        email = (ctx.email or "").lower()
        ok = (
            (item.get("contact_email") or "").lower() == email
            or (item.get("submitted_by") or "").lower() == email
            or item.get("partner_id") == ctx.partner_id
        )
        if not ok:
            return _auth_result(auth_context.forbid("not found"), event)
    return _onboarding_result(result, event)


def approve_onboarding_request(
    request_id: str,
    body: dict[str, Any],
    headers: dict[str, str],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    if not _onboarding_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "onboarding disabled"}, event)
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    result = onboarding_service.approve_request(
        request_id=request_id,
        reviewer=_actor_from_headers(headers),
        body=body,
    )
    return _onboarding_result(result, event)


def reject_onboarding_request(
    request_id: str,
    body: dict[str, Any],
    headers: dict[str, str],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    if not _onboarding_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "onboarding disabled"}, event)
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    result = onboarding_service.reject_request(
        request_id=request_id,
        reviewer=_actor_from_headers(headers),
        body=body,
    )
    return _onboarding_result(result, event)


def list_transfer_rules(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    if not _rules_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "automation disabled"}, event)
    q = _query_params(event)
    try:
        limit = min(int(q.get("limit") or "100"), 200)
    except ValueError:
        limit = 100
    result = transfer_rules_service.list_rules(partner_id=q.get("partner_id"), limit=limit)
    if result.get("ok"):
        rules = result["body"].get("rules") or []
        rules = filter_items(
            rules,
            q=q.get("q"),
            search_fields=("rule_id", "name", "partner_id", "match_pattern", "transfer_type"),
        )
        rules = sort_items(rules, sort=q.get("sort"), order=q.get("order"), default_sort="priority")
        result["body"]["rules"] = rules
        result["body"]["count"] = len(rules)
    return _auth_result(result, event)


def post_transfer_rule(body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    if not _rules_enabled():
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "automation disabled"}, event)
    return _auth_result(transfer_rules_service.create_rule(body), event)


def get_transfer_rule(rule_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    result = transfer_rules_service.get_rule(rule_id)
    if result.get("ok") and ctx.is_partner:
        rule = result["body"].get("rule") or {}
        scope_err = auth_context.enforce_partner_scope(ctx, str(rule.get("partner_id") or ""))
        if scope_err:
            return _auth_result(scope_err, event)
    return _auth_result(result, event)


def put_transfer_rule(rule_id: str, body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(transfer_rules_service.update_rule(rule_id, body), event)


def delete_transfer_rule(rule_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(transfer_rules_service.delete_rule(rule_id), event)


def post_partner(body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    pid = body.get("partner_id") or ddb.new_id("PRT")
    if not body.get("name"):
        return _resp(400, {"error": err.VALIDATION_ERROR, "message": "name required"}, event)
    ddb.partners_table().put_item(
        Item={
            "partner_id": pid,
            "name": body["name"],
            "metadata": body.get("metadata") or {},
            "created_at": ddb.now_iso(),
            "status": "ACTIVE",
        }
    )
    return _resp(201, {"partner_id": pid}, event)


def post_endpoint(body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    eid = body.get("endpoint_id") or ddb.new_id("EPT")
    required = ("partner_id", "protocol", "direction")
    missing = [k for k in required if not body.get(k)]
    if missing:
        return _resp(400, {"error": err.VALIDATION_ERROR, "message": f"missing {missing}"}, event)
    ddb.endpoints_table().put_item(
        Item={
            "endpoint_id": eid,
            "partner_id": body["partner_id"],
            "protocol": body["protocol"],
            "direction": body["direction"],
            "config_ref": body.get("config_ref") or "",
            "created_at": ddb.now_iso(),
            "status": "ACTIVE",
        }
    )
    return _resp(201, {"endpoint_id": eid}, event)


def get_partner(partner_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    result = partners_service.get_partner(partner_id)
    if result.get("ok") and ctx.is_partner:
        scope_err = auth_context.enforce_partner_scope(ctx, partner_id)
        if scope_err:
            return _auth_result(scope_err, event)
    return _auth_result(result, event)


def put_partner(partner_id: str, body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(partners_service.update_partner(partner_id, body), event)


def delete_partner(partner_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(partners_service.delete_partner(partner_id), event)


def get_endpoint(endpoint_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    result = endpoints_service.get_endpoint(endpoint_id)
    if result.get("ok"):
        scope_err = auth_context.enforce_partner_scope(ctx, str(result["body"]["endpoint"].get("partner_id") or ""))
        if scope_err:
            return _auth_result(scope_err, event)
    return _auth_result(result, event)


def put_endpoint(endpoint_id: str, body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(endpoints_service.update_endpoint(endpoint_id, body), event)


def delete_endpoint(endpoint_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(endpoints_service.delete_endpoint(endpoint_id), event)


def post_transfer_retry(
    request_id: str,
    headers: dict[str, str],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    item = ddb.transfer_requests_table().get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "not found"}, event)
    if ctx.is_partner:
        scope_err = auth_context.enforce_partner_scope(ctx, str(item.get("partner_id") or ""))
        if scope_err:
            return _auth_result(scope_err, event)
    correlation_id = headers.get("x-correlation-id") or str(uuid.uuid4())
    idem = headers.get("x-idempotency-key") or f"retry-{request_id}-{uuid.uuid4().hex[:12]}"
    result = transfers_service.retry_transfer_by_request(
        request_id=request_id,
        correlation_id=correlation_id,
        idempotency_key=idem,
    )
    if not result["ok"]:
        return _resp(result["status_code"], result["body"], event)
    return _resp(result["status_code"], result["body"], event)


def post_transfer_cancel(request_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_partner_or_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    item = ddb.transfer_requests_table().get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        return _resp(404, {"error": err.VALIDATION_ERROR, "message": "not found"}, event)
    if ctx.is_partner:
        scope_err = auth_context.enforce_partner_scope(ctx, str(item.get("partner_id") or ""))
        if scope_err:
            return _auth_result(scope_err, event)
    result = transfers_service.cancel_transfer_request(request_id)
    if not result["ok"]:
        return _resp(result["status_code"], result["body"], event)
    return _resp(result["status_code"], result["body"], event)


def list_routing_policies(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    try:
        limit = min(int(q.get("limit") or "100"), 200)
    except ValueError:
        limit = 100
    result = routing_policies_service.list_policies(partner_id=q.get("partner_id"), limit=limit)
    if result.get("ok"):
        policies = result["body"].get("policies") or []
        policies = filter_items(
            policies,
            q=q.get("q"),
            search_fields=("policy_id", "partner_id", "effect", "description"),
        )
        policies = sort_items(policies, sort=q.get("sort"), order=q.get("order"), default_sort="partner_id")
        result["body"]["policies"] = policies
        result["body"]["count"] = len(policies)
    return _auth_result(result, event)


def post_routing_policy(body: dict[str, Any], event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(routing_policies_service.create_policy(body), event)


def get_routing_policy(policy_id: str, partner_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(routing_policies_service.get_policy(policy_id, partner_id), event)


def put_routing_policy(
    policy_id: str,
    partner_id: str,
    body: dict[str, Any],
    event: dict[str, Any],
    ctx: AuthContext,
) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(routing_policies_service.update_policy(policy_id, partner_id, body), event)


def delete_routing_policy(policy_id: str, partner_id: str, event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    return _auth_result(routing_policies_service.delete_policy(policy_id, partner_id), event)


def list_audit(event: dict[str, Any], ctx: AuthContext) -> dict[str, Any]:
    denied = auth_context.require_operator(ctx)
    if denied:
        return _auth_result(denied, event)
    q = _query_params(event)
    try:
        limit = min(int(q.get("limit") or "50"), 200)
    except ValueError:
        limit = 50
    result = audit_service.list_audit_events(
        limit=limit,
        q=q.get("q"),
        correlation_id=q.get("correlation_id"),
        sort=q.get("sort"),
        order=q.get("order"),
    )
    return _auth_result(result, event)


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    if method == "OPTIONS":
        return _resp(200, {"ok": True}, event)

    rk = _route_key(event)
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    body = _json_body(event)
    ctx = auth_context.from_event(event)

    if rk == "GET /v1/me":
        return get_me(event, ctx)
    if rk == "GET /v1/ops/summary":
        return get_ops_summary(event, ctx)
    if rk == "GET /v1/transfers":
        return list_transfers(event, ctx)
    m_retry = re.match(r"POST /v1/transfers/([^/]+)/retry$", rk)
    if m_retry:
        return post_transfer_retry(m_retry.group(1), headers, event, ctx)
    m_cancel = re.match(r"POST /v1/transfers/([^/]+)/cancel$", rk)
    if m_cancel:
        return post_transfer_cancel(m_cancel.group(1), event, ctx)
    if rk.startswith("POST /v1/transfers"):
        return post_transfers(body, headers, event, ctx)
    if rk.startswith("POST /v1/agent/query"):
        denied = auth_context.require_partner_or_operator(ctx)
        if denied:
            return _auth_result(denied, event)
        return post_agent_query(body, headers, event)
    if rk == "GET /v1/partners":
        return list_partners(event, ctx)
    m_partner = re.match(r"GET /v1/partners/([^/]+)$", rk)
    if m_partner:
        return get_partner(m_partner.group(1), event, ctx)
    m_put_partner = re.match(r"PUT /v1/partners/([^/]+)$", rk)
    if m_put_partner:
        return put_partner(m_put_partner.group(1), body, event, ctx)
    m_del_partner = re.match(r"DELETE /v1/partners/([^/]+)$", rk)
    if m_del_partner:
        return delete_partner(m_del_partner.group(1), event, ctx)
    if rk.startswith("POST /v1/partners"):
        return post_partner(body, event, ctx)
    if rk == "GET /v1/endpoints":
        return list_endpoints(event, ctx)
    m_ep = re.match(r"GET /v1/endpoints/([^/]+)$", rk)
    if m_ep:
        return get_endpoint(m_ep.group(1), event, ctx)
    m_put_ep = re.match(r"PUT /v1/endpoints/([^/]+)$", rk)
    if m_put_ep:
        return put_endpoint(m_put_ep.group(1), body, event, ctx)
    m_del_ep = re.match(r"DELETE /v1/endpoints/([^/]+)$", rk)
    if m_del_ep:
        return delete_endpoint(m_del_ep.group(1), event, ctx)
    if rk.startswith("POST /v1/endpoints"):
        return post_endpoint(body, event, ctx)
    if rk == "GET /v1/audit-events":
        return list_audit(event, ctx)
    if rk == "GET /v1/routing-policies":
        return list_routing_policies(event, ctx)
    if rk == "POST /v1/routing-policies":
        return post_routing_policy(body, event, ctx)
    m_pol = re.match(r"GET /v1/routing-policies/([^/]+)$", rk)
    if m_pol:
        pid = _query_params(event).get("partner_id") or ""
        if not pid:
            return _resp(400, {"error": err.VALIDATION_ERROR, "message": "partner_id query required"}, event)
        return get_routing_policy(m_pol.group(1), pid, event, ctx)
    m_put_pol = re.match(r"PUT /v1/routing-policies/([^/]+)$", rk)
    if m_put_pol:
        pid = _query_params(event).get("partner_id") or ""
        if not pid:
            return _resp(400, {"error": err.VALIDATION_ERROR, "message": "partner_id query required"}, event)
        return put_routing_policy(m_put_pol.group(1), pid, body, event, ctx)
    m_del_pol = re.match(r"DELETE /v1/routing-policies/([^/]+)$", rk)
    if m_del_pol:
        pid = _query_params(event).get("partner_id") or ""
        if not pid:
            return _resp(400, {"error": err.VALIDATION_ERROR, "message": "partner_id query required"}, event)
        return delete_routing_policy(m_del_pol.group(1), pid, event, ctx)

    if _rules_enabled():
        if rk == "GET /v1/transfer-rules":
            return list_transfer_rules(event, ctx)
        if rk == "POST /v1/transfer-rules":
            return post_transfer_rule(body, event, ctx)
        m_rule = re.match(r"GET /v1/transfer-rules/([^/]+)$", rk)
        if m_rule:
            return get_transfer_rule(m_rule.group(1), event, ctx)
        m_put = re.match(r"PUT /v1/transfer-rules/([^/]+)$", rk)
        if m_put:
            return put_transfer_rule(m_put.group(1), body, event, ctx)
        m_del = re.match(r"DELETE /v1/transfer-rules/([^/]+)$", rk)
        if m_del:
            return delete_transfer_rule(m_del.group(1), event, ctx)

    if _onboarding_enabled():
        if rk == "GET /v1/onboarding/requests":
            return list_onboarding_requests(event, ctx)
        if rk == "POST /v1/onboarding/requests":
            return post_onboarding_request(body, headers, event, ctx)
        m_onb = re.match(r"GET /v1/onboarding/requests/([^/]+)$", rk)
        if m_onb:
            return get_onboarding_request(m_onb.group(1), event, ctx)
        m_ap = re.match(r"POST /v1/onboarding/requests/([^/]+)/approve$", rk)
        if m_ap:
            return approve_onboarding_request(m_ap.group(1), body, headers, event, ctx)
        m_rj = re.match(r"POST /v1/onboarding/requests/([^/]+)/reject$", rk)
        if m_rj:
            return reject_onboarding_request(m_rj.group(1), body, headers, event, ctx)

    m = re.match(r"GET /v1/transfers/([^/]+)$", rk)
    if m:
        return get_transfer(m.group(1), event, ctx)

    return _resp(404, {"error": err.VALIDATION_ERROR, "message": "not found"}, event)
