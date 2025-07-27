# Enable the Service Networking API
resource "google_project_service" "service_networking" {
  service = "servicenetworking.googleapis.com"
}

# Private network for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-for-sql"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [google_project_service.service_networking]
}

# Cloud SQL for MySQL instance
resource "google_sql_database_instance" "mysql_instance" {
  name             = "${var.app_name}-mysql"
  region           = var.gcp_region
  database_version = "MYSQL_8_0"
  project          = var.gcp_project_id

  settings {
    tier = "db-n1-standard-1" # Adjust tier as needed

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    database_flags {
      name  = "sql_mode"
      value = "NO_ENGINE_SUBSTITUTION"
    }
    database_flags {
      name  = "character_set_server"
      value = "utf8mb4"
    }
    database_flags {
      name  = "collation_server"
      value = "utf8mb4_bin"
    }
    database_flags {
      name  = "default_time_zone"
      value = "SYSTEM"
    }
    database_flags {
      name  = "log_timestamps"
      value = "SYSTEM"
    }
    database_flags {
      name  = "default_authentication_plugin"
      value = "mysql_native_password"
    }
    database_flags {
      name  = "slow_query_log"
      value = "On"
    }
    database_flags {
      name  = "long_query_time"
      value = "5"
    }
    database_flags {
      name  = "log_queries_not_using_indexes"
      value = "Off"
    }
    database_flags {
      name  = "general_log"
      value = "On"
    }

    # Enable backups
    backup_configuration {
      enabled = true
    }
  }

  deletion_protection = false # Set to true for production environments

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Database for F-RevoCRM
resource "google_sql_database" "frevocrm_db" {
  name      = "frevocrm"
  instance  = google_sql_database_instance.mysql_instance.name
  charset   = "utf8mb4"
  collation = "utf8mb4_bin"
}

# Database user for the application
resource "google_sql_user" "frevocrm_user" {
  name     = var.db_user
  instance = google_sql_database_instance.mysql_instance.name
  password = var.db_password
}
