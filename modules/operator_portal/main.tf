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
  mime = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
    ".map"  = "application/json"
  }
  portal_files = var.dist_dir != "" ? fileset(var.dist_dir, "**") : toset([])
}

resource "aws_s3_bucket" "portal" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "portal" {
  bucket = aws_s3_bucket.portal.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "portal" {
  bucket = aws_s3_bucket.portal.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "portal" {
  name                              = "${var.name_prefix}-portal-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_wafv2_web_acl" "portal" {
  provider = aws.us_east_1
  count    = var.enable_waf ? 1 : 0

  name  = "${var.name_prefix}-portal-edge"
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
      metric_name                = "PortalCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-portal-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} BayRelay Operator Portal"
  default_root_object = "index.html"
  web_acl_id          = var.enable_waf ? aws_wafv2_web_acl.portal[0].arn : null

  origin {
    domain_name              = aws_s3_bucket.portal.bucket_regional_domain_name
    origin_id                = "portal-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.portal.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "portal-s3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
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

data "aws_iam_policy_document" "portal_oac" {
  statement {
    sid    = "AllowCloudFront"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.portal.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.portal.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "portal" {
  bucket = aws_s3_bucket.portal.id
  policy = data.aws_iam_policy_document.portal_oac.json
}

resource "aws_s3_object" "portal_files" {
  for_each = local.portal_files

  bucket       = aws_s3_bucket.portal.id
  key          = each.value
  source       = "${var.dist_dir}/${each.value}"
  etag         = filemd5("${var.dist_dir}/${each.value}")
  content_type = lookup(local.mime, regex("\\.[^.]+$", each.value), "application/octet-stream")
}

variable "name_prefix" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "dist_dir" {
  type        = string
  description = "Path to vite build output (portal/dist)"
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "portal_url" {
  value = "https://${aws_cloudfront_distribution.portal.domain_name}"
}

output "portal_distribution_id" {
  value = aws_cloudfront_distribution.portal.id
}

output "portal_bucket" {
  value = aws_s3_bucket.portal.id
}
