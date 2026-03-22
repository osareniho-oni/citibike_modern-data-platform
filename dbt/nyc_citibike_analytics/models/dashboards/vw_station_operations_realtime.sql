{{
  config(
    materialized='view',
    schema='citibike_dashboards',
    tags=['dashboard', 'station_operations', 'realtime']
  )
}}

-- Real-Time Station Operations View
-- Purpose: Current station availability and operational status for live monitoring
-- Data Source: Latest station status from streaming data (5-minute updates)
-- Use Case: Real-time dashboard showing current bike/dock availability

WITH latest_status AS (
  SELECT
    station_id,
    num_bikes_available,
    num_ebikes_available,
    num_bikes_disabled,
    num_docks_available,
    num_docks_disabled,
    num_scooters_available,
    num_scooters_unavailable,
    total_capacity,
    occupancy_ratio,
    utilization_percentage,
    is_empty,
    is_full,
    is_installed,
    is_renting,
    is_returning,
    operational_status,
    last_reported,
    api_last_updated,
    ingestion_timestamp,
    -- Get only the most recent status per station
    ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY last_reported DESC) as rn
  FROM {{ ref('int_station_metrics') }}
  -- Only look at last 24 hours of data
  WHERE last_reported >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
),

current_status AS (
  SELECT * FROM latest_status WHERE rn = 1
),

enriched AS (
  SELECT
    -- Station information (from snapshot)
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude,
    s.capacity,
    s.region,
    
    -- Determine station type/size based on capacity
    CASE
      WHEN s.capacity >= 50 THEN 'Large'
      WHEN s.capacity >= 30 THEN 'Medium'
      WHEN s.capacity >= 15 THEN 'Small'
      ELSE 'Micro'
    END as station_type,
    
    -- Determine borough from region (simplified mapping)
    CASE
      WHEN s.region LIKE '%Manhattan%' THEN 'Manhattan'
      WHEN s.region LIKE '%Brooklyn%' THEN 'Brooklyn'
      WHEN s.region LIKE '%Queens%' THEN 'Queens'
      WHEN s.region LIKE '%Bronx%' THEN 'Bronx'
      WHEN s.region LIKE '%Staten%' THEN 'Staten Island'
      ELSE 'Unknown'
    END as borough,
    
    -- Determine station size category
    CASE
      WHEN s.capacity >= 50 THEN 'extra_large'
      WHEN s.capacity >= 35 THEN 'large'
      WHEN s.capacity >= 25 THEN 'medium'
      WHEN s.capacity >= 15 THEN 'small'
      ELSE 'unknown'
    END as station_size,
    
    -- Current availability (from real-time status)
    cs.num_bikes_available,
    cs.num_ebikes_available,
    cs.num_bikes_disabled,
    cs.num_docks_available,
    cs.num_docks_disabled,
    cs.num_scooters_available,
    cs.num_scooters_unavailable,
    
    -- Calculated totals
    (cs.num_bikes_available + cs.num_ebikes_available) as total_bikes_available,
    cs.total_capacity,
    
    -- Metrics
    ROUND(cs.occupancy_ratio, 3) as occupancy_ratio,
    ROUND(cs.utilization_percentage * 100, 1) as utilization_pct,
    
    -- Status flags
    cs.is_installed,
    cs.is_renting,
    cs.is_returning,
    COALESCE(cs.is_empty, FALSE) as eightd_has_available_keys,  -- Placeholder
    
    -- Operational status (user-friendly)
    CASE
      WHEN NOT cs.is_installed THEN 'Not Installed'
      WHEN NOT cs.is_renting AND NOT cs.is_returning THEN 'Out of Service'
      WHEN NOT cs.is_renting THEN 'Not Renting'
      WHEN NOT cs.is_returning THEN 'Not Returning'
      ELSE 'Operational'
    END as operational_status,
    
    -- Availability status
    CASE
      WHEN cs.is_empty THEN 'Empty'
      WHEN cs.is_full THEN 'Full'
      WHEN cs.num_bikes_available <= 3 THEN 'Low Bikes'
      WHEN cs.num_docks_available <= 3 THEN 'Low Docks'
      ELSE 'Available'
    END as availability_status,
    
    -- Rebalancing need
    CASE
      WHEN cs.is_empty OR cs.is_full THEN 'high'
      WHEN cs.num_bikes_available <= 3 OR cs.num_docks_available <= 3 THEN 'medium'
      ELSE 'low'
    END as rebalancing_need,
    
    -- Priority indicator
    CASE
      WHEN cs.is_empty OR cs.is_full THEN '🔴 High Priority'
      WHEN cs.num_bikes_available <= 3 OR cs.num_docks_available <= 3 THEN '🟡 Medium Priority'
      ELSE '🟢 Low Priority'
    END as priority_indicator,
    
    -- Timestamps
    cs.last_reported,
    cs.api_last_updated,
    cs.ingestion_timestamp,
    
    -- Data freshness indicators
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), cs.last_reported, MINUTE) as minutes_since_last_report,
    CASE
      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), cs.last_reported, MINUTE) <= 10 THEN 'Fresh'
      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), cs.last_reported, MINUTE) <= 30 THEN 'Recent'
      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), cs.last_reported, MINUTE) <= 60 THEN 'Stale'
      ELSE 'Very Stale'
    END as data_freshness
    
  FROM current_status cs
  LEFT JOIN {{ ref('snap_station') }} s
    ON cs.station_id = s.station_id
    AND s.dbt_valid_to IS NULL  -- Get current snapshot record
)

SELECT * FROM enriched
WHERE is_installed = TRUE  -- Only show installed stations
ORDER BY 
  CASE rebalancing_need
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
  END,
  station_name