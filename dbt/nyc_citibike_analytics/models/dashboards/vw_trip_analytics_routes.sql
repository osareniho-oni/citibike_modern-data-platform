{{
  config(
    materialized='view',
    schema='citibike_dashboards',
    tags=['dashboard', 'trip_analytics', 'routes']
  )
}}

-- Trip Analytics Routes Dashboard View
-- Purpose: Route-level analysis (start/end station pairs) for Looker Studio
-- Refresh: Standard view (queries on-demand)
-- Data Range: Last 30 days for performance

WITH route_metrics AS (
  SELECT
    -- Route information
    ss.station_id AS start_station_id,
    ss.station_name AS start_station_name,
    ss.latitude AS start_latitude,
    ss.longitude AS start_longitude,
    
    es.station_id AS end_station_id,
    es.station_name AS end_station_name,
    es.latitude AS end_latitude,
    es.longitude AS end_longitude,
    
    -- User type
    u.user_type_name,
    u.has_subscription AS is_member,
    
    -- Bike type
    f.bike_type AS rideable_type,
    
    -- Aggregated metrics
    COUNT(*) AS trip_count,
    AVG(f.trip_duration_minutes) AS avg_duration_minutes,
    MIN(f.trip_duration_minutes) AS min_duration_minutes,
    MAX(f.trip_duration_minutes) AS max_duration_minutes,
    
    -- User type breakdown
    SUM(CASE WHEN u.has_subscription = TRUE THEN 1 ELSE 0 END) AS member_trips,
    SUM(CASE WHEN u.has_subscription = FALSE THEN 1 ELSE 0 END) AS casual_trips,
    
    -- Bike type breakdown
    SUM(CASE WHEN f.bike_type = 'electric_bike' THEN 1 ELSE 0 END) AS electric_trips,
    SUM(CASE WHEN f.bike_type = 'classic_bike' THEN 1 ELSE 0 END) AS classic_trips

  FROM {{ ref('fct_trips') }} f
  LEFT JOIN {{ ref('dim_station') }} ss
    ON f.start_station_key = ss.station_key
  LEFT JOIN {{ ref('dim_station') }} es
    ON f.end_station_key = es.station_key
  INNER JOIN {{ ref('dim_date') }} d
    ON f.start_date_key = d.date_key
  INNER JOIN {{ ref('dim_user_type') }} u
    ON f.user_type_key = u.user_type_key
  
  -- Filter for last 30 days and valid routes
  WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND d.full_date <= CURRENT_DATE()
    AND f.start_station_key IS NOT NULL
    AND f.end_station_key IS NOT NULL
    AND f.start_station_key != f.end_station_key  -- Exclude round trips to same station
  
  GROUP BY
    ss.station_id,
    ss.station_name,
    ss.latitude,
    ss.longitude,
    es.station_id,
    es.station_name,
    es.latitude,
    es.longitude,
    u.user_type_name,
    u.has_subscription,
    f.bike_type
)

SELECT
  *,
  -- Calculated percentages
  SAFE_DIVIDE(member_trips, trip_count) * 100 AS member_pct,
  SAFE_DIVIDE(casual_trips, trip_count) * 100 AS casual_pct,
  SAFE_DIVIDE(electric_trips, trip_count) * 100 AS electric_pct,
  SAFE_DIVIDE(classic_trips, trip_count) * 100 AS classic_pct,
  
  -- Route popularity ranking
  ROW_NUMBER() OVER (ORDER BY trip_count DESC) AS popularity_rank,
  
  -- Route category based on trip count
  CASE
    WHEN trip_count >= 1000 THEN 'Very Popular'
    WHEN trip_count >= 500 THEN 'Popular'
    WHEN trip_count >= 100 THEN 'Moderate'
    WHEN trip_count >= 20 THEN 'Low'
    ELSE 'Very Low'
  END AS route_popularity_category

FROM route_metrics

-- Order by most popular routes
ORDER BY trip_count DESC