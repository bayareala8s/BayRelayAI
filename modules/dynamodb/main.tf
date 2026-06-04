terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

resource "aws_dynamodb_table" "partners" {
  name         = "${var.name_prefix}-partners"
  billing_mode = var.billing_mode
  hash_key     = "partner_id"

  attribute {
    name = "partner_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "endpoints" {
  name         = "${var.name_prefix}-endpoints"
  billing_mode = var.billing_mode
  hash_key     = "endpoint_id"

  attribute {
    name = "endpoint_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "transfer_requests" {
  name         = "${var.name_prefix}-transfer-requests"
  billing_mode = var.billing_mode
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "transfer_executions" {
  name         = "${var.name_prefix}-transfer-executions"
  billing_mode = var.billing_mode
  hash_key     = "execution_id"

  attribute {
    name = "execution_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "status-created_at"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "audit_events" {
  name         = "${var.name_prefix}-audit-events"
  billing_mode = var.billing_mode
  hash_key     = "audit_id"

  attribute {
    name = "audit_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "routing_policies" {
  name         = "${var.name_prefix}-routing-policies"
  billing_mode = var.billing_mode
  hash_key     = "policy_id"
  range_key    = "partner_id"

  attribute {
    name = "policy_id"
    type = "S"
  }

  attribute {
    name = "partner_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "idempotency_keys" {
  name         = "${var.name_prefix}-idempotency-keys"
  billing_mode = var.billing_mode
  hash_key     = "idempotency_key"

  attribute {
    name = "idempotency_key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = var.idempotency_ttl_enabled
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "pitr" {
  type    = bool
  default = true
}

variable "idempotency_ttl_enabled" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "partners_arn" {
  value = aws_dynamodb_table.partners.arn
}

output "endpoints_arn" {
  value = aws_dynamodb_table.endpoints.arn
}

output "transfer_requests_arn" {
  value = aws_dynamodb_table.transfer_requests.arn
}

output "transfer_executions_arn" {
  value = aws_dynamodb_table.transfer_executions.arn
}

output "audit_events_arn" {
  value = aws_dynamodb_table.audit_events.arn
}

output "routing_policies_arn" {
  value = aws_dynamodb_table.routing_policies.arn
}

output "idempotency_keys_arn" {
  value = aws_dynamodb_table.idempotency_keys.arn
}

output "partners_name" {
  value = aws_dynamodb_table.partners.name
}

output "endpoints_name" {
  value = aws_dynamodb_table.endpoints.name
}

output "transfer_requests_name" {
  value = aws_dynamodb_table.transfer_requests.name
}

output "transfer_executions_name" {
  value = aws_dynamodb_table.transfer_executions.name
}

output "audit_events_name" {
  value = aws_dynamodb_table.audit_events.name
}

output "routing_policies_name" {
  value = aws_dynamodb_table.routing_policies.name
}

output "idempotency_keys_name" {
  value = aws_dynamodb_table.idempotency_keys.name
}

resource "aws_dynamodb_table" "onboarding_requests" {
  name         = "${var.name_prefix}-onboarding-requests"
  billing_mode = var.billing_mode
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "submitted_at"
    type = "S"
  }

  global_secondary_index {
    name            = "status-submitted_at"
    hash_key        = "status"
    range_key       = "submitted_at"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

output "onboarding_requests_arn" {
  value = aws_dynamodb_table.onboarding_requests.arn
}

output "onboarding_requests_name" {
  value = aws_dynamodb_table.onboarding_requests.name
}

output "transfer_executions_status_gsi_name" {
  value = "status-created_at"
}

resource "aws_dynamodb_table" "transfer_rules" {
  name         = "${var.name_prefix}-transfer-rules"
  billing_mode = var.billing_mode
  hash_key     = "rule_id"

  attribute {
    name = "rule_id"
    type = "S"
  }

  attribute {
    name = "partner_id"
    type = "S"
  }

  attribute {
    name = "priority"
    type = "N"
  }

  global_secondary_index {
    name            = "partner_id-priority"
    hash_key        = "partner_id"
    range_key       = "priority"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr
  }

  tags = var.tags
}

output "transfer_rules_arn" {
  value = aws_dynamodb_table.transfer_rules.arn
}

output "transfer_rules_name" {
  value = aws_dynamodb_table.transfer_rules.name
}
