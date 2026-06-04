# transfer_family_connector (Phase 2)

Terraform for AWS Transfer Family **SFTP connectors** (S3 ↔ remote SFTP) will live here. Use:

- `aws_transfer_connector` for managed S3-to-partner-SFTP and partner-to-S3 pulls.
- VPC or service-managed egress per partner network requirements.

Wire connector IDs into the `workflow` Lambda or Fargate task environment; call `StartFileTransfer` from Step Functions via Lambda or SDK integration.
