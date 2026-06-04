"""Operations dashboard aggregates — transfer health, failures, partner counts."""

from __future__ import annotations

import os
from collections import Counter
from typing import Any

import ddb


def _scan_limited(table: Any, *, limit: int) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": min(limit, 100)}
    while len(items) < limit:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if len(items) >= limit or "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    return items[:limit]


def _execution_sample(*, limit: int) -> list[dict[str, Any]]:
    return _scan_limited(ddb.transfer_executions_table(), limit=limit)


def _recent_failed_executions(items: list[dict[str, Any]], *, limit: int) -> list[dict[str, Any]]:
    failed = [i for i in items if str(i.get("status") or "").upper() == "FAILED"]
    failed.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
    return failed[:limit]


def _onboarding_pending_count() -> int:
    if os.environ.get("ENABLE_SELF_SERVICE_ONBOARDING", "").lower() not in (
        "1",
        "true",
        "yes",
    ):
        return 0
    try:
        items = _scan_limited(ddb.onboarding_requests_table(), limit=200)
        return sum(1 for i in items if i.get("status") == "SUBMITTED")
    except Exception:
        return 0


def _health_label(*, failed_execs: int, failed_transfers: int, pending_onb: int) -> str:
    if failed_execs > 0 or failed_transfers > 0:
        return "attention"
    if pending_onb > 5:
        return "busy"
    return "healthy"


def get_summary(*, transfer_sample: int = 200, recent_limit: int = 8) -> dict[str, Any]:
    transfer_sample = min(max(transfer_sample, 10), 500)
    recent_limit = min(max(recent_limit, 1), 25)

    partners = _scan_limited(ddb.partners_table(), limit=500)
    endpoints = _scan_limited(ddb.endpoints_table(), limit=500)
    transfers = _scan_limited(ddb.transfer_requests_table(), limit=transfer_sample)

    status_counts: Counter[str] = Counter()
    type_counts: Counter[str] = Counter()
    for t in transfers:
        status_counts[str(t.get("status") or "UNKNOWN")] += 1
        tt = t.get("transfer_type")
        if tt:
            type_counts[str(tt)] += 1

    transfers_sorted = sorted(
        transfers,
        key=lambda x: str(x.get("created_at") or ""),
        reverse=True,
    )
    recent_transfers = [
        {
            "request_id": t.get("request_id"),
            "partner_id": t.get("partner_id"),
            "transfer_type": t.get("transfer_type"),
            "status": t.get("status"),
            "created_at": t.get("created_at"),
        }
        for t in transfers_sorted[:recent_limit]
    ]

    exec_sample = _execution_sample(limit=300)
    exec_counts: Counter[str] = Counter(
        str(ex.get("status") or "UNKNOWN").upper() for ex in exec_sample
    )
    exec_statuses = ("SUCCEEDED", "FAILED", "QUEUED", "RUNNING", "IN_PROGRESS")
    execution_by_status = {s: exec_counts.get(s, 0) for s in exec_statuses}
    for st, count in exec_counts.items():
        if st not in execution_by_status:
            execution_by_status[st] = count
    failed_recent = _recent_failed_executions(
        exec_sample,
        limit=min(recent_limit, 10),
    )

    pending_onb = _onboarding_pending_count()
    failed_xfer = status_counts.get("FAILED", 0)
    failed_exec = execution_by_status.get("FAILED", 0)

    return {
        "ok": True,
        "status_code": 200,
        "body": {
            "generated_at": ddb.now_iso(),
            "health": _health_label(
                failed_execs=failed_exec,
                failed_transfers=failed_xfer,
                pending_onb=pending_onb,
            ),
            "counts": {
                "partners": len(partners),
                "endpoints": len(endpoints),
                "transfers_sampled": len(transfers),
                "onboarding_pending": pending_onb,
            },
            "transfers": {
                "by_status": dict(status_counts),
                "by_type": dict(type_counts),
            },
            "executions": {
                "by_status": execution_by_status,
                "failed_recent": failed_recent,
            },
            "recent_transfers": recent_transfers,
        },
    }
