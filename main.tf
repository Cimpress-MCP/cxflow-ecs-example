terraform {
  backend "s3" {
    bucket = "tfstatefiles"
    key = "cxflow/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.region
}

module "cxflow" {
  source = "git::https://github.com/Cimpress-MCP/cxflow-ecs.git"

  name = var.name
  environment = var.environment
  dns_zone = var.dns_zone
  domain = var.domain
  tags = var.tags
  region = var.region
}
