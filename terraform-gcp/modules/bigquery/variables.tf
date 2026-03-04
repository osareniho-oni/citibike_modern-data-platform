variable "dataset_names" {
  type = list(string)
}

variable "location" {
  type = string
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