{{
    config(
        materialized='table',
        tags=['intermediate', 'trips', 'daily']
    )
}}

-- Intermediate model: Daily trip aggregations by station
-- Aggregates trip demand metrics at station + date grain
-- Provides demand-side KPIs for trip patterns and rider behavior analysis

with trips as (

    select * from {{ ref('stg_trips') }}

),

-- Aggregate trips started from each station
trips_started as (

    select
        start_station_id as station_id,
        date(started_at) as date_day,
        
        -- Trip counts
        count(*) as trips_started,
        
        -- Trip duration metrics (in minutes)
        avg(timestamp_diff(ended_at, started_at, minute)) as avg_trip_duration_minutes,
        approx_quantiles(timestamp_diff(ended_at, started_at, minute), 100)[offset(50)] as median_trip_duration_minutes,
        approx_quantiles(timestamp_diff(ended_at, started_at, minute), 100)[offset(95)] as p95_trip_duration_minutes,
        min(timestamp_diff(ended_at, started_at, minute)) as min_trip_duration_minutes,
        max(timestamp_diff(ended_at, started_at, minute)) as max_trip_duration_minutes,
        stddev(timestamp_diff(ended_at, started_at, minute)) as stddev_trip_duration_minutes,
        
        -- Rider type breakdown
        countif(member_casual = 'member') as member_trips_started,
        countif(member_casual = 'casual') as casual_trips_started,
        
        -- Bike type breakdown
        countif(rideable_type = 'electric_bike') as ebike_trips_started,
        countif(rideable_type = 'classic_bike') as classic_bike_trips_started,
        
        -- Time of day patterns (for started trips)
        countif(extract(hour from started_at) between 6 and 9) as morning_rush_trips_started,
        countif(extract(hour from started_at) between 16 and 19) as evening_rush_trips_started,
        countif(extract(hour from started_at) between 10 and 15) as midday_trips_started,
        countif(extract(hour from started_at) between 20 and 23 or extract(hour from started_at) between 0 and 5) as night_trips_started,
        
        -- Peak hour
        approx_top_count(extract(hour from started_at), 1)[offset(0)].value as peak_start_hour

    from trips
    where start_station_id is not null  -- Exclude trips without station (street pickups)
    group by 
        start_station_id,
        date(started_at)

),

-- Aggregate trips ended at each station
trips_ended as (

    select
        end_station_id as station_id,
        date(ended_at) as date_day,
        
        -- Trip counts
        count(*) as trips_ended,
        
        -- Rider type breakdown
        countif(member_casual = 'member') as member_trips_ended,
        countif(member_casual = 'casual') as casual_trips_ended,
        
        -- Bike type breakdown
        countif(rideable_type = 'electric_bike') as ebike_trips_ended,
        countif(rideable_type = 'classic_bike') as classic_bike_trips_ended,
        
        -- Time of day patterns (for ended trips)
        countif(extract(hour from ended_at) between 6 and 9) as morning_rush_trips_ended,
        countif(extract(hour from ended_at) between 16 and 19) as evening_rush_trips_ended,
        countif(extract(hour from ended_at) between 10 and 15) as midday_trips_ended,
        countif(extract(hour from ended_at) between 20 and 23 or extract(hour from ended_at) between 0 and 5) as night_trips_ended,
        
        -- Peak hour
        approx_top_count(extract(hour from ended_at), 1)[offset(0)].value as peak_end_hour

    from trips
    where end_station_id is not null  -- Exclude trips without station (street dropoffs)
    group by 
        end_station_id,
        date(ended_at)

),

-- Combine started and ended trips
combined as (

    select
        cast(coalesce(s.station_id, e.station_id) as string) as station_id,
        coalesce(s.date_day, e.date_day) as date_day,
        
        -- Trip counts
        coalesce(s.trips_started, 0) as trips_started,
        coalesce(e.trips_ended, 0) as trips_ended,
        coalesce(s.trips_started, 0) - coalesce(e.trips_ended, 0) as net_trips,
        
        -- Trip duration metrics (only available for started trips)
        s.avg_trip_duration_minutes,
        s.median_trip_duration_minutes,
        s.p95_trip_duration_minutes,
        s.min_trip_duration_minutes,
        s.max_trip_duration_minutes,
        s.stddev_trip_duration_minutes,
        
        -- Rider type
        coalesce(s.member_trips_started, 0) as member_trips_started,
        coalesce(s.casual_trips_started, 0) as casual_trips_started,
        coalesce(e.member_trips_ended, 0) as member_trips_ended,
        coalesce(e.casual_trips_ended, 0) as casual_trips_ended,
        
        -- Bike type
        coalesce(s.ebike_trips_started, 0) as ebike_trips_started,
        coalesce(s.classic_bike_trips_started, 0) as classic_bike_trips_started,
        coalesce(e.ebike_trips_ended, 0) as ebike_trips_ended,
        coalesce(e.classic_bike_trips_ended, 0) as classic_bike_trips_ended,
        
        -- Time of day patterns
        coalesce(s.morning_rush_trips_started, 0) as morning_rush_trips_started,
        coalesce(s.evening_rush_trips_started, 0) as evening_rush_trips_started,
        coalesce(s.midday_trips_started, 0) as midday_trips_started,
        coalesce(s.night_trips_started, 0) as night_trips_started,
        coalesce(e.morning_rush_trips_ended, 0) as morning_rush_trips_ended,
        coalesce(e.evening_rush_trips_ended, 0) as evening_rush_trips_ended,
        coalesce(e.midday_trips_ended, 0) as midday_trips_ended,
        coalesce(e.night_trips_ended, 0) as night_trips_ended,
        
        -- Peak hours
        s.peak_start_hour,
        e.peak_end_hour

    from trips_started s
    full outer join trips_ended e
        on s.station_id = e.station_id
        and s.date_day = e.date_day

),

final as (

    select
        *,
        
        -- Derived metrics
        safe_divide(member_trips_started, trips_started) as member_pct_started,
        safe_divide(casual_trips_started, trips_started) as casual_pct_started,
        safe_divide(ebike_trips_started, trips_started) as ebike_pct_started,
        
        -- Station usage pattern classification
        case
            when trips_started = 0 and trips_ended = 0 then 'inactive'
            when net_trips > 10 then 'net_source'  -- More trips start than end
            when net_trips < -10 then 'net_sink'   -- More trips end than start
            else 'balanced'
        end as station_flow_pattern,
        
        -- Rush hour intensity
        safe_divide(
            (morning_rush_trips_started + evening_rush_trips_started),
            trips_started
        ) as rush_hour_intensity

    from combined

)

select * from final