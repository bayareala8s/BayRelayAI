terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
  }
}

# SFTP connectors require trusted host keys. For the self-demo (connector → same Transfer server),
# discover the server's RSA host key at apply time. Override with connector_trusted_host_keys when
# apply environments have no outbound SSH (CI) or the remote host is not this server.
data "external" "connector_trusted_host_key" {
  count = var.enable_connector && length(var.connector_trusted_host_keys) == 0 ? 1 : 0

  program = ["bash", "${path.module}/fetch_sftp_trusted_host_key.sh"]

  query = {
    endpoint = aws_transfer_server.this.endpoint
    port     = "22"
  }
}

locals {
  connector_trusted_host_key_from_scan = (
    var.enable_connector && length(var.connector_trusted_host_keys) == 0
    ? data.external.connector_trusted_host_key[0].result.key
    : null
  )
  connector_trusted_host_keys_resolved = (
    length(var.connector_trusted_host_keys) > 0 ? var.connector_trusted_host_keys : (
      local.connector_trusted_host_key_from_scan != null ? [local.connector_trusted_host_key_from_scan] : []
    )
  )
}

# --- Inbound SFTP user (FileZilla / partner uploads → S3) ---

resource "tls_private_key" "inbound" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "inbound_private_key" {
  name                    = "${var.name_prefix}-sftp-inbound-private-key"
  recovery_window_in_days = var.secret_recovery_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "inbound_private_key" {
  secret_id     = aws_secretsmanager_secret.inbound_private_key.id
  secret_string = tls_private_key.inbound.private_key_pem
}

resource "aws_iam_role" "transfer_inbound" {
  name = "${var.name_prefix}-transfer-inbound"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "transfer.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_inbound_s3" {
  name = "${var.name_prefix}-transfer-inbound-s3"
  role = aws_iam_role.transfer_inbound.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["${var.inbound_prefix}*", trimsuffix(var.inbound_prefix, "/")] }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "${var.bucket_arn}/${var.inbound_prefix}*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_transfer_server" "this" {
  protocols              = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  domain                 = "S3"
  logging_role           = var.logging_role_arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-sftp" })
}

resource "aws_transfer_user" "inbound" {
  server_id           = aws_transfer_server.this.id
  user_name           = var.inbound_username
  role                = aws_iam_role.transfer_inbound.arn
  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${var.bucket_id}/${trimsuffix(var.inbound_prefix, "/")}"
  }

  tags = var.tags
}

resource "aws_transfer_ssh_key" "inbound" {
  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.inbound.user_name
  body      = tls_private_key.inbound.public_key_openssh
}

# --- Connector user + connector (S3 ↔ same server self-demo) ---

resource "tls_private_key" "connector" {
  count     = var.enable_connector ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "connector_creds" {
  count                   = var.enable_connector ? 1 : 0
  name                    = "${var.name_prefix}-sftp-connector-secret"
  recovery_window_in_days = var.secret_recovery_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "connector_creds" {
  count     = var.enable_connector ? 1 : 0
  secret_id = aws_secretsmanager_secret.connector_creds[0].id
  secret_string = jsonencode({
    Username   = var.connector_username
    PrivateKey = tls_private_key.connector[0].private_key_openssh
  })
}

resource "aws_iam_role" "transfer_connector_user" {
  count = var.enable_connector ? 1 : 0
  name  = "${var.name_prefix}-transfer-connector-user"

  # Trust transfer.amazonaws.com for this account only. Do not ArnLike SourceArn: some API paths
  # (direct SFTP vs connector) use different resource ARNs; omitting avoids "Unable to AssumeRole for user".
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "transfer.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_connector_user_s3" {
  count = var.enable_connector ? 1 : 0
  name  = "${var.name_prefix}-transfer-connector-user-s3"
  role  = aws_iam_role.transfer_connector_user[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = [
          "${var.bucket_arn}/${var.connector_prefix}*",
          "${var.bucket_arn}/${var.staging_prefix}*",
          "${var.bucket_arn}/${var.inbound_prefix}*",
          "${var.bucket_arn}/flat-send-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_transfer_user" "connector" {
  count               = var.enable_connector ? 1 : 0
  server_id           = aws_transfer_server.this.id
  user_name           = var.connector_username
  role                = aws_iam_role.transfer_connector_user[0].arn
  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${var.bucket_id}/${trimsuffix(var.connector_prefix, "/")}"
  }

  tags = var.tags
}

resource "aws_transfer_ssh_key" "connector" {
  count     = var.enable_connector ? 1 : 0
  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.connector[0].user_name
  body      = tls_private_key.connector[0].public_key_openssh
}

resource "aws_iam_role" "connector_access" {
  count = var.enable_connector ? 1 : 0
  name  = "${var.name_prefix}-transfer-connector-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "transfer.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "connector_access_s3" {
  count = var.enable_connector ? 1 : 0
  name  = "${var.name_prefix}-connector-access-s3"
  role  = aws_iam_role.connector_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.connector_creds[0].arn
      }
    ]
  })
}

resource "aws_transfer_connector" "this" {
  count        = var.enable_connector ? 1 : 0
  access_role  = aws_iam_role.connector_access[0].arn
  url          = "sftp://${aws_transfer_server.this.endpoint}:22"
  logging_role = var.logging_role_arn

  sftp_config {
    user_secret_id    = aws_secretsmanager_secret.connector_creds[0].id
    trusted_host_keys = local.connector_trusted_host_keys_resolved
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-sftp-connector" })
}

data "aws_iam_policy_document" "transfer_bucket" {
  statement {
    sid    = "AllowTransferServer"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObjectACL",
      "s3:PutObjectACL",
      "s3:GetBucketLocation",
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_transfer_server.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "transfer" {
  bucket = var.bucket_id
  policy = data.aws_iam_policy_document.transfer_bucket.json
}

variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_id" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "inbound_username" {
  type    = string
  default = "bayrelay-demo"
}

variable "connector_username" {
  type    = string
  default = "bayrelay-connector"
}

variable "inbound_prefix" {
  type    = string
  default = "sftp-inbound/"
}

variable "connector_prefix" {
  type    = string
  default = "sftp-connector/"
}

variable "staging_prefix" {
  type    = string
  default = "sftp-staging/"
}

variable "enable_connector" {
  type    = bool
  default = true
}

# OpenSSH-format lines: "ssh-rsa AAAA..." (no hostname prefix). When empty and enable_connector is
# true, the module runs ssh-keyscan against this stack's Transfer server endpoint at apply time.
variable "connector_trusted_host_keys" {
  type        = list(string)
  default     = []
  description = "Trusted SFTP host keys for the connector. Leave empty to auto-fetch RSA key from the managed Transfer server (requires outbound ssh-keyscan during apply)."
}

variable "secret_recovery_days" {
  type    = number
  default = 0
}

variable "logging_role_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "server_id" {
  value = aws_transfer_server.this.id
}

output "server_endpoint" {
  value = aws_transfer_server.this.endpoint
}

output "inbound_username" {
  value = aws_transfer_user.inbound.user_name
}

output "inbound_private_key_secret_arn" {
  value     = aws_secretsmanager_secret.inbound_private_key.arn
  sensitive = true
}

output "connector_id" {
  value = var.enable_connector ? aws_transfer_connector.this[0].id : ""
}

output "connector_arn" {
  value = var.enable_connector ? aws_transfer_connector.this[0].arn : ""
}

output "connector_secret_arn" {
  value     = var.enable_connector ? aws_secretsmanager_secret.connector_creds[0].arn : ""
  sensitive = true
}

output "inbound_s3_prefix" {
  value = var.inbound_prefix
}

output "connector_s3_prefix" {
  value = var.connector_prefix
}

output "staging_s3_prefix" {
  value = var.staging_prefix
}
