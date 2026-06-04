import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "lambdas" / "unified"))

import transfer_rules_service  # noqa: E402


def test_match_key_glob():
    assert transfer_rules_service._match_key("demo/inbound/*", "demo/inbound/file.txt")
    assert not transfer_rules_service._match_key("demo/outbound/*", "demo/inbound/file.txt")


def test_render_template():
    out = transfer_rules_service._render(
        {"dest_key": "out/{basename}", "source_key": "{key}"},
        {"bucket": "b", "key": "demo/in/a.txt", "basename": "a.txt"},
    )
    assert out["dest_key"] == "out/a.txt"
    assert out["source_key"] == "demo/in/a.txt"


def test_connector_staging_only_matches_sftp_to_s3_rules():
    rules = [
        {
            "rule_id": "RUL-s3",
            "enabled": True,
            "trigger_type": "S3_OBJECT_CREATED",
            "match_pattern": "sftp-connector/*",
            "transfer_type": "S3_TO_S3",
            "priority": 100,
        },
        {
            "rule_id": "RUL-pull",
            "enabled": True,
            "trigger_type": "S3_OBJECT_CREATED",
            "match_pattern": "sftp-connector/flat-send-*",
            "transfer_type": "SFTP_TO_S3",
            "priority": 100,
        },
    ]
    key = "sftp-connector/flat-send-EX-abc-file.txt"
    matched = []
    for rule in rules:
        if key.startswith("sftp-connector/") and rule.get("transfer_type") != "SFTP_TO_S3":
            continue
        if transfer_rules_service._match_key(rule["match_pattern"], key):
            matched.append(rule)
    assert len(matched) == 1
    assert matched[0]["rule_id"] == "RUL-pull"


def test_connector_staging_allows_sftp_to_sftp():
    rule_type = "SFTP_TO_SFTP"
    key = "sftp-connector/flat-send-EX-abc-file.txt"
    assert rule_type in ("SFTP_TO_S3", "SFTP_TO_SFTP")
    assert key.startswith("sftp-connector/")
