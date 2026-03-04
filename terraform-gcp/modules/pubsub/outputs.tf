output "topic_ids" {
  description = "Map of topic keys to their full resource IDs"
  value = {
    for k, v in google_pubsub_topic.topics : k => v.id
  }
}

output "topic_names" {
  description = "Map of topic keys to their names"
  value = {
    for k, v in google_pubsub_topic.topics : k => v.name
  }
}

output "subscription_ids" {
  description = "Map of subscription keys to their full resource IDs"
  value = {
    for k, v in google_pubsub_subscription.bigquery_subscriptions : k => v.id
  }
}

output "subscription_names" {
  description = "Map of subscription keys to their names"
  value = {
    for k, v in google_pubsub_subscription.bigquery_subscriptions : k => v.name
  }
}

output "pubsub_service_account" {
  description = "The Pub/Sub service account email"
  value       = "service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}