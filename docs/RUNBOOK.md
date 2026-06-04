# Operations runbook

## Failed transfers

1. Note `correlation_id` from the API response or DynamoDB `transfer_requests` / `transfer_executions`.
2. In **Step Functions**, open the failed execution; identify the failing state (precheck vs child workflow).
3. For **S3_TO_S3** failures, check Lambda `workflow` logs in CloudWatch for `SOURCE_UNAVAILABLE`, `VALIDATION_ERROR`, or boto client errors.
4. For **S3_TO_SFTP** / **SFTP_TO_S3** / **SFTP_TO_SFTP**, check `workflow` Lambda logs for `StartFileTransfer` / connector errors and IAM on the connector access role.

## Connector or SFTP issues (Phase 2)

- Verify Transfer Family connector VPC / service-managed egress matches partner allow lists.
- Rotate secrets via Secrets Manager and `rotateCredentialReference` (to be implemented) without logging secret material.

## Knowledge base sync failures

- Confirm documents in the KB source bucket and KMS permissions for Bedrock ingestion roles.
- Re-run ingestion job; if embeddings fail, check vector store capacity and IAM.

## Agent troubleshooting

- Confirm action group Lambda permission allows `bedrock.amazonaws.com` with correct `source_arn`.
- Use CloudWatch Logs for `agent_tools` and `api` Lambdas; enable Bedrock trace in `InvokeAgent` (already enabled in code) for tool and KB visibility.
- Never rely on the model for live IDs; use `getTransferStatus` and DynamoDB.

## Alarms

Subscribe operations email/SMS to the SNS topic output `alarm_topic_arn`. Lambda error alarms fire on threshold breaches (default: any error in 5 minutes).

## Idempotency

Duplicate `x-idempotency-key` values return the original `request_id` without starting a second execution.
