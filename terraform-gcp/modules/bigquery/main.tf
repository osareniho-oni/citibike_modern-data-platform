resource "google_bigquery_dataset" "datasets" {
  for_each = toset(var.dataset_names)

  dataset_id = each.value
  location   = var.location
}