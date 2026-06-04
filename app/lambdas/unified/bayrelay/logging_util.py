import json
import logging
import os
import time
import uuid
from typing import Any

_LOG = logging.getLogger(__name__)


def setup_logging(level: str | None = None) -> None:
    lvl = level or os.environ.get("LOG_LEVEL", "INFO")
    logging.basicConfig(
        level=getattr(logging, lvl.upper(), logging.INFO),
        format="%(message)s",
    )


def structured_log(
    *,
    message: str,
    correlation_id: str | None = None,
    **fields: Any,
) -> None:
    correlation_id = correlation_id or str(uuid.uuid4())
    payload = {
        "ts": time.time(),
        "message": message,
        "correlation_id": correlation_id,
        **fields,
    }
    _LOG.info(json.dumps(payload, default=str))
