"""Core domain constants and lightweight helpers."""

from enum import Enum


class TransferType(str, Enum):
    S3_TO_S3 = "S3_TO_S3"
    S3_TO_SFTP = "S3_TO_SFTP"
    SFTP_TO_S3 = "SFTP_TO_S3"
    SFTP_TO_SFTP = "SFTP_TO_SFTP"


ALLOWED_COMBINATIONS = frozenset(
    {
        TransferType.S3_TO_S3,
        TransferType.S3_TO_SFTP,
        TransferType.SFTP_TO_S3,
        TransferType.SFTP_TO_SFTP,
    }
)


def is_allowed_transfer_type(value: str) -> bool:
    try:
        return TransferType(value) in ALLOWED_COMBINATIONS
    except ValueError:
        return False
