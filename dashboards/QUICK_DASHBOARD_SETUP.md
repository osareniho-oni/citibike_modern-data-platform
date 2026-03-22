# NYC Citibike Analytics - Complete Dashboard Setup Guide

## 🚀 Build Your Dashboard from Scratch (30 minutes)

This guide walks you through creating a professional 3-page Looker Studio dashboard for your NYC Citibike Analytics project.

---

## 📋 Prerequisites

Before starting:
- ✅ dbt models deployed (`dbt run --select dashboards`)
- ✅ Data in BigQuery (`citibike_dashboards` dataset)
- ✅ Google account with BigQuery access

---

## 🎯 Step 1: Create New Dashboard (2 minutes)

1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Click **"Create"** → **"Report"**
3. Click **"Blank Report"**
4. When prompted for data source:
   - Select **"BigQuery"**
   - Navigate to: `nyc-citibike-data-platform` → `citibike_dashboards` → `vw_station_operations`
   - Click **"Add"**
5. Title your report: **"NYC Citibike Analytics Dashboard"**

---

## 📊 Page 1: Station Operations (10 minutes)

### Step 1.1: Add Page Title
1. Click **"Text"** tool
2. Type: **"STATION OPERATIONS COMMAND"**
3. Format: 24px, Bold, Center-aligned

### Step 1.2: Top Row - Key Metrics (3 Scorecards)

**Scorecard 1: Total Active Stations**
1. Click **"Add a chart"** → **"Scorecard"**
2. Place in top-left
3. **Metric**: `COUNT(DISTINCT station_id)`
4. **Label**: "Total Active Stations"
5. **Style**: Large number, blue color

**Scorecard 2: Stations Needing Rebalancing**
1. Add another **Scorecard**
2. Place in top-center
3. **Metric**: `COUNT(station_id)`
4. **Filter**: Add filter → `rebalancing_need` = "high"
5. **Label**: "Stations Needing Rebalancing"
6. **Style**: Large number, orange color

**Scorecard 3: Average Bikes Available**
1. Add another **Scorecard**
2. Place in top-right
3. **Metric**: `AVG(avg_bikes_available)`
4. **Label**: "Average Bikes Available"
5. **Style**: Large number, green color

### Step 1.3: Left Column - Bar Chart

**Top 10 Busiest Stations**
1. Click **"Add a chart"** → **"Bar chart"** (horizontal)
2. Place in left column
3. **Dimension**: `station_name`
4. **Metric**: `SUM(trips_started)`
5. **Sort**: By metric, Descending
6. **Rows to show**: 10
7. **Title**: "Top 10 Busiest Stations"
8. **Style**: Blue bars

### Step 1.4: Center - Map

**Station Map**
1. Click **"Add a chart"** → **"Geo chart"** → **"Bubble map"**
2. Place in center (large)
3. **Location**: 
   - Add field → `latitude`
   - Add field → `longitude`
4. **Size**: `SUM(trips_started)`
5. **Color**: `AVG(operational_health_score)`
   - Color scale: Red (0) → Yellow (50) → Green (100)
6. **Tooltip**: Add `station_name`, `avg_bikes_available`
7. **Map settings**:
   - Default zoom: 11
   - Default center: Latitude 40.7589, Longitude -73.9851
8. **Title**: "Station Activity Map"

### Step 1.5: Right Column - Line Chart

**7-Day Availability Trend**
1. Click **"Add a chart"** → **"Time series chart"**
2. Place in right column
3. **Date dimension**: `date_day`
4. **Metric**: `AVG(avg_bikes_available)`
5. **Date range**: Last 7 days
6. **Title**: "7-Day Availability Trend"
7. **Style**: Blue line, smooth curve

### Step 1.6: Bottom Left - Gauge Chart

**System Utilization**
1. Click **"Add a chart"** → **"Gauge chart"**
2. Place in bottom-left
3. **Metric**: `AVG(avg_utilization_pct)`
4. **Range**: 0 to 100
5. **Color zones**:
   - 0-40: Green
   - 40-70: Yellow
   - 70-100: Red
6. **Title**: "System Utilization"

### Step 1.7: Bottom Right - Table

**Stations Requiring Attention**
1. Click **"Add a chart"** → **"Table"**
2. Place in bottom-right
3. **Columns**:
   - `station_name`
   - `avg_bikes_available`
   - `operational_health_score`
   - `priority_indicator`
4. **Filter**: `rebalancing_need` IN ("high", "medium")
5. **Sort**: `operational_health_score` Ascending
6. **Rows**: 10
7. **Title**: "Stations Requiring Attention"

### Step 1.8: Add Date Filter
1. Click **"Add a control"** → **"Date range control"**
2. Place at top of page
3. **Default range**: Last 30 days
4. **Label**: "Select date range"

---

## 📊 Page 2: Trip Analytics (10 minutes)

### Step 2.1: Add New Page
1. Click **"Page"** → **"New page"**
2. Rename to: **"Trip Analytics"**

### Step 2.2: Change Data Source
1. Click **"Resource"** → **"Manage added data sources"**
2. Click **"Add a data source"**
3. Select **BigQuery** → `citibike_dashboards` → `vw_trip_analytics_daily`
4. Click **"Add"**

### Step 2.3: Add Page Title
1. Add **Text**: **"TRIP ANALYTICS"**
2. Format: 24px, Bold, Center

### Step 2.4: Top Row - Key Metrics (3 Scorecards)

**Scorecard 1: Total Trips**
1. Add **Scorecard**
2. **Data source**: `vw_trip_analytics_daily`
3. **Metric**: `SUM(trip_count)`
4. **Label**: "Total Trips"

**Scorecard 2: Average Trip Duration**
1. Add **Scorecard**
2. **Metric**: `AVG(avg_trip_duration)`
3. **Label**: "Avg Duration (min)"

**Scorecard 3: Member Percentage**
1. Add **Scorecard**
2. **Metric**: `AVG(member_pct)`
3. **Label**: "Member %"
4. **Format**: Percentage

### Step 2.5: Main Charts

**Daily Trip Volume (Line Chart)**
1. Add **Time series chart**
2. **Date**: `date_day`
3. **Metric**: `SUM(trip_count)`
4. **Breakdown dimension**: `user_type_name` (stacked)
5. **Date range**: Last 90 days
6. **Title**: "Daily Trip Volume"

**Trips by Hour (Bar Chart)**
1. Add **Bar chart** (vertical)
2. **Dimension**: `hour_of_day`
3. **Metric**: `SUM(trip_count)`
4. **Sort**: By dimension, Ascending
5. **Title**: "Trips by Hour of Day"

**Member vs Casual (Pie Chart)**
1. Add **Pie chart**
2. **Dimension**: `user_type_name`
3. **Metric**: `SUM(trip_count)`
4. **Title**: "Member vs Casual Riders"
5. **Style**: Donut chart

**Top Stations (Table)**
1. Add **Table**
2. **Columns**: `station_name`, `trip_count`, `avg_trip_duration`, `member_pct`
3. **Sort**: `trip_count` DESC
4. **Rows**: 20
5. **Title**: "Top Stations by Trip Volume"

### Step 2.6: Add Filters
1. **Date range control** (Last 30 days)
2. **User type filter** (Member/Casual dropdown)

---

## 📊 Page 3: Weather Impact (8 minutes)

### Step 3.1: Add New Page
1. Click **"Page"** → **"New page"**
2. Rename to: **"Weather Impact"**

### Step 3.2: Add Data Source
1. Add data source: `citibike_dashboards` → `vw_weather_impact`

### Step 3.3: Add Page Title
1. Add **Text**: **"WEATHER IMPACT ANALYSIS"**
2. Format: 24px, Bold, Center

### Step 3.4: Top Row - Key Metrics (3 Scorecards)

**Scorecard 1: Total Days**
1. Add **Scorecard**
2. **Metric**: `COUNT(DISTINCT date_day)`
3. **Label**: "Total Days Analyzed"

**Scorecard 2: Average Temperature**
1. Add **Scorecard**
2. **Metric**: `AVG(temperature_celsius)`
3. **Label**: "Avg Temperature (°C)"

**Scorecard 3: Average Daily Trips**
1. Add **Scorecard**
2. **Metric**: `AVG(total_trips_started)`
3. **Label**: "Avg Daily Trips"

### Step 3.5: Main Charts

**Temperature vs Trips (Scatter Plot)**
1. Add **Scatter chart**
2. **X-axis**: `temperature_celsius`
3. **Y-axis**: `total_trips_started`
4. **Size**: `avg_trip_duration`
5. **Color**: `weather_category`
6. **Trend line**: Enabled
7. **Title**: "Temperature vs Trip Volume"

**Trips by Weather (Bar Chart)**
1. Add **Bar chart** (horizontal)
2. **Dimension**: `weather_condition`
3. **Metric**: `SUM(total_trips_started)`
4. **Sort**: Descending
5. **Title**: "Trips by Weather Condition"

**Temperature & Trips Over Time (Combo Chart)**
1. Add **Combo chart**
2. **Date**: `date_day`
3. **Left axis (bars)**: `SUM(total_trips_started)`
4. **Right axis (line)**: `AVG(temperature_celsius)`
5. **Date range**: Last 90 days
6. **Title**: "Temperature & Trips Over Time"

**Weather Summary (Table)**
1. Add **Table**
2. **Columns**: 
   - `weather_category`
   - `COUNT(date_day)` (as "Days")
   - `AVG(total_trips_started)` (as "Avg Trips")
   - `AVG(temperature_celsius)` (as "Avg Temp")
3. **Sort**: By Avg Trips DESC
4. **Title**: "Weather Condition Summary"

### Step 3.6: Add Filters
1. **Date range control** (Last 90 days)
2. **Weather category filter** (dropdown)

---

## 🎨 Design & Styling (All Pages)

### Color Scheme
Apply these colors consistently:
- **Primary**: #0066CC (Citibike Blue)
- **Success**: #00A86B (Green)
- **Warning**: #FFA500 (Orange)
- **Alert**: #DC143C (Red)
- **Background**: #F5F5F5 (Light Gray)

### Typography
- **Page titles**: 24px, Bold, #333333
- **Chart titles**: 16px, Medium, #666666
- **Metrics**: 32px, Bold, Primary color
- **Labels**: 12px, Regular, #999999

### Layout Tips
- Use **grid layout** for alignment
- **16px padding** between elements
- **Consistent chart heights** in each row
- **White background** for charts
- **Rounded corners** (4px) for all charts

---

## 📱 Make Dashboard Shareable

### Step 1: Set Permissions
1. Click **"Share"** (top right)
2. Click **"Manage access"**
3. Change to **"Anyone with the link"**
4. Set permissions to **"Viewer"**

### Step 2: Get Link
1. Click **"Get link"**
2. Copy the link
3. Save this link for your project submission

### Step 3: Test
1. Open link in incognito window
2. Verify all pages load
3. Test filters work
4. Check mobile view

---

## ✅ Final Checklist

Before submitting:
- [ ] All 3 pages created and named correctly
- [ ] All data sources connected
- [ ] All charts showing data (not "No data")
- [ ] Date filters set to appropriate ranges
- [ ] Bar charts show station names (not IDs)
- [ ] Map zoomed to NYC
- [ ] Colors consistent across pages
- [ ] All charts have titles
- [ ] Dashboard is shareable (public link)
- [ ] Tested in incognito mode
- [ ] Mobile view looks good
- [ ] Link saved for submission

---

## 🔍 Verify Your Data

Run these queries in BigQuery to confirm data availability:

```sql
-- Check Station Operations data
SELECT 
  COUNT(*) as total_rows,
  MIN(date_day) as earliest_date,
  MAX(date_day) as latest_date,
  COUNT(DISTINCT station_id) as total_stations
FROM `nyc-citibike-data-platform.citibike_dashboards.vw_station_operations`;
-- Expected: ~21,000 rows, ~2,300 stations

-- Check Trip Analytics data
SELECT 
  COUNT(*) as total_rows,
  SUM(trip_count) as total_trips,
  MIN(date_day) as earliest_date,
  MAX(date_day) as latest_date
FROM `nyc-citibike-data-platform.citibike_dashboards.vw_trip_analytics_daily`;
-- Expected: ~10,000 rows, ~3 million trips

-- Check Weather Impact data
SELECT 
  COUNT(*) as total_rows,
  MIN(date_day) as earliest_date,
  MAX(date_day) as latest_date,
  COUNT(DISTINCT weather_condition) as weather_types
FROM `nyc-citibike-data-platform.citibike_dashboards.vw_weather_impact`;
-- Expected: ~60 rows, multiple weather types
```

---

## 🚨 Troubleshooting

### Problem: "No data available"
- **Solution**: Check date filters aren't too restrictive
- **Solution**: Verify data source is connected
- **Solution**: Run verification queries above

### Problem: Charts show wrong data
- **Solution**: Check you're using correct data source for each page
- **Solution**: Verify metric aggregations (SUM vs AVG)
- **Solution**: Check filters aren't excluding data

### Problem: Map not showing stations
- **Solution**: Verify latitude/longitude fields are selected
- **Solution**: Check zoom level (should be 11 for NYC)
- **Solution**: Ensure size metric has data

### Problem: Dashboard link doesn't work
- **Solution**: Check sharing settings are "Anyone with link"
- **Solution**: Verify permissions are set to "Viewer"
- **Solution**: Test in incognito window

---

## 📚 Resources

- [Looker Studio Documentation](https://support.google.com/looker-studio)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
- [Dashboard Design Guide](https://support.google.com/looker-studio/answer/7450249)

---

## 🎯 Pro Tips

1. **Save frequently** - Looker Studio auto-saves, but refresh to be sure
2. **Use templates** - Copy/paste charts between pages for consistency
3. **Test filters** - Make sure date ranges work on all charts
4. **Keep it simple** - Don't overcomplicate with too many charts
5. **Mobile first** - Check how it looks on phone
6. **Performance** - Use date filters to limit data scanned
7. **Documentation** - Take screenshots for your project README

---

**Total Time**: ~30 minutes for complete 3-page dashboard! 🚀

**Good luck with your submission!** 🎉

---

*Last Updated: March 21, 2026*