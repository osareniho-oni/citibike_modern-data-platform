-- Weather Impact Dashboard Query
-- Purpose: Analyze how weather conditions affect ridership patterns
-- Data Source: BigQuery marts layer (includes weather-enriched metrics)
-- Refresh: Daily (after weather data ingestion)

-- Main query for weather impact analysis
SELECT
  -- Date dimension
  d.date_day,
  d.day_name,
  d.is_weekend,
  d.month_name,
  d.season,
  
  -- Weather conditions
  f.temperature_celsius,
  f.temperature_range,
  f.precipitation_mm,
  f.wind_speed_kmh,
  f.weather_condition,
  f.weather_severity_score,
  f.is_ideal_biking_weather,
  f.is_poor_biking_weather,
  f.is_raining,
  f.is_snowing,
  f.is_freezing,
  f.is_windy,
  
  -- Trip metrics
  SUM(f.trips_started) as total_trips_started,
  SUM(f.trips_ended) as total_trips_ended,
  AVG(f.avg_trip_duration) as avg_trip_duration,
  
  -- Station metrics
  AVG(f.avg_bikes_available) as avg_bikes_available,
  AVG(f.avg_utilization_pct) as avg_utilization_pct,
  AVG(f.operational_health_score) as avg_health_score,
  
  -- Activity level
  AVG(f.activity_level_score) as avg_activity_level

FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key

-- Filter for recent data (last 90 days)
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)

GROUP BY 
  d.date_day, d.day_name, d.is_weekend, d.month_name, d.season,
  f.temperature_celsius, f.temperature_range, f.precipitation_mm,
  f.wind_speed_kmh, f.weather_condition, f.weather_severity_score,
  f.is_ideal_biking_weather, f.is_poor_biking_weather,
  f.is_raining, f.is_snowing, f.is_freezing, f.is_windy

ORDER BY d.date_day DESC;


-- Additional query: Temperature vs ridership correlation
SELECT
  f.temperature_range,
  COUNT(DISTINCT f.date_day) as days_count,
  AVG(f.trips_started) as avg_trips_per_station,
  SUM(f.trips_started) as total_trips,
  AVG(f.avg_utilization_pct) as avg_utilization
FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY f.temperature_range
ORDER BY 
  CASE f.temperature_range
    WHEN 'freezing' THEN 1
    WHEN 'cold' THEN 2
    WHEN 'mild' THEN 3
    WHEN 'warm' THEN 4
    WHEN 'hot' THEN 5
  END;


-- Additional query: Weather condition impact
SELECT
  f.weather_condition,
  COUNT(DISTINCT f.date_day) as days_count,
  AVG(f.trips_started) as avg_trips_per_station,
  SUM(f.trips_started) as total_trips,
  AVG(f.avg_trip_duration) as avg_trip_duration,
  AVG(f.weather_severity_score) as avg_severity_score
FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY f.weather_condition
ORDER BY total_trips DESC;


-- Additional query: Ideal vs poor biking weather comparison
SELECT
  CASE 
    WHEN f.is_ideal_biking_weather THEN 'Ideal Weather'
    WHEN f.is_poor_biking_weather THEN 'Poor Weather'
    ELSE 'Normal Weather'
  END as weather_category,
  COUNT(DISTINCT f.date_day) as days_count,
  AVG(f.trips_started) as avg_trips_per_station,
  SUM(f.trips_started) as total_trips,
  AVG(f.avg_utilization_pct) as avg_utilization,
  AVG(f.temperature_celsius) as avg_temperature,
  AVG(f.precipitation_mm) as avg_precipitation
FROM `YOUR-PROJECT.citibike_data.fct_station_day` f
JOIN `YOUR-PROJECT.citibike_data.dim_date` d 
  ON f.date_key = d.date_key
WHERE d.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY weather_category
ORDER BY total_trips DESC;