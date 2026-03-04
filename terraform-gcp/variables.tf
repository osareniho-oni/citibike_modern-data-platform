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