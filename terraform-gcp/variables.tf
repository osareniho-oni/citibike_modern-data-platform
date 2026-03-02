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