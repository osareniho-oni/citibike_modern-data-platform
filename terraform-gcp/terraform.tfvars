project_id = "kestra-dbt-platform"
region     = "us-central1"

bucket_name = "kestra-dbt-data-lake"

bigquery_datasets = [
  "raw",
  "staging",
  "analytics"
]

service_accounts = [
  "terraform-sa",
  "kestra-sa",
  "dbt-sa"
]