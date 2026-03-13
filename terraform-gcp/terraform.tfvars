project_id = "nyc-citibike-data-platform"
region     = "us-central1"

bucket_name = "citibike-data-lake"

# Looker (Google Cloud core) configuration
# ==========================================
# NOTE: Looker is an ENTERPRISE product requiring sales engagement
# - Requires: Contact Google Cloud Sales (https://cloud.google.com/contact)
# - Cost: ~$5,000+/month minimum commitment
# - Timeline: 1-2 weeks for sales process + quota approval
# - Alternative: Use Looker Studio (free) - already set up in dashboards/looker-studio/
#
# Uncomment and configure below ONLY after Google enables quota for your project
# ==========================================
# looker_instance_name      = "citibike-looker"
# looker_platform_edition   = "LOOKER_CORE_STANDARD"
# looker_region             = "us-central1"
# looker_oauth_client_id    = ""
# looker_oauth_client_secret = ""
# looker_custom_domain      = null

bigquery_datasets = [
  "raw",
  "staging",
  "marts"
]

service_accounts = [
  "terraform-sa",
  "kestra-sa",
  "dbt-sa"
]

# Streaming tables for Pub/Sub ingestion
streaming_tables = {
  station_status = {
    dataset_id  = "raw"
    table_id    = "station_status_streaming"
    description = "Real-time CitiBike station status data from Pub/Sub GBFS feed"
    schema = [
      # Standard GBFS fields
      {
        name        = "station_id"
        type        = "STRING"
        mode        = "REQUIRED"
        description = "Unique identifier of the station (UUID format)"
      },
      {
        name        = "num_bikes_available"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of functional bikes currently at the station"
      },
      {
        name        = "num_ebikes_available"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of functional electric bikes currently at the station"
      },
      {
        name        = "num_bikes_disabled"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of disabled bikes currently at the station"
      },
      {
        name        = "num_docks_available"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of empty docks currently available for returning bikes"
      },
      {
        name        = "num_docks_disabled"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of disabled docks at the station"
      },
      {
        name        = "is_installed"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "1 if the station is installed, 0 otherwise"
      },
      {
        name        = "is_renting"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "1 if the station is currently renting bikes, 0 otherwise"
      },
      {
        name        = "is_returning"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "1 if the station is currently accepting bike returns, 0 otherwise"
      },
      {
        name        = "last_reported"
        type        = "TIMESTAMP"
        mode        = "NULLABLE"
        description = "The last time this station reported its status (Unix timestamp in feed)"
      },
      # Additional GBFS fields
      {
        name        = "num_scooters_available"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of scooters available"
      },
      {
        name        = "num_scooters_unavailable"
        type        = "INTEGER"
        mode        = "NULLABLE"
        description = "Number of scooters unavailable"
      },
      # CitiBike-specific fields
      {
        name        = "eightd_has_available_keys"
        type        = "BOOLEAN"
        mode        = "NULLABLE"
        description = "CitiBike legacy field for key availability"
      },
      {
        name        = "legacy_id"
        type        = "STRING"
        mode        = "NULLABLE"
        description = "The old numeric ID for the station"
      },
      # Metadata fields for tracking
      {
        name        = "api_last_updated"
        type        = "TIMESTAMP"
        mode        = "NULLABLE"
        description = "When the API last updated (from feed metadata)"
      },
      {
        name        = "ingestion_timestamp"
        type        = "TIMESTAMP"
        mode        = "NULLABLE"
        description = "When this record was ingested into BigQuery"
      },
      # Required base field for Pub/Sub BigQuery subscriptions
      {
        name        = "data"
        type        = "STRING"
        mode        = "NULLABLE"
        description = "Raw message payload (required by Pub/Sub)"
      }
    ]
    time_partitioning = {
      type                     = "DAY"
      field                    = "last_reported"
      expiration_ms            = 2592000000  # 30 days retention
      require_partition_filter = false
    }
    clustering = ["station_id"]
  }
}

# Pub/Sub topics
pubsub_topics = {
  station_status = {
    name                       = "citibike-station-status"
    message_retention_duration = "86400s"
  }
}

# BigQuery subscriptions
pubsub_bigquery_subscriptions = {
  station_status_to_bq = {
    name                       = "citibike-station-status-to-bq"
    topic                      = "station_status"
    bigquery_table_id          = "nyc-citibike-data-platform:raw.station_status_streaming"
    use_topic_schema           = false
    write_metadata             = false
    drop_unknown_fields        = false
    use_table_schema           = true  # Use table schema to map fields
    ack_deadline_seconds       = 20
    message_retention_duration = "604800s"
    retry_policy = {
      minimum_backoff = "10s"
      maximum_backoff = "600s"
    }
  }
}