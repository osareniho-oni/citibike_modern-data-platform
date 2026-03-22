{{
  config(
    materialized='view',
    schema='citibike_dashboards',
    tags=['dashboard', 'weather_impact']
  )
}}

-- Weather Impact Dashboard View
-- Purpose: Daily weather conditions and their impact on ridership for Looker Studio
-- Refresh: This view queries live data; consider converting to materialized view for daily refresh
-- Data Range: Last 90 days (rolling window)

WITH daily_weather_metrics AS (
  SELECT
    -- Date dimension
    d.full_date as date_day,
    d.day_name,
    d.is_weekend,
    d.month_name,
    d.season,
    d.year,
    d.quarter,
    
    -- Weather conditions (take first non-null value per day)
    MAX(f.temperature_mean) AS temperature_celsius,
    MAX(f.temperature_range) AS temperature_range,
    MAX(f.precipitation_sum) AS precipitation_mm,
    MAX(f.wind_speed_max) AS wind_speed_kmh,
    MAX(f.weather_condition) AS weather_condition,
    MAX(f.weather_severity_score) AS weather_severity_score,
    MAX(CAST(f.is_ideal_biking_weather AS INT64)) AS is_ideal_biking_weather,
    MAX(CAST(f.is_poor_biking_weather AS INT64)) AS is_poor_biking_weather,
    MAX(CAST(f.is_raining AS INT64)) AS is_raining,
    MAX(CAST(f.is_snowing AS INT64)) AS is_snowing,
    MAX(CAST(f.is_freezing AS INT64)) AS is_freezing,
    MAX(CAST(f.is_windy AS INT64)) AS is_windy,
    
    -- Aggregated trip metrics across all stations
    SUM(f.trips_started) AS total_trips_started,
    SUM(f.trips_ended) AS total_trips_ended,
    AVG(f.avg_trip_duration_minutes) AS avg_trip_duration,
    
    -- Station availability metrics
    AVG(f.avg_bikes_available) AS avg_bikes_available,
    AVG(f.avg_utilization_percentage) AS avg_utilization_pct,
    AVG(f.operational_health_score) AS avg_health_score,
    
    -- Count of stations reporting
    COUNT(DISTINCT f.station_key) AS stations_reporting

  FROM {{ ref('fct_station_day') }} f
  INNER JOIN {{ ref('dim_date') }} d
    ON f.date_key = d.date_key
  
  -- Filter for last 90 days (rolling window)
  WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND d.full_date <= CURRENT_DATE()
  
  GROUP BY
    d.full_date,
    d.day_name,
    d.is_weekend,
    d.month_name,
    d.season,
    d.year,
    d.quarter
)

SELECT
  *,
  -- Weather category for easier filtering
  CASE 
    WHEN is_ideal_biking_weather = 1 THEN 'Ideal Weather'
    WHEN is_poor_biking_weather = 1 THEN 'Poor Weather'
    ELSE 'Normal Weather'
  END AS weather_category,
  
  -- Temperature category
  CASE
    WHEN temperature_celsius < 0 THEN 'Freezing'
    WHEN temperature_celsius < 10 THEN 'Cold'
    WHEN temperature_celsius < 20 THEN 'Mild'
    WHEN temperature_celsius < 30 THEN 'Warm'
    ELSE 'Hot'
  END AS temperature_category,
  
  -- Precipitation category
  CASE
    WHEN precipitation_mm = 0 THEN 'No Rain'
    WHEN precipitation_mm < 2.5 THEN 'Light Rain'
    WHEN precipitation_mm < 10 THEN 'Moderate Rain'
    ELSE 'Heavy Rain'
  END AS precipitation_category,
  
  -- Trip volume category
  CASE
    WHEN total_trips_started >= 50000 THEN 'Very High'
    WHEN total_trips_started >= 30000 THEN 'High'
    WHEN total_trips_started >= 15000 THEN 'Medium'
    WHEN total_trips_started >= 5000 THEN 'Low'
    ELSE 'Very Low'
  END AS trip_volume_category,
  
  -- Calculate trips per station
  SAFE_DIVIDE(total_trips_started, stations_reporting) AS avg_trips_per_station

FROM daily_weather_metrics

-- Order by most recent date
ORDER BY date_day DESC