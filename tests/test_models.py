import sys
from pathlib import Path

# Prefer canonical shared package
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "shared"))

from bayrelay import models  # noqa: E402


def test_transfer_types() -> None:
    assert models.is_allowed_transfer_type("S3_TO_S3")
    assert models.is_allowed_transfer_type("S3_TO_SFTP")
    assert models.is_allowed_transfer_type("SFTP_TO_S3")
    assert models.is_allowed_transfer_type("SFTP_TO_SFTP")
    assert not models.is_allowed_transfer_type("FTP_TO_GCS")


def test_enum_values() -> None:
    assert models.TransferType.S3_TO_SFTP.value == "S3_TO_SFTP"
