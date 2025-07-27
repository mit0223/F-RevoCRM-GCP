#!/bin/bash
set -e

echo "Setting up F-RevoCRM GCP deployment environment..."

# Install additional tools
echo "Installing additional tools..."
sudo apt-get update
sudo apt-get install -y make jq

# Initialize Terraform if needed
if [ ! -f "terraform/.terraform.lock.hcl" ]; then
    echo "Initializing Terraform..."
    cd terraform
    terraform init
    cd ..
fi

# Set up gcloud authentication if service account key is provided
if [ -n "$GCP_SERVICE_ACCOUNT_KEY" ]; then
    echo "Setting up GCP authentication..."
    echo "$GCP_SERVICE_ACCOUNT_KEY" | base64 -d > /tmp/gcp-key.json
    gcloud auth activate-service-account --key-file=/tmp/gcp-key.json
    gcloud config set project "$GCP_PROJECT_ID"
    rm /tmp/gcp-key.json
fi

# Login to Docker Hub if credentials are provided
if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
    echo "Logging into Docker Hub..."
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
fi

echo "Environment setup complete!"
