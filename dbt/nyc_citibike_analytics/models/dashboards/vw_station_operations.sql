{{
  config(
    materialized='view',
    schema='citibike_dashboards',
    tags=['dashboard', 'station_operations']
  )
}}

-- Station Operations Dashboard View
-- Purpose: Real-time station availability and operational metrics for Looker Studio
-- Refresh: This view queries live data; consider converting to materialized view for 5-min refresh
-- Data Range: Last 30 days (rolling window)

WITH station_metrics AS (
  SELECT
    -- Date and time
    d.full_date as date_day,
    d.day_name,
    d.is_weekend,
    d.month_name,
    d.year,
    
    -- Station information
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude,
    s.capacity,
    s.region,
    
    -- Availability metrics
    f.avg_bikes_available,
    f.avg_ebikes_available,
    f.avg_docks_available,
    
    -- Utilization metrics
    f.avg_occupancy_ratio,
    f.avg_utilization_percentage as avg_utilization_pct,
    f.occupancy_volatility,
    
    -- Operational health
    f.pct_time_empty,
    f.pct_time_full,
    f.operational_health_score,
    f.rebalancing_need,
    
    -- Trip activity
    f.trips_started,
    f.trips_ended,
    f.net_trips,
    f.station_flow_pattern,
    
    -- Capacity metrics
    f.typical_capacity,
    f.max_capacity,
    f.min_capacity,
    
    -- Rolling averages
    f.avg_bikes_available_7d as rolling_7d_avg_bikes,
    f.avg_occupancy_ratio_7d as rolling_7d_avg_occupancy,
    f.avg_utilization_7d as rolling_7d_avg_utilization,
    f.trips_started_change_dod as day_over_day_trips_change,
    f.trips_started_change_wow as week_over_week_trips_change,
    
    -- Current day indicator for filtering
    CASE
      WHEN d.full_date = CURRENT_DATE() THEN TRUE
      ELSE FALSE
    END AS is_current_day,
    
    -- Priority indicator for rebalancing
    CASE
      WHEN f.rebalancing_need = 'high' THEN '🔴 High Priority'
      WHEN f.rebalancing_need = 'medium' THEN '🟡 Medium Priority'
      ELSE '🟢 Low Priority'
    END AS priority_indicator,
    
    -- Activity level category
    CASE
      WHEN f.trips_started >= 100 THEN 'Very High'
      WHEN f.trips_started >= 50 THEN 'High'
      WHEN f.trips_started >= 20 THEN 'Medium'
      WHEN f.trips_started >= 5 THEN 'Low'
      ELSE 'Very Low'
    END AS activity_category

  FROM {{ ref('fct_station_day') }} f
  INNER JOIN {{ ref('dim_station') }} s
    ON f.station_key = s.station_key
  INNER JOIN {{ ref('dim_date') }} d
    ON f.date_key = d.date_key
  
  -- Filter for last 30 days (rolling window)
  WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND d.full_date <= CURRENT_DATE()
)

SELECT
  *,
  -- Add rank for top stations by activity
  ROW_NUMBER() OVER (
    PARTITION BY date_day
    ORDER BY trips_started DESC
  ) AS daily_activity_rank

FROM station_metrics

-- Order by most recent date and most active stations
ORDER BY date_day DESC, trips_started DESC