variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "instance_name" {
  type        = string
  description = "Name of the Looker instance"
}

variable "platform_edition" {
  type        = string
  description = "Looker platform edition (LOOKER_CORE_STANDARD, LOOKER_CORE_ENTERPRISE, LOOKER_CORE_ENTERPRISE_ANNUAL)"
  default     = "LOOKER_CORE_STANDARD"
  
  validation {
    condition     = contains(["LOOKER_CORE_STANDARD", "LOOKER_CORE_ENTERPRISE", "LOOKER_CORE_ENTERPRISE_ANNUAL"], var.platform_edition)
    error_message = "Platform edition must be one of: LOOKER_CORE_STANDARD, LOOKER_CORE_ENTERPRISE, LOOKER_CORE_ENTERPRISE_ANNUAL"
  }
}

variable "region" {
  type        = string
  description = "GCP region for Looker instance"
}

variable "oauth_client_id" {
  type        = string
  description = "OAuth client ID for Looker authentication"
  sensitive   = true
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client secret for Looker authentication"
  sensitive   = true
}

variable "custom_domain" {
  type        = string
  description = "Optional custom domain for Looker instance"
  default     = null
}