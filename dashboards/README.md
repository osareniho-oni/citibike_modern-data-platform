# NYC Citibike Analytics Dashboards

## 📊 Live Dashboards

View real-time analytics dashboards powered by Looker Studio:

- [🚲 Station Operations Dashboard](https://lookerstudio.google.com/reporting/YOUR-STATION-OPS-ID) - Real-time station availability and utilization
- [📈 Trip Analytics Dashboard](https://lookerstudio.google.com/reporting/YOUR-TRIP-ANALYTICS-ID) - Trip patterns and demand analysis
- [🌦 Weather Impact Dashboard](https://lookerstudio.google.com/reporting/YOUR-WEATHER-IMPACT-ID) - Weather correlation with ridership

*Dashboards update automatically as new data flows through the Pub/Sub → BigQuery pipeline*

---

## Dashboard Descriptions

### 🚲 Station Operations Dashboard
**Purpose**: Real-time monitoring of station availability and operational health

**Data Sources**:
- `fct_station_day` - Daily station metrics
- `dim_station` - Station attributes
- `dim_date` - Date dimension

**Key Metrics**:
- Current bike availability by station
- Station utilization rates
- Rebalancing priority indicators
- Geographic distribution map
- Time-series trends

**Refresh Rate**: Auto-updates every 5 minutes (matches Kestra schedule)

---

### 📈 Trip Analytics Dashboard
**Purpose**: Analyze trip patterns, demand trends, and user behavior

**Data Sources**:
- `fct_trips` - Trip-level transactions
- `dim_station` - Station details
- `dim_date` - Date dimension
- `dim_time` - Time of day dimension
- `dim_user_type` - Member vs casual riders

**Key Metrics**:
- Daily/weekly/monthly trip volume
- Average trip duration
- Popular routes (start → end station pairs)
- User type breakdown (member vs casual)
- Bike type usage (classic vs electric)
- Peak hour analysis

**Refresh Rate**: Daily (after trip data ingestion)

---

### 🌦 Weather Impact Dashboard
**Purpose**: Understand how weather conditions affect ridership

**Data Sources**:
- `fct_station_day` - Includes weather-enriched metrics
- `dim_date` - Date dimension

**Key Metrics**:
- Trips vs temperature correlation
- Ridership during rain/snow
- Seasonal patterns
- Weather severity impact
- Ideal biking conditions analysis

**Refresh Rate**: Daily (after weather data ingestion)

---

## 🎨 Dashboard Screenshots

Screenshots are stored in `looker-studio/screenshots/` for documentation purposes.

---

## 🔗 Access & Sharing

### Public Access
All dashboards are configured with "Anyone with the link" access for portfolio demonstration.

### Embed Codes
For embedding dashboards in websites or presentations, see `looker-studio/embed-codes.md`

---

## 📝 SQL Queries

The SQL queries used to power each dashboard are documented in the `queries/` folder:
- `station_operations.sql` - Station operations dashboard queries
- `trip_analytics.sql` - Trip analytics dashboard queries
- `weather_impact.sql` - Weather impact dashboard queries

These queries can be used to:
- Recreate dashboards
- Test data quality
- Build custom reports
- Understand dashboard logic

---

## 🚀 Creating New Dashboards

1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Create new report
3. Add data source → BigQuery → `citibike_data` dataset
4. Select mart tables (`fct_*` and `dim_*`)
5. Build visualizations
6. Share dashboard and update links in this README

---

## 📚 Additional Resources

- [Looker Studio Documentation](https://support.google.com/looker-studio)
- [BigQuery Connector Guide](https://support.google.com/looker-studio/answer/6370296)
- [Dashboard Best Practices](https://support.google.com/looker-studio/answer/7450249)

---

*Last Updated: 2026-03-11*