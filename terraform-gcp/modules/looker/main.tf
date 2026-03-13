# terraform-gcp/modules/looker/main.tf
resource "google_looker_instance" "citibike_looker" {
  name               = var.instance_name
  platform_edition   = var.platform_edition  # "LOOKER_CORE_STANDARD" or "LOOKER_CORE_ENTERPRISE"
  region             = var.region
  
  oauth_config {
    client_id     = var.oauth_client_id
    client_secret = var.oauth_client_secret
  }
  
  # Optional: Custom domain
  # custom_domain = var.custom_domain
}

# BigQuery connection for Looker
resource "google_bigquery_connection" "looker_connection" {
  connection_id = "looker-bigquery-connection"
  location      = var.region
  project       = var.project_id
  
  cloud_resource {}
}

# Grant Looker BigQuery connection service account access to BigQuery
resource "google_project_iam_member" "looker_bigquery_access" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_bigquery_connection.looker_connection.cloud_resource[0].service_account_id}"
}

# Additional permission for BigQuery job creation
resource "google_project_iam_member" "looker_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_bigquery_connection.looker_connection.cloud_resource[0].service_account_id}"
}
