variable "region" {
  type = string
  description = "The AWS region to deploy to"
}

variable "dns_zone" {
  type = string
  description = "The name of the Route 53 DNS zone to use for the domain name"
}

variable "domain" {
  type = string
  description = "The domain to host the cluster on"
}

variable "environment" {
  type = string
  default = "development"
  description = "Environment, e.g. 'prod', 'staging', 'dev', 'pre-prod', 'UAT'"
}

variable "tags" {
  type = map
  default = {}
  description = "Additional tags to apply to all resources"
}
