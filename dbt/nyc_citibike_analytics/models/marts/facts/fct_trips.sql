{{
    config(
        materialized='incremental',
        unique_key='trip_key',
        partition_by={
            'field': 'started_at',
            'data_type': 'timestamp',
            'granularity': 'day'
        },
        cluster_by=['start_station_key', 'user_type_key'],
        incremental_strategy='merge',
        tags=['marts', 'fact', 'trips']
    )
}}

/*
 * ============================================================================
 * FACT TABLE: TRIPS (Transactional)
 * ============================================================================
 * Purpose: Capture individual bike trip transactions with full dimensional context
 * Grain: 1 row per trip (atomic level)
 * Type: Transactional fact table
 *
 * Key Design Decisions:
 * 1. SURROGATE KEYS: Uses surrogate keys (not natural keys) for all dimensions
 *    - Smaller storage footprint (INT64 vs STRING)
 *    - Faster joins
 *    - Handles SCD Type 2 correctly
 *
 * 2. PARTITIONING: Partitioned by start_date_key (integer range)
 *    - Enables partition pruning for date-based queries
 *    - Reduces query costs significantly
 *    - Range partitioning is more efficient than date partitioning for integers
 *
 * 3. CLUSTERING: Clustered by [start_station_key, user_type_key]
 *    - Optimizes queries filtering by station and user type
 *    - Reduces data scanned
 *    - Order matters: most selective column first
 *
 * 4. INCREMENTAL STRATEGY: Uses 'merge' (not 'append')
 *    - Handles late-arriving data
 *    - Updates existing records if needed
 *    - More expensive but more accurate
 *
 * 5. LATE-ARRIVING DIMENSIONS: Uses COALESCE with unknown keys
 *    - Prevents referential integrity failures
 *    - Allows fact loading even if dimension is missing
 *    - Can be corrected later with dimension updates
 *
 * Measure Types:
 * - Additive: trip_duration_minutes, trip_distance_km (can be summed)
 * - Semi-additive: coordinates (can be averaged, not summed)
 * - Non-additive: flags (boolean, for filtering only)
 *
 * Usage Example:
 *   SELECT
 *     d.day_name,
 *     s.station_name,
 *     COUNT(f.trip_key) as trips,
 *     AVG(f.trip_duration_minutes) as avg_duration
 *   FROM fct_trips f
 *   JOIN dim_date d ON f.start_date_key = d.date_key
 *   JOIN dim_station s ON f.start_station_key = s.station_key
 *   WHERE d.year = 2024 AND d.month = 1
 *   GROUP BY 1, 2;
 * ============================================================================
 */

with trips as (

    /*
     * Source: Staging trips table
     * Incremental Logic: Only process trips newer than the latest trip in this table
     * This prevents reprocessing millions of historical trips on each run
     */
    select * from {{ ref('stg_trips') }}
    {% if is_incremental() %}
        where started_at > (select max(started_at) from {{ this }})
    {% endif %}

),

dim_station as (
    /*
     * Load station dimension for lookups
     * Only need station_key (surrogate) and station_id (natural key) for joins
     * Reduces memory footprint by not loading all station attributes
     */
    select station_key, station_id from {{ ref('dim_station') }}
),

dim_date as (
    /*
     * Load date dimension for lookups
     * Pre-filtering not needed as date dimension is relatively small (~2K rows)
     */
    select date_key, full_date from {{ ref('dim_date') }}
),

dim_user_type as (
    /*
     * Load user type dimension (only 3 rows: member, casual, unknown)
     */
    select user_type_key, user_type_id from {{ ref('dim_user_type') }}
),

dim_time as (
    /*
     * Load time dimension (only 24 rows: 0-23 hours)
     */
    select time_key from {{ ref('dim_time') }}
),

trips_with_keys as (

    select
        /*
         * SURROGATE KEY GENERATION
         * Uses dbt_utils.generate_surrogate_key() for deterministic hashing
         * This creates a consistent key based on the natural key (ride_id)
         * Benefits: Reproducible, no sequence gaps, works across environments
         */
        {{ dbt_utils.generate_surrogate_key(['t.ride_id']) }} as trip_key,
        
        /*
         * DEGENERATE DIMENSION
         * ride_id is stored in the fact table (not in a separate dimension)
         * This is appropriate for high-cardinality, low-reuse attributes
         * Saves the overhead of a separate dimension table
         */
        t.ride_id as trip_id,
        
        /*
         * FOREIGN KEYS - LATE-ARRIVING DIMENSION HANDLING
         * Uses COALESCE to handle missing dimension records:
         * 1. Try to find matching dimension record
         * 2. If not found, use "unknown" surrogate key (-1)
         * 3. This prevents referential integrity failures
         * 4. Can be corrected later when dimension is updated
         *
         * Why this matters:
         * - Fact data may arrive before dimension data
         * - Prevents data loss
         * - Maintains referential integrity
         * - Enables "load facts first, fix dimensions later" pattern
         */
        coalesce(ds_start.station_key,
            {{ dbt_utils.generate_surrogate_key(['-1']) }}) as start_station_key,
        coalesce(ds_end.station_key,
            {{ dbt_utils.generate_surrogate_key(['-1']) }}) as end_station_key,
        
        /*
         * DATE KEY FALLBACK
         * If date dimension doesn't have the date yet (edge case),
         * generate the date_key on-the-fly using the same format (YYYYMMDD)
         * This ensures the fact can still be loaded
         */
        coalesce(dd_start.date_key,
            cast(format_date('%Y%m%d', date(t.started_at)) as int64)) as start_date_key,
        coalesce(dd_end.date_key,
            cast(format_date('%Y%m%d', date(t.ended_at)) as int64)) as end_date_key,
        
        /*
         * TIME KEY FALLBACK
         * Extract hour directly if time dimension lookup fails
         */
        coalesce(dt_start.time_key, extract(hour from t.started_at)) as start_hour_key,
        coalesce(dt_end.time_key, extract(hour from t.ended_at)) as end_hour_key,
        
        /*
         * USER TYPE KEY FALLBACK
         * Uses subquery to get unknown user_type_key if lookup fails
         * Alternative: Could hardcode the unknown key if it's always the same
         */
        coalesce(du.user_type_key,
            (select user_type_key from dim_user_type where user_type_id = 'unknown')) as user_type_key,
        
        /*
         * TIMESTAMPS
         * Keep original timestamps for precise time-of-day analysis
         * These complement the date/time dimension keys
         * Useful for: exact duration calculations, time series analysis
         */
        t.started_at,
        t.ended_at,
        
        /*
         * ADDITIVE MEASURES
         * These can be summed across any dimension
         * Example: SUM(trip_duration_minutes) gives total riding time
         */
        timestamp_diff(t.ended_at, t.started_at, minute) as trip_duration_minutes,
        timestamp_diff(t.ended_at, t.started_at, second) as trip_duration_seconds,
        
        /*
         * DISTANCE CALCULATION - Haversine Formula
         * Calculates great-circle distance between two lat/long points
         * Formula: d = 2r × arcsin(√(sin²((lat2-lat1)/2) + cos(lat1)×cos(lat2)×sin²((lon2-lon1)/2)))
         * Where: r = Earth's radius (6371 km)
         *
         * Why Haversine?
         * - Accurate for short distances (< 1000 km)
         * - Accounts for Earth's curvature
         * - Standard formula for GPS distance
         *
         * Note: For very precise distances, consider Vincenty formula
         * For performance, could pre-calculate in staging layer
         */
        round(
            2 * 6371 * asin(sqrt(
                pow(sin((t.end_lat - t.start_lat) * 3.14159265359 / 360), 2) +
                cos(t.start_lat * 3.14159265359 / 180) *
                cos(t.end_lat * 3.14159265359 / 180) *
                pow(sin((t.end_lng - t.start_lng) * 3.14159265359 / 360), 2)
            )),
            2
        ) as trip_distance_km,
        
        /*
         * SEMI-ADDITIVE MEASURES
         * Coordinates can be averaged (for centroid) but not summed
         * Stored in fact for convenience, though could be in dimension
         * Trade-off: Storage vs. join performance
         */
        t.start_lat as start_latitude,
        t.start_lng as start_longitude,
        t.end_lat as end_latitude,
        t.end_lng as end_longitude,
        
        /*
         * DEGENERATE DIMENSIONS
         * Low-cardinality attributes stored in fact (not separate dimension)
         * bike_type: Only 2-3 values (electric_bike, classic_bike)
         * Not worth the overhead of a separate dimension table
         */
        t.rideable_type as bike_type,
        
        /*
         * DERIVED FLAGS (Non-Additive)
         * Boolean flags for filtering and segmentation
         * Calculated once at load time for query performance
         * Alternative: Could calculate in BI layer, but this is more efficient
         */
        t.start_station_id = t.end_station_id as is_round_trip,
        timestamp_diff(t.ended_at, t.started_at, minute) < 5 as is_short_trip,
        timestamp_diff(t.ended_at, t.started_at, minute) > 60 as is_long_trip,
        
        /*
         * AUDIT COLUMNS
         * Track when record was loaded for troubleshooting
         * Useful for: debugging, data lineage, SLA monitoring
         */
        current_timestamp() as loaded_at

    from trips t
    
    /*
     * DIMENSION LOOKUPS - All LEFT JOINS
     * Why LEFT JOIN (not INNER JOIN)?
     * - Prevents data loss if dimension record is missing
     * - COALESCE above handles missing keys with "unknown" values
     * - Allows fact loading to proceed even with incomplete dimensions
     *
     * Join Strategy:
     * - Join on natural keys (station_id, date, etc.)
     * - Select surrogate keys for the fact table
     * - BigQuery optimizes these joins well due to clustering
     */
    left join dim_station ds_start
        on t.start_station_id = ds_start.station_id
    left join dim_station ds_end
        on t.end_station_id = ds_end.station_id
    left join dim_date dd_start
        on date(t.started_at) = dd_start.full_date
    left join dim_date dd_end
        on date(t.ended_at) = dd_end.full_date
    left join dim_time dt_start
        on extract(hour from t.started_at) = dt_start.time_key
    left join dim_time dt_end
        on extract(hour from t.ended_at) = dt_end.time_key
    left join dim_user_type du
        on t.member_casual = du.user_type_id

)

/*
 * FINAL SELECT
 * No transformations here - just pass through
 * All business logic is in the CTE above for clarity
 */
select * from trips_with_keys