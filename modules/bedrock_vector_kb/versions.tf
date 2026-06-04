terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}
