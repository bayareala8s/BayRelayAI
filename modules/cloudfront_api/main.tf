# CloudFront + WAF (CLOUDFRONT scope) in front of API Gateway HTTP API.
# HTTP API stages cannot associate regional WAF; edge WAF is the production pattern.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.50"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  apigw_host = replace(var.api_gateway_endpoint, "https://", "")
}

resource "aws_wafv2_web_acl" "edge" {
  provider = aws.us_east_1

  name  = "${var.name_prefix}-api-edge"
  scope = "CLOUDFRONT"

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
    metric_name                = "${var.name_prefix}-waf-edge"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.name_prefix} BayRelay API (edge WAF)"
  web_acl_id      = aws_wafv2_web_acl.edge.arn

  origin {
    domain_name = local.apigw_host
    origin_id     = "apigw"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "apigw"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # AWS managed: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS managed: AllViewerExceptHostHeader (API GW needs origin Host = execute-api domain)
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

variable "name_prefix" {
  type = string
}

variable "api_gateway_endpoint" {
  type        = string
  description = "Full https URL from aws_apigatewayv2_api.api_endpoint"
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.api.domain_name
}

output "public_api_url" {
  value = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.edge.arn
}
