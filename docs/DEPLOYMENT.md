# 🚀 Deployment Guide for Reviewers

This guide helps reviewers and evaluators deploy and test the CitiBike Modern Data Platform.

---

## ⏱ Quick Start (15 minutes)

### Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and authenticated
- `terraform` >= 1.0
- `python3` >= 3.13
- `git` installed

### One-Command Deployment

```bash
# 1. Clone repository
git clone <your-repo-url>
cd citibike_modern-data-platform

# 2. Configure environment
./scripts/setup-env.sh

# 3. Deploy everything
./scripts/deploy.sh dev --full

# 4. Verify deployment
./scripts/verify-deployment.sh
```

**That's it!** The platform is now running.

---

## 📋 Detailed Setup Instructions

### Step 1: GCP Project Setup (5 minutes)

```bash
# Create or select GCP project
gcloud projects create your-project-id  # or use existing
gcloud config set project your-project-id

# Authenticate
gcloud auth application-default login

# Enable required APIs
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable iam.googleapis.com
```

### Step 2: Environment Configuration (2 minutes)

```bash
# Run interactive setup
./scripts/setup-env.sh

# This will prompt you for:
# - GCP Project ID
# - GCP Region (default: us-central1)
# - BigQuery Dataset (default: citibike_data)
# - GCS Bucket Name
# - Kestra Host (default: http://localhost:8080)
# - Kestra credentials
```

**Note:** For evaluation purposes, you can use default values for most settings.

### Step 3: Start Kestra Server (if not running)

```bash
# Download Kestra (if not already installed)
curl -LO https://api.kestra.io/latest/download
mv download kestra
chmod +x kestra

# Start Kestra server
./kestra server standalone
```

Access Kestra UI at: http://localhost:8080

### Step 4: Deploy Infrastructure (5 minutes)

```bash
# Deploy everything with one command
./scripts/deploy.sh dev --full

# This will:
# ✓ Deploy Terraform infrastructure (BigQuery, GCS, Pub/Sub)
# ✓ Register Kestra workflows
# ✓ Run dbt transformations
# ✓ Trigger initial data load
```

### Step 5: Verify Deployment (3 minutes)

```bash
# Run verification script
./scripts/verify-deployment.sh

# Expected output:
# ✓ Authenticated with GCP
# ✓ Terraform initialized
# ✓ BigQuery tables created
# ✓ GCS bucket exists
# ✓ Pub/Sub resources created
# ✓ Kestra workflows deployed
# ✓ dbt connection successful
```

---

## 🔍 What Gets Deployed

### Infrastructure (Terraform)

- **BigQuery Dataset:** `citibike_data`
  - `station_status_streaming` (partitioned, clustered)
  - `citibike_trips_raw`
  - `nyc_weather_daily`
  
- **GCS Bucket:** `{project-id}-citibike-data`
  - `/nyc_bikes/raw/` - CSV files
  - `/nyc_bikes/parquet/` - Optimized Parquet files
  
- **Pub/Sub:**
  - Topic: `citibike-station-status`
  - Subscription: `citibike-station-status-to-bq` (→ BigQuery)
  
- **Service Accounts:**
  - `kestra-sa` - For workflow execution
  - `dbt-sa` - For transformations

### Kestra Workflows

- `citibike_station_status_publisher` - Streaming (every 5 min)
- `nyc_bikes_parent` - Trip data ingestion (monthly)
- `nyc_bikes_gcs_to_bq` - Parquet → BigQuery loader
- `nyc_daily_weather_to_bigquery` - Weather data (daily)
- `citibike_kv` - KV store initialization

### dbt Models

- **Staging:** Type casting and validation
  - `stg_station_status`
  - `stg_trips`
  - `stg_weather`
  
- **Intermediate:** Business logic
  - `int_station_metrics`
  - `int_station_daily_metrics`
  - `int_trip_station_daily`
  - `int_station_weather_daily`
  
- **Marts:** Analytics-ready star schema
  - `dim_station`, `dim_date`, `dim_time`, `dim_user_type`
  - `fct_trips`, `fct_station_day`

---

## 🎯 Testing the Platform

### 1. Check Data Ingestion

```bash
# Monitor platform health
./scripts/monitor.sh

# Expected output:
# ✓ Kestra Server: ONLINE
# ✓ Station Status Data: 2 minutes old
# ✓ Active Stations: 2000+ stations
# ✓ Pub/Sub: 0 unacked messages
```

### 2. Query BigQuery Data

```sql
-- Check streaming data freshness
SELECT 
  MAX(last_reported) as latest_data,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(last_reported), MINUTE) as minutes_old,
  COUNT(DISTINCT station_id) as active_stations
FROM `your-project.citibike_data.station_status_streaming`;

-- Check trip data
SELECT 
  COUNT(*) as total_trips,
  MIN(started_at) as earliest_trip,
  MAX(started_at) as latest_trip
FROM `your-project.citibike_data.marts.fct_trips`;

-- Check station metrics
SELECT 
  station_name,
  avg_bikes_available,
  avg_docks_available,
  total_trips_started
FROM `your-project.citibike_data.marts.fct_station_day`
WHERE date = CURRENT_DATE()
ORDER BY total_trips_started DESC
LIMIT 10;
```

### 3. View Kestra Executions

1. Open Kestra UI: http://localhost:8080
2. Navigate to "Executions"
3. Verify workflows are running successfully
4. Check execution logs for any errors

### 4. View dbt Documentation

```bash
cd dbt/nyc_citibike_analytics
dbt docs generate
dbt docs serve
```

Open: http://localhost:8080 (dbt docs)

---

## 📊 Expected Results

### After Initial Deployment

- **Station Status:** ~2,000 stations with real-time data
- **Trip Data:** Historical data (if triggered with `--full`)
- **Weather Data:** Daily weather observations
- **dbt Models:** All marts tables created and populated

### Data Freshness

- **Streaming:** < 5 minutes (station status)
- **Batch:** Daily (weather), Monthly (trips)

### Performance

- **Query Latency:** < 1 second for dashboard queries
- **Ingestion:** ~30 seconds for 2,000 stations
- **dbt Build:** 2-5 minutes for full refresh

---

## 🔧 Troubleshooting

### Issue: Terraform fails with "API not enabled"

**Solution:**
```bash
gcloud services enable bigquery.googleapis.com storage.googleapis.com pubsub.googleapis.com
```

### Issue: Kestra cannot connect

**Solution:**
```bash
# Check if Kestra is running
curl http://localhost:8080/api/v1/flows

# If not, start Kestra
./kestra server standalone
```

### Issue: dbt connection fails

**Solution:**
```bash
# Check profiles.yml exists
ls ~/.dbt/profiles.yml

# Test connection
cd dbt/nyc_citibike_analytics
dbt debug
```

### Issue: No data in BigQuery

**Solution:**
```bash
# Trigger manual execution
curl -X POST http://localhost:8080/api/v1/executions/citibike.nyc/citibike_station_status_publisher

# Wait 2-3 minutes for Pub/Sub streaming buffer
# Then check BigQuery
```

### Issue: Permission denied errors

**Solution:**
```bash
# Regenerate service account keys
cd terraform-gcp
gcloud iam service-accounts keys create kestra-sa-key.json \
  --iam-account=kestra-sa@your-project.iam.gserviceaccount.com
```

---

## 🧹 Cleanup

### Remove All Resources

```bash
# Destroy everything (with confirmation)
./scripts/teardown.sh

# Force destroy (no confirmation)
./scripts/teardown.sh --force
```

**Warning:** This permanently deletes all data!

---

## 📈 Monitoring & Maintenance

### Daily Health Check (5 minutes)

```bash
./scripts/monitor.sh
```

### Weekly Review (15 minutes)

1. Check Kestra execution history
2. Review BigQuery costs
3. Verify data quality metrics
4. Check for failed workflows

### Monthly Tasks (30 minutes)

1. Review and optimize queries
2. Update documentation
3. Plan new features
4. Archive old data (if needed)

---

## 🎓 For Zoomcamp Evaluators

### What to Look For

1. **Infrastructure as Code**
   - Modular Terraform structure
   - Reusable components
   - Proper IAM configuration

2. **Data Pipelines**
   - Streaming (Pub/Sub → BigQuery)
   - Batch (CSV → Parquet → BigQuery)
   - Error handling and retries

3. **Data Modeling**
   - Layered architecture (staging → intermediate → marts)
   - Star schema design
   - Data quality tests

4. **Automation**
   - One-command deployment
   - Automated verification
   - Health monitoring

5. **Documentation**
   - Clear setup instructions
   - Architecture decisions explained
   - Troubleshooting guide

### Evaluation Checklist

- [ ] Can deploy with one command
- [ ] All infrastructure created successfully
- [ ] Data pipelines running automatically
- [ ] dbt models build without errors
- [ ] Data quality tests passing
- [ ] Documentation is clear and complete
- [ ] Code is well-organized and commented
- [ ] Follows best practices

---

## 📞 Support

If you encounter issues during evaluation:

1. Check the troubleshooting section above
2. Review logs in Kestra UI
3. Run `./scripts/verify-deployment.sh` for diagnostics
4. Check GCP Console for resource status

---

## 🎯 Success Criteria

Deployment is successful when:

- ✅ All Terraform resources created
- ✅ Kestra workflows deployed and running
- ✅ BigQuery tables populated with data
- ✅ dbt models built successfully
- ✅ Data freshness < 10 minutes
- ✅ All verification checks pass

---

**Estimated Total Time:** 15-20 minutes for full deployment

**GCP Costs:** ~$5-10 for evaluation period (can be cleaned up after)

---

*For questions or issues, please refer to the main README.md or setup.md*