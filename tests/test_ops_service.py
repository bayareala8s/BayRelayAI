"""Unit tests for operations dashboard summary."""

from __future__ import annotations

import os
import sys
from typing import Any
from unittest.mock import patch

import pytest

_ROOT = os.path.join(os.path.dirname(__file__), "..", "app", "lambdas", "unified")
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

import ops_service  # noqa: E402


class _FakeTable:
    def __init__(self, items: list[dict[str, Any]] | None = None) -> None:
        self._items = list(items or [])

    def scan(self, **kwargs: Any) -> dict[str, Any]:
        limit = kwargs.get("Limit", 100)
        return {"Items": self._items[:limit]}

    def query(self, **kwargs: Any) -> dict[str, Any]:
        if kwargs.get("Select") == "COUNT":
            status = kwargs.get("ExpressionAttributeValues", {}).get(":st")
            if status is None:
                # Key().eq("FAILED") path — boto3 uses :st in our service
                for v in kwargs.get("ExpressionAttributeValues", {}).values():
                    status = v
            count = sum(1 for i in self._items if i.get("status") == status)
            return {"Count": count}
        status = "FAILED"
        for v in (kwargs.get("ExpressionAttributeValues") or {}).values():
            status = v
        matched = [i for i in self._items if i.get("status") == status]
        matched.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        limit = kwargs.get("Limit", 10)
        return {"Items": matched[:limit]}


@pytest.fixture
def ops_env(monkeypatch: pytest.MonkeyPatch) -> None:
    transfers = [
        {
            "request_id": "TRQ-1",
            "status": "SUCCEEDED",
            "transfer_type": "S3_TO_S3",
            "created_at": "2026-05-31T10:00:00Z",
        },
        {
            "request_id": "TRQ-2",
            "status": "FAILED",
            "transfer_type": "S3_TO_SFTP",
            "created_at": "2026-05-31T09:00:00Z",
        },
    ]
    executions = [
        {
            "execution_id": "EX-1",
            "status": "SUCCEEDED",
            "created_at": "2026-05-31T10:00:00Z",
        },
        {
            "execution_id": "EX-2",
            "status": "FAILED",
            "request_id": "TRQ-2",
            "created_at": "2026-05-31T09:00:00Z",
        },
    ]
    monkeypatch.setenv("TRANSFER_EXECUTIONS_STATUS_GSI", "status-created_at")
    monkeypatch.setenv("ENABLE_SELF_SERVICE_ONBOARDING", "false")
    monkeypatch.setattr(
        ops_service.ddb,
        "transfer_requests_table",
        lambda: _FakeTable(transfers),
    )
    monkeypatch.setattr(
        ops_service.ddb,
        "transfer_executions_table",
        lambda: _FakeTable(executions),
    )
    monkeypatch.setattr(
        ops_service.ddb,
        "partners_table",
        lambda: _FakeTable([{"partner_id": "P1"}, {"partner_id": "P2"}]),
    )
    monkeypatch.setattr(
        ops_service.ddb,
        "endpoints_table",
        lambda: _FakeTable([{"endpoint_id": "E1"}]),
    )
    monkeypatch.setattr(ops_service.ddb, "now_iso", lambda: "2026-05-31T12:00:00Z")


def test_get_summary_aggregates(ops_env: None) -> None:
    result = ops_service.get_summary(transfer_sample=50, recent_limit=5)
    assert result["ok"] is True
    body = result["body"]
    assert body["counts"]["partners"] == 2
    assert body["counts"]["endpoints"] == 1
    assert body["transfers"]["by_status"]["SUCCEEDED"] == 1
    assert body["transfers"]["by_status"]["FAILED"] == 1
    assert body["health"] == "attention"
    assert len(body["executions"]["failed_recent"]) == 1
    assert body["recent_transfers"][0]["request_id"] == "TRQ-1"


def test_healthy_when_no_failures(ops_env: None) -> None:
    with patch.object(ops_service.ddb, "transfer_requests_table") as tr:
        tr.return_value = _FakeTable(
            [
                {
                    "request_id": "TRQ-ok",
                    "status": "SUCCEEDED",
                    "transfer_type": "S3_TO_S3",
                    "created_at": "2026-05-31T11:00:00Z",
                }
            ]
        )
        with patch.object(ops_service.ddb, "transfer_executions_table") as ex:
            ex.return_value = _FakeTable(
                [
                    {
                        "execution_id": "EX-ok",
                        "status": "SUCCEEDED",
                        "created_at": "2026-05-31T11:00:00Z",
                    }
                ]
            )
            body = ops_service.get_summary()["body"]
    assert body["health"] == "healthy"
