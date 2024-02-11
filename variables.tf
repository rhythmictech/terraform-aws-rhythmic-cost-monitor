
variable "name" {
  description = "Moniker to apply to all resources in the module"
  type        = string
}

variable "tags" {
  default     = {}
  description = "User-Defined tags"
  type        = map(string)
}

variable "datadog_api_key_secret_arn" {
  description = "ARN of the AWS Secret containing the Datadog API key"
  type        = string
}
