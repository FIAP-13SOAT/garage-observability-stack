variable "datadog_api_key" {
  description = "Datadog API Key"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Ambiente (prod, staging, dev)"
  type        = string
  default     = "prod"
}
