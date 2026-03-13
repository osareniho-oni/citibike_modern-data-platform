output "looker_instance_id" {
  description = "The ID of the Looker instance"
  value       = google_looker_instance.citibike_looker.id
}

output "looker_instance_name" {
  description = "The name of the Looker instance"
  value       = google_looker_instance.citibike_looker.name
}

output "looker_instance_url" {
  description = "The URL of the Looker instance"
  value       = google_looker_instance.citibike_looker.looker_uri
}

output "looker_service_account" {
  description = "The service account email used by Looker BigQuery connection"
  value       = google_bigquery_connection.looker_connection.cloud_resource[0].service_account_id
}

output "bigquery_connection_id" {
  description = "The BigQuery connection ID for Looker"
  value       = google_bigquery_connection.looker_connection.id
}

output "bigquery_connection_name" {
  description = "The BigQuery connection name for Looker"
  value       = google_bigquery_connection.looker_connection.name
}

output "bigquery_connection_service_account" {
  description = "The service account created for the BigQuery connection"
  value       = google_bigquery_connection.looker_connection.cloud_resource[0].service_account_id
}