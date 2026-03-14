#!/bin/bash

###############################################################################
# CitiBike Modern Data Platform - Automated Deployment Script
# 
# This script orchestrates the complete deployment of:
# - Terraform infrastructure (GCP resources)
# - Kestra workflows (data pipelines)
# - Kestra KV store (environment variables)
# - dbt transformations (data models)
# - Initial data load with backfill (optional)
#
# Usage:
#   ./scripts/deploy.sh [environment] [options]
#
# Examples:
#   ./scripts/deploy.sh dev                    # Deploy to dev
#   ./scripts/deploy.sh prod --full            # Full deployment with data load
#   ./scripts/deploy.sh dev --backfill-trips   # Backfill trip data
#   ./scripts/deploy.sh dev --backfill-weather # Backfill weather data
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-dev}"
DEPLOY_TERRAFORM=true
DEPLOY_KESTRA=true
DEPLOY_DBT=true
RUN_INITIAL_LOAD=false
FULL_REFRESH=false
SKIP_VERIFICATION=false
BACKFILL_TRIPS=false
BACKFILL_WEATHER=false
START_KESTRA=false

# Parse command line arguments
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            RUN_INITIAL_LOAD=true
            FULL_REFRESH=true
            BACKFILL_TRIPS=true
            BACKFILL_WEATHER=true
            shift
            ;;
        --skip-terraform)
            DEPLOY_TERRAFORM=false
            shift
            ;;
        --skip-kestra)
            DEPLOY_KESTRA=false
            shift
            ;;
        --skip-dbt)
            DEPLOY_DBT=false
            shift
            ;;
        --initial-load)
            RUN_INITIAL_LOAD=true
            shift
            ;;
        --backfill-trips)
            BACKFILL_TRIPS=true
            shift
            ;;
        --backfill-weather)
            BACKFILL_WEATHER=true
            shift
            ;;
        --start-kestra)
            START_KESTRA=true
            shift
            ;;
        --skip-verification)
            SKIP_VERIFICATION=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [environment] [--full|--skip-terraform|--skip-kestra|--skip-dbt|--initial-load|--backfill-trips|--backfill-weather|--start-kestra|--skip-verification]"
            exit 1
            ;;
    esac
done

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check required commands
    if ! command_exists terraform; then
        missing_deps+=("terraform")
    else
        print_success "Terraform installed: $(terraform version | head -n1)"
    fi
    
    if ! command_exists gcloud; then
        missing_deps+=("gcloud")
    else
        print_success "gcloud CLI installed: $(gcloud version | head -n1)"
    fi
    
    if ! command_exists python3; then
        missing_deps+=("python3")
    else
        print_success "Python installed: $(python3 --version)"
    fi
    
    if ! command_exists uv; then
        print_warning "uv not found, will try to install"
    else
        print_success "uv installed: $(uv --version)"
    fi
    
    if ! command_exists dbt; then
        print_warning "dbt not found, will install via pip"
    else
        print_success "dbt installed: $(dbt --version | head -n1)"
    fi
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    else
        print_success "curl installed"
    fi
    
    if ! command_exists jq; then
        print_warning "jq not found (optional, for JSON parsing)"
    else
        print_success "jq installed"
    fi
    
    # Check if .env file exists
    if [[ ! -f .env ]]; then
        print_error ".env file not found"
        print_info "Run: ./scripts/setup-env.sh to create it"
        exit 1
    else
        print_success ".env file found"
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install missing dependencies and try again"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to load environment variables
load_environment() {
    print_header "Loading Environment Configuration"
    
    # Load .env file
    if [[ -f .env ]]; then
        set -a
        source .env
        set +a
        print_success "Environment variables loaded from .env"
    fi
    
    # Validate required variables
    local required_vars=(
        "GCP_PROJECT_ID"
        "GCP_REGION"
        "KESTRA_HOST"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Required environment variable $var is not set"
            exit 1
        else
            print_success "$var is set"
        fi
    done
}

# Function to authenticate with GCP
authenticate_gcp() {
    print_header "Authenticating with Google Cloud"
    
    # Check if already authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_success "Already authenticated with GCP"
        CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
        print_info "Current project: $CURRENT_PROJECT"
        
        if [[ "$CURRENT_PROJECT" != "$GCP_PROJECT_ID" ]]; then
            print_warning "Current project ($CURRENT_PROJECT) differs from configured ($GCP_PROJECT_ID)"
            print_info "Setting project to $GCP_PROJECT_ID"
            gcloud config set project "$GCP_PROJECT_ID"
        fi
    else
        print_error "Not authenticated with GCP"
        print_info "Run: gcloud auth application-default login"
        exit 1
    fi
}

# Function to start Kestra server if needed
start_kestra_server() {
    if [[ "$START_KESTRA" == false ]]; then
        return 0
    fi
    
    print_header "Starting Kestra Server"
    
    # Check if Kestra is already running
    if curl -s -f "$KESTRA_HOST/api/v1/flows" >/dev/null 2>&1; then
        print_success "Kestra server is already running"
        return 0
    fi
    
    # Look for Kestra binary and config in multiple locations
    KESTRA_BIN=""
    KESTRA_CONFIG=""
    
    if [[ -f ~/kestra/kestra ]] && [[ -f ~/kestra/confs/application.yaml ]]; then
        KESTRA_BIN=~/kestra/kestra
        KESTRA_CONFIG=~/kestra/confs/application.yaml
        print_info "Found Kestra at ~/kestra/kestra"
        print_info "Using config: ~/kestra/confs/application.yaml"
    elif [[ -f ./kestra ]] && [[ -f ./confs/application.yaml ]]; then
        KESTRA_BIN=./kestra
        KESTRA_CONFIG=./confs/application.yaml
        print_info "Found Kestra at ./kestra"
        print_info "Using config: ./confs/application.yaml"
    elif command -v kestra >/dev/null 2>&1; then
        KESTRA_BIN=$(which kestra)
        print_info "Found Kestra in PATH: $KESTRA_BIN"
        print_warning "No config file specified, using Kestra defaults"
    else
        print_error "Kestra binary not found"
        print_info "Please install Kestra first:"
        echo "  curl -o kestra https://github.com/kestra-io/kestra/releases/latest/download/kestra-linux-x64"
        echo "  chmod +x kestra"
        echo "  mkdir -p ~/kestra && mv kestra ~/kestra/"
        exit 1
    fi
    
    # Ensure PostgreSQL is running (required for Kestra)
    print_info "Checking PostgreSQL..."
    if ! sudo service postgresql status >/dev/null 2>&1; then
        print_warning "PostgreSQL not running, starting it..."
        sudo service postgresql start
        sleep 2
    fi
    print_success "PostgreSQL is running"
    
    print_info "Starting Kestra server in background..."
    if [[ -n "$KESTRA_CONFIG" ]]; then
        nohup "$KESTRA_BIN" server standalone --config "$KESTRA_CONFIG" > kestra.log 2>&1 &
    else
        nohup "$KESTRA_BIN" server standalone > kestra.log 2>&1 &
    fi
    KESTRA_PID=$!
    print_info "Kestra PID: $KESTRA_PID"
    
    # Wait for Kestra to start (max 120 seconds for first start)
    print_info "Waiting for Kestra to start (this may take up to 2 minutes)..."
    for i in {1..120}; do
        # Check if Kestra web server is responding (any response means it's up)
        if [[ -n "${KESTRA_USERNAME:-}" ]] && [[ -n "${KESTRA_PASSWORD:-}" ]]; then
            # Check with authentication - any HTTP response (even 404) means server is up
            if curl -s -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" "$KESTRA_HOST/api/v1/flows" 2>&1 | grep -q "Not Found\|flows"; then
                print_success "Kestra server started successfully"
                return 0
            fi
        else
            # Try without authentication
            if curl -s "$KESTRA_HOST/api/v1/flows" 2>&1 | grep -q "Not Found\|flows\|Unauthorized"; then
                print_success "Kestra server started successfully"
                return 0
            fi
        fi
        if [[ $((i % 10)) -eq 0 ]]; then
            echo -n "."
        fi
        sleep 1
    done
    
    echo ""
    print_error "Kestra server failed to start within 120 seconds"
    print_info "Check kestra.log for details:"
    echo ""
    tail -n 20 kestra.log
    exit 1
}

# Function to check Kestra connectivity
check_kestra() {
    print_header "Checking Kestra Server"
    
    # Check if Kestra web server is responding
    local kestra_accessible=false
    if [[ -n "${KESTRA_USERNAME:-}" ]] && [[ -n "${KESTRA_PASSWORD:-}" ]]; then
        # Any response (including 404 "Not Found") means server is up
        if curl -s -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" "$KESTRA_HOST/api/v1/flows" 2>&1 | grep -q "Not Found\|flows"; then
            kestra_accessible=true
        fi
    else
        # Try without authentication
        if curl -s "$KESTRA_HOST/api/v1/flows" 2>&1 | grep -q "Not Found\|flows\|Unauthorized"; then
            kestra_accessible=true
        fi
    fi
    
    if [[ "$kestra_accessible" == true ]]; then
        print_success "Kestra server is accessible at $KESTRA_HOST"
    else
        print_warning "Cannot connect to Kestra server at $KESTRA_HOST"
        
        # If not already trying to start, offer to start it
        if [[ "$START_KESTRA" == false ]]; then
            print_info "Would you like to start Kestra server now? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                START_KESTRA=true
                start_kestra_server
                # Verify it started
                if curl -s -f "$KESTRA_HOST/api/v1/flows" >/dev/null 2>&1; then
                    print_success "Kestra server is now accessible"
                else
                    print_error "Failed to start Kestra server"
                    print_info "Check kestra.log for details"
                    exit 1
                fi
            else
                print_error "Kestra server is required for deployment"
                print_info "Options:"
                echo "  1. Start Kestra manually: ./kestra server standalone"
                echo "  2. Re-run with --start-kestra flag"
                exit 1
            fi
        else
            print_error "Failed to connect to Kestra after starting"
            exit 1
        fi
    fi
}

# Function to deploy Terraform infrastructure
deploy_terraform() {
    if [[ "$DEPLOY_TERRAFORM" == false ]]; then
        print_warning "Skipping Terraform deployment"
        return 0
    fi
    
    print_header "Deploying Terraform Infrastructure"
    
    cd terraform-gcp
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    if terraform init; then
        print_success "Terraform initialized"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    # Validate configuration
    print_info "Validating Terraform configuration..."
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Plan changes
    print_info "Planning Terraform changes..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan created"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    # Apply changes
    print_info "Applying Terraform changes..."
    if terraform apply -auto-approve tfplan; then
        print_success "Terraform infrastructure deployed"
    else
        print_error "Terraform apply failed"
        exit 1
    fi
    
    # Save outputs
    print_info "Saving Terraform outputs..."
    terraform output -json > ../terraform-outputs.json
    print_success "Terraform outputs saved to terraform-outputs.json"
    
    cd ..
}

# Function to initialize Kestra KV store
initialize_kestra_kv() {
    print_header "Initializing Kestra KV Store"
    
    print_info "Triggering citibike_kv workflow to set environment variables..."
    
    # Trigger the KV initialization workflow
    RESPONSE=$(curl -s -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/citibike_kv" \
        -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        print_success "KV store initialization triggered"
        print_info "Waiting for execution to complete..."
        sleep 10
        
        # Verify KV values are set
        print_info "Verifying KV store values..."
        if curl -s "$KESTRA_HOST/api/v1/namespaces/citibike.nyc/kv/GCP_PROJECT_ID" >/dev/null 2>&1; then
            print_success "KV store initialized successfully"
        else
            print_warning "KV store values may not be set yet"
            print_info "You may need to run citibike_kv workflow manually in Kestra UI"
        fi
    else
        print_warning "Failed to trigger KV initialization automatically"
        print_info "Please run citibike_kv workflow manually in Kestra UI"
        print_info "Navigate to: $KESTRA_HOST → Flows → citibike.nyc → citibike_kv → Execute"
    fi
}

# Function to deploy Kestra workflows
deploy_kestra() {
    if [[ "$DEPLOY_KESTRA" == false ]]; then
        print_warning "Skipping Kestra deployment"
        return 0
    fi
    
    print_header "Deploying Kestra Workflows"
    
    cd kestra
    
    # Use uv for Python environment management (faster and more reliable)
    if command_exists uv; then
        print_info "Installing Python dependencies with uv..."
        if uv pip install -r requirements.txt; then
            print_success "Dependencies installed"
        else
            print_error "Failed to install dependencies"
            exit 1
        fi
        
        # Register workflows
        print_info "Registering Kestra workflows..."
        if uv run python register_yaml_flows.py; then
            print_success "Kestra workflows deployed"
        else
            print_error "Kestra workflow deployment failed"
            exit 1
        fi
    else
        # Fallback to pip if uv is not available
        print_info "Installing Python dependencies with pip..."
        if pip install -q -r requirements.txt; then
            print_success "Dependencies installed"
        else
            print_error "Failed to install dependencies"
            exit 1
        fi
        
        # Register workflows
        print_info "Registering Kestra workflows..."
        if python register_yaml_flows.py; then
            print_success "Kestra workflows deployed"
        else
            print_error "Kestra workflow deployment failed"
            exit 1
        fi
    fi
    
    cd ..
    
    # Initialize KV store after workflows are deployed
    initialize_kestra_kv
}

# Function to deploy dbt models
deploy_dbt() {
    if [[ "$DEPLOY_DBT" == false ]]; then
        print_warning "Skipping dbt deployment"
        return 0
    fi
    
    print_header "Deploying dbt Transformations"
    
    cd dbt/nyc_citibike_analytics
    
    # Install dbt if not present
    if ! command_exists dbt; then
        print_info "Installing dbt-bigquery..."
        pip install -q dbt-bigquery==1.8.0
    fi
    
    # Install dbt dependencies
    print_info "Installing dbt dependencies..."
    if dbt deps; then
        print_success "dbt dependencies installed"
    else
        print_error "dbt deps failed"
        exit 1
    fi
    
    # Test connection
    print_info "Testing dbt connection..."
    if dbt debug; then
        print_success "dbt connection successful"
    else
        print_error "dbt connection failed"
        print_info "Check your ~/.dbt/profiles.yml configuration"
        exit 1
    fi
    
    # Run dbt models
    if [[ "$FULL_REFRESH" == true ]]; then
        print_info "Running dbt with full refresh..."
        if dbt build --full-refresh; then
            print_success "dbt models built (full refresh)"
        else
            print_error "dbt build failed"
            exit 1
        fi
    else
        print_info "Running dbt incrementally..."
        if dbt build; then
            print_success "dbt models built"
        else
            print_error "dbt build failed"
            exit 1
        fi
    fi
    
    cd ../..
}

# Function to backfill trip data
backfill_trip_data() {
    if [[ "$BACKFILL_TRIPS" == false ]]; then
        return 0
    fi
    
    print_header "Backfilling Trip Data"
    
    print_info "Triggering trip data backfill..."
    print_warning "This will process historical trip data (may take 10-30 minutes)"
    
    # Ask for backfill period
    read -p "Enter start month (YYYYMM, e.g., 202401) or press Enter for last 3 months: " START_MONTH
    
    if [[ -z "$START_MONTH" ]]; then
        # Default: last 3 months
        MONTHS=(
            "$(date -d '3 months ago' +%Y%m)"
            "$(date -d '2 months ago' +%Y%m)"
            "$(date -d '1 month ago' +%Y%m)"
        )
    else
        read -p "Enter end month (YYYYMM): " END_MONTH
        # Generate month range (simplified - you may want to enhance this)
        MONTHS=("$START_MONTH")
    fi
    
    for month in "${MONTHS[@]}"; do
        print_info "Triggering trip data load for $month..."
        curl -s -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/nyc_bikes_parent" \
            -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" \
            -H "Content-Type: application/json" \
            -d "{\"inputs\": {\"month\": \"$month\"}}" >/dev/null
        print_success "Triggered: $month"
        sleep 2
    done
    
    print_success "Trip data backfill triggered for ${#MONTHS[@]} months"
    print_info "Monitor progress in Kestra UI: $KESTRA_HOST/executions"
}

# Function to backfill weather data
backfill_weather_data() {
    if [[ "$BACKFILL_WEATHER" == false ]]; then
        return 0
    fi
    
    print_header "Backfilling Weather Data"
    
    print_info "Triggering weather data backfill..."
    
    # Ask for backfill period
    read -p "Enter start date (YYYY-MM-DD) or press Enter for last 90 days: " START_DATE
    
    if [[ -z "$START_DATE" ]]; then
        START_DATE=$(date -d '90 days ago' +%Y-%m-%d)
    fi
    
    read -p "Enter end date (YYYY-MM-DD) or press Enter for yesterday: " END_DATE
    
    if [[ -z "$END_DATE" ]]; then
        END_DATE=$(date -d 'yesterday' +%Y-%m-%d)
    fi
    
    print_info "Backfilling weather data from $START_DATE to $END_DATE..."
    
    curl -s -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/nyc_daily_weather_to_bigquery" \
        -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" \
        -H "Content-Type: application/json" \
        -d "{\"inputs\": {\"start_date\": \"$START_DATE\", \"end_date\": \"$END_DATE\"}}" >/dev/null
    
    print_success "Weather data backfill triggered"
    print_info "Monitor progress in Kestra UI: $KESTRA_HOST/executions"
}

# Function to run initial data load
run_initial_load() {
    if [[ "$RUN_INITIAL_LOAD" == false ]]; then
        print_warning "Skipping initial data load"
        return 0
    fi
    
    print_header "Running Initial Data Load"
    
    print_info "Triggering Kestra workflows for initial data load..."
    
    # Trigger station status streaming
    print_info "Starting station status streaming..."
    curl -s -X POST "$KESTRA_HOST/api/v1/executions/citibike.nyc/citibike_station_status_publisher" \
        -u "$KESTRA_USERNAME:$KESTRA_PASSWORD" >/dev/null
    print_success "Station status streaming triggered"
    sleep 5
    
    print_success "Initial data load triggered successfully"
    print_info "Monitor execution progress in Kestra UI: $KESTRA_HOST"
}

# Function to verify deployment
verify_deployment() {
    if [[ "$SKIP_VERIFICATION" == true ]]; then
        print_warning "Skipping deployment verification"
        return 0
    fi
    
    print_header "Verifying Deployment"
    
    # Check if verification script exists
    if [[ -f scripts/verify-deployment.sh ]]; then
        print_info "Running verification script..."
        if bash scripts/verify-deployment.sh; then
            print_success "Deployment verification passed"
        else
            print_warning "Some verification checks failed"
        fi
    else
        print_warning "Verification script not found, skipping"
    fi
}

# Function to print deployment summary
print_summary() {
    print_header "Deployment Summary"
    
    echo -e "${CYAN}Environment:${NC} $ENVIRONMENT"
    echo -e "${CYAN}Terraform:${NC} $([ "$DEPLOY_TERRAFORM" == true ] && echo "✓ Deployed" || echo "⊘ Skipped")"
    echo -e "${CYAN}Kestra Workflows:${NC} $([ "$DEPLOY_KESTRA" == true ] && echo "✓ Deployed" || echo "⊘ Skipped")"
    echo -e "${CYAN}Kestra KV Store:${NC} $([ "$DEPLOY_KESTRA" == true ] && echo "✓ Initialized" || echo "⊘ Skipped")"
    echo -e "${CYAN}dbt:${NC} $([ "$DEPLOY_DBT" == true ] && echo "✓ Deployed" || echo "⊘ Skipped")"
    echo -e "${CYAN}Initial Load:${NC} $([ "$RUN_INITIAL_LOAD" == true ] && echo "✓ Triggered" || echo "⊘ Skipped")"
    echo -e "${CYAN}Trip Backfill:${NC} $([ "$BACKFILL_TRIPS" == true ] && echo "✓ Triggered" || echo "⊘ Skipped")"
    echo -e "${CYAN}Weather Backfill:${NC} $([ "$BACKFILL_WEATHER" == true ] && echo "✓ Triggered" || echo "⊘ Skipped")"
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    print_info "Next steps:"
    echo "  1. Monitor Kestra executions: $KESTRA_HOST"
    echo "  2. Check BigQuery tables: https://console.cloud.google.com/bigquery?project=$GCP_PROJECT_ID"
    echo "  3. View dbt documentation: cd dbt/nyc_citibike_analytics && dbt docs serve"
    echo "  4. Run monitoring: ./scripts/monitor.sh"
    
    if [[ "$BACKFILL_TRIPS" == true ]] || [[ "$BACKFILL_WEATHER" == true ]]; then
        echo ""
        print_warning "Backfill operations are running in background"
        print_info "Check Kestra UI for execution status: $KESTRA_HOST/executions"
        print_info "Backfill may take 10-30 minutes to complete"
    fi
}

# Main execution
main() {
    print_header "CitiBike Modern Data Platform - Automated Deployment"
    echo -e "${MAGENTA}Environment: $ENVIRONMENT${NC}"
    echo -e "${MAGENTA}Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}\n"
    
    check_prerequisites
    load_environment
    authenticate_gcp
    check_kestra  # This will start Kestra if needed
    deploy_terraform
    deploy_kestra
    deploy_dbt
    run_initial_load
    backfill_trip_data
    backfill_weather_data
    verify_deployment
    print_summary
}

# Run main function
main