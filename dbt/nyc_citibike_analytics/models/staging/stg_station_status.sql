{{
    config(
        materialized='view',
        tags=['staging', 'station_status']
    )
}}

-- Staging model for real-time Citibike station status data
-- Cleans and types streaming station status data from Citibike GBFS API
-- Provides current availability of bikes, e-bikes, scooters, and docks at each station

with source as (

    select * from {{ source('raw', 'station_status_streaming') }}

),

renamed as (

    select
        -- Station identifier
        cast(station_id as string) as station_id,
        cast(legacy_id as string) as legacy_id,
        
        -- Bike availability
        cast(num_bikes_available as int64) as num_bikes_available,
        cast(num_ebikes_available as int64) as num_ebikes_available,
        cast(num_bikes_disabled as int64) as num_bikes_disabled,
        
        -- Dock availability
        cast(num_docks_available as int64) as num_docks_available,
        cast(num_docks_disabled as int64) as num_docks_disabled,
        
        -- Scooter availability
        cast(num_scooters_available as int64) as num_scooters_available,
        cast(num_scooters_unavailable as int64) as num_scooters_unavailable,
        
        -- Station status flags
        cast(is_installed as bool) as is_installed,
        cast(is_renting as bool) as is_renting,
        cast(is_returning as bool) as is_returning,
        cast(eightd_has_available_keys as bool) as eightd_has_available_keys,
        
        -- Timestamps
        cast(last_reported as timestamp) as last_reported,
        cast(api_last_updated as timestamp) as api_last_updated,
        cast(ingestion_timestamp as timestamp) as ingestion_timestamp
from source
where station_id is not null
    and last_reported is not null

)

select * from renamed