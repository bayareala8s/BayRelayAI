"""Ensure utility scripts are syntactically valid (no boto3 calls)."""

from __future__ import annotations

import py_compile
from pathlib import Path


def test_phase3_scripts_compile() -> None:
    root = Path(__file__).resolve().parents[1]
    for name in (
        "scripts/aoss_create_kb_index.py",
        "scripts/prepare_bedrock_agent.py",
        "scripts/start_kb_ingestion.py",
        "scripts/test_retrieval.py",
        "modules/bedrock_agent/scripts/disable_action_group.py",
    ):
        py_compile.compile(str(root / name), doraise=True)
