{{
    config(
        materialized='table',
        tags=['intermediate', 'weather', 'daily']
    )
}}

-- Intermediate model: Station daily metrics enriched with weather data
-- Joins station operational metrics with weather conditions
-- Adds weather-derived features for analysis

with station_daily as (

    select * from {{ ref('int_station_daily_metrics') }}

),

weather as (

    select * from {{ ref('stg_weather') }}

),

joined as (

    select
        -- Station identifiers
        s.station_id,
        s.date_day,
        
        -- Station metrics (all columns from station_daily)
        s.typical_capacity,
        s.max_capacity,
        s.min_capacity,
        s.avg_bikes_available,
        s.avg_ebikes_available,
        s.avg_docks_available,
        s.avg_bikes_disabled,
        s.avg_docks_disabled,
        s.avg_scooters_available,
        s.avg_scooters_unavailable,
        s.max_bikes_available,
        s.max_docks_available,
        s.max_scooters_available,
        s.min_bikes_available,
        s.min_docks_available,
        s.min_scooters_available,
        s.avg_occupancy_ratio,
        s.occupancy_volatility,
        s.min_occupancy_ratio,
        s.max_occupancy_ratio,
        s.avg_utilization_percentage,
        s.utilization_volatility,
        s.avg_ebike_ratio,
        s.pct_time_empty,
        s.pct_time_full,
        s.pct_time_operational,
        s.pct_time_out_of_service,
        s.total_observations,
        s.unique_5min_intervals,
        s.time_coverage_ratio,
        s.was_installed_all_day,
        s.was_renting_any_time,
        s.was_returning_any_time,
        s.first_reported_at,
        s.last_reported_at,
        s.operational_health_score,
        s.rebalancing_need,
        s.data_quality,
        
        -- Weather metrics (raw)
        w.temperature_max,
        w.temperature_min,
        w.temperature_mean,
        w.precipitation_sum,
        w.rain_sum,
        w.snowfall_sum,
        w.precipitation_hours,
        w.weather_code,
        w.wind_speed_max,
        w.wind_gusts_max

    from station_daily s
    left join weather w
        on s.date_day = w.weather_date

),

enriched as (

    select
        *,
        
        -- Weather condition categorization
        -- Based on WMO Weather interpretation codes
        case
            when weather_code is null then 'unknown'
            when weather_code = 0 then 'clear'
            when weather_code in (1, 2, 3) then 'partly_cloudy'
            when weather_code in (45, 48) then 'foggy'
            when weather_code in (51, 53, 55, 56, 57) then 'drizzle'
            when weather_code in (61, 63, 65, 66, 67, 80, 81, 82) then 'rain'
            when weather_code in (71, 73, 75, 77, 85, 86) then 'snow'
            when weather_code in (95, 96, 99) then 'thunderstorm'
            else 'other'
        end as weather_condition,
        
        -- Temperature range categorization (Celsius)
        case
            when temperature_mean is null then 'unknown'
            when temperature_mean < 0 then 'freezing'
            when temperature_mean < 10 then 'cold'
            when temperature_mean < 18 then 'mild'
            when temperature_mean < 27 then 'warm'
            else 'hot'
        end as temperature_range,
        
        -- Weather impact flags
        precipitation_sum > 0 as is_raining,
        snowfall_sum > 0 as is_snowing,
        temperature_mean <= 0 as is_freezing,
        wind_speed_max > 32 as is_windy,  -- 32+ km/h considered windy (~20 mph)
        
        -- Precipitation intensity
        case
            when precipitation_sum = 0 then 'none'
            when precipitation_sum < 0.1 then 'light'
            when precipitation_sum < 0.3 then 'moderate'
            else 'heavy'
        end as precipitation_intensity,
        
        -- Weather severity score (0-100, higher = more severe)
        -- Combines multiple weather factors
        least(100, 
            case when precipitation_sum > 0 then 20 else 0 end +
            case when snowfall_sum > 0 then 30 else 0 end +
            case when temperature_mean < 0 then 25 else 0 end +
            case when temperature_mean > 32 then 15 else 0 end +
            case when wind_speed_max > 32 then 10 else 0 end
        ) as weather_severity_score,
        
        -- Ideal biking weather flag
        -- Clear/partly cloudy, mild temps, no precipitation, light wind
        case
            when weather_code in (0, 1, 2, 3)
                and temperature_mean between 13 and 24
                and precipitation_sum = 0
                and wind_speed_max < 24
            then true
            else false
        end as is_ideal_biking_weather,
        
        -- Poor biking weather flag
        -- Heavy rain, snow, extreme temps, or high winds
        case
            when precipitation_sum > 0.3
                or snowfall_sum > 0
                or temperature_mean < 0
                or temperature_mean > 32
                or wind_speed_max > 40
            then true
            else false
        end as is_poor_biking_weather

    from joined

)

select * from enriched