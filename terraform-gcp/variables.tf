variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket"
}

variable "bigquery_datasets" {
  type        = list(string)
  default     = ["raw", "staging", "marts"]
}

variable "service_accounts" {
  type = list(string)
  default = [
    "terraform-sa",
    "kestra-sa",
    "dbt-sa"
  ]
}

variable "streaming_tables" {
  type = map(object({
    dataset_id  = string
    table_id    = string
    description = optional(string, "")
    schema = list(object({
      name        = string
      type        = string
      mode        = optional(string, "NULLABLE")
      description = optional(string, "")
    }))
    time_partitioning = optional(object({
      type                     = string
      field                    = optional(string)
      expiration_ms            = optional(number)
      require_partition_filter = optional(bool, false)
    }))
    clustering = optional(list(string), [])
  }))
  description = "Map of streaming tables to create for Pub/Sub ingestion"
  default     = {}
}

variable "pubsub_topics" {
  type = map(object({
    name                       = string
    message_retention_duration = optional(string, "86400s")
    schema = optional(object({
      name       = string
      type       = string
      definition = string
    }))
  }))
  description = "Map of Pub/Sub topics to create"
  default     = {}
}

variable "pubsub_bigquery_subscriptions" {
  type = map(object({
    name                 = string
    topic                = string
    bigquery_table_id    = string
    use_topic_schema     = optional(bool, false)
    write_metadata       = optional(bool, true)
    drop_unknown_fields  = optional(bool, false)
    use_table_schema     = optional(bool, false)
    ack_deadline_seconds = optional(number, 20)
    message_retention_duration = optional(string, "604800s")
    retry_policy = optional(object({
      minimum_backoff = optional(string, "10s")
      maximum_backoff = optional(string, "600s")
    }))
  }))
  description = "Map of BigQuery subscriptions to create"
  default     = {}
}

# Looker configuration variables
variable "looker_instance_name" {
  type        = string
  description = "Name of the Looker instance"
  default     = "citibike-looker"
}

variable "looker_platform_edition" {
  type        = string
  description = "Looker platform edition (LOOKER_CORE_STANDARD, LOOKER_CORE_ENTERPRISE, LOOKER_CORE_ENTERPRISE_ANNUAL)"
  default     = "LOOKER_CORE_STANDARD"
}

variable "looker_region" {
  type        = string
  description = "GCP region for Looker instance (defaults to main region if not specified)"
  default     = ""
}

variable "looker_oauth_client_id" {
  type        = string
  description = "OAuth client ID for Looker authentication"
  sensitive   = true
  default     = ""
}

variable "looker_oauth_client_secret" {
  type        = string
  description = "OAuth client secret for Looker authentication"
  sensitive   = true
  default     = ""
}

variable "looker_custom_domain" {
  type        = string
  description = "Optional custom domain for Looker instance"
  default     = null
}