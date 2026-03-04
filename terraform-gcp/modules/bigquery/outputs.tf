output "dataset_ids" {
  value = [for d in google_bigquery_dataset.datasets : d.dataset_id]
}

output "streaming_table_ids" {
  description = "Map of streaming table keys to their full table IDs (project:dataset.table)"
  value = {
    for k, v in google_bigquery_table.streaming_tables : k => "${v.project}:${v.dataset_id}.${v.table_id}"
  }
}

output "streaming_table_names" {
  description = "Map of streaming table keys to their table names"
  value = {
    for k, v in google_bigquery_table.streaming_tables : k => v.table_id
  }
}