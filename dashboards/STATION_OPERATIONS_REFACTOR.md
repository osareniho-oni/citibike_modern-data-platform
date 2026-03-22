# Station Operations View Refactor

## Summary
Refactored `vw_station_operations` to focus solely on **real-time station status** from the streaming data source, removing trip-related metrics that were preventing proper dashboard functionality.

## Problem
The original `vw_station_operations` view was pulling from `fct_station_day`, which:
- Aggregated daily metrics including trip information
- Made it impossible to get real-time metrics like current bikes available, docks available
- Mixed operational status with trip analytics

## Station Names - Important Note! 📝
**Q: Will I see station names or just station IDs?**

**A: You'll see proper station names!** Here's how it works:

1. **Streaming data** (`stg_station_status`) only has `station_id` (no names)
2. **Station dimension** (`dim_station`) has names from trip data
3. **The view joins them** using LEFT JOIN to get names
4. **Fallback logic**: If a station isn't in the dimension yet, it shows `station_id` as the name

**Why this works:**
- Station names come from `snap_station` which pulls from trip data (`stg_trips`)
- Trip data has actual station names (e.g., "Broadway & W 58 St")
- Most active stations will have names because they appear in trip data
- New/inactive stations might show station_id until they appear in trips

**If you see station IDs instead of names:**
- Run `dbt snapshot` to update the station dimension
- Run `dbt run --select dim_station` to rebuild the dimension
- The station may be brand new and hasn't had any trips yet

## Solution
Rebuilt `vw_station_operations` to query directly from `stg_station_status`:
- **Data Source**: Live station status stream (Citibike GBFS API)
- **Focus**: Real-time availability and operational status only
- **No Trip Data**: Trip metrics moved to separate trip analytics views

## Key Changes

### 1. Data Source Change
**Before**: `fct_station_day` (daily aggregated facts with trip data)
**After**: `stg_station_status` (live streaming station status)

### 2. Metrics Available

#### Real-Time Availability Metrics
- `num_bikes_available` - Current regular bikes available
- `num_ebikes_available` - Current electric bikes available  
- `num_docks_available` - Current docks available
- `num_bikes_disabled` - Bikes out of service
- `num_docks_disabled` - Docks out of service
- `num_scooters_available` - Scooters available
- `total_bikes_available` - Total bikes (regular + ebikes)
- `total_capacity` - Total capacity (bikes + docks)

#### Calculated Metrics
- `occupancy_ratio` - Bikes / total capacity (0-1)
- `utilization_pct` - Utilization percentage (0-100)

#### Operational Status
- `is_installed` - Station physically installed
- `is_renting` - Allowing bike rentals
- `is_returning` - Allowing bike returns
- `operational_status` - Overall status (Operational/Out of Service/etc.)
- `availability_status` - Empty/Full/Low Bikes/Low Docks/Available

#### Rebalancing Indicators
- `rebalancing_need` - Priority level (low/medium/high)
- `priority_indicator` - Visual indicator (🔴 High/🟡 Medium/🟢 Low Priority)

#### Data Freshness
- `last_reported` - When station last reported
- `minutes_since_last_report` - Minutes since last update
- `data_freshness` - Fresh/Recent/Stale/Very Stale

### 3. Removed Metrics (Now in Trip Analytics Views)
- ❌ `trips_started` - Use `vw_trip_analytics_daily` instead
- ❌ `trips_ended` - Use `vw_trip_analytics_daily` instead
- ❌ `net_trips` - Use `vw_trip_analytics_daily` instead
- ❌ `station_flow_pattern` - Use `vw_trip_analytics_daily` instead
- ❌ `avg_bikes_available` (daily avg) - Now shows current value
- ❌ `pct_time_empty` - Historical metric, not real-time
- ❌ `pct_time_full` - Historical metric, not real-time
- ❌ `operational_health_score` - Historical metric, not real-time

## Dashboard Usage

### For Looker Studio
Use the main query from `dashboards/queries/station_operations.sql`:

```sql
SELECT * 
FROM `YOUR-PROJECT.citibike_dashboards.vw_station_operations`
ORDER BY 
  CASE rebalancing_need
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
  END,
  station_name;
```

### Key Dashboard Metrics You Can Now Track
1. **Current Availability**: Real-time bikes and docks available
2. **Station Status**: Operational status and availability status
3. **Rebalancing Needs**: Priority stations needing attention
4. **Regional Overview**: Availability by region/borough
5. **Data Freshness**: How recent the data is

### Example Dashboard Visualizations

#### 1. Station Availability Map
- **Metric**: `num_bikes_available`, `num_docks_available`
- **Geo**: `latitude`, `longitude`
- **Color**: `priority_indicator` or `availability_status`

#### 2. Rebalancing Priority List
- **Filter**: `rebalancing_need IN ('high', 'medium')`
- **Columns**: `station_name`, `availability_status`, `num_bikes_available`, `num_docks_available`
- **Sort**: `priority_indicator`

#### 3. Regional Summary
- **Dimension**: `region`
- **Metrics**: `COUNT(station_id)`, `SUM(num_bikes_available)`, `AVG(utilization_pct)`

#### 4. Operational Status Overview
- **Dimension**: `operational_status`
- **Metric**: `COUNT(station_id)`
- **Chart**: Pie or bar chart

## For Trip Analytics
If you need trip-related metrics, use these views instead:
- `vw_trip_analytics_daily` - Daily trip patterns, user types, bike types
- `vw_trip_analytics_routes` - Popular routes and station pairs
- `fct_station_day` - Historical daily station metrics with trip data

## Files Modified
1. `dbt/nyc_citibike_analytics/models/dashboards/vw_station_operations.sql` - Complete rewrite
2. `dbt/nyc_citibike_analytics/models/dashboards/schema.yml` - Updated documentation
3. `dashboards/queries/station_operations.sql` - Updated example queries

## Next Steps
1. Run `dbt run --select vw_station_operations` to rebuild the view
2. Update your Looker Studio dashboard to use the new fields
3. Remove any trip-related metrics from station operations dashboard
4. Create separate trip analytics dashboard using `vw_trip_analytics_daily`

## Benefits
✅ Real-time station availability data  
✅ Clear separation of concerns (operations vs. analytics)  
✅ Faster dashboard queries (no complex aggregations)  
✅ Always shows most recent station status  
✅ Better rebalancing insights  
✅ Data freshness indicators