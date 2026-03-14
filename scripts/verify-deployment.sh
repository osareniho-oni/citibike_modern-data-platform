#!/bin/bash

###############################################################################
# Deployment Verification Script
# 
# This script verifies that all components of the data platform are
# properly deployed and functioning.
#
# Usage:
#   ./scripts/verify-deployment.sh
###############################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Load environment
if [[ -f .env ]]; then
    set -a
    source .env
    set +a
else
    print_error ".env file not found"
    exit 1
fi

# Verify GCP Authentication
verify_gcp_auth() {
    print_header "Verifying GCP Authentication"
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_success "Authenticated with GCP"
        
        CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
        if [[ "$CURRENT_PROJECT" == "$GCP_PROJECT_ID" ]]; then
            print_success "Correct project selected: $GCP_PROJECT_ID"
        else
            print_error "Wrong project selected: $CURRENT_PROJECT (expected: $GCP_PROJECT_ID)"
        fi
    else
        print_error "Not authenticated with GCP"
    fi
}

# Verify Terraform State
verify_terraform() {
    print_header "Verifying Terraform Infrastructure"
    
    cd terraform-gcp
    
    if [[ -f terraform.tfstate ]] || [[ -d .terraform ]]; then
        print_success "Terraform initialized"
        
        # Check if outputs exist
        if terraform output -json > /dev/null 2>&1; then
            print_success "Terraform state is valid"
        else
            print_warning "Cannot read Terraform outputs"
        fi
    else
        print_error "Terraform not initialized"
    fi
    
    cd ..
}

# Verify BigQuery Tables
verify_bigquery() {
    print_header "Verifying BigQuery Tables"
    
    # Check critical tables
    TABLES=(
        "station_status_streaming"
        "citibike_trips_raw"
        "nyc_weather_daily"
    )
    
    for table in "${TABLES[@]}"; do
        if bq show --project_id="$GCP_PROJECT_ID" "${GCP_DATASET}.${table}" > /dev/null 2>&1; then
            print_success "Table exists: ${GCP_DATASET}.${table}"
        else
            print_warning "Table not found: ${GCP_DATASET}.${table}"
        fi
    done
    
    # Check dbt marts tables
    MARTS_TABLES=(
        "marts.fct_trips"
        "marts.fct_station_day"
        "marts.dim_station"
        "marts.dim_date"
    )
    
    for table in "${MARTS_TABLES[@]}"; do
        if bq show --project_id="$GCP_PROJECT_ID" "${GCP_DATASET}.${table}" > /dev/null 2>&1; then
            print_success "Marts table exists: ${GCP_DATASET}.${table}"
        else
            print_warning "Marts table not found: ${GCP_DATASET}.${table} (run dbt build)"
        fi
    done
}

# Verify GCS Buckets
verify_gcs() {
    print_header "Verifying GCS Buckets"
    
    if gsutil ls "gs://${GCP_BUCKET_NAME}" > /dev/null 2>&1; then
        print_success "GCS bucket exists: ${GCP_BUCKET_NAME}"
        
        # Check for data directories
        if gsutil ls "gs://${GCP_BUCKET_NAME}/nyc_bikes/" > /dev/null 2>&1; then
            print_success "Data directory exists: nyc_bikes/"
        else
            print_warning "Data directory not found: nyc_bikes/ (will be created on first run)"
        fi
    else
        print_error "GCS bucket not found: ${GCP_BUCKET_NAME}"
    fi
}

# Verify Pub/Sub
verify_pubsub() {
    print_header "Verifying Pub/Sub Resources"
    
    # Check topic
    if gcloud pubsub topics describe citibike-station-status --project="$GCP_PROJECT_ID" > /dev/null 2>&1; then
        print_success "Pub/Sub topic exists: citibike-station-status"
    else
        print_error "Pub/Sub topic not found: citibike-station-status"
    fi
    
    # Check subscription
    if gcloud pubsub subscriptions describe citibike-station-status-to-bq --project="$GCP_PROJECT_ID" > /dev/null 2>&1; then
        print_success "Pub/Sub subscription exists: citibike-station-status-to-bq"
    else
        print_error "Pub/Sub subscription not found: citibike-station-status-to-bq"
    fi
}

# Verify Kestra
verify_kestra() {
    print_header "Verifying Kestra Workflows"
    
    # Check Kestra connectivity
    if curl -s -f "$KESTRA_HOST/api/v1/flows" > /dev/null 2>&1; then
        print_success "Kestra server is accessible"
        
        # Count flows
        FLOW_COUNT=$(curl -s "$KESTRA_HOST/api/v1/flows" | jq '. | length' 2>/dev/null || echo "0")
        if [[ "$FLOW_COUNT" -gt 0 ]]; then
            print_success "Kestra flows deployed: $FLOW_COUNT flows"
        else
            print_warning "No Kestra flows found (run: cd kestra && python register_yaml_flows.py)"
        fi
    else
        print_error "Cannot connect to Kestra server at $KESTRA_HOST"
    fi
}

# Verify dbt
verify_dbt() {
    print_header "Verifying dbt Configuration"
    
    cd dbt/nyc_citibike_analytics
    
    # Check if dbt is installed
    if command -v dbt > /dev/null 2>&1; then
        print_success "dbt is installed"
        
        # Check profiles.yml
        if [[ -f ~/.dbt/profiles.yml ]]; then
            print_success "dbt profiles.yml exists"
            
            # Test connection
            if dbt debug > /dev/null 2>&1; then
                print_success "dbt connection successful"
            else
                print_warning "dbt connection test failed (check profiles.yml)"
            fi
        else
            print_warning "dbt profiles.yml not found at ~/.dbt/profiles.yml"
        fi
    else
        print_error "dbt is not installed"
    fi
    
    cd ../..
}

# Verify Service Accounts
verify_service_accounts() {
    print_header "Verifying Service Accounts"
    
    # Check Kestra SA
    if gcloud iam service-accounts describe "kestra-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" > /dev/null 2>&1; then
        print_success "Kestra service account exists"
        
        if [[ -f terraform-gcp/kestra-sa-key.json ]]; then
            print_success "Kestra service account key file exists"
        else
            print_warning "Kestra service account key file not found"
        fi
    else
        print_error "Kestra service account not found"
    fi
    
    # Check dbt SA
    if gcloud iam service-accounts describe "dbt-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" > /dev/null 2>&1; then
        print_success "dbt service account exists"
        
        if [[ -f terraform-gcp/dbt-sa-key.json ]]; then
            print_success "dbt service account key file exists"
        else
            print_warning "dbt service account key file not found"
        fi
    else
        print_error "dbt service account not found"
    fi
}

# Print summary
print_summary() {
    print_header "Verification Summary"
    
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All critical checks passed!${NC}"
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "${YELLOW}⚠ Some warnings detected - review above${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Some checks failed - review above${NC}"
        return 1
    fi
}

# Main execution
main() {
    print_header "CitiBike Data Platform - Deployment Verification"
    
    verify_gcp_auth
    verify_terraform
    verify_bigquery
    verify_gcs
    verify_pubsub
    verify_kestra
    verify_dbt
    verify_service_accounts
    print_summary
}

main