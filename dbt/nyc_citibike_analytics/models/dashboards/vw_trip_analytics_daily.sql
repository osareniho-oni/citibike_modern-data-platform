{{
  config(
    materialized='view',
    schema='citibike_dashboards',
    tags=['dashboard', 'trip_analytics']
  )
}}

-- Trip Analytics Daily Dashboard View
-- Purpose: Pre-aggregated daily trip metrics for Looker Studio
-- Refresh: This view queries live data; consider converting to materialized view for hourly refresh
-- Data Range: Last 90 days (rolling window)

WITH daily_trip_metrics AS (
  SELECT
    -- Date dimensions
    d.full_date as date_day,
    d.day_name,
    d.is_weekend,
    d.month_name,
    d.quarter,
    d.year,
    d.week_of_year,
    
    -- Time dimensions (aggregated to hour level)
    t.hour as hour_of_day,
    t.time_bucket as time_of_day_name,
    t.is_rush_hour,
    
    -- User type
    u.user_type_name,
    u.has_subscription as is_member,
    
    -- Bike type
    f.bike_type as rideable_type,
    
    -- Aggregated metrics
    COUNT(*) AS trip_count,
    AVG(f.trip_duration_minutes) AS avg_trip_duration,
    MIN(f.trip_duration_minutes) AS min_trip_duration,
    MAX(f.trip_duration_minutes) AS max_trip_duration,
    STDDEV(f.trip_duration_minutes) AS stddev_trip_duration,
    
    -- Trip duration categories
    SUM(CASE WHEN f.trip_duration_minutes < 5 THEN 1 ELSE 0 END) AS very_short_trips,
    SUM(CASE WHEN f.trip_duration_minutes >= 5 AND f.trip_duration_minutes < 15 THEN 1 ELSE 0 END) AS short_trips,
    SUM(CASE WHEN f.trip_duration_minutes >= 15 AND f.trip_duration_minutes < 30 THEN 1 ELSE 0 END) AS medium_trips,
    SUM(CASE WHEN f.trip_duration_minutes >= 30 AND f.trip_duration_minutes < 60 THEN 1 ELSE 0 END) AS long_trips,
    SUM(CASE WHEN f.trip_duration_minutes >= 60 THEN 1 ELSE 0 END) AS very_long_trips,
    
    -- User type breakdown
    SUM(CASE WHEN u.has_subscription = TRUE THEN 1 ELSE 0 END) AS member_trips,
    SUM(CASE WHEN u.has_subscription = FALSE THEN 1 ELSE 0 END) AS casual_trips,
    
    -- Bike type breakdown
    SUM(CASE WHEN f.bike_type = 'electric_bike' THEN 1 ELSE 0 END) AS electric_bike_trips,
    SUM(CASE WHEN f.bike_type = 'classic_bike' THEN 1 ELSE 0 END) AS classic_bike_trips,
    
    -- Unique stations
    COUNT(DISTINCT f.start_station_key) AS unique_start_stations,
    COUNT(DISTINCT f.end_station_key) AS unique_end_stations

  FROM {{ ref('fct_trips') }} f
  INNER JOIN {{ ref('dim_date') }} d
    ON f.start_date_key = d.date_key
  INNER JOIN {{ ref('dim_time') }} t
    ON f.start_hour_key = t.time_key
  INNER JOIN {{ ref('dim_user_type') }} u
    ON f.user_type_key = u.user_type_key
  
  -- Filter for last 90 days (rolling window)
  WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND d.full_date <= CURRENT_DATE()
  
  GROUP BY
    d.full_date,
    d.day_name,
    d.is_weekend,
    d.month_name,
    d.quarter,
    d.year,
    d.week_of_year,
    t.hour,
    t.time_bucket,
    t.is_rush_hour,
    u.user_type_name,
    u.has_subscription,
    f.bike_type
)

SELECT
  *,
  -- Calculated percentages
  SAFE_DIVIDE(member_trips, trip_count) * 100 AS member_pct,
  SAFE_DIVIDE(casual_trips, trip_count) * 100 AS casual_pct,
  SAFE_DIVIDE(electric_bike_trips, trip_count) * 100 AS electric_bike_pct,
  SAFE_DIVIDE(classic_bike_trips, trip_count) * 100 AS classic_bike_pct,
  
  -- Day of week ranking
  ROW_NUMBER() OVER (
    PARTITION BY date_day 
    ORDER BY trip_count DESC
  ) AS hourly_rank_by_day,
  
  -- Overall ranking
  ROW_NUMBER() OVER (
    ORDER BY date_day DESC, trip_count DESC
  ) AS overall_rank

FROM daily_trip_metrics

ORDER BY date_day DESC, hour_of_day ASC