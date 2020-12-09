variable "region" {
  type = string
  description = "The AWS region to deploy to"
}

variable "name" {
  type = string
  description = "A name to apply to all resources"
}

variable "squad" {
  type = string
  default = ""
  description = "Squad, which could be your squad name or abbreviation, e.g. 'krypton' or 'kyp'"
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
