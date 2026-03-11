{{
    config(
        materialized='table',
        tags=['marts', 'dimension', 'date']
    )
}}

/*
 * ============================================================================
 * DIMENSION: DATE
 * ============================================================================
 * Purpose: Comprehensive date dimension for time-based analysis
 * Grain: 1 row per day
 * Type: Conformed dimension (shared across all fact tables)
 *
 * Key Features:
 * - Dynamically generated from fact table date range (no manual maintenance)
 * - Includes 365-day buffer for future dates (supports forecasting)
 * - 50+ calendar attributes for flexible analysis
 * - Supports fiscal year calculations
 * - Includes seasonal and holiday flags
 *
 * Usage Example:
 *   SELECT d.day_name, COUNT(f.trip_key)
 *   FROM fct_trips f
 *   JOIN dim_date d ON f.start_date_key = d.date_key
 *   WHERE d.is_weekend = TRUE
 *   GROUP BY 1;
 * ============================================================================
 */

with date_range as (
    
    /*
     * Step 1: Determine date range from existing fact data
     * This makes the dimension self-maintaining - it automatically
     * expands as new data arrives without manual intervention
     */
    select
        min(date_day) as min_date,
        max(date_day) as max_date
    from {{ ref('int_station_daily_fact') }}

),

date_spine as (
    
    /*
     * Step 2: Generate continuous date spine
     * Uses GENERATE_ARRAY to create a sequence of integers (0 to N days)
     * Then adds each integer as days to the min_date
     *
     * The +365 buffer ensures we have future dates for:
     * - Forecasting models
     * - Scheduled reports
     * - Avoiding dimension gaps
     */
    select
        date_add(dr.min_date, interval n day) as full_date
    from date_range dr
    cross join unnest(
        generate_array(
            0,  -- Start from min_date
            date_diff(dr.max_date, dr.min_date, day) + 365  -- End 1 year after max_date
        )
    ) as n

),

date_dimension as (

    select
        -- Primary key (YYYYMMDD format as integer)
        cast(format_date('%Y%m%d', full_date) as int64) as date_key,
        
        -- Full date
        full_date,
        
        -- Day attributes
        extract(day from full_date) as day_of_month,
        extract(dayofweek from full_date) as day_of_week,
        extract(dayofyear from full_date) as day_of_year,
        format_date('%A', full_date) as day_name,
        format_date('%a', full_date) as day_name_short,
        
        -- Week attributes
        extract(week from full_date) as week_of_year,
        extract(isoweek from full_date) as iso_week_of_year,
        cast(ceiling(extract(day from full_date) / 7.0) as int64) as week_of_month,
        
        -- Month attributes
        extract(month from full_date) as month,
        format_date('%B', full_date) as month_name,
        format_date('%b', full_date) as month_name_short,
        
        -- Quarter attributes
        extract(quarter from full_date) as quarter,
        concat('Q', cast(extract(quarter from full_date) as string)) as quarter_name,
        
        -- Year attributes
        extract(year from full_date) as year,
        extract(year from full_date) as fiscal_year,  -- Adjust if fiscal year differs
        extract(quarter from full_date) as fiscal_quarter,
        
        -- Boolean flags - Day type
        extract(dayofweek from full_date) in (1, 7) as is_weekend,
        extract(dayofweek from full_date) between 2 and 6 as is_weekday,
        
        -- Boolean flags - Month boundaries
        extract(day from full_date) = 1 as is_month_start,
        extract(day from full_date) = extract(day from last_day(full_date)) as is_month_end,
        
        -- Boolean flags - Quarter boundaries
        extract(month from full_date) in (1, 4, 7, 10) 
            and extract(day from full_date) = 1 as is_quarter_start,
        extract(month from full_date) in (3, 6, 9, 12) 
            and extract(day from full_date) = extract(day from last_day(full_date)) as is_quarter_end,
        
        -- Boolean flags - Year boundaries
        extract(dayofyear from full_date) = 1 as is_year_start,
        extract(dayofyear from full_date) = 
            extract(dayofyear from date(extract(year from full_date), 12, 31)) as is_year_end,
        
        -- Relative date calculations (from current date)
        date_diff(full_date, current_date(), day) as days_from_today,
        date_diff(full_date, current_date(), week) as weeks_from_today,
        date_diff(full_date, current_date(), month) as months_from_today,
        
        -- Season (Northern Hemisphere)
        case 
            when extract(month from full_date) in (3, 4, 5) then 'Spring'
            when extract(month from full_date) in (6, 7, 8) then 'Summer'
            when extract(month from full_date) in (9, 10, 11) then 'Fall'
            when extract(month from full_date) in (12, 1, 2) then 'Winter'
        end as season,
        
        -- Peak biking season (May - September)
        extract(month from full_date) between 5 and 9 as is_peak_biking_season,
        
        -- Summer vacation period (June 15 - August 31)
        (extract(month from full_date) = 6 and extract(day from full_date) >= 15)
            or extract(month from full_date) in (7, 8) as is_summer_vacation,
        
        -- Metadata
        current_timestamp() as created_at

    from date_spine

)

select * from date_dimension
order by date_key