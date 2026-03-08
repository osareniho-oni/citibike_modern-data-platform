{{
    config(
        materialized='view',
        tags=['staging', 'citibike']
    )
}}

-- Staging model for Citibike trip data
-- Cleans and types raw trip data, filters out invalid trips
-- Note: start_station_id can be NULL for trips without station (e.g., street pickups)

with source as (

    select * from {{ source('raw', 'citibike_trips_raw') }}

),

renamed as (

    select
        -- Primary key
        cast(ride_id as string) as ride_id,
        
        -- Trip details
        cast(rideable_type as string) as rideable_type,
        cast(started_at as timestamp) as started_at,
        cast(ended_at as timestamp) as ended_at,
        
        -- Start station information
        cast(start_station_name as string) as start_station_name,
        cast(start_station_id as string) as start_station_id,
        cast(start_lat as float64) as start_lat,
        cast(start_lng as float64) as start_lng,
        
        -- End station information
        cast(end_station_name as string) as end_station_name,
        cast(end_station_id as string) as end_station_id,
        cast(end_lat as float64) as end_lat,
        cast(end_lng as float64) as end_lng,
        
        -- Rider type
        cast(member_casual as string) as member_casual

    from source
    where ride_id is not null
        and started_at is not null
        and ended_at is not null
        and started_at < ended_at  -- Data quality: ensure valid trip duration

)

select * from renamed