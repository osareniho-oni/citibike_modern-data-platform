# Google Pub/Sub to BigQuery Streaming Setup

This document explains the Pub/Sub to BigQuery streaming infrastructure configured in this Terraform project, following Google Cloud best practices.

## Overview

The infrastructure automatically streams data from Pub/Sub topics directly into BigQuery tables, eliminating the need for custom ingestion code. This is ideal for real-time data pipelines like CitiBike station status updates.

## Architecture

```
Pub/Sub Topic → BigQuery Subscription → BigQuery Table
     ↓                    ↓
  Messages         Automatic Write
                   (with metadata)
```

## Key Components

### 1. Pub/Sub Topics (`modules/pubsub/`)

Topics receive and store messages temporarily before delivery to subscriptions.

**Configuration:**
- Message retention: 1 day (configurable)
- Optional schema validation
- Automatic message deduplication

### 2. BigQuery Tables (`modules/bigquery/`)

Tables store the streaming data with optimized schema for querying.

**Features:**
- Time-based partitioning for efficient queries
- Clustering for better performance
- Automatic schema enforcement
- Metadata columns (message_id, publish_time, ingestion_timestamp)

### 3. BigQuery Subscriptions (`modules/pubsub/`)

Subscriptions automatically write Pub/Sub messages to BigQuery tables.

**Key Settings:**
- `write_metadata: true` - Includes Pub/Sub metadata (message_id, publish_time)
- `use_topic_schema: false` - Maps JSON keys to table columns
- `drop_unknown_fields: false` - Keeps all fields from JSON
- Retry policy for failed writes

### 4. IAM Permissions (CRITICAL!)

The Pub/Sub service account **MUST** have `roles/bigquery.dataEditor` permission.

**Automatic Configuration:**
```hcl
# This is handled automatically by the module
service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com
  → roles/bigquery.dataEditor
  → roles/bigquery.metadataViewer
```

## Configuration Guide

### Step 1: Define Your BigQuery Table

In `terraform.tfvars`, define the table schema that matches your data:

```hcl
streaming_tables = {
  station_status = {
    dataset_id  = "raw"
    table_id    = "station_status_streaming"
    description = "Real-time CitiBike station status"
    
    schema = [
      {
        name = "station_id"
        type = "STRING"
        mode = "REQUIRED"
      },
      {
        name = "num_bikes_available"
        type = "INTEGER"
        mode = "NULLABLE"
      },
      # Add metadata columns for tracking
      {
        name = "ingestion_timestamp"
        type = "TIMESTAMP"
        mode = "NULLABLE"
      },
      {
        name = "message_id"
        type = "STRING"
        mode = "NULLABLE"
      },
      {
        name = "publish_time"
        type = "TIMESTAMP"
        mode = "NULLABLE"
      }
    ]
    
    # Partition by ingestion time for efficient queries
    time_partitioning = {
      type  = "DAY"
      field = "ingestion_timestamp"
    }
    
    # Cluster for better query performance
    clustering = ["station_id", "last_reported"]
  }
}
```

### Step 2: Create Pub/Sub Topic

```hcl
pubsub_topics = {
  station_status = {
    name                       = "citibike-station-status"
    message_retention_duration = "86400s"  # 1 day
  }
}
```

### Step 3: Create BigQuery Subscription

```hcl
pubsub_bigquery_subscriptions = {
  station_status_to_bq = {
    name              = "citibike-station-status-to-bq"
    topic             = "station_status"  # References topic key above
    bigquery_table_id = "PROJECT_ID:DATASET.TABLE"
    
    # Important settings
    use_topic_schema    = false  # Map JSON to table columns
    write_metadata      = true   # Include Pub/Sub metadata
    drop_unknown_fields = false  # Keep all JSON fields
    
    # Reliability settings
    ack_deadline_seconds       = 20
    message_retention_duration = "604800s"  # 7 days
    
    retry_policy = {
      minimum_backoff = "10s"
      maximum_backoff = "600s"
    }
  }
}
```

## Schema Mapping Strategies

### Strategy 1: Structured Schema (Recommended)

**Best for:** Production workloads with known data structure

Define exact columns matching your JSON message keys:

```json
// Pub/Sub Message (CitiBike GBFS format)
{
  "station_id": "66dd056e-0aca-11e7-82f6-3863bb44ef7c",
  "num_bikes_available": 5,
  "num_ebikes_available": 2,
  "is_installed": 1,
  "is_renting": 1,
  "last_reported": 1771728456
}
```

```hcl
// BigQuery Schema
schema = [
  { name = "station_id", type = "STRING", mode = "REQUIRED" },
  { name = "num_bikes_available", type = "INTEGER", mode = "NULLABLE" },
  { name = "num_ebikes_available", type = "INTEGER", mode = "NULLABLE" },
  { name = "is_installed", type = "INTEGER", mode = "NULLABLE" },
  { name = "is_renting", type = "INTEGER", mode = "NULLABLE" },
  { name = "last_reported", type = "TIMESTAMP", mode = "NULLABLE" }
]
```

**Important Data Type Notes:**

1. **Boolean Fields as INTEGER**: CitiBike uses `0` and `1` for boolean fields (`is_installed`, `is_renting`, `is_returning`). Use `INTEGER` type for safe ingestion, then convert in SQL if needed:
   ```sql
   SELECT
     station_id,
     CAST(is_renting AS BOOL) as is_renting_bool
   FROM table
   ```

2. **Unix Timestamps**: The `last_reported` field comes as Unix seconds (e.g., `1771728456`). BigQuery's Pub/Sub subscription automatically converts this to TIMESTAMP type. If you need to convert manually in SQL:
   ```sql
   SELECT TIMESTAMP_SECONDS(last_reported) as last_reported_ts
   ```

3. **Metadata Timestamps**: When `write_metadata = true`, Pub/Sub adds:
   - `ingestion_timestamp`: When BigQuery received the message
   - `publish_time`: When the message was published to Pub/Sub
   
   These are useful for tracking data freshness and debugging stuck stations.

**Pros:**
- Type safety and validation
- Efficient storage and queries
- Clear data contract
- Matches actual CitiBike GBFS feed structure

**Cons:**
- Schema changes require table updates
- Must know structure upfront

### Strategy 2: Raw JSON Storage

**Best for:** Initial testing, unknown schemas, or flexible data

Store entire message as JSON string:

```hcl
schema = [
  { name = "data", type = "STRING", mode = "NULLABLE" },
  { name = "ingestion_timestamp", type = "TIMESTAMP", mode = "NULLABLE" },
  { name = "message_id", type = "STRING", mode = "NULLABLE" }
]
```

**Pros:**
- No schema changes needed
- Captures everything
- Good for debugging

**Cons:**
- Requires JSON parsing in queries
- Less efficient storage
- No type validation

## Deployment

### 1. Initialize Terraform

```bash
cd terraform-gcp
terraform init
```

### 2. Review Changes

```bash
terraform plan
```

**Expected resources:**
- `google_pubsub_topic.topics`
- `google_bigquery_table.streaming_tables`
- `google_pubsub_subscription.bigquery_subscriptions`
- `google_project_iam_member.pubsub_bq_editor` (CRITICAL!)

### 3. Apply Configuration

```bash
terraform apply
```

### 4. Verify Setup

```bash
# Check topic exists
gcloud pubsub topics list

# Check subscription exists
gcloud pubsub subscriptions list

# Check BigQuery table
bq show PROJECT_ID:DATASET.TABLE

# Verify IAM permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:service-*@gcp-sa-pubsub.iam.gserviceaccount.com"
```

## Testing the Pipeline

### 1. Publish Test Message

```bash
gcloud pubsub topics publish citibike-station-status \
  --message '{
    "station_id": "test-123",
    "num_bikes_available": 10,
    "num_docks_available": 5,
    "last_reported": "2024-03-04T10:30:00Z"
  }'
```

### 2. Check BigQuery

```sql
SELECT *
FROM `PROJECT_ID.raw.station_status_streaming`
WHERE station_id = 'test-123'
ORDER BY ingestion_timestamp DESC
LIMIT 10;
```

### 3. Monitor Subscription

```bash
# Check subscription metrics
gcloud pubsub subscriptions describe citibike-station-status-to-bq

# View undelivered messages
gcloud pubsub subscriptions pull citibike-station-status-to-bq \
  --limit=5 --auto-ack
```

## Troubleshooting

### Messages Not Appearing in BigQuery

**Check 1: IAM Permissions**
```bash
# Verify Pub/Sub service account has bigquery.dataEditor
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/bigquery.dataEditor"
```

**Check 2: Subscription Status**
```bash
gcloud pubsub subscriptions describe SUBSCRIPTION_NAME
```

**Check 3: BigQuery Streaming Buffer**
```sql
-- Data may be in streaming buffer (not immediately queryable)
SELECT COUNT(*) FROM `PROJECT_ID.DATASET.TABLE`
```

**Check 4: Schema Mismatch**
- Ensure JSON keys match table column names exactly
- Check data types are compatible
- Verify REQUIRED fields are present in messages

### Common Errors

#### "Service account does not exist"
**Error:** `Service account service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com does not exist`

**Cause:** The Pub/Sub service account is created automatically when:
- The Pub/Sub API is enabled, OR
- The first Pub/Sub resource (topic/subscription) is created

**Fix:** The module now handles this automatically by:
1. Enabling the Pub/Sub API first
2. Creating topics before IAM bindings
3. Using `depends_on` to ensure proper ordering

If you still see this error:
```bash
# Manually enable the API and wait a few seconds
gcloud services enable pubsub.googleapis.com
sleep 10

# Then retry terraform apply
terraform apply
```

#### "Permission Denied"
**Cause:** Pub/Sub service account lacks BigQuery permissions
**Fix:** Ensure `enable_pubsub_sa_permissions = true` in module

#### "Schema Mismatch"
**Cause:** JSON structure doesn't match table schema
**Fix:**
- Set `drop_unknown_fields = true` to ignore extra fields
- Or update table schema to match JSON

#### "Table Not Found"
**Cause:** Table doesn't exist or wrong project/dataset
**Fix:** Verify `bigquery_table_id` format: `PROJECT:DATASET.TABLE`

## Best Practices

### 1. Always Include Metadata
```hcl
write_metadata = true  # Adds message_id, publish_time
```

### 2. Use Time Partitioning
```hcl
time_partitioning = {
  type  = "DAY"
  field = "ingestion_timestamp"
}
```

### 3. Add Clustering for Common Queries
```hcl
clustering = ["station_id", "timestamp"]
```

### 4. Set Appropriate Retention
```hcl
message_retention_duration = "604800s"  # 7 days for replay
```

### 5. Configure Retry Policy
```hcl
retry_policy = {
  minimum_backoff = "10s"
  maximum_backoff = "600s"
}
```

### 6. Monitor Dead Letter Topics
Consider adding a dead letter topic for failed messages:
```hcl
dead_letter_policy = {
  dead_letter_topic     = "projects/PROJECT/topics/failed-messages"
  max_delivery_attempts = 5
}
```

## Cost Optimization

1. **Partition old data:** Use time partitioning with expiration
2. **Cluster frequently queried columns:** Reduces data scanned
3. **Set message retention:** Don't keep messages longer than needed
4. **Monitor streaming inserts:** BigQuery streaming has costs

## Monitoring

### Key Metrics to Track

1. **Pub/Sub Metrics:**
   - Unacked messages
   - Oldest unacked message age
   - Publish/delivery throughput

2. **BigQuery Metrics:**
   - Streaming insert errors
   - Rows inserted per second
   - Storage growth

3. **Subscription Metrics:**
   - Delivery latency
   - Ack/Nack rates
   - Retry attempts

## Next Steps

1. **Set up monitoring alerts** for failed deliveries
2. **Create views** on streaming tables for easier querying
3. **Implement data quality checks** in downstream dbt models
4. **Configure backup/archival** for long-term storage
5. **Add dead letter topics** for failed message handling

## References

- [Pub/Sub to BigQuery Guide](https://cloud.google.com/pubsub/docs/bigquery)
- [BigQuery Streaming Best Practices](https://cloud.google.com/bigquery/docs/streaming-data-into-bigquery)
- [Pub/Sub IAM Permissions](https://cloud.google.com/pubsub/docs/access-control)