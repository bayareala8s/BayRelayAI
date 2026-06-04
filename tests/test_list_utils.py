from list_utils import filter_items, sort_items


def test_filter_by_status_and_q():
    items = [
        {"partner_id": "P1", "name": "Acme", "status": "ACTIVE"},
        {"partner_id": "P2", "name": "Beta", "status": "DISABLED"},
    ]
    out = filter_items(items, q="acme", status="ACTIVE", search_fields=("name", "partner_id"))
    assert len(out) == 1
    assert out[0]["partner_id"] == "P1"


def test_sort_items_desc():
    items = [
        {"created_at": "2024-01-02", "id": "b"},
        {"created_at": "2024-01-03", "id": "a"},
    ]
    out = sort_items(items, sort="created_at", order="desc")
    assert out[0]["id"] == "a"
