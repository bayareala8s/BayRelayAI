import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "shared"))

from bayrelay import errors  # noqa: E402


def test_error_categories_complete() -> None:
    assert errors.VALIDATION_ERROR in errors.ALL_CATEGORIES
    assert errors.POLICY_DENIED in errors.ALL_CATEGORIES
    assert len(errors.ALL_CATEGORIES) >= 9
