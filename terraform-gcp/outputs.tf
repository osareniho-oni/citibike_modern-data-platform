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