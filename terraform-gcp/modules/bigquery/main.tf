resource "google_bigquery_dataset" "datasets" {
  for_each = toset(var.dataset_names)

  dataset_id = each.value
  location   = var.location
}

# Create tables for streaming data from Pub/Sub
resource "google_bigquery_table" "streaming_tables" {
  for_each = var.streaming_tables

  dataset_id          = google_bigquery_dataset.datasets[each.value.dataset_id].dataset_id
  table_id            = each.value.table_id
  description         = each.value.description
  deletion_protection = false

  # Schema definition
  schema = jsonencode([
    for field in each.value.schema : {
      name        = field.name
      type        = field.type
      mode        = field.mode
      description = field.description
    }
  ])

  # Time partitioning for efficient querying
  dynamic "time_partitioning" {
    for_each = each.value.time_partitioning != null ? [each.value.time_partitioning] : []
    content {
      type                     = time_partitioning.value.type
      field                    = time_partitioning.value.field
      expiration_ms            = time_partitioning.value.expiration_ms
      require_partition_filter = time_partitioning.value.require_partition_filter
    }
  }

  # Clustering for better query performance
  clustering = length(each.value.clustering) > 0 ? each.value.clustering : null
}