#!/bin/bash

###############################################################################
# Monitoring Script
# 
# This script checks the health and status of the data platform components.
# Run this regularly to ensure everything is working properly.
#
# Usage:
#   ./scripts/monitor.sh
###############################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_metric() {
    local label="$1"
    local value="$2"
    local status="$3"
    
    case $status in
        "good")
            echo -e "${CYAN}$label:${NC} ${GREEN}$value${NC}"
            ;;
        "warning")
            echo -e "${CYAN}$label:${NC} ${YELLOW}$value${NC}"
            ;;
        "error")
            echo -e "${CYAN}$label:${NC} ${RED}$value${NC}"
            ;;
        *)
            echo -e "${CYAN}$label:${NC} $value"
            ;;
    esac
}

# Load environment
if [[ -f .env ]]; then
    set -a
    source .env
    set +a
else
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

# Monitor Kestra Workflows
monitor_kestra() {
    print_header "Kestra Workflow Status"
    
    if ! curl -s -f "$KESTRA_HOST/api/v1/flows" > /dev/null 2>&1; then
        print_metric "Kestra Server" "OFFLINE" "error"
        return 1
    fi
    
    print_metric "Kestra Server" "ONLINE" "good"
    
    # Get flow count
    FLOW_COUNT=$(curl -s "$KESTRA_HOST/api/v1/flows" | jq '. | length' 2>/dev/null || echo "0")
    print_metric "Total Flows" "$FLOW_COUNT" "info"
    
    # Check recent executions (last 24 hours)
    EXECUTIONS=$(curl -s "$KESTRA_HOST/api/v1/executions/search?size=100" | jq '.results' 2>/dev/null || echo "[]")
    
    if [[ "$EXECUTIONS" != "[]" ]]; then
        SUCCESS_COUNT=$(echo "$EXECUTIONS" | jq '[.[] | select(.state.current == "SUCCESS")] | length' 2>/dev/null || echo "0")
        FAILED_COUNT=$(echo "$EXECUTIONS" | jq '[.[] | select(.state.current == "FAILED")] | length' 2>/dev/null || echo "0")
        RUNNING_COUNT=$(echo "$EXECUTIONS" | jq '[.[] | select(.state.current == "RUNNING")] | length' 2>/dev/null || echo "0")
        
        print_metric "Recent Executions (24h)" "Success: $SUCCESS_COUNT | Failed: $FAILED_COUNT | Running: $RUNNING_COUNT" "info"
        
        if [[ $FAILED_COUNT -gt 0 ]]; then
            print_metric "Status" "Some failures detected" "warning"
        else
            print_metric "Status" "All executions successful" "good"
        fi
    else
        print_metric "Recent Executions" "No executions found" "warning"
    fi
}

# Monitor BigQuery Data Freshness
monitor_bigquery() {
    print_header "BigQuery Data Freshness"
    
    # Check station status streaming table
    STREAMING_FRESHNESS=$(bq query --project_id="$GCP_PROJECT_ID" --use_legacy_sql=false --format=csv \
        "SELECT TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(last_reported), MINUTE) as minutes_old 
         FROM \`${GCP_PROJECT_ID}.${GCP_DATASET}.station_status_streaming\`" 2>/dev/null | tail -n1)
    
    if [[ -n "$STREAMING_FRESHNESS" ]] && [[ "$STREAMING_FRESHNESS" != "minutes_old" ]]; then
        if [[ $STREAMING_FRESHNESS -lt 10 ]]; then
            print_metric "Station Status Data" "${STREAMING_FRESHNESS} minutes old" "good"
        elif [[ $STREAMING_FRESHNESS -lt 30 ]]; then
            print_metric "Station Status Data" "${STREAMING_FRESHNESS} minutes old" "warning"
        else
            print_metric "Station Status Data" "${STREAMING_FRESHNESS} minutes old" "error"
        fi
    else
        print_metric "Station Status Data" "No data found" "error"
    fi
    
    # Check active stations
    ACTIVE_STATIONS=$(bq query --project_id="$GCP_PROJECT_ID" --use_legacy_sql=false --format=csv \
        "SELECT COUNT(DISTINCT station_id) as count 
         FROM \`${GCP_PROJECT_ID}.${GCP_DATASET}.station_status_streaming\`
         WHERE last_reported >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)" 2>/dev/null | tail -n1)
    
    if [[ -n "$ACTIVE_STATIONS" ]] && [[ "$ACTIVE_STATIONS" != "count" ]]; then
        if [[ $ACTIVE_STATIONS -gt 1500 ]]; then
            print_metric "Active Stations (10 min)" "$ACTIVE_STATIONS stations" "good"
        elif [[ $ACTIVE_STATIONS -gt 1000 ]]; then
            print_metric "Active Stations (10 min)" "$ACTIVE_STATIONS stations" "warning"
        else
            print_metric "Active Stations (10 min)" "$ACTIVE_STATIONS stations" "error"
        fi
    else
        print_metric "Active Stations" "Unable to query" "error"
    fi
    
    # Check trip data
    TRIP_COUNT=$(bq query --project_id="$GCP_PROJECT_ID" --use_legacy_sql=false --format=csv \
        "SELECT COUNT(*) as count FROM \`${GCP_PROJECT_ID}.${GCP_DATASET}.citibike_trips_raw\`" 2>/dev/null | tail -n1)
    
    if [[ -n "$TRIP_COUNT" ]] && [[ "$TRIP_COUNT" != "count" ]]; then
        print_metric "Total Trip Records" "$(printf "%'d" $TRIP_COUNT)" "info"
    fi
    
    # Check weather data
    WEATHER_FRESHNESS=$(bq query --project_id="$GCP_PROJECT_ID" --use_legacy_sql=false --format=csv \
        "SELECT DATE_DIFF(CURRENT_DATE(), MAX(date), DAY) as days_old 
         FROM \`${GCP_PROJECT_ID}.${GCP_DATASET}.nyc_weather_daily\`" 2>/dev/null | tail -n1)
    
    if [[ -n "$WEATHER_FRESHNESS" ]] && [[ "$WEATHER_FRESHNESS" != "days_old" ]]; then
        if [[ $WEATHER_FRESHNESS -lt 2 ]]; then
            print_metric "Weather Data" "${WEATHER_FRESHNESS} days old" "good"
        elif [[ $WEATHER_FRESHNESS -lt 7 ]]; then
            print_metric "Weather Data" "${WEATHER_FRESHNESS} days old" "warning"
        else
            print_metric "Weather Data" "${WEATHER_FRESHNESS} days old" "error"
        fi
    fi
}

# Monitor Pub/Sub
monitor_pubsub() {
    print_header "Pub/Sub Status"
    
    # Check unacked messages
    UNACKED=$(gcloud pubsub subscriptions describe citibike-station-status-to-bq \
        --project="$GCP_PROJECT_ID" --format="value(numUndeliveredMessages)" 2>/dev/null || echo "unknown")
    
    if [[ "$UNACKED" != "unknown" ]]; then
        if [[ $UNACKED -eq 0 ]]; then
            print_metric "Unacked Messages" "$UNACKED" "good"
        elif [[ $UNACKED -lt 1000 ]]; then
            print_metric "Unacked Messages" "$UNACKED" "warning"
        else
            print_metric "Unacked Messages" "$UNACKED" "error"
        fi
    else
        print_metric "Unacked Messages" "Unable to query" "error"
    fi
}

# Monitor GCS Storage
monitor_gcs() {
    print_header "GCS Storage Status"
    
    # Check bucket size
    BUCKET_SIZE=$(gsutil du -s "gs://${GCP_BUCKET_NAME}" 2>/dev/null | awk '{print $1}')
    
    if [[ -n "$BUCKET_SIZE" ]]; then
        SIZE_GB=$(echo "scale=2; $BUCKET_SIZE / 1024 / 1024 / 1024" | bc)
        print_metric "Bucket Size" "${SIZE_GB} GB" "info"
    else
        print_metric "Bucket Size" "Unable to query" "error"
    fi
    
    # Check for recent files
    RECENT_FILES=$(gsutil ls -l "gs://${GCP_BUCKET_NAME}/nyc_bikes/parquet/**" 2>/dev/null | wc -l || echo "0")
    print_metric "Parquet Files" "$RECENT_FILES files" "info"
}

# Monitor dbt Models
monitor_dbt() {
    print_header "dbt Models Status"
    
    # Check if marts tables exist
    MARTS_TABLES=(
        "marts.fct_trips"
        "marts.fct_station_day"
        "marts.dim_station"
        "marts.dim_date"
    )
    
    EXISTING_TABLES=0
    for table in "${MARTS_TABLES[@]}"; do
        if bq show --project_id="$GCP_PROJECT_ID" "${GCP_DATASET}.${table}" > /dev/null 2>&1; then
            ((EXISTING_TABLES++))
        fi
    done
    
    if [[ $EXISTING_TABLES -eq ${#MARTS_TABLES[@]} ]]; then
        print_metric "Marts Tables" "$EXISTING_TABLES/${#MARTS_TABLES[@]} deployed" "good"
    elif [[ $EXISTING_TABLES -gt 0 ]]; then
        print_metric "Marts Tables" "$EXISTING_TABLES/${#MARTS_TABLES[@]} deployed" "warning"
    else
        print_metric "Marts Tables" "0/${#MARTS_TABLES[@]} deployed" "error"
    fi
    
    # Check fct_trips freshness
    if bq show --project_id="$GCP_PROJECT_ID" "${GCP_DATASET}.marts.fct_trips" > /dev/null 2>&1; then
        TRIPS_COUNT=$(bq query --project_id="$GCP_PROJECT_ID" --use_legacy_sql=false --format=csv \
            "SELECT COUNT(*) as count FROM \`${GCP_PROJECT_ID}.${GCP_DATASET}.marts.fct_trips\`" 2>/dev/null | tail -n1)
        
        if [[ -n "$TRIPS_COUNT" ]] && [[ "$TRIPS_COUNT" != "count" ]]; then
            print_metric "Fact Trips Records" "$(printf "%'d" $TRIPS_COUNT)" "info"
        fi
    fi
}

# Monitor System Resources
monitor_system() {
    print_header "System Resources"
    
    # Check disk space
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -lt 80 ]]; then
        print_metric "Disk Usage" "${DISK_USAGE}%" "good"
    elif [[ $DISK_USAGE -lt 90 ]]; then
        print_metric "Disk Usage" "${DISK_USAGE}%" "warning"
    else
        print_metric "Disk Usage" "${DISK_USAGE}%" "error"
    fi
    
    # Check if Kestra server is running (if local)
    if [[ "$KESTRA_HOST" == *"localhost"* ]] || [[ "$KESTRA_HOST" == *"127.0.0.1"* ]]; then
        if pgrep -f "kestra" > /dev/null; then
            print_metric "Kestra Process" "Running" "good"
        else
            print_metric "Kestra Process" "Not running" "error"
        fi
    fi
}

# Print summary
print_summary() {
    print_header "Monitoring Summary"
    
    echo -e "${CYAN}Timestamp:${NC} $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo -e "${CYAN}Environment:${NC} ${ENVIRONMENT:-dev}"
    echo -e "${CYAN}Project:${NC} $GCP_PROJECT_ID"
    echo ""
    echo -e "${GREEN}✓ Monitoring complete${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  • Review any warnings or errors above"
    echo "  • Check Kestra UI: $KESTRA_HOST"
    echo "  • View BigQuery: https://console.cloud.google.com/bigquery?project=$GCP_PROJECT_ID"
    echo "  • Run full verification: ./scripts/verify-deployment.sh"
}

# Main execution
main() {
    print_header "CitiBike Data Platform - Health Monitor"
    
    monitor_kestra
    monitor_bigquery
    monitor_pubsub
    monitor_gcs
    monitor_dbt
    monitor_system
    print_summary
}

main