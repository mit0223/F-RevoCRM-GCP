#!/bin/bash
set -e

echo "Setting up F-RevoCRM GCP deployment environment..."

# Install additional tools
echo "Installing additional tools..."
sudo apt-get update
sudo apt-get install -y make jq curl wget gnupg lsb-release

# Install Google Cloud SDK
echo "Installing Google Cloud SDK..."
if ! command -v gcloud &> /dev/null; then
    # Alternative installation method using snap (more reliable in containers)
    if command -v snap &> /dev/null; then
        echo "Installing gcloud via snap..."
        sudo snap install google-cloud-cli --classic
    else
        # Fallback to APT installation
        echo "Installing gcloud via APT..."
        # Add the Cloud SDK distribution URI as a package source
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        
        # Import the Google Cloud Platform public key
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        
        # Update and install the Cloud SDK
        sudo apt-get update && sudo apt-get install -y google-cloud-sdk
    fi
    
    echo "Google Cloud SDK installed successfully"
else
    echo "Google Cloud SDK already installed"
fi

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
