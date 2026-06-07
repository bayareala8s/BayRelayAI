import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "lambdas" / "unified"))

import routing_policies_service  # noqa: E402


def test_list_policies_scans_with_partner_filter():
    table = MagicMock()
    table.scan.return_value = {
        "Items": [{"policy_id": "default", "partner_id": "PRT-acme", "effect": "ALLOW"}],
    }
    with patch.object(routing_policies_service.ddb, "routing_policies_table", return_value=table):
        result = routing_policies_service.list_policies(partner_id="PRT-acme", limit=10)

    assert result["ok"] is True
    assert result["body"]["count"] == 1
    kwargs = table.scan.call_args.kwargs
    assert "FilterExpression" in kwargs
    assert kwargs["ExpressionAttributeValues"][":p"] == "PRT-acme"
    table.query.assert_not_called()
