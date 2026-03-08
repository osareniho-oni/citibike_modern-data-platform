{{
    config(
        materialized='table',
        tags=['intermediate', 'station_metrics', 'daily']
    )
}}

-- Intermediate model: Daily aggregated station operational metrics
-- Aggregates 5-minute station metrics to daily grain
-- Provides supply-side KPIs for station capacity and availability analysis

with station_metrics as (

    select * from {{ ref('int_station_metrics') }}

),

daily_aggregation as (

    select
        -- Identifiers
        station_id,
        
        -- Time dimension
        date(reported_at_5min) as date_day,
        
        -- Capacity metrics (using mode for most common value, as capacity shouldn't change much)
        approx_top_count(total_capacity, 1)[offset(0)].value as typical_capacity,
        max(total_capacity) as max_capacity,
        min(total_capacity) as min_capacity,
        
        -- Average availability
        avg(num_bikes_available) as avg_bikes_available,
        avg(num_ebikes_available) as avg_ebikes_available,
        avg(num_docks_available) as avg_docks_available,
        avg(num_bikes_disabled) as avg_bikes_disabled,
        avg(num_docks_disabled) as avg_docks_disabled,
        avg(num_scooters_available) as avg_scooters_available,
        avg(num_scooters_unavailable) as avg_scooters_unavailable,
        
        -- Peak availability (useful for capacity planning)
        max(num_bikes_available) as max_bikes_available,
        max(num_docks_available) as max_docks_available,
        max(num_scooters_available) as max_scooters_available,
        min(num_bikes_available) as min_bikes_available,
        min(num_docks_available) as min_docks_available,
        min(num_scooters_available) as min_scooters_available,
        
        -- Occupancy metrics
        avg(occupancy_ratio) as avg_occupancy_ratio,
        stddev(occupancy_ratio) as occupancy_volatility,
        min(occupancy_ratio) as min_occupancy_ratio,
        max(occupancy_ratio) as max_occupancy_ratio,
        
        -- Utilization metrics
        avg(utilization_percentage) as avg_utilization_percentage,
        stddev(utilization_percentage) as utilization_volatility,
        
        -- E-bike availability
        avg(ebike_ratio) as avg_ebike_ratio,
        
        -- Operational status percentages
        countif(is_empty) / count(*) as pct_time_empty,
        countif(is_full) / count(*) as pct_time_full,
        countif(operational_status = 'operational') / count(*) as pct_time_operational,
        countif(operational_status = 'out_of_service') / count(*) as pct_time_out_of_service,
        
        -- Observation counts (for data quality)
        count(*) as total_observations,
        count(distinct reported_at_5min) as unique_5min_intervals,
        
        -- Time coverage (should be ~288 for full day at 5-min intervals)
        count(distinct reported_at_5min) / 288.0 as time_coverage_ratio,
        
        -- Operational flags
        logical_and(is_installed) as was_installed_all_day,
        logical_or(is_renting) as was_renting_any_time,
        logical_or(is_returning) as was_returning_any_time,
        
        -- Metadata
        min(last_reported) as first_reported_at,
        max(last_reported) as last_reported_at

    from station_metrics
    group by 
        station_id,
        date(reported_at_5min)

),

final as (

    select
        *,
        
        -- Derived operational health score (0-100)
        -- Higher score = better operational health
        case
            when pct_time_operational >= 0.95 then 100
            when pct_time_operational >= 0.90 then 90
            when pct_time_operational >= 0.80 then 80
            when pct_time_operational >= 0.70 then 70
            when pct_time_operational >= 0.50 then 50
            else 0
        end as operational_health_score,
        
        -- Rebalancing need indicator
        -- High when station is frequently empty or full
        case
            when (pct_time_empty + pct_time_full) > 0.5 then 'high'
            when (pct_time_empty + pct_time_full) > 0.3 then 'medium'
            else 'low'
        end as rebalancing_need,
        
        -- Data quality flag
        case
            when time_coverage_ratio < 0.5 then 'poor'
            when time_coverage_ratio < 0.8 then 'fair'
            when time_coverage_ratio < 0.95 then 'good'
            else 'excellent'
        end as data_quality

    from daily_aggregation

)

select * from final