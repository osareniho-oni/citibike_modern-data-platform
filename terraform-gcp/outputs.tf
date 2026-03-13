output "bucket_name" {
  value = module.storage.bucket_name
}

output "bigquery_datasets" {
  value = module.bigquery.dataset_ids
}

output "service_accounts" {
  value = module.service_accounts.service_account_emails
}

output "iam_bindings" {
  value = module.iam.iam_bindings
}

# Looker outputs
# NOTE: Commented out - Looker module is disabled until quota is approved
# Uncomment when Looker module is enabled in main.tf
#
# output "looker_instance_url" {
#   description = "The URL to access the Looker instance"
#   value       = module.looker.looker_instance_url
# }
#
# output "looker_instance_id" {
#   description = "The ID of the Looker instance"
#   value       = module.looker.looker_instance_id
# }
#
# output "looker_service_account" {
#   description = "The service account email used by Looker"
#   value       = module.looker.looker_service_account
# }
#
# output "looker_bigquery_connection_id" {
#   description = "The BigQuery connection ID for Looker"
#   value       = module.looker.bigquery_connection_id
# }