terraform {
  backend "s3" {
    key = "podaac-carpathia/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.default_tags
  }

  ignore_tags {
    key_prefixes = ["gsfc-ngap"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ngap_ami" {
  name = var.ami_ssm_key
}

locals {
  resource_prefix      = coalesce(
    var.resource_prefix,
    "podaac-${var.stage}-${var.app_name}"
  )

  default_tags = length(var.default_tags) == 0 ? {
    team = "IA"
    application = local.resource_prefix
    #version = local.version TODO: Introduce versioning
    Environment = var.stage
  } : var.default_tags
}
