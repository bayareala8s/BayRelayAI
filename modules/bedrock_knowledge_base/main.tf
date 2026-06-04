terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

# Curated S3 document repository for Bedrock. The vector store + Knowledge Base live in
# module bedrock_vector_kb (Phase 3); this module is the encrypted source bucket only.

module "source_bucket" {
  source = "../s3_bucket"

  bucket_name   = var.bucket_name
  kms_key_arn   = var.kms_key_arn
  versioning    = true
  force_destroy = var.force_destroy
  lifecycle_rules = [
    {
      id              = "archive-old-versions"
      prefix          = ""
      noncurrent_days = 90
      expiration_days = null
    }
  ]
  tags = var.tags
}

variable "bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "source_bucket_id" {
  value = module.source_bucket.bucket_id
}

output "source_bucket_arn" {
  value = module.source_bucket.bucket_arn
}
