{% snapshot snap_station %}

{{
    config(
      target_schema='snapshots',
      unique_key='station_id',
      strategy='timestamp',
      updated_at='updated_at',
      invalidate_hard_deletes=True,
      tags=['snapshot', 'scd_type_2']
    )
}}

/*
 * ============================================================================
 * SNAPSHOT: STATION (SCD Type 2)
 * ============================================================================
 * Purpose: Track historical changes to station attributes
 * Strategy: Timestamp-based (compares updated_at column)
 *
 * How it works:
 * 1. dbt compares current data to previous snapshot
 * 2. If updated_at changed, marks old record as expired (dbt_valid_to = now)
 * 3. Inserts new record with dbt_valid_from = now
 * 4. Each record gets unique dbt_scd_id (surrogate key)
 *
 * Columns added by dbt:
 * - dbt_valid_from: When this version became active
 * - dbt_valid_to: When superseded (NULL = current)
 * - dbt_scd_id: Unique ID for this version
 * - dbt_updated_at: When dbt last updated this record
 *
 * Note: Currently derives from int_station_daily_metrics
 *
 * KNOWN LIMITATION: Station names are currently set to station_id because
 * the station status data (which has names) uses UUID-based station IDs that
 * don't match the numeric station IDs in trip data. This is a data integration
 * challenge between two separate Citibike data feeds.
 *
 * Future Enhancement: Integrate proper station metadata when a unified
 * station identifier system becomes available.
 * ============================================================================
 */

-- Source station attributes from trip data (has names and numeric IDs)
-- This provides the station metadata needed for dimensional modeling
with trip_stations as (
    -- Get unique stations from trip data with their attributes
    select
        start_station_id as station_id,
        start_station_name as station_name,
        start_lat as latitude,
        start_lng as longitude
    from {{ ref('stg_trips') }}
    where start_station_id is not null
        and start_station_name is not null
    
    union distinct
    
    select
        end_station_id as station_id,
        end_station_name as station_name,
        end_lat as latitude,
        end_lng as longitude
    from {{ ref('stg_trips') }}
    where end_station_id is not null
        and end_station_name is not null
)

select
    station_id,
    station_name,
    
    -- Use most common lat/lng for each station (handles minor GPS variations)
    approx_top_count(latitude, 1)[offset(0)].value as latitude,
    approx_top_count(longitude, 1)[offset(0)].value as longitude,
    
    -- Capacity: NULL (not available in trip data)
    cast(null as int64) as capacity,
    
    -- Region: NULL (not available in trip data)
    cast(null as string) as region,
    
    -- Active if we have recent trip data
    true as is_active,
    
    -- Use current timestamp as updated_at (will trigger snapshot on first run)
    current_timestamp() as updated_at
    
from trip_stations
group by
    station_id,
    station_name

{% endsnapshot %}