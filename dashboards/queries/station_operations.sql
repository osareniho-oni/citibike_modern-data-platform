-- Station Operations Dashboard Query
-- Purpose: Real-time station availability and operational metrics
-- Data Source: BigQuery marts layer
-- Refresh: Every 5 minutes (matches Kestra schedule)

-- Main query for station operations dashboard
SELECT
  -- Date and time
  d.date_day,
  d.day_name,
  d.is_weekend,
  
  -- Station information
  s.station_id,
  s.station_name,
  s.latitude,
  s.longitude,
  s.capacity,
  s.region_id,
  
  -- Availability metrics
  f.avg_bikes_available,
  f.avg_ebikes_available,
  f.avg_docks_available,
  f.avg_scooters_available,
  
  -- Utilization metrics
  f.avg_occupancy_ratio,
  f.avg_utilization_pct,
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
  f.min_capacity

FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_station` s 
  ON f.station_id = s.station_id
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key

-- Filter for recent data (last 30 days)
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)

-- Order by most recent and most active stations
ORDER BY d.date_day DESC, f.trips_started DESC;


-- Additional query: Current station status (most recent day)
SELECT
  s.station_id,
  s.station_name,
  s.latitude,
  s.longitude,
  f.avg_bikes_available,
  f.avg_utilization_pct,
  f.operational_health_score,
  f.rebalancing_need,
  CASE 
    WHEN f.rebalancing_need = 'high' THEN '🔴 High Priority'
    WHEN f.rebalancing_need = 'medium' THEN '🟡 Medium Priority'
    ELSE '🟢 Low Priority'
  END as priority_indicator
FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_station` s 
  ON f.station_id = s.station_id
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day = CURRENT_DATE()
ORDER BY f.operational_health_score ASC;


-- Additional query: Station availability trends (7-day rolling average)
SELECT
  d.date_day,
  s.station_name,
  f.avg_bikes_available,
  f.rolling_7d_avg_occupancy,
  f.rolling_7d_avg_utilization,
  f.day_over_day_trips_change,
  f.week_over_week_trips_change
FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_station` s 
  ON f.station_id = s.station_id
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY d.date_day DESC, s.station_name;