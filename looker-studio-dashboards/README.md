# NYC Citibike Analytics Dashboards

## 📊 Live Dashboards

View the complete analytics platform powered by Looker Studio and BigQuery:

**📄 [Complete Dashboard PDF](NYC_Citibike_Analytics_Platform.pdf)** - All four dashboards in one document

### Individual Dashboard Screenshots

1. **🚲 Station Operations Dashboard**
   - ![Station Operations](Station%20Operations%20Dashborad.png)
   - Real-time station availability and operational health monitoring
   - Data Source: `vw_station_operations_realtime`

2. **📈 Daily Trip Analytics Dashboard**
   - ![Daily Trip Analytics](Daily%20Trip%20Analytics%20Dashboard.png)
   - Hourly and daily trip patterns, user types, and bike preferences
   - Data Source: `vw_trip_analytics_daily`

3. **🗺️ Popular Routes & Stations Dashboard**
   - ![Popular Routes](Popular%20Routes%20and%20Stations%20Dashboard.png)
   - Most popular routes, busiest stations, and route patterns
   - Data Source: `vw_trip_analytics_routes`

4. **🌦️ Weather Impact on Ridership Dashboard**
   - ![Weather Impact](Weather%20impact%20on%20ridership%20Dashboard.png)
   - Weather correlation with ridership patterns and demand analysis
   - Data Source: `vw_weather_impact`

---

## 🎯 Dashboard Overview

### Dashboard 1: Station Operations
**Purpose**: Real-time monitoring of station availability and operational health

**Key Metrics**:
- Current bike availability by station
- Station utilization rates
- Rebalancing priority indicators
- Geographic distribution map
- Time-series trends

**Refresh Rate**: Auto-updates every 5 minutes (matches Kestra schedule)

---

### Dashboard 2: Daily Trip Analytics
**Purpose**: Analyze hourly and daily trip patterns, user types, and bike preferences

**Key Metrics**:
- Total trips and average duration
- Member vs casual rider breakdown
- Electric vs classic bike usage
- Hourly trip patterns
- Time of day analysis (morning, afternoon, evening, night)

**Refresh Rate**: Daily (after trip data ingestion)

---

### Dashboard 3: Popular Routes & Stations
**Purpose**: Identify most popular routes, busiest stations, and route patterns

**Key Metrics**:
- Top 20 routes by trip count
- Most popular start and end stations
- Route popularity categories
- Geographic visualization of station activity
- Average trip duration by route

**Refresh Rate**: Daily (last 30 days rolling window)

---

### Dashboard 4: Weather Impact Analysis
**Purpose**: Understand how weather conditions affect ridership patterns

**Key Metrics**:
- Temperature vs trips correlation
- Precipitation impact on ridership
- Weather condition breakdown
- Ideal vs poor biking weather days
- Daily trends with weather overlay

**Refresh Rate**: Daily (after weather data ingestion)

---

## 🏗️ Technical Architecture

### Data Sources
All dashboards connect to BigQuery views in the `citibike_dashboards` dataset:

| Dashboard | View | Data Range | Grain |
|-----------|------|------------|-------|
| Station Operations | `vw_station_operations_realtime` | Real-time | 5-minute intervals |
| Daily Trip Analytics | `vw_trip_analytics_daily` | Last 90 days | Hourly |
| Popular Routes | `vw_trip_analytics_routes` | Last 30 days | Route-level |
| Weather Impact | `vw_weather_impact` | Last 90 days | Daily |

### Data Pipeline
```
Raw Data (BigQuery)
    ↓
dbt Transformations
    ↓
Dashboard Views (citibike_dashboards)
    ↓
Looker Studio Dashboards
```

---

## 📝 Implementation Guide

For detailed instructions on building these dashboards, see:
- **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Step-by-step dashboard creation guide

---

## 🎨 Design Principles

### Color Palette
- **Primary**: Blue (#1E88E5) - Main metrics
- **Secondary**: Green (#43A047) - Positive indicators
- **Accent**: Orange (#FB8C00) - Highlights
- **Warning**: Red (#E53935) - Alerts/issues
- **Member**: Purple (#5E35B1) - Member-related
- **Casual**: Cyan (#00ACC1) - Casual rider-related

### Layout Standards
- **Scorecards**: Top row for key metrics
- **Time Series**: Full-width charts for trends
- **Comparisons**: Side-by-side bar charts
- **Details**: Bottom tables with drill-down capability

---

## 📊 Key Insights from Dashboards

### Operational Insights
- Real-time station availability enables proactive rebalancing
- Peak hours identified for resource allocation
- Geographic hotspots for expansion planning

### User Behavior Patterns
- Member vs casual rider preferences differ significantly
- Electric bikes show higher usage during peak hours
- Weekend patterns differ from weekday commuting

### Weather Impact
- Temperature has strong correlation with ridership
- Precipitation significantly reduces trip volume
- Ideal biking weather (15-25°C, no rain) shows 40% higher ridership

---

## 🚀 Future Enhancements

- [ ] Add real-time alerts for low station availability
- [ ] Implement predictive analytics for demand forecasting
- [ ] Create mobile-optimized dashboard views
- [ ] Add year-over-year comparison metrics
- [ ] Integrate ML-based anomaly detection

---

## 📚 Additional Resources

- [Looker Studio Documentation](https://support.google.com/looker-studio)
- [BigQuery Connector Guide](https://support.google.com/looker-studio/answer/6370296)
- [Dashboard Best Practices](https://support.google.com/looker-studio/answer/7450249)
- [dbt Documentation](https://docs.getdbt.com)

---

*Last Updated: 2026-03-22*
*Dashboards created for Data Engineering Zoomcamp Final Project*