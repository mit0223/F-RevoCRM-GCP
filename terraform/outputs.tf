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
  value       = google_cloud_run_v2_service.app_service.uri
}

output "cloudrun_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.app_service.name
}

output "db_connection_name" {
  description = "The connection name of the Cloud SQL instance."
  value       = google_sql_database_instance.mysql_instance.connection_name
}

output "db_private_ip" {
  description = "The private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.mysql_instance.private_ip_address
}
