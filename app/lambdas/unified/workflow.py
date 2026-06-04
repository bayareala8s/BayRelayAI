"""Step Functions task Lambda — deterministic execution helpers."""

from __future__ import annotations

import json
import os
import re
import time
from typing import Any

import boto3
from botocore.exceptions import ClientError

from bayrelay import errors as err
from bayrelay.logging_util import setup_logging, structured_log

import ddb

setup_logging()

_S3 = boto3.client("s3")
_EVENTS = boto3.client("events")
_TRANSFER = boto3.client("transfer")


def _state_machine_arn(suffix: str) -> str:
    account = os.environ["AWS_ACCOUNT_ID"]
    region = os.environ["AWS_REGION"]
    prefix = os.environ["BAYRELAY_PREFIX"]
    name = f"{prefix}-{suffix}"
    return f"arn:aws:states:{region}:{account}:stateMachine:{name}"


def _payload(event: dict[str, Any]) -> dict[str, Any]:
    if "Payload" in event:
        inner = event["Payload"]
        if isinstance(inner, str):
            return json.loads(inner)
        return inner
    return event


def task_precheck_validate(data: dict[str, Any]) -> dict[str, Any]:
    correlation_id = data.get("correlation_id", "")
    missing = [
        k
        for k in ("request_id", "execution_id", "transfer_type", "partner_id")
        if not data.get(k)
    ]
    if missing:
        return {"ok": False, "error": err.VALIDATION_ERROR, "missing": missing}
    ddb.put_audit(
        correlation_id=correlation_id,
        action="precheck_validated",
        detail={"request_id": data["request_id"], "execution_id": data["execution_id"]},
    )
    structured_log(message="precheck_ok", correlation_id=correlation_id)
    return {"ok": True, "next": "policy"}


def task_precheck_policy(data: dict[str, Any]) -> dict[str, Any]:
    partner_id = data.get("partner_id")
    pol = (
        ddb.routing_policies_table()
        .get_item(Key={"policy_id": "default", "partner_id": partner_id or ""})
        .get("Item")
    )
    if pol and pol.get("effect") == "DENY":
        return {"ok": False, "error": err.POLICY_DENIED}
    return {"ok": True, "next": "route"}


def task_precheck_route(data: dict[str, Any]) -> dict[str, Any]:
    tt = data.get("transfer_type")
    arns = {
        "S3_TO_S3": _state_machine_arn("sf-s3-to-s3"),
        "S3_TO_SFTP": _state_machine_arn("sf-s3-to-sftp"),
        "SFTP_TO_S3": _state_machine_arn("sf-sftp-to-s3"),
        "SFTP_TO_SFTP": _state_machine_arn("sf-sftp-to-sftp"),
    }
    target_arn = arns.get(str(tt), "")
    if not target_arn:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "unknown transfer_type or ARN not set"}
    child_input = {
        "correlation_id": data.get("correlation_id"),
        "request_id": data.get("request_id"),
        "execution_id": data.get("execution_id"),
        "transfer_type": tt,
        "partner_id": data.get("partner_id"),
        "source_endpoint_id": data.get("source_endpoint_id"),
        "target_endpoint_id": data.get("target_endpoint_id"),
        "payload": data.get("payload") or {},
    }
    return {
        "ok": True,
        "child_state_machine_arn": target_arn,
        "transfer_type": tt,
        "child_input": child_input,
    }


def task_precheck_all(data: dict[str, Any]) -> dict[str, Any]:
    v = task_precheck_validate(data)
    if not v.get("ok"):
        return v
    p = task_precheck_policy(data)
    if not p.get("ok"):
        return p
    return task_precheck_route(data)


def task_s3_verify_source(data: dict[str, Any]) -> dict[str, Any]:
    payload = data.get("payload") or {}
    bucket = payload.get("source_bucket")
    key = payload.get("source_key")
    if not bucket or not key:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "source_bucket and source_key required"}
    try:
        _S3.head_object(Bucket=bucket, Key=key)
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code in ("404", "NoSuchKey", "NotFound"):
            return {"ok": False, "error": err.SOURCE_UNAVAILABLE}
        return {"ok": False, "error": err.SOURCE_UNAVAILABLE, "detail": code}
    return {"ok": True}


def task_s3_copy(data: dict[str, Any]) -> dict[str, Any]:
    payload = data.get("payload") or {}
    sb, sk = payload.get("source_bucket"), payload.get("source_key")
    db, dk = payload.get("dest_bucket"), payload.get("dest_key")
    if not all([sb, sk, db, dk]):
        return {"ok": False, "error": err.VALIDATION_ERROR}
    copy_source = {"Bucket": sb, "Key": sk}
    _S3.copy_object(Bucket=db, Key=dk, CopySource=copy_source)
    return {"ok": True, "dest_bucket": db, "dest_key": dk}


def task_update_execution_status(data: dict[str, Any]) -> dict[str, Any]:
    eid = data.get("execution_id")
    status = data.get("status", "SUCCEEDED")
    if not eid:
        return {"ok": False}
    ddb.transfer_executions_table().update_item(
        Key={"execution_id": eid},
        UpdateExpression="SET #s = :s, updated_at = :u",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": status, ":u": ddb.now_iso()},
    )
    rid = data.get("request_id")
    if rid:
        ddb.transfer_requests_table().update_item(
            Key={"request_id": rid},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": status},
        )
    return {"ok": True}


def task_emit_eventbridge(data: dict[str, Any]) -> dict[str, Any]:
    bus = (os.environ.get("EVENT_BUS_NAME") or "").strip()
    entry: dict[str, Any] = {
        "Source": "bayrelay.transfer",
        "DetailType": "TransferLifecycle",
        "Detail": json.dumps(
            {
                "request_id": data.get("request_id"),
                "execution_id": data.get("execution_id"),
                "status": data.get("status", "UNKNOWN"),
                "transfer_type": data.get("transfer_type"),
            }
        ),
    }
    if bus and bus != "default":
        entry["EventBusName"] = bus
    _EVENTS.put_events(Entries=[entry])
    return {"ok": True}


def _wait_file_transfer(connector_id: str, transfer_id: str, *, timeout_sec: int = 180) -> dict[str, Any]:
    done_ok = frozenset({"COMPLETED", "COMPLETE", "SUCCESS", "SUCCEEDED"})
    done_bad = frozenset({"FAILED", "CANCELLED", "ERROR"})
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            resp = _TRANSFER.list_file_transfer_results(ConnectorId=connector_id, TransferId=transfer_id)
        except ClientError as e:
            return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": str(e)}
        rows = resp.get("FileTransferResults") or []
        if not rows:
            time.sleep(2)
            continue
        codes = {str(r.get("StatusCode") or "").upper() for r in rows}
        if codes & done_bad:
            return {
                "ok": False,
                "error": err.WORKFLOW_FAILED,
                "status_codes": list(codes),
                "file_transfer_results": rows,
            }
        if codes and codes <= done_ok:
            return {"ok": True, "file_transfer_results": rows}
        time.sleep(3)
    return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "timeout waiting for connector transfer"}


def _default_transfer_bucket() -> str:
    return (os.environ.get("TRANSFER_DATA_BUCKET") or "").strip()


def _transfer_s3_uri(bucket: str, *key_parts: str) -> str:
    """Transfer Family connector S3 paths must start with / (bucket/key)."""
    tail = "/".join(p.strip("/") for p in key_parts if p)
    return f"/{bucket.strip('/')}/{tail}" if tail else f"/{bucket.strip('/')}"


def task_s3_to_sftp_send(data: dict[str, Any]) -> dict[str, Any]:
    connector_id = (os.environ.get("TRANSFER_CONNECTOR_ID") or "").strip()
    if not connector_id:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "TRANSFER_CONNECTOR_ID not configured"}
    payload = data.get("payload") or {}
    sb = payload.get("source_bucket")
    sk = payload.get("source_key")
    if not sb or not sk:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "source_bucket and source_key required"}
    remote_dir = (payload.get("remote_directory") or "").strip() or "/"
    eid = data.get("execution_id") or "adhoc"
    base = os.path.basename(sk.replace("\\", "/")) or "object"
    safe_name = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("_") or "object"
    # No slashes in the key: otherwise the connector mirrors path segments on the SFTP side and mkdir fails.
    # Also avoid staging under the logical home prefix (e.g. sftp-connector/).
    staging_key = f"flat-send-{eid}-{safe_name}"[:900]
    try:
        _S3.copy_object(Bucket=sb, Key=staging_key, CopySource={"Bucket": sb, "Key": sk})
    except ClientError as e:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": e.response.get("Error", {}), "phase": "stage_for_connector"}
    send_path = _transfer_s3_uri(sb, staging_key)
    try:
        xfer_kw: dict[str, Any] = {
            "ConnectorId": connector_id,
            "SendFilePaths": [send_path],
        }
        # API default is the SFTP user's home. Passing "/" can yield permission errors with LOGICAL mappings.
        if remote_dir not in ("/", "."):
            xfer_kw["RemoteDirectoryPath"] = remote_dir
        out = _TRANSFER.start_file_transfer(**xfer_kw)
    except ClientError as e:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": e.response.get("Error", {})}
    tid = out.get("TransferId", "")
    wait = _wait_file_transfer(connector_id, tid)
    if not wait.get("ok"):
        return {**wait, "transfer_id": tid}
    eid = data.get("execution_id")
    if eid:
        ddb.transfer_executions_table().update_item(
            Key={"execution_id": eid},
            UpdateExpression="SET updated_at = :u, operator_summary = :o, transfer_connector_id = :c, transfer_connector_transfer_id = :t",
            ExpressionAttributeValues={
                ":u": ddb.now_iso(),
                ":o": "S3→SFTP via Transfer Family connector",
                ":c": connector_id,
                ":t": tid,
            },
        )
    ddb.put_audit(
        correlation_id=data.get("correlation_id", ""),
        action="s3_to_sftp_completed",
        detail={"execution_id": eid, "transfer_id": tid},
    )
    return {"ok": True, "transfer_id": tid}


def task_sftp_retrieve_to_s3(data: dict[str, Any]) -> dict[str, Any]:
    connector_id = (os.environ.get("TRANSFER_CONNECTOR_ID") or "").strip()
    if not connector_id:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "TRANSFER_CONNECTOR_ID not configured"}
    payload = data.get("payload") or {}
    paths = payload.get("remote_paths")
    if isinstance(paths, str):
        paths = [paths]
    if not paths:
        paths = []
    if not paths and payload.get("remote_path"):
        paths = [str(payload["remote_path"])]
    if not paths:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "remote_paths or remote_path required"}
    dest_bucket = payload.get("dest_bucket") or _default_transfer_bucket()
    if not dest_bucket:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "dest_bucket or TRANSFER_DATA_BUCKET required"}
    dest_prefix = (payload.get("dest_prefix") or "").strip().strip("/")
    if not dest_prefix:
        dest_prefix = f"sftp-pulled/{data.get('execution_id', 'unknown')}"
    local_path = _transfer_s3_uri(dest_bucket, dest_prefix)
    try:
        out = _TRANSFER.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=paths,
            LocalDirectoryPath=local_path,
        )
    except ClientError as e:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": e.response.get("Error", {})}
    tid = out.get("TransferId", "")
    wait = _wait_file_transfer(connector_id, tid)
    if not wait.get("ok"):
        return {**wait, "transfer_id": tid}
    eid = data.get("execution_id")
    if eid:
        ddb.transfer_executions_table().update_item(
            Key={"execution_id": eid},
            UpdateExpression="SET updated_at = :u, operator_summary = :o, transfer_connector_transfer_id = :t",
            ExpressionAttributeValues={
                ":u": ddb.now_iso(),
                ":o": "SFTP→S3 retrieve via Transfer connector",
                ":t": tid,
            },
        )
    return {"ok": True, "transfer_id": tid, "local_directory_path": local_path}


def task_sftp_relay(data: dict[str, Any]) -> dict[str, Any]:
    """Retrieve from remote SFTP into S3 staging, then send to remote destination path."""
    connector_id = (os.environ.get("TRANSFER_CONNECTOR_ID") or "").strip()
    if not connector_id:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "TRANSFER_CONNECTOR_ID not configured"}
    bucket = _default_transfer_bucket()
    if not bucket:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "TRANSFER_DATA_BUCKET not set"}
    payload = data.get("payload") or {}
    src_paths = payload.get("remote_source_paths")
    if isinstance(src_paths, str):
        src_paths = [src_paths]
    if not src_paths:
        src_paths = []
    if not src_paths and payload.get("remote_source_path"):
        src_paths = [str(payload["remote_source_path"])]
    if not src_paths:
        return {"ok": False, "error": err.VALIDATION_ERROR, "message": "remote_source_paths or remote_source_path required"}
    dest_remote = (payload.get("remote_dest_directory") or "").strip() or "/"
    ex = data.get("execution_id") or "unknown"
    staging = (payload.get("staging_prefix") or "").strip().strip("/")
    if not staging:
        staging = f"sftp-staging/{ex}"
    local_path = _transfer_s3_uri(bucket, staging)
    try:
        r1 = _TRANSFER.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=src_paths,
            LocalDirectoryPath=local_path,
        )
    except ClientError as e:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": e.response.get("Error", {}), "phase": "retrieve"}
    tid1 = r1.get("TransferId", "")
    w1 = _wait_file_transfer(connector_id, tid1)
    if not w1.get("ok"):
        return {**w1, "transfer_id": tid1, "phase": "retrieve"}

    pref = f"{staging}/"
    keys: list[str] = []
    paginator = _S3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=pref):
        for o in page.get("Contents") or []:
            keys.append(o["Key"])
    if not keys:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "message": "no objects after retrieve", "phase": "list"}

    send_paths = [_transfer_s3_uri(bucket, k) for k in keys]
    try:
        xfer_send: dict[str, Any] = {
            "ConnectorId": connector_id,
            "SendFilePaths": send_paths,
        }
        if dest_remote not in ("/", "."):
            xfer_send["RemoteDirectoryPath"] = dest_remote
        r2 = _TRANSFER.start_file_transfer(**xfer_send)
    except ClientError as e:
        return {"ok": False, "error": err.WORKFLOW_FAILED, "detail": e.response.get("Error", {}), "phase": "send"}
    tid2 = r2.get("TransferId", "")
    w2 = _wait_file_transfer(connector_id, tid2)
    if not w2.get("ok"):
        return {**w2, "transfer_id": tid2, "phase": "send"}
    eid = data.get("execution_id")
    if eid:
        ddb.transfer_executions_table().update_item(
            Key={"execution_id": eid},
            UpdateExpression="SET updated_at = :u, operator_summary = :o, transfer_connector_transfer_id = :t",
            ExpressionAttributeValues={
                ":u": ddb.now_iso(),
                ":o": "SFTP→SFTP relay (retrieve+send via connector)",
                ":t": tid2,
            },
        )
    return {"ok": True, "retrieve_transfer_id": tid1, "send_transfer_id": tid2, "keys": keys}


def task_mark_pending_phase2(data: dict[str, Any]) -> dict[str, Any]:
    """SFTP server / connector flows land in Phase 2."""
    eid = data.get("execution_id")
    if eid:
        ddb.transfer_executions_table().update_item(
            Key={"execution_id": eid},
            UpdateExpression="SET #s = :s, updated_at = :u, operator_summary = :o",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":s": "PENDING_IMPLEMENTATION",
                ":u": ddb.now_iso(),
                ":o": "Phase 2: Transfer Family server/connector or Fargate pull",
            },
        )
        rid = data.get("request_id")
        if rid:
            ddb.transfer_requests_table().update_item(
                Key={"request_id": rid},
                UpdateExpression="SET #s = :s, operator_summary = :o",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "PENDING_IMPLEMENTATION", ":o": "Awaiting Phase 2 SFTP automation"},
            )
    ddb.put_audit(
        correlation_id=data.get("correlation_id", ""),
        action="transfer_pending_phase2",
        detail={"execution_id": eid, "transfer_type": data.get("transfer_type")},
    )
    return {"ok": True, "status": "PENDING_IMPLEMENTATION"}


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    data = _payload(event)
    op = data.get("operation") or data.get("task")
    correlation_id = data.get("correlation_id", "")

    dispatch = {
        "mark_pending_phase2": task_mark_pending_phase2,
        "precheck_all": task_precheck_all,
        "precheck_validate": task_precheck_validate,
        "precheck_policy": task_precheck_policy,
        "precheck_route": task_precheck_route,
        "s3_verify_source": task_s3_verify_source,
        "s3_copy": task_s3_copy,
        "update_execution_status": task_update_execution_status,
        "emit_event": task_emit_eventbridge,
        "s3_to_sftp_send": task_s3_to_sftp_send,
        "sftp_retrieve_to_s3": task_sftp_retrieve_to_s3,
        "sftp_relay": task_sftp_relay,
    }

    fn = dispatch.get(str(op or ""))
    if not fn:
        return {"ok": False, "error": err.INTERNAL_ERROR, "message": f"unknown operation {op}"}
    result = fn(data)
    structured_log(message="workflow_task", correlation_id=correlation_id, operation=op, ok=result.get("ok"))
    return result
