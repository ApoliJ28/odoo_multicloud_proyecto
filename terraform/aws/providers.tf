terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "odoo-multicloud-terraform-state-aws-bucket-unir"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "odoo-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
  token      = var.session_token

  default_tags {
    tags = {
      Project     = "Odoo-Multicloud"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }
}