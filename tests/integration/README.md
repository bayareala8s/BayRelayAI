# Integration tests

End-to-end checks against the deployed production stack (AWS credentials + `terraform apply` in `environments/`):

- Run from repo root: `AWS_REGION=us-west-2 ./scripts/run_full_demo.sh`
- With JWT: set `COGNITO_CLIENT_ID`, `COGNITO_USERNAME`, `COGNITO_PASSWORD`
- Skip KB phase: `SKIP_KB_PHASE=1 ./scripts/run_full_demo.sh`

See [docs/DEMO.md](../docs/DEMO.md) and [docs/PRODUCTION.md](../docs/PRODUCTION.md).
