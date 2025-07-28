#!/bin/bash
set -e

# F-RevoCRM GCP Destroy Script - Handles VPC peering dependency issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set up GCP authentication
setup_gcp_auth() {
    print_status "Setting up GCP authentication..."
    
    if [ -z "$GCP_SERVICE_ACCOUNT_KEY" ]; then
        print_error "GCP_SERVICE_ACCOUNT_KEY environment variable not set"
        exit 1
    fi
    
    echo "$GCP_SERVICE_ACCOUNT_KEY" | base64 -d > /tmp/gcp-key.json
    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-key.json
    gcloud auth activate-service-account --key-file=/tmp/gcp-key.json
    gcloud config set project "$GCP_PROJECT_ID"
    
    print_success "GCP authentication configured"
}

# Cleanup GCP credentials file
cleanup_gcp_auth() {
    print_status "Cleaning up GCP credentials..."
    rm -f /tmp/gcp-key.json
}

# Trap to ensure cleanup
trap cleanup_gcp_auth EXIT

# Phase 1: Destroy application services first
destroy_app_services() {
    print_status "Phase 1: Destroying application services..."
    
    cd terraform
    
    # Target specific resources that depend on VPC connection
    terraform destroy -target="google_cloud_run_v2_service.app_service" -auto-approve || print_warning "Cloud Run service already destroyed or not found"
    terraform destroy -target="google_vpc_access_connector.connector" -auto-approve || print_warning "VPC Access Connector already destroyed or not found"
    
    print_success "Phase 1 completed"
}

# Phase 2: Destroy database services
destroy_database_services() {
    print_status "Phase 2: Destroying database services..."
    
    # Destroy database user and database first
    terraform destroy -target="google_sql_user.frevocrm_user" -auto-approve || print_warning "Database user already destroyed or not found"
    terraform destroy -target="google_sql_database.frevocrm_db" -auto-approve || print_warning "Database already destroyed or not found"
    
    # Destroy the Cloud SQL instance
    terraform destroy -target="google_sql_database_instance.mysql_instance" -auto-approve || print_warning "SQL instance already destroyed or not found"
    
    print_success "Phase 2 completed"
}

# Phase 3: Destroy VPC connection
destroy_vpc_connection() {
    print_status "Phase 3: Destroying VPC service networking connection..."
    
    # Wait a bit for the SQL instance to be fully destroyed
    print_status "Waiting for SQL instance to be fully destroyed..."
    sleep 30
    
    # Destroy the service networking connection
    terraform destroy -target="google_service_networking_connection.private_vpc_connection" -auto-approve || print_warning "VPC connection already destroyed or not found"
    
    print_success "Phase 3 completed"
}

# Phase 4: Destroy remaining infrastructure
destroy_remaining_infrastructure() {
    print_status "Phase 4: Destroying remaining infrastructure..."
    
    # Destroy all remaining resources
    terraform destroy -auto-approve
    
    print_success "Phase 4 completed"
}

# Manual cleanup guidance
provide_manual_cleanup_guidance() {
    print_warning ""
    print_warning "=============================================="
    print_warning "MANUAL CLEANUP GUIDANCE"
    print_warning "=============================================="
    print_warning "If automatic destruction fails, please:"
    print_warning "1. Go to GCP Console -> VPC Network -> VPC network peering"
    print_warning "2. Delete any remaining peering connections manually"
    print_warning "3. Go to SQL -> Instances and ensure all instances are deleted"
    print_warning "4. Run: terraform destroy -auto-approve"
    print_warning "=============================================="
}

# Main destroy function
main() {
    print_status "Starting F-RevoCRM GCP infrastructure destruction..."
    
    if [ -z "$GCP_PROJECT_ID" ]; then
        print_error "GCP_PROJECT_ID environment variable not set"
        exit 1
    fi
    
    setup_gcp_auth
    
    print_warning "This will destroy ALL F-RevoCRM infrastructure. Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Destruction cancelled"
        exit 0
    fi
    
    # Execute destruction phases
    destroy_app_services
    destroy_database_services
    destroy_vpc_connection
    destroy_remaining_infrastructure
    
    print_success "Infrastructure destruction completed successfully!"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
