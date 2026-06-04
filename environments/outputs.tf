output "http_api_endpoint" {
  value       = aws_apigatewayv2_api.http.api_endpoint
  description = "Direct API Gateway HTTP API URL (internal/debug)."
}

output "http_api_public_endpoint" {
  value       = local.http_api_public_url
  description = "Customer-facing API URL (CloudFront+WAF when enable_cloudfront_waf, else direct API Gateway)."
}

output "aws_deployment_region" {
  value       = var.aws_region
  description = "Region for this stack; use for AWS_REGION when running scripts."
}

output "bedrock_agent_id" {
  value       = module.bedrock_agent.agent_id
  description = "Amazon Bedrock Agent ID for file-transfer-orchestrator-agent"
}

output "bedrock_agent_alias_id" {
  value       = local.bedrock_agent_alias_id
  description = "Alias ID passed to InvokeAgent (production alias when bedrock_create_production_alias)."
}

output "bedrock_agent_version" {
  value       = module.bedrock_agent.agent_version
  description = "Prepared Bedrock agent version string."
}

output "cognito_user_pool_id" {
  value       = try(module.cognito_api[0].user_pool_id, null)
  description = "Cognito user pool when enable_api_jwt_auth is true."
}

output "cognito_client_id" {
  value       = try(module.cognito_api[0].client_id, null)
  description = "App client ID (JWT audience) when enable_api_jwt_auth is true."
}

output "cognito_token_issuer" {
  value       = try(module.cognito_api[0].issuer, null)
  description = "JWT issuer URL for Cognito when enable_api_jwt_auth is true."
}

output "transfer_data_bucket" {
  value = module.transfer_data_bucket.bucket_id
}

output "kb_source_bucket" {
  value       = module.kb_source.source_bucket_id
  description = "Upload curated KB documents here before ingestion (Phase 3 vector store)."
}

output "bedrock_knowledge_base_id" {
  value       = try(module.bedrock_vector_kb[0].knowledge_base_id, null)
  description = "Bedrock vector knowledge base ID when enable_bedrock_vector_kb is true."
}

output "bedrock_kb_data_source_id" {
  value       = try(module.bedrock_vector_kb[0].data_source_id, null)
  description = "S3 data source ID for ingestion scripts."
}

output "opensearch_vector_collection_name" {
  value       = try(module.bedrock_vector_kb[0].opensearch_collection_name, null)
  description = "OpenSearch Serverless collection for the KB."
}

output "cloudfront_distribution_domain" {
  value       = try(module.cloudfront_api[0].distribution_domain_name, null)
  description = "CloudFront domain when enable_cloudfront_waf is true."
}

output "waf_web_acl_arn" {
  value       = try(module.cloudfront_api[0].web_acl_arn, try(aws_wafv2_web_acl.http_api[0].arn, null))
  description = "Edge WAF ACL (CloudFront) or regional ACL if enable_waf without CloudFront."
}

output "alarm_topic_arn" {
  value       = module.observability.alarm_topic_arn
  description = "SNS topic for Lambda error alarms; subscribe ops emails via alarm_subscription_emails."
}

output "step_function_precheck_arn" {
  value = module.step_functions.precheck_arn
}

output "sftp_server_endpoint" {
  value       = var.enable_transfer_family ? module.transfer_family[0].server_endpoint : null
  description = "AWS Transfer Family SFTP hostname (port 22) when enable_transfer_family is true."
}

output "sftp_inbound_username" {
  value       = var.enable_transfer_family ? module.transfer_family[0].inbound_username : null
  description = "Service-managed SFTP user for partner uploads (logical home → sftp-inbound/ in the transfer bucket)."
}

output "transfer_connector_id" {
  value       = var.enable_transfer_family ? module.transfer_family[0].connector_id : null
  description = "Transfer Family connector ID for StartFileTransfer (S3↔SFTP)."
}

output "sftp_inbound_private_key_secret_arn" {
  value       = var.enable_transfer_family ? module.transfer_family[0].inbound_private_key_secret_arn : null
  sensitive   = true
  description = "Retrieve PEM private key from Secrets Manager for SFTP clients (e.g. FileZilla)."
}

output "operator_portal_url" {
  value       = try(module.operator_portal[0].portal_url, null)
  description = "CloudFront URL for the operator web portal when enable_operator_portal is true."
}

output "operator_portal_distribution_id" {
  value       = try(module.operator_portal[0].portal_distribution_id, null)
  description = "CloudFront distribution ID for portal cache invalidation."
}
