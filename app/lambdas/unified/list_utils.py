"""Shared list filtering, sorting, and search for API list endpoints."""

from __future__ import annotations

from typing import Any, Callable


def _field_text(item: dict[str, Any], key: str) -> str:
    val = item.get(key)
    if val is None:
        return ""
    if isinstance(val, (dict, list)):
        return str(val)
    return str(val).lower()


def filter_items(
    items: list[dict[str, Any]],
    *,
    q: str | None = None,
    status: str | None = None,
    partner_id: str | None = None,
    search_fields: tuple[str, ...] = (),
) -> list[dict[str, Any]]:
    out = items
    if partner_id:
        out = [i for i in out if i.get("partner_id") == partner_id]
    if status:
        st = status.upper()
        out = [i for i in out if str(i.get("status") or "").upper() == st]
    if q:
        needle = q.strip().lower()
        if needle:
            fields = search_fields or tuple(
                k for k in (out[0].keys() if out else []) if k not in ("payload", "metadata", "detail")
            )

            def matches(item: dict[str, Any]) -> bool:
                for f in fields:
                    if needle in _field_text(item, f):
                        return True
                return False

            out = [i for i in out if matches(i)]
    return out


def sort_items(
    items: list[dict[str, Any]],
    *,
    sort: str | None = None,
    order: str | None = None,
    default_sort: str = "created_at",
) -> list[dict[str, Any]]:
    key = (sort or default_sort).strip()
    reverse = (order or "desc").lower() != "asc"

    def sort_key(item: dict[str, Any]) -> Any:
        val = item.get(key)
        if val is None:
            return ""
        return val

    try:
        return sorted(items, key=sort_key, reverse=reverse)
    except TypeError:
        return sorted(items, key=lambda x: str(sort_key(x)), reverse=reverse)
