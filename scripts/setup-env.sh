#!/bin/bash

###############################################################################
# Environment Setup Script
# 
# This script helps you configure the environment variables needed for
# deployment. It creates a .env file with your GCP and Kestra settings.
#
# Usage:
#   ./scripts/setup-env.sh
###############################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -p "$prompt: " value
        echo "$value"
    fi
}

# Main setup
main() {
    print_header "CitiBike Data Platform - Environment Setup"
    
    # Check if .env already exists
    if [[ -f .env ]]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            exit 0
        fi
        mv .env .env.backup
        print_info "Backed up existing .env to .env.backup"
    fi
    
    print_info "This script will help you configure your environment"
    echo ""
    
    # GCP Configuration
    print_header "Google Cloud Platform Configuration"
    
    # Try to get current GCP project
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
    
    GCP_PROJECT_ID=$(prompt_with_default "Enter your GCP Project ID" "$CURRENT_PROJECT")
    GCP_REGION=$(prompt_with_default "Enter your GCP Region" "us-central1")
    GCP_DATASET=$(prompt_with_default "Enter your BigQuery Dataset" "citibike_data")
    GCP_BUCKET_NAME=$(prompt_with_default "Enter your GCS Bucket Name" "${GCP_PROJECT_ID}-citibike-data")
    
    # Kestra Configuration
    print_header "Kestra Configuration"
    
    KESTRA_HOST=$(prompt_with_default "Enter Kestra Host URL" "http://localhost:8080")
    KESTRA_USERNAME=$(prompt_with_default "Enter Kestra Username" "admin@kestra.io")
    
    # Prompt for password without echoing
    echo -n "Enter Kestra Password: "
    read -s KESTRA_PASSWORD
    echo ""
    
    # dbt Configuration
    print_header "dbt Configuration"
    
    DBT_TARGET=$(prompt_with_default "Enter dbt Target Environment" "dev")
    
    # Create .env file
    print_header "Creating .env File"
    
    cat > .env << EOF
# Google Cloud Platform Configuration
GCP_PROJECT_ID=$GCP_PROJECT_ID
GCP_REGION=$GCP_REGION
GCP_DATASET=$GCP_DATASET
GCP_BUCKET_NAME=$GCP_BUCKET_NAME

# Kestra Configuration
KESTRA_HOST=$KESTRA_HOST
KESTRA_USERNAME=$KESTRA_USERNAME
KESTRA_PASSWORD=$KESTRA_PASSWORD

# dbt Configuration
DBT_TARGET=$DBT_TARGET

# Deployment Configuration
ENVIRONMENT=dev
EOF
    
    print_success ".env file created successfully"
    
    # Verify GCP authentication
    print_header "Verifying GCP Authentication"
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_success "Authenticated with GCP"
        
        # Set project
        gcloud config set project "$GCP_PROJECT_ID" 2>/dev/null
        print_success "Set active project to $GCP_PROJECT_ID"
    else
        print_warning "Not authenticated with GCP"
        print_info "Run: gcloud auth application-default login"
    fi
    
    # Check if service account keys exist
    print_header "Checking Service Account Keys"
    
    if [[ -f terraform-gcp/kestra-sa-key.json ]]; then
        print_success "Kestra service account key found"
    else
        print_warning "Kestra service account key not found"
        print_info "After running terraform apply, generate keys with:"
        echo "  gcloud iam service-accounts keys create terraform-gcp/kestra-sa-key.json \\"
        echo "    --iam-account=kestra-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    fi
    
    if [[ -f terraform-gcp/dbt-sa-key.json ]]; then
        print_success "dbt service account key found"
    else
        print_warning "dbt service account key not found"
        print_info "After running terraform apply, generate keys with:"
        echo "  gcloud iam service-accounts keys create terraform-gcp/dbt-sa-key.json \\"
        echo "    --iam-account=dbt-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    fi
    
    # Summary
    print_header "Setup Complete"
    
    print_success "Environment configured successfully"
    echo ""
    print_info "Next steps:"
    echo "  1. Review .env file and make any necessary adjustments"
    echo "  2. Ensure you have GCP service account keys (see warnings above)"
    echo "  3. Run deployment: ./scripts/deploy.sh dev"
    echo ""
    print_warning "Important: Never commit .env or service account keys to git!"
}

main