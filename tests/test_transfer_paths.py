"""Contract tests for Transfer Family S3 path formatting (mirrors workflow._transfer_s3_uri)."""


def transfer_s3_uri(bucket: str, *key_parts: str) -> str:
    tail = "/".join(p.strip("/") for p in key_parts if p)
    b = bucket.strip("/")
    return f"/{b}/{tail}" if tail else f"/{b}"


def test_transfer_s3_uri_bucket_and_key() -> None:
    assert transfer_s3_uri("my-bucket", "a", "b.txt") == "/my-bucket/a/b.txt"


def test_transfer_s3_uri_strips_slashes() -> None:
    assert transfer_s3_uri("/bucket/", "/p/", "q/") == "/bucket/p/q"


def test_transfer_s3_uri_bucket_only() -> None:
    assert transfer_s3_uri("bucket") == "/bucket"


def test_transfer_s3_uri_flat_send_shape() -> None:
    assert transfer_s3_uri("b", "flat-send-EX-abc-file.txt") == "/b/flat-send-EX-abc-file.txt"
