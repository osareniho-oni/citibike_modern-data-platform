terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}


module "storage" {
  source      = "./modules/storage"
  bucket_name = var.bucket_name
  location    = var.region
}

module "bigquery" {
  source            = "./modules/bigquery"
  dataset_names     = var.bigquery_datasets
  location          = var.region
  streaming_tables  = var.streaming_tables
}

module "service_accounts" {
  source = "./modules/service-accounts"
  service_accounts = var.service_accounts
}

module "iam" {
  source = "./modules/iam"

  project_id        = var.project_id
  service_accounts  = module.service_accounts.service_account_emails
}

module "pubsub" {
  source = "./modules/pubsub"

  project_id               = var.project_id
  topics                   = var.pubsub_topics
  bigquery_subscriptions   = var.pubsub_bigquery_subscriptions
  enable_pubsub_sa_permissions = true

  # Ensure BigQuery tables exist before creating subscriptions
  depends_on = [
    module.bigquery
  ]
}

# Looker instance for analytics and dashboards
# NOTE: Commented out - requires Google Cloud Sales engagement and quota approval
# Uncomment after quota is enabled. See LOOKER_SETUP.md for details.
# Alternative: Use Looker Studio (free) - dashboards/looker-studio/
#
# module "looker" {
#   source = "./modules/looker"
#
#   project_id         = var.project_id
#   instance_name      = var.looker_instance_name
#   platform_edition   = var.looker_platform_edition
#   region             = var.looker_region
#   oauth_client_id    = var.looker_oauth_client_id
#   oauth_client_secret = var.looker_oauth_client_secret
#   custom_domain      = var.looker_custom_domain
#
#   # Ensure BigQuery datasets exist before creating Looker instance
#   depends_on = [
#     module.bigquery
#   ]
# }