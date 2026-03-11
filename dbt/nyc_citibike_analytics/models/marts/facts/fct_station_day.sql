{{
    config(
        materialized='incremental',
        unique_key=['station_key', 'date_key'],
        partition_by={
            'field': 'date_day',
            'data_type': 'date',
            'granularity': 'day'
        },
        cluster_by=['station_key'],
        incremental_strategy='merge',
        tags=['marts', 'fact', 'station_day']
    )
}}

-- Fact Table: Station Day (Aggregate)
-- Grain: 1 row per station per day
-- Combines operational metrics, trip demand, and weather context

with station_daily_fact as (

    select * from {{ ref('int_station_daily_fact') }}
    {% if is_incremental() %}
        where date_day > (select max(full_date) from {{ this }} f
                          join {{ ref('dim_date') }} d on f.date_key = d.date_key)
    {% endif %}

),

dim_station as (
    -- Only join to current records to avoid duplicates from SCD Type 2
    select station_key, station_id, is_current
    from {{ ref('dim_station') }}
    where is_current = true
),

dim_date as (
    select date_key, full_date from {{ ref('dim_date') }}
),

fact_with_keys as (

    select
        -- Foreign keys (surrogate keys)
        coalesce(ds.station_key,
            {{ dbt_utils.generate_surrogate_key(['-1']) }}) as station_key,
        coalesce(dd.date_key,
            cast(format_date('%Y%m%d', f.date_day) as int64)) as date_key,
        
        -- Date column for partitioning
        f.date_day,
        
        -- Station ID for debugging
        f.station_id,
        
        -- === ADDITIVE MEASURES (can be summed) ===
        
        -- Trip counts
        f.trips_started,
        f.trips_ended,
        f.net_trips,
        f.total_trip_activity,
        f.member_trips_started,
        f.casual_trips_started,
        f.ebike_trips_started,
        f.classic_bike_trips_started,
        f.morning_rush_trips_started,
        f.evening_rush_trips_started,
        
        -- === SEMI-ADDITIVE MEASURES (can be averaged) ===
        
        -- Supply metrics
        f.avg_bikes_available,
        f.avg_ebikes_available,
        f.avg_docks_available,
        f.avg_occupancy_ratio,
        f.avg_utilization_percentage,
        f.avg_ebike_ratio,
        
        -- Trip metrics
        f.avg_trip_duration_minutes,
        f.median_trip_duration_minutes,
        f.p95_trip_duration_minutes,
        
        -- === NON-ADDITIVE MEASURES (snapshots/ratios) ===
        
        -- Capacity
        f.typical_capacity,
        f.max_capacity,
        f.min_capacity,
        
        -- Operational metrics
        f.pct_time_empty,
        f.pct_time_full,
        f.pct_time_operational,
        f.occupancy_volatility,
        f.utilization_volatility,
        f.operational_health_score,
        f.rebalancing_need,
        f.data_quality,
        
        -- Station patterns
        f.member_pct_started,
        f.ebike_pct_started,
        f.station_flow_pattern,
        f.rush_hour_intensity,
        
        -- Derived metrics
        f.trips_per_bike_ratio,
        f.demand_capacity_ratio,
        f.supply_demand_balance_score,
        
        -- === WEATHER CONTEXT ===
        
        f.temperature_mean,
        f.temperature_max,
        f.temperature_min,
        f.precipitation_sum,
        f.rain_sum,
        f.snowfall_sum,
        f.wind_speed_max,
        f.weather_condition,
        f.temperature_range,
        f.is_raining,
        f.is_snowing,
        f.is_freezing,
        f.is_windy,
        f.precipitation_intensity,
        f.weather_severity_score,
        f.is_ideal_biking_weather,
        f.is_poor_biking_weather,
        
        -- === ROLLING AVERAGES (7-day) ===
        
        f.avg_bikes_available_7d,
        f.avg_occupancy_ratio_7d,
        f.avg_utilization_7d,
        f.avg_pct_time_empty_7d,
        f.avg_pct_time_full_7d,
        f.avg_trips_started_7d,
        f.avg_trips_ended_7d,
        f.avg_total_activity_7d,
        
        -- === ROLLING AVERAGES (28-day) ===
        
        f.avg_trips_started_28d,
        f.avg_occupancy_ratio_28d,
        
        -- === LAG METRICS ===
        
        f.trips_started_prev_day,
        f.occupancy_ratio_prev_day,
        f.trips_started_same_day_last_week,
        
        -- === TREND INDICATORS ===
        
        f.trips_started_change_dod,
        f.trips_started_change_wow,
        f.trips_started_deviation_pct_7d,
        f.demand_trend,
        
        -- === TIME DIMENSIONS (denormalized for convenience) ===
        
        f.day_of_week,
        f.day_name,
        f.is_weekend,
        f.month,
        f.month_name,
        f.quarter,
        f.year,
        f.week_of_year,
        
        -- === AUDIT ===
        
        current_timestamp() as loaded_at

    from station_daily_fact f
    
    -- Join to dimensions to get surrogate keys
    left join dim_station ds
        on f.station_id = ds.station_id
        and ds.is_current = true  -- Only join to current station records
    left join dim_date dd
        on f.date_day = dd.full_date

)

-- Aggregate to ensure uniqueness (in case source has duplicates)
select
    station_key,
    date_key,
    date_day,
    max(typical_capacity) as typical_capacity,
    max(max_capacity) as max_capacity,
    max(min_capacity) as min_capacity,
    sum(trips_started) as trips_started,
    sum(trips_ended) as trips_ended,
    sum(net_trips) as net_trips,
    sum(total_trip_activity) as total_trip_activity,
    sum(member_trips_started) as member_trips_started,
    sum(casual_trips_started) as casual_trips_started,
    sum(ebike_trips_started) as ebike_trips_started,
    sum(classic_bike_trips_started) as classic_bike_trips_started,
    sum(morning_rush_trips_started) as morning_rush_trips_started,
    sum(evening_rush_trips_started) as evening_rush_trips_started,
    avg(avg_bikes_available) as avg_bikes_available,
    avg(avg_ebikes_available) as avg_ebikes_available,
    avg(avg_docks_available) as avg_docks_available,
    avg(avg_occupancy_ratio) as avg_occupancy_ratio,
    avg(occupancy_volatility) as occupancy_volatility,
    avg(avg_utilization_percentage) as avg_utilization_percentage,
    avg(utilization_volatility) as utilization_volatility,
    avg(avg_ebike_ratio) as avg_ebike_ratio,
    avg(pct_time_empty) as pct_time_empty,
    avg(pct_time_full) as pct_time_full,
    avg(pct_time_operational) as pct_time_operational,
    max(operational_health_score) as operational_health_score,
    max(avg_trip_duration_minutes) as avg_trip_duration_minutes,
    max(median_trip_duration_minutes) as median_trip_duration_minutes,
    max(p95_trip_duration_minutes) as p95_trip_duration_minutes,
    max(member_pct_started) as member_pct_started,
    max(ebike_pct_started) as ebike_pct_started,
    max(rush_hour_intensity) as rush_hour_intensity,
    max(temperature_mean) as temperature_mean,
    max(temperature_max) as temperature_max,
    max(temperature_min) as temperature_min,
    max(precipitation_sum) as precipitation_sum,
    max(rain_sum) as rain_sum,
    max(snowfall_sum) as snowfall_sum,
    max(wind_speed_max) as wind_speed_max,
    max(temperature_range) as temperature_range,
    max(precipitation_intensity) as precipitation_intensity,
    max(weather_severity_score) as weather_severity_score,
    avg(trips_per_bike_ratio) as trips_per_bike_ratio,
    avg(demand_capacity_ratio) as demand_capacity_ratio,
    avg(supply_demand_balance_score) as supply_demand_balance_score,
    avg(avg_bikes_available_7d) as avg_bikes_available_7d,
    avg(avg_occupancy_ratio_7d) as avg_occupancy_ratio_7d,
    avg(avg_utilization_7d) as avg_utilization_7d,
    avg(avg_pct_time_empty_7d) as avg_pct_time_empty_7d,
    avg(avg_pct_time_full_7d) as avg_pct_time_full_7d,
    avg(avg_trips_started_7d) as avg_trips_started_7d,
    avg(avg_trips_ended_7d) as avg_trips_ended_7d,
    avg(avg_total_activity_7d) as avg_total_activity_7d,
    avg(avg_trips_started_28d) as avg_trips_started_28d,
    avg(avg_occupancy_ratio_28d) as avg_occupancy_ratio_28d,
    avg(trips_started_prev_day) as trips_started_prev_day,
    avg(occupancy_ratio_prev_day) as occupancy_ratio_prev_day,
    avg(trips_started_same_day_last_week) as trips_started_same_day_last_week,
    avg(trips_started_change_dod) as trips_started_change_dod,
    avg(trips_started_change_wow) as trips_started_change_wow,
    avg(trips_started_deviation_pct_7d) as trips_started_deviation_pct_7d,
    max(rebalancing_need) as rebalancing_need,
    max(data_quality) as data_quality,
    max(station_flow_pattern) as station_flow_pattern,
    max(weather_condition) as weather_condition,
    max(is_raining) as is_raining,
    max(is_snowing) as is_snowing,
    max(is_freezing) as is_freezing,
    max(is_windy) as is_windy,
    max(is_ideal_biking_weather) as is_ideal_biking_weather,
    max(is_poor_biking_weather) as is_poor_biking_weather,
    max(demand_trend) as demand_trend,
    max(day_of_week) as day_of_week,
    max(day_name) as day_name,
    max(is_weekend) as is_weekend,
    max(month) as month,
    max(month_name) as month_name,
    max(quarter) as quarter,
    max(year) as year,
    max(week_of_year) as week_of_year,
    current_timestamp() as loaded_at
from fact_with_keys
group by station_key, date_key, date_day