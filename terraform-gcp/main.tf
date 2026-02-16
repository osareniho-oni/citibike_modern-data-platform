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
  source        = "./modules/bigquery"
  dataset_names = var.bigquery_datasets
  location      = var.region
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