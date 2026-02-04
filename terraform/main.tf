terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix              = "${var.project_name}-${var.environment}"
  account_id               = data.aws_caller_identity.current.account_id
  region                   = data.aws_region.current.name
  lambda_function_name     = "${local.name_prefix}-handler"
  api_gateway_name         = "${local.name_prefix}-api"
  sns_topic_name           = "${local.name_prefix}-notifications"
  log_group_name           = "/aws/lambda/${local.lambda_function_name}"
  
  protected_clusters = [
    for cluster_name, config in var.ecs_clusters :
    cluster_name
    if config.protected || (
      var.auto_protect_prod_clusters && 
      (strcontains(lower(cluster_name), "prod") || strcontains(lower(cluster_name), "production"))
    )
  ]
  
  protected_clusters_string = join(",", local.protected_clusters)
  
  all_service_mappings = flatten([
    for cluster_name, config in var.ecs_clusters : [
      for service_name in config.services : {
        cluster = cluster_name
        service = service_name
        key     = "${cluster_name}:${service_name}"
      }
    ]
  ])
  
  common_tags = var.common_tags
}
