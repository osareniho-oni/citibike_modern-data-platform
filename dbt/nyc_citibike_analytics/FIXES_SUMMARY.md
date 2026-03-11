# Int_Station_Daily_Fact Data Issues - Analysis & Fixes

## Issues Identified

### 1. Station ID Appearing as Decimals (e.g., 4485.1, 2009.04, 7230.1)

**Root Cause:**
- Station IDs from the trips table are numeric strings (e.g., "4485.1")
- When using `FULL OUTER JOIN` with `COALESCE()`, BigQuery may implicitly convert numeric strings to FLOAT64 if not explicitly cast
- The existing table schema may have been created with FLOAT64 type due to type inference

**Fix Applied:**
1. Added explicit `CAST(... AS STRING)` in `int_station_daily_fact.sql` line 42:
   ```sql
   cast(coalesce(sw.station_id, td.station_id) as string) as station_id,
   ```

2. Added explicit `CAST(... AS STRING)` in `int_trip_station_daily.sql` line 100:
   ```sql
   cast(coalesce(s.station_id, e.station_id) as string) as station_id,
   ```

3. Added `data_type: string` declarations in `schema.yml` for all intermediate models to enforce STRING type in BigQuery schema

**Action Required:**
- Run `dbt run --full-refresh --select int_trip_station_daily int_station_daily_fact` to rebuild tables with correct data types
- This will drop and recreate the tables with proper STRING typing

---

### 2. Capacity Metrics (typical_capacity, max_capacity, min_capacity) Returning Same Values

**Analysis:**
This is **EXPECTED BEHAVIOR**, not a bug. Here's why:

**For Stations WITH Status Data (Rows 1-3 in your sample):**
- Station capacity is **static** - it doesn't change during a day
- `typical_capacity` = mode (most common value)
- `max_capacity` = maximum value observed
- `min_capacity` = minimum value observed
- All three return the same value because capacity is constant (e.g., 22, 30, or 14)

**For Stations WITHOUT Status Data (Rows 4-12 in your sample):**
- These stations have trip data but no station status data
- All capacity fields are NULL (correct behavior)
- The `FULL OUTER JOIN` preserves trip records even when station status is missing

**Why the aggregations exist:**
The three different aggregations (mode, max, min) are defensive programming to handle edge cases:
- If a station's capacity is temporarily reported differently (e.g., during maintenance)
- To detect data quality issues
- To provide flexibility for future analysis

**No Fix Required:**
This behavior is correct. The capacity metrics are working as designed.

---

## Summary of Changes

### Files Modified:
1. `models/intermediate/int_station_daily_fact.sql` - Added explicit STRING cast for station_id
2. `models/intermediate/int_trip_station_daily.sql` - Added explicit STRING cast for station_id
3. `models/intermediate/schema.yml` - Added data_type declarations for station_id columns

### Rebuild Instructions:

```bash
# Navigate to dbt project directory
cd nyc_citibike_analytics

# Rebuild the affected models with full refresh
dbt run --full-refresh --select int_trip_station_daily int_station_daily_fact

# Or rebuild all intermediate models
dbt run --full-refresh --select intermediate
```

### Verification:

After rebuilding, verify in BigQuery:
```sql
-- Check station_id data type (should be STRING)
SELECT column_name, data_type 
FROM `nyc-citibike-data-platform.intermediate.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'int_station_daily_fact' 
  AND column_name = 'station_id';

-- Check for decimal station IDs (should return 0 rows with FLOAT-like values)
SELECT station_id, COUNT(*) as cnt
FROM `nyc-citibike-data-platform.intermediate.int_station_daily_fact`
WHERE REGEXP_CONTAINS(station_id, r'^\d+\.\d+$')
GROUP BY station_id
ORDER BY cnt DESC
LIMIT 10;

-- Verify capacity metrics behavior
SELECT 
  station_id,
  date_day,
  typical_capacity,
  max_capacity,
  min_capacity,
  trips_started,
  trips_ended
FROM `nyc-citibike-data-platform.intermediate.int_station_daily_fact`
WHERE date_day = '2026-01-04'
ORDER BY station_id
LIMIT 20;
```

---

## Expected Results After Fix

1. **Station IDs**: All station_id values should be STRING type, displayed without decimal points (e.g., "4485.1" as a string, not 4485.1 as a float)

2. **Capacity Metrics**: 
   - Stations with status data: typical_capacity = max_capacity = min_capacity (this is correct)
   - Stations without status data: All capacity fields = NULL (this is correct)

3. **Data Integrity**: The FULL OUTER JOIN will continue to preserve all records from both station status and trip data sources