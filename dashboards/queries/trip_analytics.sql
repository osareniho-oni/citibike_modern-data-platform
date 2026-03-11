-- Trip Analytics Dashboard Query
-- Purpose: Trip patterns, demand trends, and user behavior analysis
-- Data Source: BigQuery marts layer
-- Refresh: Daily (after trip data ingestion)

-- Main query for trip analytics dashboard
SELECT
  -- Date and time dimensions
  d.date_day,
  d.day_name,
  d.is_weekend,
  d.month_name,
  d.quarter,
  t.hour_of_day,
  t.time_of_day_name,
  t.is_rush_hour,
  
  -- Trip details
  f.trip_id,
  f.started_at,
  f.ended_at,
  f.trip_duration_minutes,
  
  -- Station information
  f.start_station_id,
  ss.station_name as start_station_name,
  ss.latitude as start_latitude,
  ss.longitude as start_longitude,
  
  f.end_station_id,
  es.station_name as end_station_name,
  es.latitude as end_latitude,
  es.longitude as end_longitude,
  
  -- User and bike type
  u.user_type_name,
  u.is_member,
  f.rideable_type,
  
  -- Derived metrics
  CASE 
    WHEN f.trip_duration_minutes < 5 THEN 'Very Short (<5 min)'
    WHEN f.trip_duration_minutes < 15 THEN 'Short (5-15 min)'
    WHEN f.trip_duration_minutes < 30 THEN 'Medium (15-30 min)'
    WHEN f.trip_duration_minutes < 60 THEN 'Long (30-60 min)'
    ELSE 'Very Long (>60 min)'
  END as trip_duration_category

FROM `YOUR-PROJECT.citibike_data.fct_trips` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
JOIN `YOUR-PROJECT.citibike_data.dim_time` t 
  ON f.time_key = t.time_key
JOIN `YOUR-PROJECT.citibike_data.dim_user_type` u 
  ON f.user_type_key = u.user_type_key
LEFT JOIN `YOUR-PROJECT.citibike_data.dim_station` ss 
  ON f.start_station_id = ss.station_id
LEFT JOIN `YOUR-PROJECT.citibike_data.dim_station` es 
  ON f.end_station_id = es.station_id

-- Filter for recent data (last 90 days)
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)

ORDER BY f.started_at DESC;


-- Additional query: Daily trip volume trends
SELECT
  d.date_day,
  d.day_name,
  d.is_weekend,
  COUNT(*) as total_trips,
  AVG(f.trip_duration_minutes) as avg_duration_minutes,
  SUM(CASE WHEN u.is_member THEN 1 ELSE 0 END) as member_trips,
  SUM(CASE WHEN NOT u.is_member THEN 1 ELSE 0 END) as casual_trips,
  SUM(CASE WHEN f.rideable_type = 'electric_bike' THEN 1 ELSE 0 END) as electric_bike_trips,
  SUM(CASE WHEN f.rideable_type = 'classic_bike' THEN 1 ELSE 0 END) as classic_bike_trips
FROM `YOUR-PROJECT.citibike_data.fct_trips` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
JOIN `YOUR-PROJECT.citibike_data.dim_user_type` u 
  ON f.user_type_key = u.user_type_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY d.date_day, d.day_name, d.is_weekend
ORDER BY d.date_day DESC;


-- Additional query: Popular routes (top 20)
SELECT
  f.start_station_id,
  ss.station_name as start_station,
  f.end_station_id,
  es.station_name as end_station,
  COUNT(*) as trip_count,
  AVG(f.trip_duration_minutes) as avg_duration
FROM `YOUR-PROJECT.citibike_data.fct_trips` f
LEFT JOIN `YOUR-PROJECT.citibike_data.dim_station` ss 
  ON f.start_station_id = ss.station_id
LEFT JOIN `YOUR-PROJECT.citibike_data.dim_station` es 
  ON f.end_station_id = es.station_id
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND f.start_station_id IS NOT NULL
  AND f.end_station_id IS NOT NULL
  AND f.start_station_id != f.end_station_id
GROUP BY f.start_station_id, ss.station_name, f.end_station_id, es.station_name
ORDER BY trip_count DESC
LIMIT 20;