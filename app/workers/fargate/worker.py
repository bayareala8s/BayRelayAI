"""
ECS Fargate worker entrypoint (Phase 2).
Run heavy SFTP, PGP, checksum, and long-running transfers started from Step Functions
via ECS RunTask / .sync integration.
"""

import json
import os
import sys
import time


def main() -> None:
    job = json.loads(os.environ.get("TRANSFER_JOB", "{}"))
    correlation_id = job.get("correlation_id", "unknown")
    print(json.dumps({"message": "worker_stub", "correlation_id": correlation_id, "ts": time.time()}))
    # Phase 2: implement paramiko/ssh, PGP, streaming copy, progress to DynamoDB.
    sys.exit(0)


if __name__ == "__main__":
    main()
