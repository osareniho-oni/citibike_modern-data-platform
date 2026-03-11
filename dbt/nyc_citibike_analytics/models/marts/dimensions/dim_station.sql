{{
    config(
        materialized='table',
        tags=['marts', 'dimension', 'station']
    )
}}

/*
 * ============================================================================
 * DIMENSION: STATION (with SCD Type 2)
 * ============================================================================
 * Purpose: Track station attributes and their changes over time
 * Grain: 1 row per station (current version only in this view)
 * Type: Slowly Changing Dimension Type 2
 *
 * SCD Type 2 Strategy:
 * - Historical changes tracked in snapshot table (snap_station)
 * - This dimension shows CURRENT state only (dbt_valid_to IS NULL)
 * - Each station can have multiple historical versions in snapshot
 * - Fact tables reference this dimension via surrogate keys
 *
 * Why SCD Type 2?
 * - Stations can change: capacity upgrades, relocations, name changes
 * - Need to maintain "as-was" reporting (what was capacity when trip occurred?)
 * - Preserves referential integrity with historical facts
 * - Enables trend analysis (e.g., "trips before vs after capacity increase")
 *
 * How it works:
 * 1. dbt snapshot runs daily, comparing current state to previous
 * 2. If changes detected, old record gets dbt_valid_to = current_timestamp
 * 3. New record inserted with dbt_valid_from = current_timestamp
 * 4. This dimension always shows latest version (dbt_valid_to IS NULL)
 * 5. Fact tables can join to historical versions using dbt_scd_id if needed
 *
 * Unknown Station Handling:
 * - Includes a default "Unknown Station" record (station_id = '-1')
 * - Used for late-arriving dimensions (fact arrives before dimension)
 * - Prevents referential integrity failures
 * - Can be corrected later when actual station data arrives
 *
 * Usage Example:
 *   -- Current state
 *   SELECT * FROM dim_station WHERE is_current = TRUE;
 *
 *   -- Historical analysis (requires joining to snapshot)
 *   SELECT f.*, s.capacity as capacity_at_trip_time
 *   FROM fct_trips f
 *   JOIN snap_station s
 *     ON f.start_station_key = s.dbt_scd_id
 *     AND f.started_at BETWEEN s.dbt_valid_from AND COALESCE(s.dbt_valid_to, '9999-12-31');
 * ============================================================================
 */

with station_snapshot as (

    /*
     * Source: dbt snapshot table (snap_station)
     * Filter: Only current records (dbt_valid_to IS NULL)
     *
     * dbt snapshot columns explained:
     * - dbt_valid_from: When this version became active
     * - dbt_valid_to: When this version was superseded (NULL = current)
     * - dbt_scd_id: Unique ID for this specific version (surrogate key)
     *
     * Note: If snapshot hasn't run yet, this will be empty
     * Solution: Run `dbt snapshot` before building this dimension
     */
    select
        station_id,
        station_name,
        latitude,
        longitude,
        capacity,
        region,
        is_active,
        updated_at,
        dbt_valid_from,
        dbt_valid_to,
        dbt_scd_id
    from {{ ref('snap_station') }}
    where dbt_valid_to is null  -- Current records only

),

station_enriched as (

    select
        /*
         * SURROGATE KEY GENERATION
         * Combines station_id + dbt_valid_from to create unique key
         * Why both? Because same station can have multiple versions
         * This key is stable and deterministic across dbt runs
         *
         * Alternative approaches:
         * - Use dbt_scd_id directly (simpler but less portable)
         * - Use ROW_NUMBER() (not deterministic)
         * - Use GENERATE_UUID() (not deterministic)
         */
        {{ dbt_utils.generate_surrogate_key(['station_id', 'dbt_valid_from']) }} as station_key,
        
        /*
         * NATURAL KEY
         * The business key that users recognize
         * Not used as primary key because:
         * - Not unique across versions (SCD Type 2)
         * - String comparison slower than integer
         * - May change (though rare for station IDs)
         */
        station_id,
        
        /*
         * DESCRIPTIVE ATTRIBUTES
         * These are the attributes that can change over time
         * Changes to these trigger new snapshot versions
         */
        station_name,
        latitude,
        longitude,
        capacity,
        coalesce(cast(region as string), 'Unknown') as region,
        is_active,
        
        /*
         * DERIVED GEOGRAPHIC ATTRIBUTES
         * Borough classification based on latitude/longitude
         *
         * NYC Geography (approximate):
         * - Bronx: lat > 40.8
         * - Upper Manhattan: 40.75 < lat <= 40.8
         * - Midtown Manhattan: 40.7 < lat <= 40.75
         * - Lower Manhattan: 40.65 < lat <= 40.7
         * - Brooklyn: lon < -74.0 (west of Manhattan)
         * - Queens: Everything else
         *
         * Note: This is simplified. For production, consider:
         * - Using PostGIS or BigQuery GIS functions
         * - Joining to a proper borough boundary table
         * - Handling edge cases (Staten Island, etc.)
         */
        case
            when latitude is not null then
                case
                    when latitude > 40.8 then 'Bronx'
                    when latitude > 40.75 then 'Upper Manhattan'
                    when latitude > 40.7 then 'Midtown Manhattan'
                    when latitude > 40.65 then 'Lower Manhattan'
                    when longitude < -74.0 then 'Brooklyn'
                    else 'Queens'
                end
            else 'Unknown'
        end as borough,
        
        /*
         * STATION SIZE CLASSIFICATION
         * Based on capacity (total docks)
         * Useful for: capacity planning, station type analysis
         *
         * Size categories:
         * - Large: 50+ docks (major hubs, transit centers)
         * - Medium: 30-49 docks (busy intersections)
         * - Small: 15-29 docks (neighborhood stations)
         * - Micro: <15 docks (low-traffic areas)
         */
        case
            when capacity >= 50 then 'large'
            when capacity >= 30 then 'medium'
            when capacity >= 15 then 'small'
            else 'micro'
        end as station_size,
        
        /*
         * SCD TYPE 2 METADATA
         * Tracks when this version was valid
         * - effective_date: When this version became active
         * - end_date: When superseded (NULL = still current)
         * - is_current: Boolean flag for current version
         *
         * Use cases:
         * - Point-in-time queries: "What was capacity on 2024-01-15?"
         * - Change analysis: "When did capacity increase?"
         * - Audit trail: "What changed and when?"
         */
        dbt_valid_from as effective_date,
        dbt_valid_to as end_date,
        dbt_valid_to is null as is_current,
        
        /*
         * AUDIT METADATA
         * Tracks data lineage and freshness
         */
        updated_at,
        current_timestamp() as created_at

    from station_snapshot

),

/*
 * UNKNOWN STATION RECORD
 * Default record for late-arriving dimensions
 *
 * Why needed?
 * - Fact data may reference stations not yet in dimension
 * - Prevents referential integrity failures
 * - Allows fact loading to proceed
 * - Can be corrected later when station data arrives
 *
 * When used?
 * - New stations appear in trip data before station info
 * - Data quality issues (missing station IDs)
 * - Historical data with decommissioned stations
 *
 * Best practices:
 * - Use consistent unknown key across all dimensions (-1)
 * - Make it obvious (name = "Unknown Station")
 * - Set is_active = FALSE to exclude from active station counts
 * - Use ancient effective_date (1900-01-01) to sort last
 *
 * Monitoring:
 * - Track fact records using unknown key
 * - Alert if percentage exceeds threshold (e.g., >1%)
 * - Investigate and backfill missing dimension data
 */
unknown_station as (

    select
        {{ dbt_utils.generate_surrogate_key(['-1']) }} as station_key,
        '-1' as station_id,
        'Unknown Station' as station_name,
        cast(null as float64) as latitude,
        cast(null as float64) as longitude,
        cast(null as int64) as capacity,
        'Unknown' as region,
        false as is_active,
        'Unknown' as borough,
        'unknown' as station_size,
        timestamp('1900-01-01 00:00:00') as effective_date,
        cast(null as timestamp) as end_date,
        true as is_current,
        cast(null as timestamp) as updated_at,
        current_timestamp() as created_at

)

/*
 * FINAL UNION
 * Combines actual stations with unknown station record
 * Unknown station will always be present, even if no real stations exist
 */
select * from station_enriched
union all
select * from unknown_station