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
 * TODO: Replace with actual station info source when available
 * ============================================================================
 */

-- Derive station attributes from daily metrics
-- This is a temporary solution until proper station info source is available
select
    station_id,
    
    -- Use station_id as name temporarily (replace with actual name when available)
    cast(station_id as string) as station_name,
    
    -- Geographic attributes (NULL until proper source available)
    cast(null as float64) as latitude,
    cast(null as float64) as longitude,
    
    -- Capacity from most recent observation
    typical_capacity as capacity,
    
    -- Region (NULL until proper source available)
    cast(null as string) as region,
    
    -- Assume active if we have recent data
    true as is_active,
    
    -- Use most recent report time as updated_at
    max(last_reported_at) as updated_at
    
from {{ ref('int_station_daily_metrics') }}
group by
    station_id,
    typical_capacity

{% endsnapshot %}