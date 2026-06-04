# ecs_fargate (Phase 2)

Module for:

- ECS cluster, Fargate task definition, and private subnets for workers.
- Step Functions `arn:aws:states:::ecs:runTask.sync` patterns for long-running transfers, PGP, and checksums.

The reference worker image is under `app/workers/fargate/`.
