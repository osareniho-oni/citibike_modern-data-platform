# Marts Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the star schema data marts for the NYC Citibike analytics project.

---

## 📁 Files Created

### Dimensions
- `models/marts/dimensions/dim_date.sql` - Date dimension with dynamic generation
- `models/marts/dimensions/dim_user_type.sql` - User type dimension
- `models/marts/dimensions/dim_time.sql` - Time of day dimension
- `models/marts/dimensions/dim_station.sql` - Station dimension (current state)

### Facts
- `models/marts/facts/fct_trips.sql` - Transactional trip fact table
- `models/marts/facts/fct_station_day.sql` - Aggregate station-day fact table

### Snapshots
- `snapshots/snap_station.sql` - SCD Type 2 snapshot for station dimension

### Documentation
- `models/marts/schema.yml` - Comprehensive schema documentation and tests

---

## 🚀 Implementation Steps

### Phase 1: Prerequisites

Before running the marts, ensure you have:

1. **Completed intermediate models:**
   ```bash
   dbt run --select intermediate
   ```

2. **dbt_utils package installed:**
   Check `packages.yml` includes:
   ```yaml
   packages:
     - package: dbt-labs/dbt_utils
       version: 1.1.1
   ```
   
   Then run:
   ```bash
   dbt deps
   ```

### Phase 2: Build Dimensions (Order Matters!)

Run dimensions in dependency order:

```bash
# Step 1: Build simple dimensions (no dependencies)
dbt run --select dim_date dim_user_type dim_time

# Step 2: Build station snapshot (requires int_station_daily_metrics)
dbt snapshot --select snap_station

# Step 3: Build station dimension (requires snapshot)
dbt run --select dim_station
```

**Expected Results:**
- `dim_date`: ~1,000-2,000 rows (depending on date range)
- `dim_user_type`: 3 rows (member, casual, unknown)
- `dim_time`: 24 rows (0-23 hours)
- `snap_station`: Variable (depends on station count)
- `dim_station`: Variable + 1 (stations + unknown record)

### Phase 3: Build Fact Tables

```bash
# Step 4: Build transactional fact (requires all dimensions)
dbt run --select fct_trips

# Step 5: Build aggregate fact (requires dimensions)
dbt run --select fct_station_day
```

**Expected Results:**
- `fct_trips`: Millions of rows (1 per trip)
- `fct_station_day`: Thousands of rows (stations × days)

### Phase 4: Run Tests

```bash
# Test all marts
dbt test --select marts

# Test specific models
dbt test --select dim_date
dbt test --select fct_trips
dbt test --select fct_station_day
```

### Phase 5: Full Refresh (If Needed)

If you need to rebuild everything:

```bash
# Full refresh all marts
dbt run --select marts --full-refresh

# Full refresh specific model
dbt run --select fct_trips --full-refresh
```

---

## 🔧 Troubleshooting

### Issue 1: Missing stg_station_info

**Error:** `Compilation Error: Model 'stg_station_info' not found`

**Solution:** The snapshot currently references a non-existent staging model. You have two options:

**Option A: Create stg_station_info (Recommended)**
```sql
-- models/staging/stg_station_info.sql
-- Create this if you have a station information source
```

**Option B: Use existing data (Temporary)**
The snapshot is already configured to fall back to `int_station_daily_metrics`. This will work but won't track name/location changes.

### Issue 2: Snapshot Fails on First Run

**Error:** `Snapshot target does not exist`

**Solution:** This is normal on first run. dbt will create the snapshot table automatically.

### Issue 3: Surrogate Key Collisions

**Error:** `Duplicate key value violates unique constraint`

**Solution:** 
1. Check if `dbt_utils` is installed: `dbt deps`
2. Verify unique_key configuration in model config
3. Run with `--full-refresh` to rebuild

### Issue 4: Incremental Model Not Updating

**Problem:** New data not appearing in incremental models

**Solution:**
```bash
# Force full refresh
dbt run --select fct_trips --full-refresh

# Or drop and recreate
dbt run-operation drop_relation --args '{relation: "fct_trips"}'
dbt run --select fct_trips
```

### Issue 5: Relationship Test Failures

**Error:** `Referential integrity test failed`

**Solution:**
1. Ensure dimensions are built before facts
2. Check for NULL foreign keys
3. Verify unknown/default records exist in dimensions

---

## 📊 Data Quality Checks

### Dimension Checks

```sql
-- Check dim_date coverage
SELECT 
  MIN(full_date) as min_date,
  MAX(full_date) as max_date,
  COUNT(*) as total_days
FROM {{ ref('dim_date') }};

-- Check dim_station for unknowns
SELECT COUNT(*) 
FROM {{ ref('dim_station') }}
WHERE station_id = '-1';  -- Should be 1

-- Check dim_user_type completeness
SELECT * FROM {{ ref('dim_user_type') }};  -- Should be 3 rows
```

### Fact Table Checks

```sql
-- Check fct_trips for orphaned records
SELECT COUNT(*) 
FROM {{ ref('fct_trips') }} f
LEFT JOIN {{ ref('dim_station') }} ds 
  ON f.start_station_key = ds.station_key
WHERE ds.station_key IS NULL;  -- Should be 0

-- Check fct_station_day grain
SELECT 
  station_key, 
  date_key, 
  COUNT(*) as cnt
FROM {{ ref('fct_station_day') }}
GROUP BY station_key, date_key
HAVING COUNT(*) > 1;  -- Should be 0 rows

-- Check measure reasonableness
SELECT 
  AVG(trip_duration_minutes) as avg_duration,
  MIN(trip_duration_minutes) as min_duration,
  MAX(trip_duration_minutes) as max_duration
FROM {{ ref('fct_trips') }}
WHERE trip_duration_minutes > 0;
```

---

## 🎯 Performance Optimization

### Partitioning Strategy

Both fact tables are partitioned for optimal performance:

**fct_trips:**
- Partitioned by: `start_date_key` (integer range)
- Clustered by: `start_station_key`, `user_type_key`
- Best for: Time-based queries with station filters

**fct_station_day:**
- Partitioned by: `date_key` (integer range)
- Clustered by: `station_key`
- Best for: Station-specific time series analysis

### Query Optimization Tips

```sql
-- ✅ GOOD: Uses partition pruning
SELECT * 
FROM {{ ref('fct_trips') }}
WHERE start_date_key BETWEEN 20240101 AND 20240131
  AND start_station_key = 'abc123';

-- ❌ BAD: Full table scan
SELECT * 
FROM {{ ref('fct_trips') }}
WHERE started_at BETWEEN '2024-01-01' AND '2024-01-31';
```

### Incremental Strategy

Both facts use `merge` strategy:
- Handles late-arriving data
- Updates existing records
- More expensive than `append` but more accurate

---

## 📈 Usage Examples

### Example 1: Daily Trip Analysis

```sql
SELECT 
  d.full_date,
  d.day_name,
  d.is_weekend,
  COUNT(f.trip_key) as total_trips,
  AVG(f.trip_duration_minutes) as avg_duration,
  SUM(f.trip_distance_km) as total_distance
FROM {{ ref('fct_trips') }} f
JOIN {{ ref('dim_date') }} d 
  ON f.start_date_key = d.date_key
WHERE d.year = 2024
  AND d.month = 1
GROUP BY 1, 2, 3
ORDER BY 1;
```

### Example 2: Station Performance Dashboard

```sql
SELECT 
  s.station_name,
  s.borough,
  d.day_name,
  f.trips_started,
  f.trips_ended,
  f.net_trips,
  f.avg_occupancy_ratio,
  f.operational_health_score,
  f.demand_trend
FROM {{ ref('fct_station_day') }} f
JOIN {{ ref('dim_station') }} s 
  ON f.station_key = s.station_key
JOIN {{ ref('dim_date') }} d 
  ON f.date_key = d.date_key
WHERE d.full_date = CURRENT_DATE() - 1
  AND s.is_active = TRUE
ORDER BY f.trips_started DESC
LIMIT 20;
```

### Example 3: Rush Hour Analysis

```sql
SELECT 
  t.hour_name,
  t.time_bucket,
  t.is_rush_hour,
  u.user_type_name,
  COUNT(f.trip_key) as trip_count,
  AVG(f.trip_duration_minutes) as avg_duration
FROM {{ ref('fct_trips') }} f
JOIN {{ ref('dim_time') }} t 
  ON f.start_hour_key = t.time_key
JOIN {{ ref('dim_user_type') }} u 
  ON f.user_type_key = u.user_type_key
JOIN {{ ref('dim_date') }} d 
  ON f.start_date_key = d.date_key
WHERE d.is_weekend = FALSE
  AND d.year = 2024
GROUP BY 1, 2, 3, 4
ORDER BY 1, 4;
```

### Example 4: Weather Impact Analysis

```sql
SELECT 
  f.weather_condition,
  f.is_ideal_biking_weather,
  f.is_poor_biking_weather,
  COUNT(DISTINCT f.station_key) as stations,
  SUM(f.trips_started) as total_trips,
  AVG(f.avg_occupancy_ratio) as avg_occupancy,
  AVG(f.temperature_mean) as avg_temp
FROM {{ ref('fct_station_day') }} f
JOIN {{ ref('dim_date') }} d 
  ON f.date_key = d.date_key
WHERE d.year = 2024
  AND d.month IN (6, 7, 8)  -- Summer months
GROUP BY 1, 2, 3
ORDER BY 5 DESC;
```

---

## 🔄 Maintenance

### Daily Operations

```bash
# Run incremental updates (recommended for production)
dbt run --select marts

# Run tests
dbt test --select marts

# Update snapshots
dbt snapshot
```

### Weekly Operations

```bash
# Full refresh of aggregate facts (to recalculate rolling averages)
dbt run --select fct_station_day --full-refresh

# Run all tests including relationships
dbt test --select marts
```

### Monthly Operations

```bash
# Review and optimize partitions
# Check for data quality issues
# Update dimension attributes if needed
```

---

## 📝 Next Steps

1. **Create BI Views:** Build simplified views for Looker/Tableau
2. **Add More Dimensions:** Consider weather dimension, bike dimension
3. **Create Aggregate Tables:** Monthly/yearly rollups for faster queries
4. **Implement dbt Exposures:** Document downstream BI dashboards
5. **Set Up Alerts:** Monitor data quality and freshness

---

## 🆘 Support

For issues or questions:
1. Check dbt logs: `logs/dbt.log`
2. Review compiled SQL: `target/compiled/`
3. Check BigQuery console for detailed errors
4. Review this guide's troubleshooting section

---

## ✅ Success Criteria

Your marts implementation is successful when:

- [ ] All dimension tables build without errors
- [ ] All fact tables build without errors
- [ ] All dbt tests pass
- [ ] Referential integrity is maintained
- [ ] Query performance is acceptable (<5 seconds for typical queries)
- [ ] Data quality checks pass
- [ ] Documentation is complete and accurate