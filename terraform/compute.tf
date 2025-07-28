# Reserve static IP address
resource "google_compute_global_address" "static_ip" {
  name = "${var.app_name}-static-ip"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app_service" {
  count    = var.deploy_containers ? 1 : 0
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

      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.app_storage.name
      }

      env {
        name  = "STORAGE_PATH"
        value = "/var/www/html"
      }

      # GCS FUSE optimization environment variables
      env {
        name  = "GCSFUSE_STAT_CACHE_TTL"
        value = "1h"
      }

      env {
        name  = "GCSFUSE_TYPE_CACHE_TTL"
        value = "1h"
      }

      # GCS FUSE write optimization (increased for large file operations)
      env {
        name  = "GCSFUSE_WRITE_GLOBAL_MAX_BLOCKS"
        value = "1024"
      }

      env {
        name  = "GCSFUSE_WRITE_MAX_BLOCKS_PER_FILE"
        value = "64"
      }

      env {
        name  = "GCSFUSE_DISABLE_PARALLEL_DIROPS"
        value = "true"
      }

      # Additional GCS FUSE performance tuning
      env {
        name  = "GCSFUSE_WRITE_BUFFER_SIZE"
        value = "1048576" # 1MB buffer
      }

      env {
        name  = "GCSFUSE_SEQUENTIAL_READ_SIZE"
        value = "2097152" # 2MB read buffer
      }

      # Resource limits
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      # Startup probe
      startup_probe {
        timeout_seconds   = 5
        period_seconds    = 20
        failure_threshold = 24
        http_get {
          path = "/"
          port = 80
        }
      }

      # Volume mounts for persistent storage
      volume_mounts {
        name       = "app-storage"
        mount_path = "/var/www/html"
      }
    }

    # Volume configuration for Cloud Storage
    volumes {
      name = "app-storage"
      gcs {
        bucket    = google_storage_bucket.app_storage.name
        read_only = false
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

  depends_on = [
    google_sql_database_instance.mysql_instance,
    google_vpc_access_connector.connector
  ]
}

# VPC Access Connector for Cloud Run to access private resources
resource "google_vpc_access_connector" "connector" {
  name          = "${var.app_name}-connector"
  region        = var.gcp_region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name

  depends_on = [
    google_compute_network.vpc,
    google_compute_subnetwork.subnet
  ]
}

# Cloud Storage bucket for persistent storage
resource "google_storage_bucket" "app_storage" {
  name          = "${var.gcp_project_id}-${var.app_name}-storage"
  location      = var.gcp_region
  force_destroy = true

  versioning {
    enabled = false
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
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

# IAM policy for Cloud Storage access
resource "google_project_iam_member" "cloudrun_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Storage bucket IAM binding
resource "google_storage_bucket_iam_binding" "app_storage_binding" {
  bucket = google_storage_bucket.app_storage.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.cloudrun_sa.email}"
  ]
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
  count    = var.deploy_containers ? 1 : 0
  location = google_cloud_run_v2_service.app_service[0].location
  service  = google_cloud_run_v2_service.app_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

# Backend service for Load Balancer
resource "google_compute_backend_service" "app_backend" {
  count       = var.deploy_containers ? 1 : 0
  name        = "${var.app_name}-backend"
  protocol    = "HTTP"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg[0].id
  }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  count                 = var.deploy_containers ? 1 : 0
  name                  = "${var.app_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = google_cloud_run_v2_service.app_service[0].name
  }
}

# URL map for HTTP
resource "google_compute_url_map" "app_url_map_http" {
  count = var.deploy_containers ? 1 : 0
  name  = "${var.app_name}-url-map-http"

  # When SSL is disabled, serve content directly
  default_service = var.enable_ssl ? null : google_compute_backend_service.app_backend[0].id

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
  count           = var.enable_ssl && var.deploy_containers ? 1 : 0
  name            = "${var.app_name}-url-map-https"
  default_service = google_compute_backend_service.app_backend[0].id
}

# HTTP(S) proxy
resource "google_compute_target_http_proxy" "app_http_proxy" {
  count   = var.deploy_containers ? 1 : 0
  name    = "${var.app_name}-http-proxy"
  url_map = google_compute_url_map.app_url_map_http[0].id
}

resource "google_compute_target_https_proxy" "app_https_proxy" {
  count            = var.enable_ssl && var.deploy_containers ? 1 : 0
  name             = "${var.app_name}-https-proxy"
  url_map          = google_compute_url_map.app_url_map_https[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_ssl_cert[0].id]
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "app_http_forwarding_rule" {
  count      = var.deploy_containers ? 1 : 0
  name       = "${var.app_name}-http-forwarding-rule"
  target     = google_compute_target_http_proxy.app_http_proxy[0].id
  port_range = "80"
  ip_address = google_compute_global_address.static_ip.address
}

# Global forwarding rule for HTTPS (only when SSL is enabled)
resource "google_compute_global_forwarding_rule" "app_https_forwarding_rule" {
  count      = var.enable_ssl && var.deploy_containers ? 1 : 0
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
