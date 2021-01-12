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

variable "environments" {
  type = map
  default = {"production": "stable"}
  description = "Environments to build services for.  Should be a map with the environment name as the key and the container tag reference as the value"
}

variable "tags" {
  type = map
  default = {}
  description = "Additional tags to apply to all resources"
}

variable "flow_log_bucket" {
  type        = string
  default     = ""
  description = "An S3 bucket to send VPC flow logs to"
}
