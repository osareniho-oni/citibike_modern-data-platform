#!/bin/bash

# Fix Station Dimension - Complete Rebuild Script
# This script completely rebuilds the station dimension with numeric IDs only
#
# Dataset Structure:
# - raw: Source data from Kestra
# - staging: Staging and intermediate models
# - snapshots: dbt snapshots (SCD Type 2)
# - marts: Star schema (dimensions and facts)
# - citibike_dashboards: Dashboard views

echo "🔧 Starting Station Dimension Fix..."
echo ""

# Step 1: Drop the corrupted snapshot table
echo "Step 1: Dropping corrupted snapshot table (snapshots dataset)..."
bq query --use_legacy_sql=false "
DROP TABLE IF EXISTS \`nyc-citibike-data-platform.snapshots.snap_station\`;
"

# Step 2: Drop dim_station (marts dataset)
echo "Step 2: Dropping dim_station (marts dataset)..."
bq query --use_legacy_sql=false "
DROP TABLE IF EXISTS \`nyc-citibike-data-platform.marts.dim_station\`;
"

# Step 3: Drop fct_trips (marts dataset, references dim_station)
echo "Step 3: Dropping fct_trips (marts dataset)..."
bq query --use_legacy_sql=false "
DROP TABLE IF EXISTS \`nyc-citibike-data-platform.marts.fct_trips\`;
"

# Step 4: Drop fct_station_day (marts dataset, references dim_station)
echo "Step 4: Dropping fct_station_day (marts dataset)..."
bq query --use_legacy_sql=false "
DROP TABLE IF EXISTS \`nyc-citibike-data-platform.marts.fct_station_day\`;
"

# Step 5: Rebuild in correct order
echo ""
echo "Step 5: Rebuilding models in correct order..."
echo ""

echo "  → Building staging models (staging dataset)..."
dbt run --select staging

echo "  → Building intermediate models (staging dataset)..."
dbt run --select intermediate

echo "  → Creating snapshot with numeric IDs from trips (snapshots dataset)..."
dbt snapshot

echo "  → Building dimension tables (marts dataset)..."
dbt run --select marts.dimensions

echo "  → Building fact tables (marts dataset)..."
dbt run --select marts.facts

echo "  → Building dashboard views (citibike_dashboards dataset)..."
dbt run --select dashboards

echo ""
echo "✅ Station dimension fix complete!"
echo ""
echo "Verify with this query in BigQuery:"
echo "SELECT station_id, station_name, latitude, longitude"
echo "FROM \`nyc-citibike-data-platform.marts.dim_station\`"
echo "WHERE station_id LIKE '%.%'"
echo "LIMIT 5;"