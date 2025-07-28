variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-northeast1-a"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "f-revocrm"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "enable_ssl" {
  description = "Enable SSL certificate creation and HTTPS"
  type        = bool
  default     = false
}

variable "db_user" {
  description = "The username for the database user."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "The password for the database user."
  type        = string
  sensitive   = true
}

variable "deploy_containers" {
  description = "Whether to deploy Cloud Run containers"
  type        = bool
  default     = true
}
