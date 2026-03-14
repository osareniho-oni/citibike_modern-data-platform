# 📋 Answers to Your Deployment Questions

## Question 1: Kestra KV Store (Environment Variables)

### Your Setup
You're using `citibike_kv.yml` workflow to set Kestra environment variables, not service accounts.

### How the Script Handles This

The updated `deploy.sh` script now includes a dedicated function `initialize_kestra_kv()` that:

1. **Automatically triggers** the `citibike_kv` workflow after deploying Kestra workflows
2. **Waits** for the execution to complete (10 seconds)
3. **Verifies** that KV values are set correctly

```bash
# This happens automatically during deployment:
./scripts/deploy.sh dev

# The script will:
# 1. Deploy Kestra workflows
# 2. Trigger citibike_kv workflow
# 3. Set GCP_PROJECT_ID, GCP_LOCATION, GCP_BUCKET_NAME, GCP_DATASET
```

### Manual Alternative

If automatic initialization fails, the script provides clear instructions:

```bash
# Navigate to Kestra UI
http://localhost:8080

# Go to: Flows → citibike.nyc → citibike_kv → Execute
```

### Important Note

Before running the deployment, **update** `kestra/flows/citibike_kv.yml` with your actual values:

```yaml
# Edit these values in citibike_kv.yml:
value: nyc-citibike-data-platform  # Change to YOUR project ID
value: citibike-data-lake          # Change to YOUR bucket name
value: citibike_data               # Change to YOUR dataset name
```

---

## Question 2: Backfilling Trip and Weather Data

### Your Setup
- Trip data: Has optional backfill configuration (commented out in `nyc_bikes_parent.yml`)
- Weather data: Accepts `start_date` and `end_date` inputs for backfill

### How the Script Handles This

The updated script now includes **two new flags**:

#### Option 1: Full Backfill (Recommended for Initial Setup)

```bash
./scripts/deploy.sh dev --full

# This will:
# 1. Deploy infrastructure
# 2. Deploy workflows
# 3. Prompt you for backfill periods
# 4. Trigger trip data backfill
# 5. Trigger weather data backfill
```

#### Option 2: Selective Backfill

```bash
# Backfill only trip data
./scripts/deploy.sh dev --backfill-trips

# Backfill only weather data
./scripts/deploy.sh dev --backfill-weather

# Backfill both
./scripts/deploy.sh dev --backfill-trips --backfill-weather
```

### Interactive Backfill Process

When you run with backfill flags, the script will **prompt you**:

**For Trip Data:**
```
Enter start month (YYYYMM, e.g., 202601) or press Enter for last 3 months: 202601
Enter end month (YYYYMM): 202603
```

**For Weather Data:**
```
Enter start date (YYYY-MM-DD) or press Enter for last 90 days: 2026-01-01
Enter end date (YYYY-MM-DD) or press Enter for yesterday: 2026-03-13
```

### Default Backfill Periods

If you just press Enter (no input):

- **Trip Data:** Last 3 months (December 2025, January 2026, February 2026)
- **Weather Data:** Last 90 days (from December 14, 2025 to March 13, 2026)

### How It Works

**Trip Data Backfill:**
```bash
# The script triggers multiple executions:
# For each month: 202601, 202602, 202603, etc.
curl -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/nyc_bikes_parent" \
  -d '{"inputs": {"month": "202601"}}'
```

**Weather Data Backfill:**
```bash
# Single execution with date range:
curl -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/nyc_daily_weather_to_bigquery" \
  -d '{"inputs": {"start_date": "2026-01-01", "end_date": "2026-03-13"}}'
```

### Monitoring Backfill Progress

```bash
# Check execution status
./scripts/monitor.sh

# Or view in Kestra UI
http://localhost:8080/executions
```

### Expected Backfill Time

- **Trip Data:** 5-10 minutes per month
- **Weather Data:** 2-5 minutes for 90 days
- **Total for 3 months + 90 days:** ~20-35 minutes

### Example: Backfill Year-to-Date (2026)

```bash
# Deploy with backfill
./scripts/deploy.sh dev --full

# When prompted for trip data:
Enter start month (YYYYMM): 202601
Enter end month (YYYYMM): 202603

# When prompted for weather data:
Enter start date (YYYY-MM-DD): 2026-01-01
Enter end date (YYYY-MM-DD): 2026-03-13

# This will backfill:
# - Trip data: January, February, March 2026
# - Weather data: January 1 - March 13, 2026
```

---

## Question 3: Kestra Server Status

### Your Concern
Will the Kestra server be running after deployment?

### How the Script Handles This

The script now includes **automatic Kestra server management**:

#### Option 1: Kestra Already Running

```bash
# If Kestra is already running, script detects it:
./scripts/deploy.sh dev

# Output:
# ✓ Kestra server is accessible at http://localhost:8080
```

#### Option 2: Start Kestra Automatically

```bash
# Use --start-kestra flag to auto-start:
./scripts/deploy.sh dev --start-kestra

# The script will:
# 1. Check if Kestra is running
# 2. If not, download Kestra binary (if needed)
# 3. Start Kestra in background
# 4. Wait for it to be ready (max 60 seconds)
# 5. Continue with deployment
```

#### Option 3: Manual Start (Recommended for Development)

```bash
# Terminal 1: Start Kestra manually
./kestra server standalone

# Terminal 2: Run deployment
./scripts/deploy.sh dev --full
```

### Kestra Server Lifecycle

**After Deployment:**
- ✅ Kestra server **remains running** (if started with `--start-kestra`)
- ✅ Workflows are **scheduled** and run automatically
- ✅ You can **close the terminal** (if started with `nohup`)

**To Check Kestra Status:**
```bash
# Check if Kestra is running
curl http://localhost:8080/api/v1/flows

# Or check process
ps aux | grep kestra

# Or use monitoring script
./scripts/monitor.sh
```

**To Stop Kestra:**
```bash
# Find Kestra process
ps aux | grep kestra

# Kill process
kill <PID>

# Or if started in foreground, just Ctrl+C
```

### Recommended Workflow for Reviewers

```bash
# Step 1: Start Kestra (one-time)
./kestra server standalone &

# Step 2: Deploy everything
./scripts/deploy.sh dev --full

# Step 3: Monitor (Kestra keeps running)
./scripts/monitor.sh

# Kestra will continue running and executing workflows automatically
```

---

## 🎯 Complete Deployment Example (March 2026)

Here's the **recommended deployment flow** that handles all three concerns:

```bash
# 1. Configure environment
./scripts/setup-env.sh

# 2. Update Kestra KV values
# Edit kestra/flows/citibike_kv.yml with your GCP project details

# 3. Deploy with full backfill and auto-start Kestra
./scripts/deploy.sh dev --full --start-kestra

# When prompted for trip data:
# Enter start month: 202601
# Enter end month: 202603

# When prompted for weather data:
# Enter start date: 2026-01-01
# Enter end date: 2026-03-13

# This will:
# ✅ Start Kestra server (if not running)
# ✅ Deploy Terraform infrastructure
# ✅ Deploy Kestra workflows
# ✅ Initialize KV store (citibike_kv workflow)
# ✅ Deploy dbt models
# ✅ Trigger trip data backfill (Jan-Mar 2026)
# ✅ Trigger weather data backfill (Jan 1 - Mar 13, 2026)
# ✅ Verify deployment

# 4. Monitor progress
./scripts/monitor.sh

# 5. Check Kestra UI
# Open: http://localhost:8080
```

---

## 📊 Deployment Timeline (March 2026)

### With Full Backfill (Q1 2026 Data)

| Step | Time | Status |
|------|------|--------|
| Prerequisites check | 30s | Automatic |
| Terraform deployment | 3-5 min | Automatic |
| Kestra workflows | 1 min | Automatic |
| KV store initialization | 10s | Automatic |
| dbt models | 2-3 min | Automatic |
| Trip backfill (Jan-Mar 2026) | 15-30 min | Background |
| Weather backfill (90 days) | 2-5 min | Background |
| **Total** | **25-45 min** | **Mostly automated** |

### Without Backfill

| Step | Time | Status |
|------|------|--------|
| Prerequisites check | 30s | Automatic |
| Terraform deployment | 3-5 min | Automatic |
| Kestra workflows | 1 min | Automatic |
| KV store initialization | 10s | Automatic |
| dbt models | 2-3 min | Automatic |
| Initial data load | 1 min | Automatic |
| **Total** | **8-12 min** | **Fully automated** |

---

## 🔍 Verification Checklist

After deployment, verify:

```bash
# 1. Check Kestra is running
curl http://localhost:8080/api/v1/flows
# Expected: JSON response with flows

# 2. Check KV store values
# In Kestra UI: Settings → KV Store
# Should see: GCP_PROJECT_ID, GCP_LOCATION, GCP_BUCKET_NAME, GCP_DATASET

# 3. Check workflows are scheduled
# In Kestra UI: Flows
# Should see 5 workflows with schedules

# 4. Check executions
# In Kestra UI: Executions
# Should see recent runs (station status, backfills if triggered)

# 5. Check BigQuery data
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) FROM \`PROJECT.DATASET.station_status_streaming\`"
# Expected: > 0 rows

# 6. Check trip data (if backfilled)
bq query --use_legacy_sql=false \
  "SELECT 
     MIN(started_at) as earliest_trip,
     MAX(started_at) as latest_trip,
     COUNT(*) as total_trips
   FROM \`PROJECT.DATASET.citibike_trips_raw\`"
# Expected: Trips from Jan-Mar 2026

# 7. Run monitoring script
./scripts/monitor.sh
# Expected: All checks passing
```

---

## 🚨 Troubleshooting

### Issue: KV Store Not Initialized

**Symptom:** Workflows fail with "KV key not found"

**Solution:**
```bash
# Manually trigger KV initialization
curl -X POST http://localhost:8080/api/v1/executions/citibike.nyc/citibike_kv

# Or in Kestra UI:
# Flows → citibike.nyc → citibike_kv → Execute
```

### Issue: Backfill Not Starting

**Symptom:** No executions visible in Kestra UI

**Solution:**
```bash
# Check Kestra logs
tail -f kestra.log

# Manually trigger backfill for March 2026
curl -X POST http://localhost:8080/api/v1/executions/citibike.nyc/nyc_bikes_parent \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"month": "202603"}}'
```

### Issue: Kestra Server Not Starting

**Symptom:** "Cannot connect to Kestra server"

**Solution:**
```bash
# Check if port 8080 is in use
lsof -i :8080

# Start Kestra manually
./kestra server standalone

# Check logs
tail -f kestra.log
```

---

## 📚 Additional Resources

- **Kestra KV Store Docs:** https://kestra.io/docs/developer-guide/kv-store
- **Kestra Backfill Docs:** https://kestra.io/docs/workflow-components/triggers#backfill
- **Script Usage:** See `scripts/deploy.sh --help`

---

## 🎓 For Zoomcamp Reviewers (March 2026)

**Recommended deployment command:**

```bash
# One-command deployment with everything
./scripts/deploy.sh dev --full --start-kestra

# When prompted, use current 2026 dates:
# Trip data: 202601 to 202603
# Weather data: 2026-01-01 to 2026-03-13

# Then monitor
./scripts/monitor.sh
```

This handles:
- ✅ Kestra server startup
- ✅ KV store initialization
- ✅ Workflow deployment
- ✅ Data backfill for Q1 2026
- ✅ Verification

**Total time:** 25-45 minutes (mostly automated, runs in background)

---

*All three concerns are now addressed with current 2026 dates!*