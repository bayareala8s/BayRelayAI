locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = {
    Project     = var.project
    Environment = var.environment
    Layer       = "D-production-deployment"
  }
  bedrock_agent_alias_id = var.bedrock_agent_alias_id
  http_api_public_url    = var.enable_cloudfront_waf ? module.cloudfront_api[0].public_api_url : aws_apigatewayv2_api.http.api_endpoint
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  _aoss_sts = regexall("^arn:aws:sts::([0-9]+):assumed-role/([^/]+)/", data.aws_caller_identity.current.arn)
  aoss_terraform_deployer_role_arn = length(local._aoss_sts) > 0 ? [
    format("arn:aws:iam::%s:role/%s", local._aoss_sts[0][0], local._aoss_sts[0][1])
  ] : []
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app/lambdas/unified"
  output_path = "${path.module}/.build/unified.zip"
}

module "kms" {
  source      = "../modules/kms"
  name_prefix = local.name_prefix
  tags        = local.tags
}

module "ddb" {
  source      = "../modules/dynamodb"
  name_prefix = local.name_prefix
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
}

module "transfer_data_bucket" {
  source        = "../modules/s3_bucket"
  bucket_name   = "${local.name_prefix}-transfer-data-${data.aws_caller_identity.current.account_id}"
  kms_key_arn   = module.kms.key_arn
  versioning    = true
  force_destroy = var.transfer_data_bucket_force_destroy
  tags          = local.tags
}

module "transfer_family" {
  count  = var.enable_transfer_family ? 1 : 0
  source = "../modules/transfer_family"

  name_prefix          = local.name_prefix
  account_id           = data.aws_caller_identity.current.account_id
  region               = data.aws_region.current.id
  bucket_id            = module.transfer_data_bucket.bucket_id
  bucket_arn           = module.transfer_data_bucket.bucket_arn
  kms_key_arn          = module.kms.key_arn
  tags                 = local.tags
  secret_recovery_days = 30

  connector_trusted_host_keys = var.connector_trusted_host_keys

  depends_on = [module.transfer_data_bucket, module.kms]
}

module "kb_source" {
  source        = "../modules/bedrock_knowledge_base"
  bucket_name   = "bayrelay-kb-source-${var.environment}-${data.aws_caller_identity.current.account_id}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = var.kb_force_destroy
  tags          = merge(local.tags, { Purpose = "bedrock-kb-source" })
}

module "networking" {
  source      = "../modules/networking"
  create_vpc  = var.create_vpc
  name_prefix = local.name_prefix
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  tags        = local.tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_data" {
  name = "${local.name_prefix}-lambda-data"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          module.ddb.partners_arn,
          module.ddb.endpoints_arn,
          module.ddb.transfer_requests_arn,
          module.ddb.transfer_executions_arn,
          "${module.ddb.transfer_executions_arn}/index/*",
          module.ddb.audit_events_arn,
          module.ddb.routing_policies_arn,
          module.ddb.idempotency_keys_arn,
          module.ddb.onboarding_requests_arn,
          "${module.ddb.onboarding_requests_arn}/index/*",
          module.ddb.transfer_rules_arn,
          "${module.ddb.transfer_rules_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.transfer_data_bucket.bucket_arn,
          "${module.transfer_data_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = "arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-sf-transfer-precheck"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:GetAgent",
          "bedrock:ListAgentAliases"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:agent/${module.bedrock_agent.agent_id}",
          "arn:aws:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:agent-alias/${module.bedrock_agent.agent_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = module.kms.key_arn
      }
    ]
  })
}

locals {
  transfer_connector_id = var.enable_transfer_family ? module.transfer_family[0].connector_id : ""
  sftp_server_endpoint  = var.enable_transfer_family ? module.transfer_family[0].server_endpoint : ""
  lambda_env_common = {
    ENABLE_API_JWT_AUTH            = var.enable_api_jwt_auth ? "true" : "false"
    AWS_ACCOUNT_ID                 = data.aws_caller_identity.current.account_id
    BAYRELAY_PREFIX                = local.name_prefix
    PARTNERS_TABLE                 = module.ddb.partners_name
    ENDPOINTS_TABLE                = module.ddb.endpoints_name
    TRANSFER_REQUESTS_TABLE        = module.ddb.transfer_requests_name
    TRANSFER_EXECUTIONS_TABLE      = module.ddb.transfer_executions_name
    AUDIT_EVENTS_TABLE             = module.ddb.audit_events_name
    ROUTING_POLICIES_TABLE         = module.ddb.routing_policies_name
    IDEMPOTENCY_KEYS_TABLE         = module.ddb.idempotency_keys_name
    ONBOARDING_REQUESTS_TABLE      = module.ddb.onboarding_requests_name
    TRANSFER_RULES_TABLE           = module.ddb.transfer_rules_name
    TRANSFER_DATA_BUCKET           = module.transfer_data_bucket.bucket_id
    TRANSFER_EXECUTIONS_STATUS_GSI = module.ddb.transfer_executions_status_gsi_name
    LOG_LEVEL                      = "INFO"
  }
}

resource "aws_lambda_function" "workflow" {
  function_name    = "${local.name_prefix}-workflow"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "workflow.lambda_handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300
  memory_size      = 256

  environment {
    variables = merge(local.lambda_env_common, {
      TRANSFER_CONNECTOR_ID = local.transfer_connector_id
      EVENT_BUS_NAME        = "default"
    })
  }

  tags = local.tags
}

resource "aws_lambda_function" "agent_tools" {
  function_name    = "${local.name_prefix}-agent-tools"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "agent_tools.lambda_handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = local.lambda_env_common
  }

  tags = local.tags
}

resource "aws_lambda_function" "api" {
  function_name    = "${local.name_prefix}-api"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "api.lambda_handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 120
  memory_size      = 512

  environment {
    variables = merge(local.lambda_env_common, {
      BEDROCK_AGENT_ID                = module.bedrock_agent.agent_id
      BEDROCK_AGENT_ALIAS_ID          = local.bedrock_agent_alias_id
      BAYRELAY_ALLOW_AGENT_TRACE      = var.allow_agent_trace_header ? "true" : "false"
      ENABLE_SELF_SERVICE_ONBOARDING  = var.enable_self_service_onboarding ? "true" : "false"
      ENABLE_TRANSFER_AUTOMATION      = var.enable_transfer_automation ? "true" : "false"
      ONBOARDING_AUTO_APPROVE         = var.onboarding_auto_approve ? "true" : "false"
      ENABLE_PUBLIC_ONBOARDING_SUBMIT = var.enable_public_onboarding_submit ? "true" : "false"
      COGNITO_USER_POOL_ID            = var.enable_api_jwt_auth ? module.cognito_api[0].user_pool_id : ""
    })
  }

  tags = local.tags

  depends_on = [module.bedrock_agent, aws_lambda_function.agent_tools]
}

resource "aws_iam_role" "sfn" {
  name = "${local.name_prefix}-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "sfn" {
  name = "${local.name_prefix}-sfn-policy"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.workflow.arn
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-sf-s3-to-s3",
          "arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-sf-s3-to-sftp",
          "arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-sf-sftp-to-s3",
          "arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.name_prefix}-sf-sftp-to-sftp"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = "*"
      }
    ]
  })
}

module "step_functions" {
  source              = "../modules/step_functions"
  name_prefix         = local.name_prefix
  workflow_lambda_arn = aws_lambda_function.workflow.arn
  sfn_role_arn        = aws_iam_role.sfn.arn
  tags                = local.tags

  depends_on = [aws_lambda_function.workflow, aws_iam_role_policy.sfn]
}

module "bedrock_agent" {
  source                    = "../modules/bedrock_agent"
  name_prefix               = local.name_prefix
  name_suffix               = var.environment
  foundation_model          = var.foundation_model
  agent_tools_lambda_arn    = aws_lambda_function.agent_tools.arn
  agent_tools_function_name = aws_lambda_function.agent_tools.function_name
  prepare_agent             = var.bedrock_prepare_agent
  tags                      = local.tags

  depends_on = [aws_lambda_function.agent_tools]
}

module "bedrock_vector_kb" {
  count  = var.enable_bedrock_vector_kb ? 1 : 0
  source = "../modules/bedrock_vector_kb"

  name_prefix                       = local.name_prefix
  tags                              = local.tags
  aws_region                        = data.aws_region.current.id
  aws_account_id                    = data.aws_caller_identity.current.account_id
  kb_bucket_id                      = module.kb_source.source_bucket_id
  kb_bucket_arn                     = module.kb_source.source_bucket_arn
  kb_kms_key_arn                    = module.kms.key_arn
  agent_id                          = module.bedrock_agent.agent_id
  bedrock_agent_execution_role_name = module.bedrock_agent.execution_role_name
  embedding_model_id                = var.bedrock_kb_embedding_model_id

  opensearch_data_access_principal_arns = distinct(concat(
    ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    [data.aws_caller_identity.current.arn],
    local.aoss_terraform_deployer_role_arn
  ))

  depends_on = [module.bedrock_agent, module.kb_source, module.kms]
}

resource "null_resource" "bedrock_agent_prepare_after_kb" {
  count = var.enable_bedrock_vector_kb && var.terraform_prepare_agent_after_kb ? 1 : 0

  triggers = {
    kb = module.bedrock_vector_kb[0].knowledge_base_id
  }

  provisioner "local-exec" {
    command = "python3 \"${path.module}/../scripts/prepare_bedrock_agent.py\" --agent-id \"${module.bedrock_agent.agent_id}\" --region \"${data.aws_region.current.id}\" --wait"
  }

  depends_on = [module.bedrock_vector_kb]
}

resource "aws_iam_role_policy" "lambda_transfer_connector" {
  count = var.enable_transfer_family ? 1 : 0
  name  = "${local.name_prefix}-lambda-transfer-connector"
  role  = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "transfer:StartFileTransfer",
        "transfer:ListFileTransferResults"
      ]
      Resource = [module.transfer_family[0].connector_arn]
    }]
  })
}

module "cognito_api" {
  count  = var.enable_api_jwt_auth ? 1 : 0
  source = "../modules/cognito_api"

  name_prefix = local.name_prefix
  tags        = local.tags
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  tags          = local.tags

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["authorization", "content-type", "x-idempotency-key", "x-correlation-id", "x-enable-trace"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = var.api_cors_allow_origins
    max_age           = 86400
  }
}

resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.enable_api_jwt_auth ? 1 : 0

  api_id           = aws_apigatewayv2_api.http.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.name_prefix}-jwt"

  jwt_configuration {
    audience = [module.cognito_api[0].client_id]
    issuer   = module.cognito_api[0].issuer
  }
}

locals {
  api_routes_base = toset([
    "GET /v1/ops/summary",
    "GET /v1/transfers",
    "GET /v1/transfers/{id}",
    "POST /v1/transfers",
    "POST /v1/transfers/{id}/retry",
    "POST /v1/transfers/{id}/cancel",
    "GET /v1/partners",
    "GET /v1/partners/{id}",
    "POST /v1/partners",
    "PUT /v1/partners/{id}",
    "DELETE /v1/partners/{id}",
    "GET /v1/endpoints",
    "GET /v1/endpoints/{id}",
    "POST /v1/endpoints",
    "PUT /v1/endpoints/{id}",
    "DELETE /v1/endpoints/{id}",
    "GET /v1/routing-policies",
    "GET /v1/routing-policies/{id}",
    "POST /v1/routing-policies",
    "PUT /v1/routing-policies/{id}",
    "DELETE /v1/routing-policies/{id}",
    "GET /v1/audit-events",
    "POST /v1/agent/query",
  ])
  api_routes_onboarding = var.enable_self_service_onboarding ? toset([
    "GET /v1/onboarding/requests",
    "POST /v1/onboarding/requests",
    "GET /v1/onboarding/requests/{id}",
    "POST /v1/onboarding/requests/{id}/approve",
    "POST /v1/onboarding/requests/{id}/reject",
  ]) : toset([])
  api_routes_automation = var.enable_transfer_automation ? toset([
    "GET /v1/transfer-rules",
    "POST /v1/transfer-rules",
    "GET /v1/transfer-rules/{id}",
    "PUT /v1/transfer-rules/{id}",
    "DELETE /v1/transfer-rules/{id}",
  ]) : toset([])
  api_routes = setunion(
    local.api_routes_base,
    toset(["GET /v1/me"]),
    local.api_routes_onboarding,
    local.api_routes_automation,
  )
}

resource "aws_apigatewayv2_route" "api" {
  for_each = local.api_routes

  api_id             = aws_apigatewayv2_api.http.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
  authorization_type = var.enable_api_jwt_auth ? "JWT" : "NONE"
  authorizer_id      = var.enable_api_jwt_auth ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

resource "aws_wafv2_web_acl" "http_api" {
  count = var.enable_waf ? 1 : 0

  name  = "${local.name_prefix}-http-api"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "http_api" {
  # AWS WAFv2 supports REST API stages only (restapis/...), not HTTP API (apis/...).
  count        = 0
  resource_arn = aws_apigatewayv2_stage.default.arn
  web_acl_arn  = aws_wafv2_web_acl.http_api[0].arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

module "cloudfront_api" {
  count  = var.enable_cloudfront_waf ? 1 : 0
  source = "../modules/cloudfront_api"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix          = local.name_prefix
  api_gateway_endpoint = aws_apigatewayv2_api.http.api_endpoint
  tags                 = local.tags
}

resource "aws_lambda_function" "transfer_dispatcher" {
  count = var.enable_transfer_automation ? 1 : 0

  function_name    = "${local.name_prefix}-transfer-dispatcher"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "transfer_dispatcher.lambda_handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 120
  memory_size      = 256

  environment {
    variables = merge(local.lambda_env_common, {
      ENABLE_TRANSFER_AUTOMATION = "true"
    })
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "transfer_automation_s3" {
  count = var.enable_transfer_automation ? 1 : 0

  name_prefix = "${local.name_prefix}-xfer-auto-"
  description = "Auto-submit transfers when objects land in transfer bucket"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.transfer_data_bucket.bucket_id]
      }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "transfer_automation_s3" {
  count = var.enable_transfer_automation ? 1 : 0

  rule      = aws_cloudwatch_event_rule.transfer_automation_s3[0].name
  target_id = "TransferDispatcher"
  arn       = aws_lambda_function.transfer_dispatcher[0].arn
}

resource "aws_lambda_permission" "transfer_dispatcher_events" {
  count = var.enable_transfer_automation ? 1 : 0

  statement_id  = "AllowEventBridgeInvokeTransferDispatcher"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transfer_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transfer_automation_s3[0].arn
}

resource "aws_iam_role_policy" "lambda_cognito_partner_link" {
  count = var.enable_api_jwt_auth ? 1 : 0

  name = "${local.name_prefix}-lambda-cognito-link"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminAddUserToGroup"
      ]
      Resource = module.cognito_api[0].user_pool_arn
    }]
  })
}

resource "aws_lambda_function" "sftp_inbound" {
  count = var.enable_transfer_family ? 1 : 0

  function_name    = "${local.name_prefix}-sftp-inbound"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "sftp_inbound.lambda_handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_env_common
  }

  tags = local.tags
}

resource "aws_s3_bucket_notification" "transfer_eventbridge" {
  count = (var.enable_transfer_family || var.enable_transfer_automation) ? 1 : 0

  bucket      = module.transfer_data_bucket.bucket_id
  eventbridge = true

}

resource "aws_cloudwatch_event_rule" "sftp_inbound" {
  count = var.enable_transfer_family ? 1 : 0

  name_prefix = "${local.name_prefix}-sftp-in-"
  description = "Audit objects created under sftp-inbound/ (Transfer Family uploads)"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.transfer_data_bucket.bucket_id]
      }
      object = {
        key = [{ prefix = "sftp-inbound/" }]
      }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sftp_inbound" {
  count = var.enable_transfer_family ? 1 : 0

  rule      = aws_cloudwatch_event_rule.sftp_inbound[0].name
  target_id = "SftpInboundLambda"
  arn       = aws_lambda_function.sftp_inbound[0].arn
}

resource "aws_lambda_permission" "sftp_inbound_events" {
  count = var.enable_transfer_family ? 1 : 0

  statement_id  = "AllowEventBridgeInvokeSftpInbound"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_inbound[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sftp_inbound[0].arn
}

module "observability" {
  source = "../modules/cloudwatch"

  name_prefix               = local.name_prefix
  alarm_subscription_emails = var.alarm_subscription_emails
  lambda_function_names = merge(
    {
      api         = aws_lambda_function.api.function_name
      workflow    = aws_lambda_function.workflow.function_name
      agent_tools = aws_lambda_function.agent_tools.function_name
    },
    var.enable_transfer_family ? {
      sftp_inbound = aws_lambda_function.sftp_inbound[0].function_name
    } : {},
    var.enable_transfer_automation ? {
      transfer_dispatcher = aws_lambda_function.transfer_dispatcher[0].function_name
    } : {},
  )
  tags = local.tags
}

module "operator_portal" {
  count  = var.enable_operator_portal ? 1 : 0
  source = "../modules/operator_portal"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix
  bucket_name = "${local.name_prefix}-portal-${data.aws_caller_identity.current.account_id}"
  dist_dir    = "${path.module}/../portal/dist"
  enable_waf  = true
  tags        = local.tags

  depends_on = [module.cloudfront_api]
}
