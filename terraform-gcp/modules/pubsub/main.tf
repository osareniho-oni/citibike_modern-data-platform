# Data source to get the Pub/Sub service account
data "google_project" "project" {
  project_id = var.project_id
}

# Create Pub/Sub topics
resource "google_pubsub_topic" "topics" {
  for_each = var.topics

  name    = each.value.name
  project = var.project_id

  message_retention_duration = each.value.message_retention_duration

  # Optional schema configuration
  dynamic "schema_settings" {
    for_each = each.value.schema != null ? [1] : []
    content {
      schema   = google_pubsub_schema.schemas[each.key].id
      encoding = "JSON"
    }
  }
}

# Create Pub/Sub schemas (if defined)
resource "google_pubsub_schema" "schemas" {
  for_each = {
    for k, v in var.topics : k => v.schema
    if v.schema != null
  }

  name       = each.value.name
  type       = each.value.type
  definition = each.value.definition
  project    = var.project_id
}

# Create BigQuery subscriptions
resource "google_pubsub_subscription" "bigquery_subscriptions" {
  for_each = var.bigquery_subscriptions

  name    = each.value.name
  topic   = google_pubsub_topic.topics[each.value.topic].id
  project = var.project_id

  ack_deadline_seconds       = each.value.ack_deadline_seconds
  message_retention_duration = each.value.message_retention_duration

  # BigQuery configuration
  bigquery_config {
    table            = each.value.bigquery_table_id
    use_topic_schema = each.value.use_topic_schema
    write_metadata   = each.value.write_metadata
    drop_unknown_fields = each.value.drop_unknown_fields
    use_table_schema = each.value.use_table_schema
  }

  # Retry policy for failed messages
  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      minimum_backoff = retry_policy.value.minimum_backoff
      maximum_backoff = retry_policy.value.maximum_backoff
    }
  }

  # Depends on the IAM binding to ensure permissions are set first
  depends_on = [
    google_project_iam_member.pubsub_bq_editor
  ]
}

# Enable Pub/Sub API to ensure service account exists
resource "google_project_service" "pubsub_api" {
  project = var.project_id
  service = "pubsub.googleapis.com"

  disable_on_destroy = false
}

# Grant BigQuery Data Editor role to Pub/Sub service account
# This is CRITICAL for BigQuery subscriptions to work
# Note: The service account is created automatically when Pub/Sub API is enabled
resource "google_project_iam_member" "pubsub_bq_editor" {
  count = var.enable_pubsub_sa_permissions ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.pubsub_api,
    google_pubsub_topic.topics
  ]
}

# Optional: Grant BigQuery Metadata Viewer for better error messages
resource "google_project_iam_member" "pubsub_bq_metadata_viewer" {
  count = var.enable_pubsub_sa_permissions ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.pubsub_api,
    google_pubsub_topic.topics
  ]
}