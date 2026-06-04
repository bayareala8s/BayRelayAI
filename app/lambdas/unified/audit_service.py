"""Audit event listing for operators."""

from __future__ import annotations

from typing import Any

import ddb
from list_utils import filter_items, sort_items


def list_audit_events(
    *,
    limit: int = 50,
    q: str | None = None,
    correlation_id: str | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    table = ddb.audit_events_table()
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {"Limit": min(limit * 3, 300)}
    while len(items) < limit * 3:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    if correlation_id:
        items = [i for i in items if i.get("correlation_id") == correlation_id]
    items = filter_items(
        items,
        q=q,
        search_fields=("audit_id", "action", "actor", "correlation_id"),
    )
    items = sort_items(items, sort=sort, order=order, default_sort="timestamp")
    items = items[:limit]
    return {"ok": True, "status_code": 200, "body": {"events": items, "count": len(items)}}
