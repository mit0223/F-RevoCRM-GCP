#!/bin/bash

# F-RevoCRM Health Check Script
# This script checks the health of the deployed application

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${YELLOW}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if domain is set
if [ -z "$DOMAIN_NAME" ]; then
    print_error "DOMAIN_NAME environment variable is not set"
    exit 1
fi

# Check HTTP endpoint
print_status "Checking HTTP endpoint..."
if curl -f -s "http://$DOMAIN_NAME" > /dev/null; then
    print_success "HTTP endpoint is responding"
else
    print_error "HTTP endpoint is not responding"
fi

# Check HTTPS endpoint
print_status "Checking HTTPS endpoint..."
if curl -f -s "https://$DOMAIN_NAME" > /dev/null; then
    print_success "HTTPS endpoint is responding"
else
    print_error "HTTPS endpoint is not responding"
fi

# Check health endpoint
print_status "Checking health endpoint..."
if curl -f -s "https://$DOMAIN_NAME/health" > /dev/null; then
    print_success "Health endpoint is responding"
    curl -s "https://$DOMAIN_NAME/health" | jq .
else
    print_error "Health endpoint is not responding"
fi

# Check SSL certificate
print_status "Checking SSL certificate..."
ssl_info=$(echo | openssl s_client -connect "$DOMAIN_NAME:443" -servername "$DOMAIN_NAME" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    print_success "SSL certificate is valid"
    echo "$ssl_info"
else
    print_error "SSL certificate check failed"
fi

print_success "Health check completed"
