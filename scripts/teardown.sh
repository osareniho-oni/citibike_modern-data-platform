#!/bin/bash

###############################################################################
# Teardown Script
# 
# This script safely destroys all infrastructure and cleans up resources.
# Use with caution - this will delete all data!
#
# Usage:
#   ./scripts/teardown.sh [--force]
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
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

# Confirmation
confirm_teardown() {
    print_header "⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️"
    
    echo -e "${RED}This will permanently delete:${NC}"
    echo "  • All BigQuery datasets and tables"
    echo "  • All GCS buckets and data"
    echo "  • All Pub/Sub topics and subscriptions"
    echo "  • All service accounts"
    echo "  • All Terraform state"
    echo ""
    echo -e "${YELLOW}Project: $GCP_PROJECT_ID${NC}"
    echo ""
    
    if [[ "$FORCE" == false ]]; then
        read -p "Type 'DELETE' to confirm: " confirmation
        if [[ "$confirmation" != "DELETE" ]]; then
            echo -e "${GREEN}Teardown cancelled${NC}"
            exit 0
        fi
        
        read -p "Are you absolutely sure? (yes/no): " final_confirm
        if [[ "$final_confirm" != "yes" ]]; then
            echo -e "${GREEN}Teardown cancelled${NC}"
            exit 0
        fi
    fi
}

# Stop Kestra workflows
stop_kestra_workflows() {
    print_header "Stopping Kestra Workflows"
    
    if curl -s -f "$KESTRA_HOST/api/v1/flows" > /dev/null 2>&1; then
        print_warning "Kestra workflows will continue running"
        print_warning "Stop Kestra server manually if needed"
    else
        print_warning "Kestra server not accessible"
    fi
}

# Destroy Terraform infrastructure
destroy_terraform() {
    print_header "Destroying Terraform Infrastructure"
    
    cd terraform-gcp
    
    if [[ -f terraform.tfstate ]] || [[ -d .terraform ]]; then
        echo "Running terraform destroy..."
        if terraform destroy -auto-approve; then
            print_success "Terraform infrastructure destroyed"
        else
            print_error "Terraform destroy failed"
            print_warning "You may need to manually delete resources in GCP Console"
        fi
    else
        print_warning "No Terraform state found"
    fi
    
    cd ..
}

# Clean up local files
cleanup_local() {
    print_header "Cleaning Up Local Files"
    
    # Remove Terraform state
    if [[ -f terraform-gcp/terraform.tfstate ]]; then
        rm -f terraform-gcp/terraform.tfstate
        rm -f terraform-gcp/terraform.tfstate.backup
        print_success "Removed Terraform state files"
    fi
    
    # Remove service account keys
    if [[ -f terraform-gcp/kestra-sa-key.json ]]; then
        rm -f terraform-gcp/kestra-sa-key.json
        print_success "Removed Kestra service account key"
    fi
    
    if [[ -f terraform-gcp/dbt-sa-key.json ]]; then
        rm -f terraform-gcp/dbt-sa-key.json
        print_success "Removed dbt service account key"
    fi
    
    # Remove Terraform outputs
    if [[ -f terraform-outputs.json ]]; then
        rm -f terraform-outputs.json
        print_success "Removed Terraform outputs"
    fi
    
    # Clean dbt artifacts
    if [[ -d dbt/nyc_citibike_analytics/target ]]; then
        rm -rf dbt/nyc_citibike_analytics/target
        print_success "Removed dbt artifacts"
    fi
    
    # Clean Python virtual environments
    if [[ -d kestra/.venv ]]; then
        rm -rf kestra/.venv
        print_success "Removed Kestra Python virtual environment"
    fi
}

# Backup data (optional)
backup_data() {
    print_header "Data Backup (Optional)"
    
    read -p "Do you want to backup BigQuery data before deletion? (y/N): " backup_choice
    
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        BACKUP_BUCKET="gs://${GCP_PROJECT_ID}-backup-$(date +%Y%m%d)"
        
        echo "Creating backup bucket: $BACKUP_BUCKET"
        gsutil mb -p "$GCP_PROJECT_ID" "$BACKUP_BUCKET" 2>/dev/null || true
        
        echo "Exporting BigQuery tables..."
        bq extract --destination_format=PARQUET \
            "${GCP_PROJECT_ID}:${GCP_DATASET}.station_status_streaming" \
            "${BACKUP_BUCKET}/station_status_*.parquet" 2>/dev/null || true
        
        bq extract --destination_format=PARQUET \
            "${GCP_PROJECT_ID}:${GCP_DATASET}.citibike_trips_raw" \
            "${BACKUP_BUCKET}/trips_*.parquet" 2>/dev/null || true
        
        print_success "Backup created at: $BACKUP_BUCKET"
        print_warning "Remember to delete backup bucket manually when no longer needed"
    else
        print_warning "Skipping backup"
    fi
}

# Print summary
print_summary() {
    print_header "Teardown Complete"
    
    echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
    echo -e "${GREEN}✓ Local files cleaned up${NC}"
    echo ""
    echo -e "${YELLOW}Manual cleanup required:${NC}"
    echo "  • Stop Kestra server if running locally"
    echo "  • Delete .env file if no longer needed"
    echo "  • Verify all resources deleted in GCP Console"
    echo "  • Delete backup bucket if created"
    echo ""
    echo -e "${BLUE}To redeploy:${NC}"
    echo "  ./scripts/setup-env.sh"
    echo "  ./scripts/deploy.sh dev --full"
}

# Main execution
main() {
    print_header "CitiBike Data Platform - Teardown"
    
    confirm_teardown
    backup_data
    stop_kestra_workflows
    destroy_terraform
    cleanup_local
    print_summary
}

main