{{
    config(
        materialized='table',
        tags=['marts', 'dimension', 'time']
    )
}}

-- Dimension: Time
-- Grain: 1 row per hour (0-23)
-- Static dimension for time-of-day analysis

with hours as (
    
    select hour
    from unnest(generate_array(0, 23)) as hour

)

select
    -- Surrogate key (same as hour for simplicity)
    hour as time_key,
    
    -- Hour attributes
    hour,
    case 
        when hour = 0 then 12
        when hour <= 12 then hour
        else hour - 12
    end as hour_12,
    case when hour < 12 then 'AM' else 'PM' end as am_pm,
    
    -- Formatted hour names
    case 
        when hour = 0 then '12:00 AM'
        when hour < 12 then concat(cast(hour as string), ':00 AM')
        when hour = 12 then '12:00 PM'
        else concat(cast(hour - 12 as string), ':00 PM')
    end as hour_name,
    
    -- Time buckets
    case
        when hour between 0 and 5 then 'late_night'
        when hour between 6 and 9 then 'morning_rush'
        when hour between 10 and 15 then 'midday'
        when hour between 16 and 19 then 'evening_rush'
        when hour between 20 and 23 then 'evening'
    end as time_bucket,
    
    -- Boolean flags
    hour between 7 and 9 or hour between 16 and 19 as is_rush_hour,
    hour between 6 and 9 as is_morning_rush,
    hour between 16 and 19 as is_evening_rush,
    hour between 9 and 17 as is_business_hours,
    hour between 7 and 22 as is_peak_biking_hours,
    
    -- Shift classification
    case
        when hour between 6 and 13 then 'morning'
        when hour between 14 and 19 then 'afternoon'
        when hour between 20 and 23 then 'evening'
        else 'night'
    end as shift,
    
    -- Metadata
    current_timestamp() as created_at

from hours
order by hour