{% docs __overview__ %}

# NYC Citibike Analytics

## Project Overview

This dbt project provides a comprehensive analytics framework for NYC Citibike data, integrating trip history, real-time station status, and weather information to enable data-driven insights into bike-sharing patterns across New York City.

## Data Architecture

### Staging Layer
The staging layer (`models/staging/`) contains cleaned and typed versions of raw data sources:

- **stg_trips**: Citibike trip data with ride details, station information, and rider classification
- **stg_weather**: Daily weather observations including temperature, precipitation, and wind metrics
- **stg_station_status**: Real-time station status showing bike and dock availability

### Intermediate Layer
The intermediate layer (`models/intermediate/`) contains business logic transformations and enrichments (to be developed).

### Marts Layer
The marts layer (`models/marts/`) contains final analytics-ready models optimized for reporting and analysis (to be developed).

## Data Sources

### Citibike Trips
Historical trip data from NYC Citibike's public dataset, including:
- Unique ride identifiers
- Bike type (classic or electric)
- Trip timestamps and duration
- Start/end station information
- Geographic coordinates
- Rider type (member or casual)

**Note**: Some trips may not have station information (NULL station_id) as they represent street pickups or dropoffs outside of docking stations.

### NYC Weather
Daily weather data from the Open-Meteo API for New York City:
- Temperature metrics (max, min, mean)
- Precipitation and snowfall amounts
- Wind speed and gusts
- Weather condition codes

**Data Quality**: Weather data is automatically deduplicated by date, keeping the most recent load to handle any reprocessing scenarios.

### Station Status
Real-time station status from Citibike's GBFS (General Bikeshare Feed Specification) API:
- Bike availability (regular and electric)
- Dock availability
- Scooter availability
- Station operational status
- Last reported timestamps

## Data Quality

The project implements comprehensive data quality checks:

- **Uniqueness**: Primary keys are tested for uniqueness (ride_id, weather_date)
- **Not Null**: Critical fields are validated for completeness
- **Accepted Values**: Categorical fields are validated against expected values
- **Freshness**: Source data freshness is monitored with configurable thresholds

## Getting Started

1. **Setup**: Configure your database connection in `~/.dbt/profiles.yml`
2. **Install**: Run `dbt deps` to install package dependencies
3. **Build**: Run `dbt build` to execute all models and tests
4. **Document**: Run `dbt docs generate && dbt docs serve` to view this documentation

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [NYC Citibike System Data](https://citibikenyc.com/system-data)
- [Open-Meteo Weather API](https://open-meteo.com/)
- [GBFS Specification](https://github.com/MobilityData/gbfs)

{% enddocs %}