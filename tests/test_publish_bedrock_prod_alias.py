"""Tests for Bedrock prod alias publish helper logic."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import publish_bedrock_prod_alias as pub  # noqa: E402


def test_latest_numeric_version_picks_max():
    client = MagicMock()
    client.list_agent_versions.return_value = {
        "agentVersionSummaries": [
            {"agentVersion": "DRAFT"},
            {"agentVersion": "2"},
            {"agentVersion": "1"},
        ]
    }
    assert pub._latest_numeric_version(client, "AGENT1") == "2"


def test_latest_numeric_version_none_when_only_draft():
    client = MagicMock()
    client.list_agent_versions.return_value = {"agentVersionSummaries": [{"agentVersion": "DRAFT"}]}
    assert pub._latest_numeric_version(client, "AGENT1") is None
