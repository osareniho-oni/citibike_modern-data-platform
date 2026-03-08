# 🚴 NYC Citibike Analytics

_powered by the dbt Fusion engine_

## Overview

This dbt project provides analytics for NYC Citibike data, combining trip data, real-time station status, and weather information to enable comprehensive analysis of bike-sharing patterns in New York City.

## Data Sources

The project integrates three primary data sources:

1. **Citibike Trips** (`citibike_trips_raw`) - Historical trip data including ride details, station information, and rider type
2. **NYC Weather** (`nyc_weather_daily`) - Daily weather observations from Open-Meteo API including temperature, precipitation, and wind data
3. **Station Status** (`station_status_streaming`) - Real-time station status from Citibike GBFS API showing bike/dock availability

## Project Structure

```
models/
├── staging/          # Cleaned and typed source data
│   ├── stg_trips.sql
│   ├── stg_weather.sql
│   └── stg_station_status.sql
├── intermediate/     # Business logic transformations
└── marts/           # Final analytics-ready models
```

## Getting Started

1. Set up your database connection in `~/.dbt/profiles.yml`
2. Install dependencies: `dbt deps`
3. Run the project: `dbt build`
4. Generate documentation: `dbt docs generate && dbt docs serve`

## Key Features

- **Data Quality Tests**: Comprehensive tests for data integrity including uniqueness, not-null constraints, and accepted values
- **Freshness Checks**: Automated monitoring of data freshness with configurable warning and error thresholds
- **Deduplication**: Automatic handling of duplicate weather records by selecting the most recent load
- **Flexible Station Data**: Handles trips without station information (e.g., street pickups/dropoffs)

## Documentation

Run `dbt docs generate` to create comprehensive documentation including:
- Data lineage graphs
- Column-level descriptions
- Test coverage
- Source freshness status

## Notes

- Weather data is deduplicated by date, keeping the most recent load
- Trip data filters out invalid trips (e.g., end time before start time)
- Station IDs can be NULL for trips without station information