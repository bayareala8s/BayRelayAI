terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# WAF for CloudFront must be created in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Optional remote state (uncomment before team/production apply):
# terraform {
#   backend "s3" {
#     bucket         = "YOUR-org-tf-state"
#     key            = "bayrelay/prod/terraform.tfstate"
#     region         = "us-west-2"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
