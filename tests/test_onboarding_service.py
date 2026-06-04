"""Unit tests for self-service onboarding service (in-memory DDB mocks)."""

from __future__ import annotations

import os
import sys
from typing import Any
import pytest

# Lambda package layout: app/lambdas/unified
_ROOT = os.path.join(os.path.dirname(__file__), "..", "app", "lambdas", "unified")
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

import onboarding_service  # noqa: E402


class _FakeTable:
    def __init__(self) -> None:
        self._items: dict[str, dict[str, Any]] = {}

    def put_item(self, *, Item: dict[str, Any]) -> None:
        key = self._key_from_item(Item)
        self._items[key] = dict(Item)

    def get_item(self, *, Key: dict[str, Any]) -> dict[str, Any]:
        key = self._key_from_key(Key)
        item = self._items.get(key)
        return {"Item": item} if item else {}

    def update_item(self, **kwargs: Any) -> None:
        key = self._key_from_key(kwargs["Key"])
        item = self._items.get(key)
        if not item:
            return
        values = kwargs.get("ExpressionAttributeValues", {})
        names = kwargs.get("ExpressionAttributeNames", {})
        for placeholder, val in values.items():
            field = placeholder.lstrip(":")
            if field in ("ap", "rj"):
                status_key = names.get("#st", "status")
                item[status_key] = val
            elif field == "pid":
                item["partner_id"] = val
            elif field == "rr":
                item["rejection_reason"] = val
            elif field == "rb":
                item["reviewed_by"] = val
            elif field in ("ra", "ua"):
                if field == "ra":
                    item["reviewed_at"] = val
                item["updated_at"] = val
        self._items[key] = item

    def query(self, **kwargs: Any) -> dict[str, Any]:
        status = kwargs.get("ExpressionAttributeValues", {}).get(":st")
        items = [i for i in self._items.values() if i.get("status") == status]
        items.sort(key=lambda x: x.get("submitted_at", ""), reverse=True)
        limit = kwargs.get("Limit", 50)
        return {"Items": items[:limit]}

    def scan(self, **kwargs: Any) -> dict[str, Any]:
        items = list(self._items.values())
        items.sort(key=lambda x: x.get("submitted_at", ""), reverse=True)
        limit = kwargs.get("Limit", 50)
        return {"Items": items[:limit]}

    @staticmethod
    def _key_from_item(item: dict[str, Any]) -> str:
        for k in ("request_id", "partner_id", "endpoint_id"):
            if k in item:
                return item[k]
        raise KeyError(f"no known key in {item!r}")

    @staticmethod
    def _key_from_key(key: dict[str, Any]) -> str:
        for k in ("request_id", "partner_id", "endpoint_id"):
            if k in key:
                return key[k]
        raise KeyError(f"no known key in {key!r}")


@pytest.fixture
def ddb_tables(monkeypatch: pytest.MonkeyPatch) -> dict[str, _FakeTable]:
    onb = _FakeTable()
    partners = _FakeTable()
    endpoints = _FakeTable()
    audit: list[dict[str, Any]] = []

    monkeypatch.setattr(onboarding_service.ddb, "onboarding_requests_table", lambda: onb)
    monkeypatch.setattr(onboarding_service.ddb, "partners_table", lambda: partners)
    monkeypatch.setattr(onboarding_service.ddb, "endpoints_table", lambda: endpoints)
    monkeypatch.setattr(
        onboarding_service.ddb,
        "put_audit",
        lambda **kw: audit.append(kw),
    )
    monkeypatch.setattr(onboarding_service.ddb, "new_id", lambda prefix: f"{prefix}-testid")
    monkeypatch.setattr(onboarding_service.ddb, "now_iso", lambda: "2026-05-31T12:00:00Z")

    return {"onb": onb, "partners": partners, "endpoints": endpoints, "audit": audit}


def test_create_request_requires_company(ddb_tables: dict) -> None:
    result = onboarding_service.create_request(body={}, submitted_by="op@example.com")
    assert result["ok"] is False
    assert result["status_code"] == 400


def test_create_and_approve_flow(ddb_tables: dict) -> None:
    created = onboarding_service.create_request(
        body={
            "company_name": "Acme Corp",
            "contact_email": "edi@acme.example",
            "transfer_types": ["S3_TO_S3"],
        },
        submitted_by="demo@bayareala8s.com",
    )
    assert created["ok"] is True
    assert created["status_code"] == 201
    rid = created["body"]["onboarding_request"]["request_id"]

    listed = onboarding_service.list_requests(status="SUBMITTED")
    assert listed["body"]["count"] == 1

    approved = onboarding_service.approve_request(
        request_id=rid,
        reviewer="reviewer@example.com",
        body={},
    )
    assert approved["ok"] is True
    assert approved["body"]["partner_id"] == "PRT-testid"
    assert len(approved["body"]["endpoint_ids"]) == 2

    got = onboarding_service.get_request(rid)
    assert got["body"]["onboarding_request"]["status"] == "APPROVED"


def test_reject_request(ddb_tables: dict) -> None:
    created = onboarding_service.create_request(
        body={"company_name": "Reject Me"},
        submitted_by="op@example.com",
    )
    rid = created["body"]["onboarding_request"]["request_id"]
    result = onboarding_service.reject_request(
        request_id=rid,
        reviewer="op@example.com",
        body={"reason": "Incomplete documentation"},
    )
    assert result["ok"] is True
    assert result["body"]["status"] == "REJECTED"


def test_cannot_approve_twice(ddb_tables: dict) -> None:
    created = onboarding_service.create_request(
        body={"company_name": "Once Only"},
        submitted_by="op@example.com",
    )
    rid = created["body"]["onboarding_request"]["request_id"]
    onboarding_service.approve_request(
        request_id=rid, reviewer="op@example.com", body={}
    )
    again = onboarding_service.approve_request(
        request_id=rid, reviewer="op@example.com", body={}
    )
    assert again["ok"] is False
    assert again["status_code"] == 409


def test_invalid_endpoint_validation(ddb_tables: dict) -> None:
    result = onboarding_service.create_request(
        body={
            "company_name": "Bad EP",
            "endpoints": [{"protocol": "FTP", "direction": "SIDEWAYS"}],
        },
        submitted_by="op@example.com",
    )
    assert result["ok"] is False
    assert result["status_code"] == 400
