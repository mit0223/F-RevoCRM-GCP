output "static_ip_address" {
  description = "The static IP address assigned to the load balancer"
  value       = google_compute_global_address.static_ip.address
}

output "domain_name" {
  description = "The domain name for the application"
  value       = var.domain_name
}

output "http_url" {
  description = "HTTP URL for the application"
  value       = "http://${var.domain_name}"
}

output "https_url" {
  description = "HTTPS URL for the application (when SSL is enabled)"
  value       = var.enable_ssl ? "https://${var.domain_name}" : "SSL not enabled"
}

output "ssl_certificate_name" {
  description = "The name of the managed SSL certificate."
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.app_ssl_cert[0].name : "SSL not enabled"
}

output "cloudrun_service_url" {
  description = "Cloud Run service URL"
  value       = var.deploy_containers ? google_cloud_run_v2_service.app_service[0].uri : "Containers not deployed"
}

output "cloudrun_service_name" {
  description = "Cloud Run service name"
  value       = var.deploy_containers ? google_cloud_run_v2_service.app_service[0].name : "Containers not deployed"
}

output "app_storage_bucket" {
  description = "Cloud Storage bucket for persistent application data"
  value       = google_storage_bucket.app_storage.name
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket name (for gsutil commands)"
  value       = google_storage_bucket.app_storage.name
}

output "app_storage_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.app_storage.url
}

output "db_connection_name" {
  description = "The connection name of the Cloud SQL instance."
  value       = google_sql_database_instance.mysql_instance.connection_name
}

output "db_private_ip" {
  description = "The private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.mysql_instance.private_ip_address
}
