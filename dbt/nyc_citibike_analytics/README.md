# 🚴 NYC Citibike Analytics

_powered by the dbt Fusion engine_

## Overview

This dbt project provides comprehensive analytics for NYC Citibike data, combining trip history, real-time station status, and weather information to enable data-driven insights into bike-sharing patterns, station operations, and demand forecasting across New York City.

## Data Sources

The project integrates three primary data sources:

1. **Citibike Trips** (`citibike_trips_raw`) - Historical trip data including ride details, station information, and rider type
   - Bike types: `classic_bike`, `electric_bike`
   - Rider types: `member`, `casual`
   
2. **NYC Weather** (`nyc_weather_daily`) - Daily weather observations from Open-Meteo API
   - Temperature in **Celsius**
   - Precipitation in **millimeters**
   - Wind speed in **km/h**
   
3. **Station Status** (`station_status_streaming`) - Real-time station status from Citibike GBFS API
   - Bike availability (regular and e-bikes)
   - Dock availability
   - Scooter availability
   - Operational status flags

## Project Structure

```
models/
├── staging/              # Cleaned and typed source data
│   ├── stg_trips.sql            # Trip data with data quality filters
│   ├── stg_weather.sql          # Weather data (deduplicated by date)
│   └── stg_station_status.sql   # Real-time station status
│
├── intermediate/         # Business logic and feature engineering
│   ├── int_station_metrics.sql          # 5-minute operational metrics
│   ├── int_station_daily_metrics.sql    # Daily aggregated supply metrics
│   ├── int_trip_station_daily.sql       # Daily trip demand by station
│   ├── int_station_weather_daily.sql    # Station metrics + weather enrichment
│   └── int_station_daily_fact.sql       # Comprehensive daily fact table (incremental)
│
└── marts/               # Final analytics-ready models (to be developed)
```

## Intermediate Layer Details

### Station Operational Metrics

**`int_station_metrics`** (5-minute grain, view)
- **Purpose**: Real-time operational KPIs
- **Key Metrics**:
  - `total_capacity`: Total docking points (bikes + docks + scooters)
  - `occupancy_ratio`: Available vehicles / total capacity
  - `utilization_percentage`: Capacity in use
  - `operational_status`: Categorized station health
  - `ebike_ratio`: E-bike availability proportion

**`int_station_daily_metrics`** (daily grain, table)
- **Purpose**: Daily aggregated supply-side metrics
- **Key Metrics**:
  - Average availability (bikes, e-bikes, docks, scooters)
  - Occupancy volatility (standard deviation)
  - `pct_time_empty`, `pct_time_full`: Operational constraints
  - `operational_health_score`: 0-100 health indicator
  - `rebalancing_need`: High/medium/low priority classification

### Trip Demand Analysis

**`int_trip_station_daily`** (daily grain, table)
- **Purpose**: Daily trip demand aggregations by station
- **Key Metrics**:
  - `trips_started`, `trips_ended`: Separate tracking per station
  - `net_trips`: Station flow balance (started - ended)
  - Trip duration statistics (avg, median, p95)
  - Rider type breakdown (member vs casual)
  - Bike type breakdown (electric vs classic)
  - Time-of-day patterns (morning/evening rush)
  - `station_flow_pattern`: net_source, net_sink, balanced, inactive

> **Why track starts and ends separately?** Trips often start at one station and end at another. This enables rebalancing analysis - stations with high `trips_started` need bike restocking, while stations with high `trips_ended` need dock availability.

### Weather Enrichment

**`int_station_weather_daily`** (daily grain, table)
- **Purpose**: Station metrics enriched with weather context
- **Key Features**:
  - `weather_condition`: Categorized conditions (clear, rain, snow, etc.)
  - `temperature_range`: Celsius-based categories (freezing <0°C, cold 0-10°C, mild 10-18°C, warm 18-27°C, hot >27°C)
  - Weather impact flags: `is_raining`, `is_snowing`, `is_freezing`, `is_windy`
  - `weather_severity_score`: 0-100 composite score
  - `is_ideal_biking_weather`: Optimal conditions flag (13-24°C, clear, light wind)
  - `is_poor_biking_weather`: Adverse conditions flag

### Comprehensive Daily Fact

**`int_station_daily_fact`** (daily grain, incremental + partitioned)
- **Purpose**: Primary fact table combining supply, demand, and weather
- **Materialization**: Incremental with date partitioning for scalability
- **Key Features**:
  - All supply metrics (capacity, occupancy, utilization)
  - All demand metrics (trips, durations, patterns)
  - All weather context (conditions, temperature, severity)
  - Derived KPIs:
    - `trips_per_bike_ratio`: Demand intensity
    - `demand_capacity_ratio`: Utilization from demand perspective
    - `supply_demand_balance_score`: -100 to 100 balance indicator
  - Time features: day_of_week, is_weekend, month, quarter
  - **7-day rolling averages**: trips, occupancy, utilization, activity
  - **28-day rolling averages**: trips, occupancy (monthly trends)
  - Trend indicators: day-over-day, week-over-week changes
  - `demand_trend`: surge, above_average, stable, below_average, decline

## Key Concepts

### Station Capacity

**What are docks?** Physical parking/locking stations where bikes are stored. Each station has multiple docking points.

**Total Capacity Calculation:**
```
Total Capacity = Bikes (available + disabled) 
               + Docks (available + disabled)
               + Scooters (available + unavailable)
```

At any moment, docking points are either:
- Occupied by a vehicle (bike/scooter)
- Empty and available for returns
- Empty but broken/disabled

### Station Flow Patterns

- **Net Source Stations**: More trips start than end (e.g., residential areas in morning)
- **Net Sink Stations**: More trips end than start (e.g., business districts in morning)
- **Balanced Stations**: Similar starts and ends
- **Inactive Stations**: No trip activity

These patterns reverse during different times of day, driving rebalancing operations.

## Getting Started

1. Set up your database connection in `~/.dbt/profiles.yml`
2. Install dependencies: `dbt deps`
3. Build staging layer: `dbt build --select staging`
4. Build intermediate layer: `dbt build --select intermediate`
5. Generate documentation: `dbt docs generate && dbt docs serve`

## Key Features

- **Comprehensive Data Quality**: Tests for uniqueness, not-null constraints, accepted values, and grain validation
- **Freshness Monitoring**: Automated checks with configurable thresholds
- **Incremental Processing**: Efficient daily fact table with date partitioning
- **Weather Integration**: Celsius-based thresholds calibrated for NYC climate
- **Operational Insights**: Health scores, rebalancing priorities, and demand trends
- **Flexible Architecture**: Handles NULL station IDs (street pickups/dropoffs)

## Data Quality Notes

- **Weather data**: Deduplicated by date, keeping most recent load (Celsius units)
- **Trip data**: Filters invalid trips (end time before start time)
- **Station IDs**: Can be NULL for trips without station information
- **Bike types**: Only `classic_bike` and `electric_bike` (no docked_bike in current data)
- **Scooters**: Included in all capacity calculations and availability metrics

## Temperature Units

All temperature values are in **Celsius (°C)**:
- Freezing: < 0°C
- Cold: 0-10°C
- Mild: 10-18°C
- Warm: 18-27°C
- Hot: > 27°C

## Documentation

Run `dbt docs generate` to create comprehensive documentation including:
- Data lineage graphs showing model dependencies
- Column-level descriptions with business context
- Test coverage and results
- Source freshness status
- Model performance metrics

## Next Steps

- **Marts Layer**: Build dimensional models for specific analytics use cases
- **Dashboards**: Connect to BI tools for operational monitoring
- **ML Features**: Use rolling averages and trends for demand forecasting
- **Alerts**: Set up monitoring for operational health scores and rebalancing needs