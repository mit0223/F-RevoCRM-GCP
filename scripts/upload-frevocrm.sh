#!/bin/bash
set -e

# F-RevoCRM Upload Script for Cloud Storage

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
if [ -z "$GCP_PROJECT_ID" ]; then
    print_error "GCP_PROJECT_ID environment variable is not set"
    exit 1
fi

# Set up GCP authentication
setup_gcp_auth() {
    print_status "Setting up GCP authentication..."
    
    if [ -z "$GCP_SERVICE_ACCOUNT_KEY" ]; then
        print_error "GCP_SERVICE_ACCOUNT_KEY environment variable is not set"
        exit 1
    fi
    
    echo "$GCP_SERVICE_ACCOUNT_KEY" | base64 -d > /tmp/gcp-key.json
    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-key.json
    gcloud auth activate-service-account --key-file=/tmp/gcp-key.json
    gcloud config set project "$GCP_PROJECT_ID"
    
    print_success "GCP authentication configured"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f /tmp/gcp-key.json
    rm -rf "$TEMP_DIR"
}

# Trap to ensure cleanup
trap cleanup EXIT

# Set variables
BUCKET_NAME="${GCP_PROJECT_ID}-f-revocrm-storage"
F_REVOCRM_VERSION="7.4.1"
TEMP_DIR="/tmp/frevocrm-upload"

print_status "Starting F-RevoCRM upload to Cloud Storage..."

# Set up authentication
setup_gcp_auth

# Create temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download F-RevoCRM if not exists
if [ ! -f "F-RevoCRM-${F_REVOCRM_VERSION}.zip" ]; then
    print_status "Downloading F-RevoCRM v${F_REVOCRM_VERSION}..."
    curl -L -o "F-RevoCRM-${F_REVOCRM_VERSION}.zip" \
        "https://github.com/thinkingreed-inc/F-RevoCRM/archive/refs/tags/v${F_REVOCRM_VERSION}.zip"
fi

# Extract F-RevoCRM
print_status "Extracting F-RevoCRM..."
unzip -q "F-RevoCRM-${F_REVOCRM_VERSION}.zip"

# Check if bucket exists, if not wait for it to be created
print_status "Checking Cloud Storage bucket..."
BUCKET_EXISTS=false
for i in {1..30}; do
    if gsutil ls -b "gs://${BUCKET_NAME}" > /dev/null 2>&1; then
        BUCKET_EXISTS=true
        break
    fi
    print_status "Waiting for bucket gs://${BUCKET_NAME} to be created... (attempt $i/30)"
    sleep 10
done

if [ "$BUCKET_EXISTS" = false ]; then
    print_error "Bucket gs://${BUCKET_NAME} does not exist or is not accessible after waiting"
    exit 1
fi

# Check if F-RevoCRM is already uploaded
if gsutil ls "gs://${BUCKET_NAME}/index.php" > /dev/null 2>&1; then
    print_warning "F-RevoCRM files already exist in gs://${BUCKET_NAME}"
    print_warning "Skipping upload. Use 'gsutil -m rm -r gs://${BUCKET_NAME}/*' to clear bucket first."
    exit 0
fi

# Upload F-RevoCRM files to Cloud Storage
print_status "Uploading F-RevoCRM files to gs://${BUCKET_NAME}..."

# Upload files with parallel processing and progress
gsutil -m cp -r "F-RevoCRM-${F_REVOCRM_VERSION}/"* "gs://${BUCKET_NAME}/"

# Verify upload
print_status "Verifying upload..."
if gsutil ls "gs://${BUCKET_NAME}/index.php" > /dev/null 2>&1; then
    print_success "F-RevoCRM files uploaded successfully to gs://${BUCKET_NAME}"
else
    print_error "Upload verification failed"
    exit 1
fi

print_success "F-RevoCRM upload completed!"
print_status "Files are now available in Cloud Storage bucket: gs://${BUCKET_NAME}"
