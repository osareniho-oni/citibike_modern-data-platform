# 🚀 Complete Deployment Guide

This comprehensive guide covers all aspects of deploying the CitiBike Modern Data Platform.

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Detailed Setup](#detailed-setup)
3. [Configuration](#configuration)
4. [Deployment Options](#deployment-options)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites
- GCP account with billing enabled
- `gcloud`, `terraform`, `python3` installed
- Kestra server (or use `--start-kestra` flag)

### Deploy in 3 Steps

```bash
# 1. Configure environment
./scripts/setup-env.sh

# 2. Deploy everything
./scripts/deploy.sh dev --full --start-kestra

# 3. Verify
./scripts/monitor.sh
```

**Total time:** 25-45 minutes (mostly automated)

---

## Detailed Setup

### Step 1: GCP Project Setup

```bash
# Set project
gcloud config set project nyc-citibike-data-platform

# Authenticate
gcloud auth application-default login

# Enable APIs
gcloud services enable bigquery.googleapis.com storage.googleapis.com pubsub.googleapis.com iam.googleapis.com
```

### Step 2: Environment Configuration

The `.env` file is already configured with:
- GCP Project: `nyc-citibike-data-platform`
- Datasets: `raw`, `staging`, `marts`
- Bucket: `citibike-data-lake`
- Kestra: `http://localhost:8080`

### Step 3: Deployment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Full deployment with backfill
./scripts/deploy.sh dev --full --start-kestra
```

---

## Configuration

### Your Project Values

| Setting | Value |
|---------|-------|
| GCP Project | `nyc-citibike-data-platform` |
| Region | `us-central1` |
| Datasets | `raw`, `staging`, `marts` |
| Bucket | `citibike-data-lake` |
| Kestra Host | `http://localhost:8080` |

### Dataset Structure

- **`raw`** - Kestra data ingestion (station_status_streaming, citibike_trips_raw, nyc_weather_daily)
- **`staging`** - dbt staging & intermediate models (views)
- **`marts`** - dbt analytics tables (dim_*, fct_*)

### Bucket Structure

```
citibike-data-lake/
└── nyc_bikes/
    └── parquet/
        └── year=2026/
            ├── month=01/
            ├── month=02/
            └── month=03/
```

---

## Deployment Options

### Option 1: Full Deployment (Recommended)
```bash
./scripts/deploy.sh dev --full --start-kestra
```
- Deploys infrastructure
- Deploys workflows
- Initializes KV store
- Runs dbt models
- Prompts for backfill (2026 dates)

### Option 2: Quick Deployment (No Backfill)
```bash
./scripts/deploy.sh dev --start-kestra
```
- Deploys everything except historical data

### Option 3: Selective Deployment
```bash
# Infrastructure only
./scripts/deploy.sh dev --skip-kestra --skip-dbt

# Workflows only
./scripts/deploy.sh dev --skip-terraform --skip-dbt

# dbt only
./scripts/deploy.sh dev --skip-terraform --skip-kestra
```

### Option 4: Backfill Only
```bash
# Trip data backfill
./scripts/deploy.sh dev --backfill-trips

# Weather data backfill
./scripts/deploy.sh dev --backfill-weather

# Both
./scripts/deploy.sh dev --backfill-trips --backfill-weather
```

---

## Verification

### Automated Verification
```bash
./scripts/verify-deployment.sh
```

Checks:
- GCP authentication
- Terraform state
- BigQuery datasets and tables
- GCS bucket
- Pub/Sub resources
- Kestra workflows
- dbt configuration

### Manual Verification

```bash
# Check BigQuery datasets
bq ls --project_id=nyc-citibike-data-platform

# Check tables
bq ls nyc-citibike-data-platform:raw
bq ls nyc-citibike-data-platform:staging
bq ls nyc-citibike-data-platform:marts

# Check GCS bucket
gsutil ls gs://citibike-data-lake/

# Check Kestra
curl http://localhost:8080/api/v1/flows
```

### Health Monitoring
```bash
./scripts/monitor.sh
```

Shows:
- Kestra workflow status
- Data freshness
- Active stations
- Pub/Sub metrics
- dbt model status

---

## Troubleshooting

### Issue: Kestra Not Accessible

**Solution:**
```bash
# Start Kestra manually
./kestra server standalone

# Or use auto-start flag
./scripts/deploy.sh dev --start-kestra
```

### Issue: KV Store Not Initialized

**Solution:**
```bash
# Manually trigger KV workflow
curl -X POST http://localhost:8080/api/v1/executions/citibike.nyc/citibike_kv

# Or in Kestra UI:
# Flows → citibike.nyc → citibike_kv → Execute
```

### Issue: Terraform Errors

**Solution:**
```bash
cd terraform-gcp
terraform init
terraform plan
terraform apply
```

### Issue: dbt Connection Failed

**Solution:**
```bash
# Check profiles.yml
cat ~/.dbt/profiles.yml

# Test connection
cd dbt/nyc_citibike_analytics
dbt debug
```

### Issue: No Data in BigQuery

**Solution:**
```bash
# Check Kestra executions
# Open: http://localhost:8080/executions

# Manually trigger station status
curl -X POST http://localhost:8080/api/v1/executions/citibike.nyc/citibike_station_status_publisher

# Wait 2-3 minutes for Pub/Sub streaming buffer
```

---

## Data Flow

```
┌─────────────────────────────────────────┐
│     DATA INGESTION (Kestra)             │
│                                          │
│  Station: GBFS → Pub/Sub → raw         │
│  Trips: S3 → Parquet → GCS → raw       │
│  Weather: Open-Meteo → raw              │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│   DATA TRANSFORMATION (dbt)              │
│                                          │
│  raw → staging (views) → marts (tables) │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      ANALYTICS (Looker Studio)           │
└─────────────────────────────────────────┘
```

---

## Backfill Guide

### Trip Data Backfill

When prompted:
```
Enter start month (YYYYMM): 202601
Enter end month (YYYYMM): 202603
```

This will backfill January, February, March 2026.

### Weather Data Backfill

When prompted:
```
Enter start date (YYYY-MM-DD): 2026-01-01
Enter end date (YYYY-MM-DD): 2026-03-13
```

This will backfill 72 days of weather data.

### Default Backfill

Press Enter without input to use defaults:
- Trip data: Last 3 months
- Weather data: Last 90 days

---

## Cleanup

### Remove All Resources
```bash
./scripts/teardown.sh
```

This will:
- Prompt for confirmation
- Offer optional data backup
- Destroy Terraform infrastructure
- Clean up local files

### Force Cleanup (No Prompts)
```bash
./scripts/teardown.sh --force
```

---

## For Zoomcamp Reviewers

### Quick Evaluation Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd citibike_modern-data-platform

# 2. Update configuration
# Edit .env with your GCP project
# Edit kestra/flows/citibike_kv.yml

# 3. Deploy
./scripts/deploy.sh dev --full --start-kestra

# 4. Monitor
./scripts/monitor.sh
```

**Time:** 25-45 minutes
**Cost:** ~$5-10 for evaluation

---

## Additional Resources

- **Project Configuration:** `docs/PROJECT_CONFIGURATION.md`
- **Automation Strategy:** `docs/AUTOMATION_STRATEGY.md`
- **Deployment Answers:** `docs/DEPLOYMENT_ANSWERS.md`
- **Zoomcamp Guide:** `docs/ZOOMCAMP_PROJECT_RECOMMENDATION.md`
- **Original Setup:** `setup.md`

---

*Last Updated: March 14, 2026*