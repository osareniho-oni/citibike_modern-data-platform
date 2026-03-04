variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "topics" {
  type = map(object({
    name                       = string
    message_retention_duration = optional(string, "86400s") # 1 day default
    schema = optional(object({
      name       = string
      type       = string
      definition = string
    }))
  }))
  description = "Map of Pub/Sub topics to create"
  default     = {}
}

variable "bigquery_subscriptions" {
  type = map(object({
    name                 = string
    topic                = string
    bigquery_table_id    = string
    use_topic_schema     = optional(bool, false)
    write_metadata       = optional(bool, true)
    drop_unknown_fields  = optional(bool, false)
    use_table_schema     = optional(bool, false)
    ack_deadline_seconds = optional(number, 20)
    message_retention_duration = optional(string, "604800s") # 7 days default
    retry_policy = optional(object({
      minimum_backoff = optional(string, "10s")
      maximum_backoff = optional(string, "600s")
    }))
  }))
  description = "Map of BigQuery subscriptions to create"
  default     = {}
}

variable "enable_pubsub_sa_permissions" {
  type        = bool
  description = "Whether to grant BigQuery Data Editor role to Pub/Sub service account"
  default     = true
}