terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

data "aws_region" "current" {}

resource "aws_cognito_user_pool" "api" {
  name = "${var.name_prefix}-api-users"

  schema {
    name                     = "partner_id"
    attribute_data_type    = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags

  # Cognito does not allow adding/removing schema attributes on an existing pool.
  lifecycle {
    ignore_changes = [schema]
  }
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "${var.name_prefix}-api-client"
  user_pool_id = aws_cognito_user_pool.api.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "user_pool_id" {
  value = aws_cognito_user_pool.api.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.api.arn
}

output "client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "issuer" {
  value = "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.api.id}"
}

resource "aws_cognito_user_group" "operators" {
  name         = "bayrelay-operators"
  user_pool_id = aws_cognito_user_pool.api.id
  description  = "BayRelay operators — full portal and API access"
}

resource "aws_cognito_user_group" "partners" {
  name         = "bayrelay-partners"
  user_pool_id = aws_cognito_user_pool.api.id
  description  = "Trading partners — scoped to custom:partner_id"
}

output "operator_group_name" {
  value = aws_cognito_user_group.operators.name
}

output "partner_group_name" {
  value = aws_cognito_user_group.partners.name
}
