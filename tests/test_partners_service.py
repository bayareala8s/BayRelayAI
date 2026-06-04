import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "lambdas" / "unified"))

import partners_service


def test_delete_partner_soft_disables():
    table = MagicMock()
    table.get_item.return_value = {
        "Item": {"partner_id": "P1", "name": "Acme", "status": "ACTIVE"}
    }
    with patch("partners_service.ddb.partners_table", return_value=table):
        result = partners_service.delete_partner("P1")
    assert result["ok"] is True
    saved = table.put_item.call_args[1]["Item"]
    assert saved["status"] == "DISABLED"
