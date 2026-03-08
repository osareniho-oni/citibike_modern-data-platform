{{
    config(
        materialized='view',
        tags=['staging', 'weather']
    )
}}

-- Staging model for NYC daily weather data
-- Cleans and types raw weather data from Open-Meteo API
-- Deduplicates by taking the most recent load for each date

with source as (

    select * from {{ source('raw', 'nyc_weather_daily') }}

),

renamed as (

    select
        -- Date
        cast(weather_date as date) as weather_date,
        
        -- Temperature metrics (Celsius)
        cast(temperature_max as float64) as temperature_max,
        cast(temperature_min as float64) as temperature_min,
        cast(temperature_mean as float64) as temperature_mean,
        
        -- Precipitation metrics (inches)
        cast(precipitation_sum as float64) as precipitation_sum,
        cast(rain_sum as float64) as rain_sum,
        cast(snowfall_sum as float64) as snowfall_sum,
        cast(precipitation_hours as float64) as precipitation_hours,
        
        -- Weather conditions
        cast(weather_code as int64) as weather_code,
        
        -- Wind metrics (mph)
        cast(wind_speed_max as float64) as wind_speed_max,
        cast(wind_gusts_max as float64) as wind_gusts_max,
        
        -- Location
        cast(latitude as float64) as latitude,
        cast(longitude as float64) as longitude,
        cast(city as string) as city,
        
        -- Metadata
        cast(loaded_at as timestamp) as loaded_at

    from source
    where weather_date is not null
    -- Deduplicate by taking the most recent load for each date
    qualify row_number() over (partition by cast(weather_date as date) order by loaded_at desc) = 1

)

select * from renamed