# 🚀 Quick Start Guide

## For Zoomcamp Reviewers - Deploy in 15 Minutes

### Prerequisites Check

```bash
# Verify you have these installed:
gcloud --version
terraform --version
python3 --version
git --version
```

### Step-by-Step Deployment

#### 1. Clone and Navigate (1 minute)

```bash
git clone <your-repo-url>
cd citibike_modern-data-platform
```

#### 2. Setup GCP (2 minutes)

```bash
# Set your GCP project
export GCP_PROJECT_ID="your-project-id"
gcloud config set project $GCP_PROJECT_ID

# Authenticate
gcloud auth application-default login

# Enable APIs
gcloud services enable bigquery.googleapis.com storage.googleapis.com pubsub.googleapis.com iam.googleapis.com
```

#### 3. Configure Environment (2 minutes)

```bash
# Make scripts executable (Linux/Mac)
chmod +x scripts/*.sh

# Or on Windows WSL:
cd scripts
chmod +x deploy.sh setup-env.sh verify-deployment.sh monitor.sh teardown.sh
cd ..

# Run setup wizard
./scripts/setup-env.sh
```

**Use these defaults when prompted:**
- GCP Region: `us-central1`
- BigQuery Dataset: `citibike_data`
- GCS Bucket: `{your-project-id}-citibike-data`
- Kestra Host: `http://localhost:8080`
- Kestra Username: `admin@kestra.io`
- Kestra Password: (set your own)

#### 4. Start Kestra (if not running) (2 minutes)

```bash
# Download Kestra
curl -LO https://api.kestra.io/latest/download
mv download kestra
chmod +x kestra

# Start in background
./kestra server standalone &

# Wait for startup (check http://localhost:8080)
```

#### 5. Deploy Everything (5 minutes)

```bash
# Full deployment with initial data load
./scripts/deploy.sh dev --full
```

**What happens:**
- ✅ Terraform creates GCP infrastructure
- ✅ Kestra workflows registered
- ✅ dbt models deployed
- ✅ Initial data load triggered

#### 6. Verify (3 minutes)

```bash
# Run verification
./scripts/verify-deployment.sh

# Check health
./scripts/monitor.sh
```

---

## 🎯 Quick Validation

### Check Data in BigQuery

```bash
# Query streaming data
bq query --use_legacy_sql=false \
"SELECT COUNT(*) as stations, MAX(last_reported) as latest 
FROM \`${GCP_PROJECT_ID}.citibike_data.station_status_streaming\`"
```

Expected: ~2000 stations, latest timestamp within last 10 minutes

### Check Kestra UI

Open: http://localhost:8080
- Navigate to "Flows" → Should see 5 workflows
- Navigate to "Executions" → Should see recent runs

### Check dbt Models

```bash
cd dbt/nyc_citibike_analytics
dbt docs generate
dbt docs serve
```

Open: http://localhost:8080 (dbt docs)

---

## 🧹 Cleanup After Review

```bash
# Destroy all resources
./scripts/teardown.sh
```

---

## ⚡ Troubleshooting

### Scripts not executable?

**Windows WSL:**
```bash
cd scripts
chmod +x *.sh
cd ..
```

**Windows (Git Bash):**
```bash
bash scripts/deploy.sh dev --full
```

### Kestra not accessible?

```bash
# Check if running
curl http://localhost:8080/api/v1/flows

# If not, start it
./kestra server standalone
```

### Terraform errors?

```bash
# Re-initialize
cd terraform-gcp
terraform init
terraform plan
cd ..
```

### Permission errors?

```bash
# Re-authenticate
gcloud auth application-default login
gcloud auth login
```

---

## 📊 What You Should See

### After Deployment

1. **Terraform Output:**
   - BigQuery dataset created
   - GCS bucket created
   - Pub/Sub topic and subscription created
   - Service accounts created

2. **Kestra UI:**
   - 5 workflows deployed
   - Recent executions visible
   - No failed runs

3. **BigQuery:**
   - `station_status_streaming` table with data
   - `marts.fct_trips` table (if full deployment)
   - `marts.dim_station` table

4. **Monitoring:**
   - Data freshness < 10 minutes
   - Active stations > 1500
   - All checks passing

---

## 🎓 For Evaluation

This project demonstrates:

✅ **Infrastructure as Code** - Modular Terraform  
✅ **Streaming Pipeline** - Pub/Sub → BigQuery  
✅ **Batch Processing** - CSV → Parquet → BigQuery  
✅ **Data Modeling** - dbt with star schema  
✅ **Orchestration** - Kestra workflows  
✅ **Automation** - One-command deployment  
✅ **Monitoring** - Health checks and verification  
✅ **Documentation** - Clear setup instructions  

---

## 📞 Need Help?

1. Check `DEPLOYMENT.md` for detailed instructions
2. Check `setup.md` for comprehensive setup guide
3. Run `./scripts/verify-deployment.sh` for diagnostics
4. Check Kestra logs in UI

---

**Total Time:** 15-20 minutes  
**GCP Cost:** ~$5-10 for evaluation  
**Cleanup:** `./scripts/teardown.sh`