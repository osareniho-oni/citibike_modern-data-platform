-- ============================================================================
-- KEY UNIQUENESS AND DATA CONSISTENCY VALIDATION
-- ============================================================================
-- Purpose: Query BigQuery to verify no duplicate keys and validate record counts
-- Run this in BigQuery console or via dbt run-operation
-- ============================================================================

-- ============================================================================
-- 1. STAGING MODELS - Check for Duplicates
-- ============================================================================

-- stg_trips: Check for duplicate ride_id
SELECT 
    'stg_trips' as model_name,
    'ride_id' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT ride_id) as unique_keys,
    COUNT(*) - COUNT(DISTINCT ride_id) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT ride_id) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_staging.stg_trips`

UNION ALL

-- stg_weather: Check for duplicate weather_date
SELECT 
    'stg_weather' as model_name,
    'weather_date' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT weather_date) as unique_keys,
    COUNT(*) - COUNT(DISTINCT weather_date) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT weather_date) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_staging.stg_weather`

UNION ALL

-- stg_station_status: Check composite key (station_id + last_reported)
SELECT 
    'stg_station_status' as model_name,
    'station_id + last_reported' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(last_reported AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(last_reported AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(last_reported AS STRING))) THEN '✅ PASS' ELSE '⚠️ WARNING' END as status
FROM `{{ target.project }}.{{ target.dataset }}_staging.stg_station_status`;

-- ============================================================================
-- 2. INTERMEDIATE MODELS - Check Composite Keys
-- ============================================================================

-- int_station_metrics: Check station_id + reported_at_5min
SELECT 
    'int_station_metrics' as model_name,
    'station_id + reported_at_5min' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(reported_at_5min AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(reported_at_5min AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(reported_at_5min AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_intermediate.int_station_metrics`

UNION ALL

-- int_station_daily_metrics: Check station_id + date_day
SELECT 
    'int_station_daily_metrics' as model_name,
    'station_id + date_day' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_intermediate.int_station_daily_metrics`

UNION ALL

-- int_trip_station_daily: Check station_id + date_day
SELECT 
    'int_trip_station_daily' as model_name,
    'station_id + date_day' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_intermediate.int_trip_station_daily`

UNION ALL

-- int_station_weather_daily: Check station_id + date_day
SELECT 
    'int_station_weather_daily' as model_name,
    'station_id + date_day' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_intermediate.int_station_weather_daily`

UNION ALL

-- int_station_daily_fact: Check station_id + date_day
SELECT 
    'int_station_daily_fact' as model_name,
    'station_id + date_day' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_id, '|', CAST(date_day AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_intermediate.int_station_daily_fact`;

-- ============================================================================
-- 3. DIMENSION TABLES - Check Primary Keys
-- ============================================================================

-- dim_date: Check date_key
SELECT 
    'dim_date' as model_name,
    'date_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT date_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT date_key) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT date_key) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_date`

UNION ALL

-- dim_station: Check station_key (should be unique across all versions)
SELECT 
    'dim_station' as model_name,
    'station_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT station_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT station_key) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT station_key) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_station`

UNION ALL

-- dim_time: Check time_key
SELECT 
    'dim_time' as model_name,
    'time_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT time_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT time_key) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT time_key) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_time`

UNION ALL

-- dim_user_type: Check user_type_key
SELECT 
    'dim_user_type' as model_name,
    'user_type_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_type_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT user_type_key) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT user_type_key) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_user_type`;

-- ============================================================================
-- 4. FACT TABLES - Check Primary/Composite Keys
-- ============================================================================

-- fct_trips: Check trip_key
SELECT 
    'fct_trips' as model_name,
    'trip_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT trip_key) as unique_keys,
    COUNT(*) - COUNT(DISTINCT trip_key) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT trip_key) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips`

UNION ALL

-- fct_station_day: Check station_key + date_key
SELECT 
    'fct_station_day' as model_name,
    'station_key + date_key' as key_column,
    COUNT(*) as total_records,
    COUNT(DISTINCT CONCAT(station_key, '|', CAST(date_key AS STRING))) as unique_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(station_key, '|', CAST(date_key AS STRING))) as duplicate_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(station_key, '|', CAST(date_key AS STRING))) THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_station_day`;

-- ============================================================================
-- 5. RECORD COUNT CONSISTENCY CHECKS
-- ============================================================================

-- Compare trip counts across layers
WITH trip_counts AS (
    SELECT 'stg_trips' as layer, COUNT(*) as record_count
    FROM `{{ target.project }}.{{ target.dataset }}_staging.stg_trips`
    UNION ALL
    SELECT 'fct_trips' as layer, COUNT(*) as record_count
    FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips`
)
SELECT 
    'Trip Count Consistency' as check_name,
    STRING_AGG(CONCAT(layer, ': ', FORMAT('%,d', record_count)), ' | ') as counts,
    CASE 
        WHEN COUNT(DISTINCT record_count) = 1 THEN '✅ PASS - Counts match'
        ELSE '⚠️ WARNING - Counts differ (may be expected if incremental)'
    END as status
FROM trip_counts;

-- ============================================================================
-- 6. FOREIGN KEY INTEGRITY CHECKS
-- ============================================================================

-- Check for orphaned records in fct_trips (start_station_key not in dim_station)
SELECT 
    'fct_trips → dim_station (start)' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_station` d
    ON f.start_station_key = d.station_key
WHERE d.station_key IS NULL

UNION ALL

-- Check for orphaned records in fct_trips (end_station_key not in dim_station)
SELECT 
    'fct_trips → dim_station (end)' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_station` d
    ON f.end_station_key = d.station_key
WHERE d.station_key IS NULL

UNION ALL

-- Check for orphaned records in fct_trips (start_date_key not in dim_date)
SELECT 
    'fct_trips → dim_date (start)' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_date` d
    ON f.start_date_key = d.date_key
WHERE d.date_key IS NULL

UNION ALL

-- Check for orphaned records in fct_trips (user_type_key not in dim_user_type)
SELECT 
    'fct_trips → dim_user_type' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_user_type` d
    ON f.user_type_key = d.user_type_key
WHERE d.user_type_key IS NULL

UNION ALL

-- Check for orphaned records in fct_station_day (station_key not in dim_station)
SELECT 
    'fct_station_day → dim_station' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_station_day` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_station` d
    ON f.station_key = d.station_key
WHERE d.station_key IS NULL

UNION ALL

-- Check for orphaned records in fct_station_day (date_key not in dim_date)
SELECT 
    'fct_station_day → dim_date' as relationship,
    COUNT(*) as orphaned_records,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_station_day` f
LEFT JOIN `{{ target.project }}.{{ target.dataset }}_marts.dim_date` d
    ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

-- ============================================================================
-- 7. DIMENSION TABLE RECORD COUNTS
-- ============================================================================

SELECT 
    'dim_date' as dimension,
    COUNT(*) as record_count,
    MIN(full_date) as min_date,
    MAX(full_date) as max_date,
    DATE_DIFF(MAX(full_date), MIN(full_date), DAY) + 1 as expected_count,
    CASE 
        WHEN COUNT(*) = DATE_DIFF(MAX(full_date), MIN(full_date), DAY) + 1 
        THEN '✅ PASS - Continuous dates'
        ELSE '⚠️ WARNING - Date gaps exist'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_date`

UNION ALL

SELECT 
    'dim_station' as dimension,
    COUNT(*) as record_count,
    COUNT(DISTINCT station_id) as unique_stations,
    SUM(CASE WHEN is_current THEN 1 ELSE 0 END) as current_versions,
    CASE 
        WHEN COUNT(*) >= COUNT(DISTINCT station_id) 
        THEN '✅ PASS - SCD Type 2 working'
        ELSE '❌ FAIL - Fewer records than stations'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_station`

UNION ALL

SELECT 
    'dim_time' as dimension,
    COUNT(*) as record_count,
    24 as expected_count,
    24 as expected_count_dup,
    CASE 
        WHEN COUNT(*) = 24 
        THEN '✅ PASS - All 24 hours present'
        ELSE '❌ FAIL - Missing hours'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_time`

UNION ALL

SELECT 
    'dim_user_type' as dimension,
    COUNT(*) as record_count,
    3 as expected_count,
    3 as expected_count_dup,
    CASE 
        WHEN COUNT(*) = 3 
        THEN '✅ PASS - All 3 user types present'
        ELSE '❌ FAIL - Missing user types'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.dim_user_type`;

-- ============================================================================
-- 8. NULL KEY CHECKS
-- ============================================================================

-- Check for NULL keys in fct_trips
SELECT 
    'fct_trips NULL keys' as check_name,
    SUM(CASE WHEN trip_key IS NULL THEN 1 ELSE 0 END) as null_trip_key,
    SUM(CASE WHEN start_station_key IS NULL THEN 1 ELSE 0 END) as null_start_station,
    SUM(CASE WHEN end_station_key IS NULL THEN 1 ELSE 0 END) as null_end_station,
    SUM(CASE WHEN start_date_key IS NULL THEN 1 ELSE 0 END) as null_start_date,
    SUM(CASE WHEN user_type_key IS NULL THEN 1 ELSE 0 END) as null_user_type,
    CASE 
        WHEN SUM(CASE WHEN trip_key IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN start_station_key IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN end_station_key IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN start_date_key IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN user_type_key IS NULL THEN 1 ELSE 0 END) = 0
        THEN '✅ PASS - No NULL keys'
        ELSE '❌ FAIL - NULL keys found'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_trips`

UNION ALL

-- Check for NULL keys in fct_station_day
SELECT 
    'fct_station_day NULL keys' as check_name,
    SUM(CASE WHEN station_key IS NULL THEN 1 ELSE 0 END) as null_station_key,
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) as null_date_key,
    0 as null_col3,
    0 as null_col4,
    0 as null_col5,
    CASE 
        WHEN SUM(CASE WHEN station_key IS NULL THEN 1 ELSE 0 END) = 0
        AND SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) = 0
        THEN '✅ PASS - No NULL keys'
        ELSE '❌ FAIL - NULL keys found'
    END as status
FROM `{{ target.project }}.{{ target.dataset }}_marts.fct_station_day`;