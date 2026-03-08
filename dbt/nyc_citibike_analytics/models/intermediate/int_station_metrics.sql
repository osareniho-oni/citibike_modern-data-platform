{{
    config(
        materialized='view',
        tags=['intermediate', 'station_metrics', 'operational']
    )
}}

-- Intermediate model: Station operational metrics at 5-minute grain
-- Calculates real-time operational KPIs from station status data
-- Provides foundation for daily aggregations and capacity analysis

with station_status as (

    select * from {{ ref('stg_station_status') }}

),

metrics as (

    select
        -- Identifiers
        station_id,
        legacy_id,
        
        -- Time dimension (5-minute buckets)
        timestamp_seconds(300 * div(unix_seconds(last_reported), 300)) as reported_at_5min,
        last_reported,
        
        -- Raw availability counts
        num_bikes_available,
        num_ebikes_available,
        num_bikes_disabled,
        num_docks_available,
        num_docks_disabled,
        num_scooters_available,
        num_scooters_unavailable,
        
        -- Capacity calculations (including scooters)
        (num_bikes_available + num_ebikes_available + num_bikes_disabled +
         num_docks_available + num_docks_disabled +
         num_scooters_available + num_scooters_unavailable) as total_capacity,
        
        -- Occupancy metrics (bikes + scooters perspective)
        case
            when (num_bikes_available + num_ebikes_available + num_bikes_disabled +
                  num_docks_available + num_docks_disabled +
                  num_scooters_available + num_scooters_unavailable) > 0
            then safe_divide(
                (num_bikes_available + num_ebikes_available + num_scooters_available),
                (num_bikes_available + num_ebikes_available + num_bikes_disabled +
                 num_docks_available + num_docks_disabled +
                 num_scooters_available + num_scooters_unavailable)
            )
            else null
        end as occupancy_ratio,
        
        -- Utilization metrics (capacity usage perspective)
        case
            when (num_bikes_available + num_ebikes_available + num_bikes_disabled +
                  num_docks_available + num_docks_disabled +
                  num_scooters_available + num_scooters_unavailable) > 0
            then safe_divide(
                (num_bikes_available + num_ebikes_available + num_bikes_disabled +
                 num_docks_disabled + num_scooters_available + num_scooters_unavailable),
                (num_bikes_available + num_ebikes_available + num_bikes_disabled +
                 num_docks_available + num_docks_disabled +
                 num_scooters_available + num_scooters_unavailable)
            )
            else null
        end as utilization_percentage,
        
        -- Operational status flags
        (num_bikes_available + num_ebikes_available) = 0 as is_empty,
        num_docks_available = 0 as is_full,
        is_installed,
        is_renting,
        is_returning,
        
        -- Operational status categorization
        case
            when not is_installed then 'not_installed'
            when not is_renting and not is_returning then 'out_of_service'
            when not is_renting then 'not_renting'
            when not is_returning then 'not_returning'
            when (num_bikes_available + num_ebikes_available) = 0 then 'empty'
            when num_docks_available = 0 then 'full'
            else 'operational'
        end as operational_status,
        
        -- E-bike availability ratio
        case 
            when (num_bikes_available + num_ebikes_available) > 0
            then safe_divide(num_ebikes_available, (num_bikes_available + num_ebikes_available))
            else null
        end as ebike_ratio,
        
        -- Metadata
        api_last_updated,
        ingestion_timestamp

    from station_status
    where is_installed = true  -- Focus on installed stations only

)

select * from metrics