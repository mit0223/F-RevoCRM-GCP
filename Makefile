.PHONY: help build phase1 phase2 deploy destroy status clean

# Default target
help: ## Show this help message
	@echo "F-RevoCRM GCP Deployment"
	@echo "========================"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build and push Docker image
build: ## Build and push Docker image to Docker Hub
	@echo "Building and pushing Docker image..."
	./scripts/deploy.sh build

# Phase 1: Deploy without SSL to get static IP
phase1: ## Deploy Phase 1 (without SSL) to get static IP
	@echo "Deploying Phase 1 (without SSL)..."
	./scripts/deploy.sh phase1

# Phase 2: Deploy with SSL after DNS setup
phase2: ## Deploy Phase 2 (with SSL) after DNS configuration
	@echo "Deploying Phase 2 (with SSL)..."
	./scripts/deploy.sh phase2

# Full deployment (Phase 1 only, requires manual DNS setup before Phase 2)
deploy: ## Full deployment (Phase 1, then manual DNS setup, then run 'make phase2')
	@echo "Starting full deployment..."
	./scripts/deploy.sh all

# Destroy all resources
destroy: ## Destroy all GCP resources
	@echo "Destroying all resources..."
	./scripts/deploy.sh destroy

# Check deployment status
status: ## Check the status of the deployment
	@echo "Checking deployment status..."
	@cd terraform && terraform output

# Check SSL certificate status
ssl-status: ## Check SSL certificate status
	@echo "Checking SSL certificate status..."
	@cd terraform && terraform output ssl_certificate_status

# Clean up local files
clean: ## Clean up local temporary files
	@echo "Cleaning up..."
	@rm -f terraform/terraform.tfvars
	@docker system prune -f

# Initialize Terraform
init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	@cd terraform && terraform init

# Validate Terraform configuration
validate: ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	@cd terraform && terraform validate

# Format Terraform files
fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

# Plan Terraform changes
plan: ## Plan Terraform changes
	@echo "Planning Terraform changes..."
	@cd terraform && terraform plan -var-file=terraform.tfvars

# Show Terraform state
show: ## Show Terraform state
	@echo "Showing Terraform state..."
	@cd terraform && terraform show

# Docker commands
docker-build: ## Build Docker image locally
	@echo "Building Docker image locally..."
	@docker build -t f-revocrm:local .

docker-run: ## Run Docker container locally
	@echo "Running Docker container locally..."
	@docker run -p 8080:80 f-revocrm:local

# Development helpers
dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	@echo "Installing pre-commit hooks..."
	@echo "Development environment ready!"

# Logs and monitoring
logs: ## View application logs from GCP
	@echo "Viewing application logs..."
	@cd terraform && gcloud logging read "resource.type=gce_instance AND resource.labels.instance_name:f-revocrm" --limit=50 --format="table(timestamp,severity,textPayload)"

# Health check
health: ## Check application health
	@echo "Checking application health..."
	@curl -f http://localhost:8080/ || echo "Health check failed"
