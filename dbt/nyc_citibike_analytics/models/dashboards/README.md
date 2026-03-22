# Dashboard Views for Looker Studio

This folder contains optimized BigQuery views designed specifically for Looker Studio dashboards.

## 📊 Views Overview

### 1. `vw_station_operations.sql`
**Purpose**: Real-time station availability and operational health metrics

**Key Metrics**:
- Station availability (bikes, docks, e-bikes)
- Utilization and occupancy rates
- Operational health scores
- Rebalancing priorities
- Trip activity (starts/ends)

**Data Range**: Last 30 days (rolling window)

**Refresh Strategy**: Standard view (queries live data). Consider converting to materialized view with 5-minute refresh for production.

**Dashboard Use**: Station Operations Dashboard (Page 1)

---

### 2. `vw_trip_analytics_daily.sql`
**Purpose**: Pre-aggregated daily trip metrics for trend analysis

**Key Metrics**:
- Trip counts by hour, user type, bike type
- Average trip duration
- Member vs casual breakdown
- Electric vs classic bike usage
- Trip duration categories

**Data Range**: Last 90 days (rolling window)

**Refresh Strategy**: Standard view. Consider converting to materialized view with hourly refresh for production.

**Dashboard Use**: Trip Analytics Dashboard (Page 2)

---

### 3. `vw_trip_analytics_routes.sql`
**Purpose**: Route-level analysis (start/end station pairs)

**Key Metrics**:
- Popular routes (station pairs)
- Trip counts per route
- Average duration per route
- User type and bike type breakdown by route

**Data Range**: Last 30 days (for performance)

**Refresh Strategy**: Standard view (on-demand queries)

**Dashboard Use**: Trip Analytics Dashboard (Page 2) - Route analysis section

---

### 4. `vw_weather_impact.sql`
**Purpose**: Daily weather conditions and ridership correlation

**Key Metrics**:
- Temperature, precipitation, wind speed
- Weather condition categories
- System-wide trip volumes
- Ideal vs poor weather flags
- Weather severity scores

**Data Range**: Last 90 days (rolling window)

**Refresh Strategy**: Standard view. Consider converting to materialized view with daily refresh for production.

**Dashboard Use**: Weather Impact Dashboard (Page 3)

---

## 🚀 Deployment

### Initial Deployment (Standard Views)

```bash
# From dbt project directory
cd dbt/nyc_citibike_analytics

# Run only dashboard models
dbt run --select dashboards

# Or run specific view
dbt run --select vw_station_operations
```

### Production Optimization (Materialized Views)

For production, convert to materialized views for better performance:

```sql
-- Example: Convert vw_station_operations to materialized view
CREATE MATERIALIZED VIEW `project.citibike_dashboards.vw_station_operations`
PARTITION BY date_day
CLUSTER BY station_id, rebalancing_need
OPTIONS (
  enable_refresh = true,
  refresh_interval_minutes = 5
) AS
SELECT * FROM `project.citibike_dashboards.vw_station_operations`;
```

**Recommended Refresh Intervals**:
- `vw_station_operations`: 5 minutes (real-time dashboard)
- `vw_trip_analytics_daily`: 60 minutes (hourly updates)
- `vw_trip_analytics_routes`: Standard view (on-demand)
- `vw_weather_impact`: 1440 minutes (daily at midnight)

---

## 📝 Configuration

All views are configured in `dbt_project.yml`:

```yaml
dashboards:
  +schema: citibike_dashboards
  +materialized: view
  +tags: ['dashboard']
```

This ensures:
- Views are created in the `citibike_dashboards` dataset
- Default materialization is `view` (can override per model)
- All models are tagged for easy selection

---

## 🔍 Testing

```bash
# Test all dashboard views
dbt test --select dashboards

# Validate data freshness
dbt source freshness

# Check for schema changes
dbt run --select dashboards --full-refresh
```

---

## 📚 Documentation

View documentation is maintained in `schema.yml` and can be generated:

```bash
# Generate documentation site
dbt docs generate

# Serve documentation locally
dbt docs serve
```

---

## 🎨 Looker Studio Integration

### Connecting to Views

1. Open Looker Studio
2. Create new data source
3. Select BigQuery connector
4. Navigate to: `project > citibike_dashboards`
5. Select view (e.g., `vw_station_operations`)
6. Click "Connect"

### Best Practices

- **Use date filters**: All views include date fields for filtering
- **Leverage pre-aggregations**: Views are optimized for dashboard performance
- **Cache settings**: Set appropriate cache duration in Looker Studio
- **Incremental refresh**: Use date-based filters for incremental data loads

---

## 🔧 Maintenance

### Updating Views

1. Modify SQL in the `.sql` file
2. Test locally: `dbt run --select model_name`
3. Validate results in BigQuery
4. Deploy: `dbt run --select dashboards`

### Monitoring

- Check BigQuery audit logs for query performance
- Monitor view refresh times (for materialized views)
- Track dashboard load times in Looker Studio
- Set up alerts for data freshness

---

## 💡 Future Enhancements

Consider adding:
- **Incremental models**: For very large datasets
- **Snapshot views**: For point-in-time analysis
- **Aggregation tables**: For ultra-fast dashboard loads
- **Data quality views**: For monitoring data health
- **User activity tracking**: For dashboard usage analytics

---

## 📞 Support

For questions or issues:
1. Check dbt logs: `logs/dbt.log`
2. Review BigQuery execution details
3. Validate source data in marts layer
4. Check Looker Studio data source settings

---

*Last Updated: 2026-03-14*