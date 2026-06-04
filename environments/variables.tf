variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "project" {
  type    = string
  default = "bayrelay"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "foundation_model" {
  type        = string
  description = "Bedrock foundation model ID for the orchestrator agent (region-specific)."
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "create_vpc" {
  type    = bool
  default = false
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "kb_force_destroy" {
  type        = bool
  default     = false
  description = "Allow empty+destroy KB source bucket (false in prod)."
}

variable "transfer_data_bucket_force_destroy" {
  type        = bool
  default     = false
  description = "Must stay false in prod unless you accept Terraform deleting bucket contents on destroy."
}

variable "enable_transfer_family" {
  type        = bool
  default     = true
  description = "Provision AWS Transfer Family SFTP server + connector (Phase 2)."
}

variable "connector_trusted_host_keys" {
  type        = list(string)
  default     = []
  description = "OpenSSH RSA host keys for the Transfer connector (skip ssh-keyscan at apply when set)."
}

variable "allow_agent_trace_header" {
  type        = bool
  default     = false
  description = "Disable client-controlled Bedrock traces in production APIs."
}

variable "enable_api_jwt_auth" {
  type        = bool
  default     = true
  description = "Require Cognito JWT on all HTTP API routes."
}

variable "enable_waf" {
  type        = bool
  default     = false
  description = "Create regional WAF Web ACL only (not associated: API Gateway HTTP API v2 does not support WAF). Use CloudFront+WAF or REST API for edge protection."
}

variable "bedrock_agent_alias_id" {
  type        = string
  default     = "TSTALIASID"
  description = "Set to a published Bedrock agent alias ID before go-live (avoid TSTALIASID in production traffic)."
}

variable "bedrock_prepare_agent" {
  type        = bool
  default     = true
  description = "Prepare Bedrock agent after changes."
}

variable "enable_bedrock_vector_kb" {
  type        = bool
  default     = true
  description = "OpenSearch Serverless + Bedrock KB + agent association (Phase 3). Incurrs AOSS OCUs; set false only to disable RAG in prod."
}

variable "terraform_prepare_agent_after_kb" {
  type        = bool
  default     = false
  description = "Run prepare_bedrock_agent.py from terraform apply (needs Python+boto3)."
}

variable "bedrock_kb_embedding_model_id" {
  type        = string
  default     = "amazon.titan-embed-text-v1"
  description = "Embedding model ID; enable in Bedrock model access."
}

variable "enable_cloudfront_waf" {
  type        = bool
  default     = false
  description = "CloudFront distribution + edge WAF in front of HTTP API (required for WAF with API Gateway v2)."
}

variable "alarm_subscription_emails" {
  type        = list(string)
  default     = []
  description = "SNS email subscriptions for Lambda error alarms (confirm subscription in inbox)."
}

variable "enable_operator_portal" {
  type        = bool
  default     = false
  description = "Deploy React operator portal (S3 + CloudFront) and enable API CORS for browser clients."
}

variable "enable_self_service_onboarding" {
  type        = bool
  default     = true
  description = "Enable partner/customer onboarding API and portal wizard (submit → approve → active partner)."
}

variable "enable_transfer_automation" {
  type        = bool
  default     = true
  description = "S3 EventBridge rules auto-submit transfers from transfer_rules table."
}

variable "onboarding_auto_approve" {
  type        = bool
  default     = true
  description = "Automatically approve onboarding requests and provision partner + endpoints."
}

variable "enable_public_onboarding_submit" {
  type        = bool
  default     = false
  description = "Allow unauthenticated POST /v1/onboarding/requests (usually partners authenticate instead)."
}

variable "api_cors_allow_origins" {
  type        = list(string)
  default     = ["*"]
  description = "CORS allow_origins on HTTP API (use portal URL in production when known)."
}
