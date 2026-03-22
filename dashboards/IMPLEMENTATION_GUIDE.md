# NYC Citibike Analytics - Dashboard Implementation Guide

## Overview

This guide provides step-by-step instructions for building three professional dashboards in Looker Studio using the pre-built dbt views.

**Estimated Time**: 45-60 minutes total (15-20 minutes per dashboard)

---

## Prerequisites

✅ dbt models built and deployed to BigQuery
✅ Access to Looker Studio (formerly Google Data Studio)
✅ BigQuery connection configured in Looker Studio

---

## Dashboard Architecture

### Available Views

| View Name | Purpose | Data Source | Date Range |
|-----------|---------|-------------|------------|
| `vw_trip_analytics_daily` | Hourly/daily trip patterns | Trip data | Last 90 days |
| `vw_trip_analytics_routes` | Popular routes & station pairs | Trip data | Last 30 days |
| `vw_weather_impact` | Weather effects on ridership | Trip + Weather data | Last 90 days |

### ⚠️ Important Note

**Do NOT use** `vw_station_operations` - this view requires overlapping trip and station status data, which are not available due to different ingestion schedules (monthly historical vs real-time streaming).

---

## Dashboard 1: Trip Analytics - Daily Patterns

### Purpose
Analyze hourly and daily trip patterns, user types, and bike preferences.

### Data Source Setup

1. **Open Looker Studio**: https://lookerstudio.google.com
2. **Create New Report**: Click "Create" → "Report"
3. **Add Data Source**:
   - Select "BigQuery"
   - Choose your project: `nyc-citibike-data-platform`
   - Dataset: `citibike_dashboards`
   - Table: `vw_trip_analytics_daily`
   - Click "Add"

### Page Layout

**Page Name**: "Trip Analytics - Daily Patterns"

**Dimensions**: 1200px x 900px (standard)

---

### Charts to Build

#### 1. Scorecard Row (Top of Page)

**Chart 1.1: Total Trips**
- Chart Type: Scorecard
- Metric: `trip_count` (SUM)
- Style: Large number, blue color
- Position: Top left

**Chart 1.2: Average Duration**
- Chart Type: Scorecard
- Metric: `avg_trip_duration` (AVG)
- Style: Large number, green color
- Suffix: " min"
- Position: Top center-left

**Chart 1.3: Member Percentage**
- Chart Type: Scorecard
- Metric: `member_pct` (AVG)
- Style: Large number, orange color
- Suffix: "%"
- Position: Top center-right

**Chart 1.4: Electric Bike Usage**
- Chart Type: Scorecard
- Metric: `electric_bike_pct` (AVG)
- Style: Large number, purple color
- Suffix: "%"
- Position: Top right

---

#### 2. Time Series Chart

**Chart 2: Trips by Hour of Day**
- Chart Type: Time series (line chart)
- Date Range Dimension: `date_day`
- Dimension: `hour_of_day`
- Metric: `trip_count` (SUM)
- Breakdown Dimension: `user_type_name`
- Style:
  - Line thickness: 2
  - Show data labels: No
  - Show legend: Yes (bottom)
- Position: Below scorecards, full width

---

#### 3. Bar Charts Row

**Chart 3.1: Trips by User Type**
- Chart Type: Bar chart (horizontal)
- Dimension: `user_type_name`
- Metric: `trip_count` (SUM)
- Sort: Descending by trip_count
- Style: Different color per user type
- Position: Middle left

**Chart 3.2: Trips by Bike Type**
- Chart Type: Pie chart
- Dimension: `rideable_type`
- Metric: `trip_count` (SUM)
- Style: Show percentages
- Position: Middle center

**Chart 3.3: Trips by Time of Day**
- Chart Type: Bar chart (vertical)
- Dimension: `time_of_day_name`
- Metric: `trip_count` (SUM)
- Sort: By time order (morning, afternoon, evening, night)
- Position: Middle right

---

#### 4. Detailed Table

**Chart 4: Hourly Breakdown Table**
- Chart Type: Table
- Dimensions:
  - `date_day`
  - `hour_of_day`
  - `time_of_day_name`
  - `user_type_name`
  - `rideable_type`
- Metrics:
  - `trip_count` (SUM)
  - `avg_trip_duration` (AVG)
  - `member_pct` (AVG)
  - `electric_bike_pct` (AVG)
- Sort: `date_day` DESC, `hour_of_day` ASC
- Rows per page: 20
- Position: Bottom, full width

---

### Filters to Add

1. **Date Range Filter**
   - Control Type: Date range
   - Default: Last 30 days
   - Position: Top right corner

2. **User Type Filter**
   - Control Type: Drop-down list
   - Dimension: `user_type_name`
   - Default: All
   - Position: Below date range

3. **Weekend Filter**
   - Control Type: Drop-down list
   - Dimension: `is_weekend`
   - Options: All, Weekday, Weekend
   - Position: Below user type

---

## Dashboard 2: Trip Analytics - Popular Routes

### Purpose
Identify most popular routes, busiest stations, and route patterns.

### Data Source Setup

1. **Create New Page** in same report OR **Create New Report**
2. **Add Data Source**:
   - BigQuery → `nyc-citibike-data-platform.citibike_dashboards.vw_trip_analytics_routes`

### Page Layout

**Page Name**: "Popular Routes & Stations"

---

### Charts to Build

#### 1. Scorecard Row

**Chart 1.1: Total Routes**
- Chart Type: Scorecard
- Metric: `trip_count` (COUNT DISTINCT of route combinations)
- Position: Top left

**Chart 1.2: Average Trips per Route**
- Chart Type: Scorecard
- Metric: `trip_count` (AVG)
- Position: Top center

**Chart 1.3: Most Popular Route**
- Chart Type: Scorecard with comparison
- Dimension: `start_station_name` + " → " + `end_station_name`
- Metric: `trip_count` (MAX)
- Position: Top right

---

#### 2. Top Routes Table

**Chart 2: Top 20 Routes**
- Chart Type: Table with bars
- Dimensions:
  - `start_station_name`
  - `end_station_name`
  - `route_popularity_category`
- Metrics:
  - `trip_count` (SUM)
  - `avg_duration_minutes` (AVG)
  - `member_pct` (AVG)
  - `electric_pct` (AVG)
- Sort: `trip_count` DESC
- Rows per page: 20
- Style: Add bar chart to trip_count column
- Position: Top section, full width

---

#### 3. Station Analysis Row

**Chart 3.1: Top Start Stations**
- Chart Type: Bar chart (horizontal)
- Dimension: `start_station_name`
- Metric: `trip_count` (SUM)
- Sort: Descending
- Rows: Top 15
- Position: Middle left

**Chart 3.2: Top End Stations**
- Chart Type: Bar chart (horizontal)
- Dimension: `end_station_name`
- Metric: `trip_count` (SUM)
- Sort: Descending
- Rows: Top 15
- Position: Middle right

---

#### 4. Geographic Visualization

**Chart 4.1: Start Station Map**
- Chart Type: Geo chart (bubble map)
- Location: `start_latitude`, `start_longitude`
- Size Metric: `trip_count` (SUM)
- Color Metric: `avg_duration_minutes` (AVG)
- Style:
  - Bubble size: Medium
  - Color scale: Green (short) to Red (long)
- Position: Bottom left

**Chart 4.2: End Station Map**
- Chart Type: Geo chart (bubble map)
- Location: `end_latitude`, `end_longitude`
- Size Metric: `trip_count` (SUM)
- Color Metric: `avg_duration_minutes` (AVG)
- Style: Same as start station map
- Position: Bottom right

---

### Filters to Add

1. **Route Popularity Filter**
   - Control Type: Drop-down list
   - Dimension: `route_popularity_category`
   - Default: All
   - Position: Top right

2. **User Type Filter**
   - Control Type: Drop-down list
   - Dimension: `user_type_name`
   - Position: Below popularity filter

3. **Minimum Trips Filter**
   - Control Type: Slider
   - Metric: `trip_count`
   - Range: 1 to 1000
   - Default: 10
   - Position: Below user type

---

## Dashboard 3: Weather Impact Analysis

### Purpose
Analyze how weather conditions affect ridership patterns.

### Data Source Setup

1. **Create New Page** in same report OR **Create New Report**
2. **Add Data Source**:
   - BigQuery → `nyc-citibike-data-platform.citibike_dashboards.vw_weather_impact`

### Page Layout

**Page Name**: "Weather Impact on Ridership"

---

### Charts to Build

#### 1. Scorecard Row

**Chart 1.1: Average Daily Trips**
- Chart Type: Scorecard
- Metric: `total_trips_started` (AVG)
- Position: Top left

**Chart 1.2: Ideal Weather Days**
- Chart Type: Scorecard
- Metric: `is_ideal_biking_weather` (SUM)
- Suffix: " days"
- Position: Top center-left

**Chart 1.3: Poor Weather Days**
- Chart Type: Scorecard
- Metric: `is_poor_biking_weather` (SUM)
- Suffix: " days"
- Position: Top center-right

**Chart 1.4: Average Temperature**
- Chart Type: Scorecard
- Metric: `temperature_celsius` (AVG)
- Suffix: "°C"
- Position: Top right

---

#### 2. Weather vs Trips Analysis

**Chart 2.1: Temperature vs Trips**
- Chart Type: Scatter plot
- X-axis: `temperature_celsius`
- Y-axis: `total_trips_started`
- Size: `stations_reporting`
- Color: `weather_category`
- Style:
  - Show trend line: Yes
  - Point size: Medium
- Position: Upper middle, left side

**Chart 2.2: Precipitation vs Trips**
- Chart Type: Scatter plot
- X-axis: `precipitation_mm`
- Y-axis: `total_trips_started`
- Color: `precipitation_category`
- Style: Show trend line
- Position: Upper middle, right side

---

#### 3. Weather Condition Analysis

**Chart 3.1: Trips by Weather Condition**
- Chart Type: Bar chart (horizontal)
- Dimension: `weather_condition`
- Metric: `total_trips_started` (AVG)
- Sort: Descending
- Style: Color by weather severity
- Position: Middle left

**Chart 3.2: Trips by Temperature Category**
- Chart Type: Column chart
- Dimension: `temperature_category`
- Metric: `total_trips_started` (AVG)
- Sort: By temperature order (Freezing → Hot)
- Style: Color gradient (blue to red)
- Position: Middle center

**Chart 3.3: Weather Category Distribution**
- Chart Type: Pie chart
- Dimension: `weather_category`
- Metric: `date_day` (COUNT)
- Style: Show percentages
- Position: Middle right

---

#### 4. Time Series with Weather

**Chart 4: Daily Trips with Weather Overlay**
- Chart Type: Combo chart (line + bars)
- Date Dimension: `date_day`
- Left Y-axis (Line): `total_trips_started`
- Right Y-axis (Bars): `temperature_celsius`
- Color: Different colors for trips vs temperature
- Style:
  - Line thickness: 2
  - Bar opacity: 50%
  - Show dual axis: Yes
- Position: Bottom, full width

---

#### 5. Detailed Weather Table

**Chart 5: Daily Weather & Trips**
- Chart Type: Table
- Dimensions:
  - `date_day`
  - `day_name`
  - `weather_condition`
  - `temperature_category`
  - `precipitation_category`
- Metrics:
  - `total_trips_started` (SUM)
  - `temperature_celsius` (AVG)
  - `precipitation_mm` (SUM)
  - `wind_speed_kmh` (MAX)
  - `avg_trip_duration` (AVG)
- Sort: `date_day` DESC
- Rows per page: 20
- Style: Conditional formatting on trip volume
- Position: Very bottom, full width

---

### Filters to Add

1. **Date Range Filter**
   - Control Type: Date range
   - Default: Last 60 days
   - Position: Top right

2. **Weather Category Filter**
   - Control Type: Drop-down list
   - Dimension: `weather_category`
   - Options: All, Ideal Weather, Normal Weather, Poor Weather
   - Position: Below date range

3. **Temperature Range Filter**
   - Control Type: Slider
   - Metric: `temperature_celsius`
   - Range: -10 to 40
   - Position: Below weather category

4. **Weekend Filter**
   - Control Type: Checkbox
   - Dimension: `is_weekend`
   - Position: Below temperature

---

## Styling Guidelines

### Color Palette

Use consistent colors across all dashboards:

- **Primary**: `#1E88E5` (Blue) - Main metrics
- **Secondary**: `#43A047` (Green) - Positive indicators
- **Accent**: `#FB8C00` (Orange) - Highlights
- **Warning**: `#E53935` (Red) - Alerts/issues
- **Member**: `#5E35B1` (Purple) - Member-related
- **Casual**: `#00ACC1` (Cyan) - Casual rider-related

### Typography

- **Title**: Roboto, 24px, Bold
- **Subtitle**: Roboto, 18px, Medium
- **Body**: Roboto, 14px, Regular
- **Metrics**: Roboto, 32px, Bold

### Layout

- **Margins**: 20px on all sides
- **Spacing**: 15px between charts
- **Alignment**: Left-align text, center-align numbers
- **Grid**: Use 12-column grid for consistency

---

## Testing Checklist

Before finalizing each dashboard:

- [ ] All charts load without errors
- [ ] Filters work correctly and affect all relevant charts
- [ ] Date ranges are appropriate for the data available
- [ ] Numbers make sense (no negative trips, reasonable durations)
- [ ] Colors are consistent and accessible
- [ ] Mobile view is readable
- [ ] Dashboard loads in under 5 seconds
- [ ] All tooltips show relevant information
- [ ] Export to PDF works correctly

---

## Sharing & Permissions

### Make Dashboard Public

1. Click "Share" button (top right)
2. Change "Restricted" to "Anyone with the link"
3. Set permission to "Viewer"
4. Copy link for submission

### Embed in Website (Optional)

1. Click "File" → "Embed report"
2. Copy embed code
3. Adjust width/height as needed
4. Paste into your website/documentation

---

## Troubleshooting

### Common Issues

**Issue**: "No data available"
- **Solution**: Check date range filter - your trip data may only go through March 1st, 2026

**Issue**: Charts load slowly
- **Solution**: Reduce date range or add more filters to limit data

**Issue**: Station names show as "Unknown Station"
- **Solution**: This is expected for `vw_station_operations` - use the trip analytics views instead

**Issue**: Metrics show NULL
- **Solution**: Some dates may not have all data types (e.g., no weather data for recent dates)

---

## Performance Optimization

### For Large Datasets

1. **Use Date Range Filters**: Limit to 30-90 days
2. **Add Aggregation**: Use SUM/AVG instead of showing all rows
3. **Limit Table Rows**: Show top 20-50 rows only
4. **Cache Data**: Enable data caching in Looker Studio settings
5. **Materialize Views**: Consider converting views to tables in BigQuery

---

## Next Steps

After building all three dashboards:

1. **Review & Refine**: Check all metrics and visualizations
2. **Add Insights**: Include text boxes with key findings
3. **Create Summary Page**: Add an overview page with highlights from all three dashboards
4. **Document Limitations**: Note the data date ranges and any known issues
5. **Share**: Generate public link for your Zoomcamp submission

---

## Support

For issues or questions:
- Check dbt documentation: https://docs.getdbt.com
- Looker Studio help: https://support.google.com/looker-studio
- BigQuery docs: https://cloud.google.com/bigquery/docs

---

**Happy Dashboard Building!** 🎉📊