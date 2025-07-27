#!/bin/bash
set -e

# F-RevoCRM GCP Deployment Script

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

# Check required environment variables
check_env_vars() {
    print_status "Checking required environment variables..."
    
    required_vars=(
        "GCP_PROJECT_ID"
        "DOMAIN_NAME"
        "DOCKERHUB_USERNAME"
        "DOCKERHUB_TOKEN"
        "GCP_SERVICE_ACCOUNT_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Environment variable $var is not set"
            exit 1
        fi
    done
    
    print_success "All required environment variables are set"
}

# Set up GCP authentication
setup_gcp_auth() {
    print_status "Setting up GCP authentication..."
    
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


# Login to Docker Hub
docker_login() {
    print_status "Logging into Docker Hub..."
    
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
    
    print_success "Docker Hub login successful"
}

# Build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    local image_tag="${DOCKERHUB_USERNAME}/f-revocrm:$(date +%Y%m%d-%H%M%S)"
    local latest_tag="${DOCKERHUB_USERNAME}/f-revocrm:latest"
    
    # Build image
    docker build -t "$image_tag" -t "$latest_tag" .
    
    # Push images
    docker push "$image_tag"
    docker push "$latest_tag"
    
    export DOCKER_IMAGE="$image_tag"
    print_success "Docker image built and pushed: $image_tag"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd terraform
    terraform init
    
    print_success "Terraform initialized"
}

# Deploy Phase 1 (without SSL)
deploy_phase1() {
    print_status "Starting Phase 1 deployment (without SSL)..."
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
gcp_project_id = "$GCP_PROJECT_ID"
domain_name    = "$DOMAIN_NAME"
docker_image   = "$DOCKER_IMAGE"
enable_ssl     = false
EOF
    
    # Plan and apply
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    # Get static IP
    export STATIC_IP=$(terraform output -raw static_ip_address)
    
    print_success "Phase 1 deployment completed"
    print_warning "Static IP Address: $STATIC_IP"
    print_warning "Please add DNS A record: $DOMAIN_NAME -> $STATIC_IP"
    print_warning "Wait for DNS propagation before proceeding to Phase 2"
}

# Deploy Phase 2 (with SSL)
deploy_phase2() {
    print_status "Starting Phase 2 deployment (with SSL)..."
    
    # Update terraform.tfvars to enable SSL
    cat > terraform.tfvars << EOF
gcp_project_id = "$GCP_PROJECT_ID"
domain_name    = "$DOMAIN_NAME"
docker_image   = "$DOCKER_IMAGE"
enable_ssl     = true
EOF
    
    # Plan and apply
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    print_success "Phase 2 deployment completed"
    print_success "Application is now available at: https://$DOMAIN_NAME"
}

# Check SSL certificate status
check_ssl_status() {
    print_status "Checking SSL certificate status..."
    
    local ssl_status=$(terraform output -raw ssl_certificate_status)
    print_status "SSL Certificate Status: $ssl_status"
    
    if [ "$ssl_status" = "ACTIVE" ]; then
        print_success "SSL certificate is active"
    else
        print_warning "SSL certificate is not yet active. Status: $ssl_status"
        print_warning "Please wait for the certificate to be provisioned"
    fi
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f /tmp/gcp-key.json
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main deployment function
main() {
    local phase="${1:-all}"
    
    print_status "Starting F-RevoCRM GCP deployment - Phase: $phase"
    
    case "$phase" in
        "build")
            check_env_vars
            docker_login
            build_and_push_image
            ;;
        "phase1")
            check_env_vars
            setup_gcp_auth
            init_terraform
            deploy_phase1
            ;;
        "phase2")
            check_env_vars
            setup_gcp_auth
            init_terraform
            deploy_phase2
            check_ssl_status
            ;;
        "all")
            check_env_vars
            setup_gcp_auth
            docker_login
            build_and_push_image
            init_terraform
            deploy_phase1
            
            print_warning ""
            print_warning "=================================="
            print_warning "PHASE 1 COMPLETED"
            print_warning "=================================="
            print_warning "Static IP: $STATIC_IP"
            print_warning "Please add DNS A record and run:"
            print_warning "./scripts/deploy.sh phase2"
            print_warning "=================================="
            ;;
        "destroy")
            check_env_vars
            setup_gcp_auth
            init_terraform
            print_warning "This will destroy all resources. Are you sure? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                terraform destroy -auto-approve
                print_success "All resources destroyed"
            else
                print_status "Destruction cancelled"
            fi
            ;;
        *)
            print_error "Usage: $0 {build|phase1|phase2|all|destroy}"
            exit 1
            ;;
    esac
    
    print_success "Deployment script completed!"
}

# Run main function with all arguments
main "$@"
