# Reserve static IP address
resource "google_compute_global_address" "static_ip" {
  name = "${var.app_name}-static-ip"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app_service" {
  name     = "${var.app_name}-service"
  location = var.gcp_region

  template {
    containers {
      image = var.docker_image

      ports {
        container_port = 80
      }

      # Environment variables for database connection
      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.mysql_instance.private_ip_address
      }

      env {
        name  = "DB_NAME"
        value = google_sql_database.frevocrm_db.name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      # Resource limits
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    # Scaling configuration
    scaling {
      min_instance_count = 0
      max_instance_count = 100
    }

    # Service account for Cloud Run
    service_account = google_service_account.cloudrun_sa.email

    # VPC connector for private database access
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# VPC Access Connector for Cloud Run to access private resources
resource "google_vpc_access_connector" "connector" {
  name          = "${var.app_name}-connector"
  region        = var.gcp_region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
}

# Service account for Cloud Run
resource "google_service_account" "cloudrun_sa" {
  account_id   = "${var.app_name}-cloudrun-sa"
  display_name = "Cloud Run Service Account"
}

# IAM policy for Cloud Run service account
resource "google_project_iam_member" "cloudrun_sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# IAM policy for Secret Manager access
resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Secret Manager for database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.app_name}-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password

  depends_on = [
    google_project_iam_member.cloudrun_secret_accessor
  ]
}

# IAM binding for Cloud Run to access Secret Manager
resource "google_secret_manager_secret_iam_binding" "binding" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.cloudrun_sa.email}"
  ]

  depends_on = [
    google_service_account.cloudrun_sa
  ]
}

# Allow unauthenticated access to Cloud Run service
resource "google_cloud_run_service_iam_binding" "noauth" {
  location = google_cloud_run_v2_service.app_service.location
  service  = google_cloud_run_v2_service.app_service.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

# Backend service for Load Balancer
resource "google_compute_backend_service" "app_backend" {
  name        = "${var.app_name}-backend"
  protocol    = "HTTP"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "${var.app_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = google_cloud_run_v2_service.app_service.name
  }
}

# URL map for HTTP
resource "google_compute_url_map" "app_url_map_http" {
  name = "${var.app_name}-url-map-http"

  # When SSL is disabled, serve content directly
  default_service = var.enable_ssl ? null : google_compute_backend_service.app_backend.id

  # When SSL is enabled, redirect HTTP to HTTPS
  dynamic "default_url_redirect" {
    for_each = var.enable_ssl ? [1] : []
    content {
      https_redirect = true
      strip_query    = false
    }
  }
}

# URL map for HTTPS (only when SSL is enabled)
resource "google_compute_url_map" "app_url_map_https" {
  count           = var.enable_ssl ? 1 : 0
  name            = "${var.app_name}-url-map-https"
  default_service = google_compute_backend_service.app_backend.id
}

# HTTP(S) proxy
resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "${var.app_name}-http-proxy"
  url_map = google_compute_url_map.app_url_map_http.id
}

resource "google_compute_target_https_proxy" "app_https_proxy" {
  count            = var.enable_ssl ? 1 : 0
  name             = "${var.app_name}-https-proxy"
  url_map          = google_compute_url_map.app_url_map_https[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_ssl_cert[0].id]
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "app_http_forwarding_rule" {
  name       = "${var.app_name}-http-forwarding-rule"
  target     = google_compute_target_http_proxy.app_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.static_ip.address
}

# Global forwarding rule for HTTPS (only when SSL is enabled)
resource "google_compute_global_forwarding_rule" "app_https_forwarding_rule" {
  count      = var.enable_ssl ? 1 : 0
  name       = "${var.app_name}-https-forwarding-rule"
  target     = google_compute_target_https_proxy.app_https_proxy[0].id
  port_range = "443"
  ip_address = google_compute_global_address.static_ip.address
}

# Managed SSL certificate (only when SSL is enabled)
resource "google_compute_managed_ssl_certificate" "app_ssl_cert" {
  count = var.enable_ssl ? 1 : 0
  name  = "${var.app_name}-ssl-cert"

  managed {
    domains = [var.domain_name]
  }
}
