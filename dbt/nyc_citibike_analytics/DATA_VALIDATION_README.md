# Data Quality Validation Guide

This guide explains how to validate data quality, check for duplicate keys, and verify unique constraints across all dbt models.

## Overview

We have two validation approaches:
1. **Python Script** - Automated validation with detailed reporting
2. **SQL Queries** - Manual queries for ad-hoc checks

## Method 1: Python Validation Script (Recommended)

### Prerequisites

```bash
# Install required packages (using uv)
uv pip install tabulate
# google-cloud-bigquery should already be installed
```

### Setup

1. Ensure you're authenticated with GCP:
```bash
gcloud auth application-default login
```

2. Your project uses these schemas:
   - `staging` - for staging and intermediate models
   - `marts` - for dimension and fact tables
   - `snapshots` - for SCD Type 2 snapshots

### Run Validation

```bash
cd dbt/nyc_citibike_analytics

# Set your GCP project ID
export GCP_PROJECT_ID=nyc-citibike-data-platform

# Run the validation script with uv
uv run python validate_data_quality.py
```

**Note:** The script automatically uses the correct schema names (`staging`, `marts`) based on your dbt configuration.

### What It Checks

The script performs comprehensive validation:

#### 1. **Duplicate Key Checks**
- ✅ All staging models (stg_trips, stg_weather, stg_station_status)
- ✅ All intermediate models (int_station_metrics, int_station_daily_metrics, etc.)
- ✅ All dimension tables (dim_date, dim_station, dim_time, dim_user_type)
- ✅ All fact tables (fct_trips, fct_station_day)

#### 2. **Record Count Consistency**
- Compares record counts between staging and marts
- Identifies data loss or unexpected growth

#### 3. **Foreign Key Integrity**
- Validates all relationships between facts and dimensions
- Checks for orphaned records

#### 4. **Dimension Table Validation**
- dim_date: Verifies continuous date range
- dim_station: Validates SCD Type 2 implementation
- dim_time: Confirms all 24 hours present
- dim_user_type: Confirms all 3 user types present

#### 5. **NULL Key Checks**
- Ensures no NULL values in primary/foreign keys
- Critical for referential integrity

### Sample Output

```
================================================================================
1. CHECKING FOR DUPLICATE KEYS
================================================================================

+---------------------------+---------------------------+----------------+--------------+-------------+-----------+
| Model                     | Key                       | Total Records  | Unique Keys  | Duplicates  | Status    |
+===========================+===========================+================+==============+=============+===========+
| stg_trips                 | ride_id                   | 1,234,567      | 1,234,567    | 0           | ✅ PASS   |
| stg_weather               | weather_date              | 365            | 365          | 0           | ✅ PASS   |
| int_station_daily_metrics | station_id + date_day     | 45,678         | 45,678       | 0           | ✅ PASS   |
| dim_date                  | date_key                  | 730            | 730          | 0           | ✅ PASS   |
| fct_trips                 | trip_key                  | 1,234,567      | 1,234,567    | 0           | ✅ PASS   |
| fct_station_day           | station_key + date_key    | 45,678         | 45,678       | 0           | ✅ PASS   |
+---------------------------+---------------------------+----------------+--------------+-------------+-----------+

================================================================================
VALIDATION SUMMARY
================================================================================

✅ PASSED: 45/45
❌ FAILED: 0/45
⚠️  WARNINGS: 0/45

✅ ALL VALIDATIONS PASSED
```

## Method 2: Manual SQL Queries

If you prefer to run queries manually in BigQuery console, use the queries in `validate_keys_and_counts.sql`.

### Quick Manual Checks

#### Check for duplicates in fct_trips:
```sql
SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT trip_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT trip_key) as duplicates
FROM `nyc-citibike-data-platform.marts.fct_trips`;
```

#### Check for duplicates in fct_station_day:
```sql
SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_key, '|', CAST(date_key AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_key, '|', CAST(date_key AS STRING))) as duplicates
FROM `nyc-citibike-data-platform.marts.fct_station_day`;
```

#### Check foreign key integrity:
```sql
-- Check for orphaned trips (station not in dimension)
SELECT COUNT(*) as orphaned_records
FROM `nyc-citibike-data-platform.marts.fct_trips` f
LEFT JOIN `nyc-citibike-data-platform.marts.dim_station` d
    ON f.start_station_key = d.station_key
WHERE d.station_key IS NULL;
```

#### Verify dimension counts:
```sql
-- Should have 24 hours
SELECT COUNT(*) FROM `nyc-citibike-data-platform.marts.dim_time`;

-- Should have 3 user types
SELECT COUNT(*) FROM `nyc-citibike-data-platform.marts.dim_user_type`;

-- Should have continuous dates
SELECT
    COUNT(*) as actual_count,
    DATE_DIFF(MAX(full_date), MIN(full_date), DAY) + 1 as expected_count
FROM `nyc-citibike-data-platform.marts.dim_date`;
```

## Method 3: dbt Tests

Run dbt's built-in tests:

```bash
cd dbt/nyc_citibike_analytics

# Run all tests
dbt test

# Run only uniqueness tests
dbt test --select test_type:unique

# Run only relationship tests
dbt test --select test_type:relationships

# Test specific model
dbt test --select fct_trips
dbt test --select dim_station
```

## Troubleshooting

### Issue: "Table not found"
**Solution:** Ensure you've run `dbt build` to create all models:
```bash
dbt build --full-refresh
```

### Issue: "Permission denied"
**Solution:** Ensure your service account has BigQuery Data Viewer role:
```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer"
```

### Issue: Duplicates found
**Solution:** 
1. Check the source data for duplicates
2. Review incremental model logic
3. Verify unique_key configuration in model config
4. Run `dbt build --full-refresh` to rebuild from scratch

### Issue: Orphaned records
**Solution:**
1. Check if dimension tables are up to date
2. Verify late-arriving dimension handling (COALESCE with unknown keys)
3. Ensure dimensions are built before facts

## Best Practices

1. **Run validation after every dbt build:**
   ```bash
   dbt build && export GCP_PROJECT_ID=nyc-citibike-data-platform && uv run python validate_data_quality.py
   ```

2. **Add to CI/CD pipeline:**
   ```yaml
   - name: Validate Data Quality
     run: |
       cd dbt/nyc_citibike_analytics
       export GCP_PROJECT_ID=nyc-citibike-data-platform
       uv run python validate_data_quality.py
   ```

3. **Schedule regular validation:**
   - Run daily after data refresh
   - Alert on failures
   - Track trends over time

4. **Monitor key metrics:**
   - Duplicate count trends
   - Orphaned record counts
   - Record count growth rates
   - NULL key occurrences

## Expected Results

### All Models Should Have:
- ✅ Zero duplicate keys
- ✅ Zero NULL primary keys
- ✅ Zero orphaned foreign keys
- ✅ Consistent record counts across layers

### Dimension Tables:
- **dim_date**: Continuous date range, no gaps
- **dim_station**: Records ≥ unique stations (SCD Type 2)
- **dim_time**: Exactly 24 records (0-23 hours)
- **dim_user_type**: Exactly 3 records (member, casual, unknown)

### Fact Tables:
- **fct_trips**: 1 record per trip, matches stg_trips count
- **fct_station_day**: 1 record per station per day

## Additional Resources

- [dbt Testing Documentation](https://docs.getdbt.com/docs/build/tests)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
- [Data Quality Framework](../docs/DATA_QUALITY.md)

## Support

If validation fails:
1. Review the specific failure in the output
2. Check the model's SQL logic
3. Verify source data quality
4. Review recent changes in git history
5. Contact the data team for assistance