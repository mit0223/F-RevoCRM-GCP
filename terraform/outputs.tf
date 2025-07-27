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

output "ssl_certificate_status" {
  description = "Status of the SSL certificate"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.app_ssl_cert[0].managed[0].status : "SSL not enabled"
}

output "instance_group_manager" {
  description = "Instance group manager details"
  value = {
    name   = google_compute_region_instance_group_manager.app_group.name
    region = google_compute_region_instance_group_manager.app_group.region
  }
}
