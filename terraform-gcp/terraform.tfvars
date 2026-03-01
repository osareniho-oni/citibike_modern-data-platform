project_id = "nyc-citibike-data-platform"
region     = "us-central1"

bucket_name = "citibike-data-lake"

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