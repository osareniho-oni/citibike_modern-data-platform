{{
    config(
        materialized='incremental',
        unique_key=['station_id', 'date_day'],
        partition_by={
            'field': 'date_day',
            'data_type': 'date',
            'granularity': 'day'
        },
        cluster_by=['station_id'],
        tags=['intermediate', 'fact', 'daily']
    )
}}

-- Intermediate model: Comprehensive daily station fact table
-- Combines supply (station metrics), demand (trips), and weather context
-- Includes rolling averages and derived features for analysis
-- Incremental model partitioned by date for scalability

with station_weather as (

    select * from {{ ref('int_station_weather_daily') }}
    {% if is_incremental() %}
        where date_day > (select max(date_day) from {{ this }})
    {% endif %}

),

trip_demand as (

    select * from {{ ref('int_trip_station_daily') }}
    {% if is_incremental() %}
        where date_day > (select max(date_day) from {{ this }})
    {% endif %}

),

joined as (

    select
        -- Primary keys
        cast(coalesce(sw.station_id, td.station_id) as string) as station_id,
        coalesce(sw.date_day, td.date_day) as date_day,
        
        -- === SUPPLY METRICS (from station_weather) ===
        sw.typical_capacity,
        sw.max_capacity,
        sw.min_capacity,
        sw.avg_bikes_available,
        sw.avg_ebikes_available,
        sw.avg_docks_available,
        sw.avg_occupancy_ratio,
        sw.occupancy_volatility,
        sw.avg_utilization_percentage,
        sw.utilization_volatility,
        sw.avg_ebike_ratio,
        sw.pct_time_empty,
        sw.pct_time_full,
        sw.pct_time_operational,
        sw.operational_health_score,
        sw.rebalancing_need,
        sw.data_quality,
        
        -- === DEMAND METRICS (from trip_demand) ===
        coalesce(td.trips_started, 0) as trips_started,
        coalesce(td.trips_ended, 0) as trips_ended,
        coalesce(td.net_trips, 0) as net_trips,
        td.avg_trip_duration_minutes,
        td.median_trip_duration_minutes,
        td.p95_trip_duration_minutes,
        coalesce(td.member_trips_started, 0) as member_trips_started,
        coalesce(td.casual_trips_started, 0) as casual_trips_started,
        coalesce(td.ebike_trips_started, 0) as ebike_trips_started,
        coalesce(td.classic_bike_trips_started, 0) as classic_bike_trips_started,
        coalesce(td.morning_rush_trips_started, 0) as morning_rush_trips_started,
        coalesce(td.evening_rush_trips_started, 0) as evening_rush_trips_started,
        td.member_pct_started,
        td.ebike_pct_started,
        td.station_flow_pattern,
        td.rush_hour_intensity,
        
        -- === WEATHER CONTEXT ===
        sw.temperature_mean,
        sw.temperature_max,
        sw.temperature_min,
        sw.precipitation_sum,
        sw.rain_sum,
        sw.snowfall_sum,
        sw.wind_speed_max,
        sw.weather_condition,
        sw.temperature_range,
        sw.is_raining,
        sw.is_snowing,
        sw.is_freezing,
        sw.is_windy,
        sw.precipitation_intensity,
        sw.weather_severity_score,
        sw.is_ideal_biking_weather,
        sw.is_poor_biking_weather

    from station_weather sw
    full outer join trip_demand td
        on sw.station_id = td.station_id
        and sw.date_day = td.date_day

),

with_derived_metrics as (

    select
        *,
        
        -- === DERIVED SUPPLY-DEMAND METRICS ===
        
        -- Trips per available bike (demand intensity)
        safe_divide(trips_started, avg_bikes_available) as trips_per_bike_ratio,
        
        -- Demand vs capacity (utilization from demand perspective)
        safe_divide(trips_started, typical_capacity) as demand_capacity_ratio,
        
        -- Supply-demand balance score (-100 to 100)
        -- Negative = oversupply, Positive = undersupply
        case
            when avg_bikes_available = 0 then 100  -- No bikes = max undersupply
            when trips_started = 0 then -100  -- No demand = max oversupply
            else least(100, greatest(-100, 
                ((trips_started / nullif(avg_bikes_available, 0)) - 1) * 50
            ))
        end as supply_demand_balance_score,
        
        -- Total activity (trips in + out)
        trips_started + trips_ended as total_trip_activity,
        
        -- === TIME-BASED FEATURES ===
        
        -- Day of week (1 = Sunday, 7 = Saturday)
        extract(dayofweek from date_day) as day_of_week,
        
        -- Day name
        format_date('%A', date_day) as day_name,
        
        -- Is weekend
        extract(dayofweek from date_day) in (1, 7) as is_weekend,
        
        -- Month
        extract(month from date_day) as month,
        
        -- Month name
        format_date('%B', date_day) as month_name,
        
        -- Quarter
        extract(quarter from date_day) as quarter,
        
        -- Year
        extract(year from date_day) as year,
        
        -- Week of year
        extract(week from date_day) as week_of_year

    from joined

),

with_rolling_averages as (

    select
        *,
        
        -- === 7-DAY ROLLING AVERAGES ===
        
        -- Supply metrics
        avg(avg_bikes_available) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_bikes_available_7d,
        
        avg(avg_occupancy_ratio) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_occupancy_ratio_7d,
        
        avg(avg_utilization_percentage) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_utilization_7d,
        
        avg(pct_time_empty) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_pct_time_empty_7d,
        
        avg(pct_time_full) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_pct_time_full_7d,
        
        -- Demand metrics
        avg(trips_started) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_trips_started_7d,
        
        avg(trips_ended) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_trips_ended_7d,
        
        avg(total_trip_activity) over (
            partition by station_id 
            order by date_day 
            rows between 6 preceding and current row
        ) as avg_total_activity_7d,
        
        -- === 28-DAY ROLLING AVERAGES (monthly trends) ===
        
        avg(trips_started) over (
            partition by station_id 
            order by date_day 
            rows between 27 preceding and current row
        ) as avg_trips_started_28d,
        
        avg(avg_occupancy_ratio) over (
            partition by station_id 
            order by date_day 
            rows between 27 preceding and current row
        ) as avg_occupancy_ratio_28d,
        
        -- === LAG METRICS (day-over-day comparison) ===
        
        lag(trips_started, 1) over (
            partition by station_id 
            order by date_day
        ) as trips_started_prev_day,
        
        lag(avg_occupancy_ratio, 1) over (
            partition by station_id 
            order by date_day
        ) as occupancy_ratio_prev_day,
        
        -- Same day last week
        lag(trips_started, 7) over (
            partition by station_id 
            order by date_day
        ) as trips_started_same_day_last_week

    from with_derived_metrics

),

final as (

    select
        *,
        
        -- === TREND INDICATORS ===
        
        -- Day-over-day change
        trips_started - trips_started_prev_day as trips_started_change_dod,
        
        -- Week-over-week change
        trips_started - trips_started_same_day_last_week as trips_started_change_wow,
        
        -- Deviation from 7-day average (%)
        safe_divide(
            (trips_started - avg_trips_started_7d),
            nullif(avg_trips_started_7d, 0)
        ) * 100 as trips_started_deviation_pct_7d,
        
        -- Trend classification
        case
            when trips_started > avg_trips_started_7d * 1.2 then 'surge'
            when trips_started > avg_trips_started_7d * 1.1 then 'above_average'
            when trips_started < avg_trips_started_7d * 0.8 then 'decline'
            when trips_started < avg_trips_started_7d * 0.9 then 'below_average'
            else 'stable'
        end as demand_trend

    from with_rolling_averages

)

select * from final