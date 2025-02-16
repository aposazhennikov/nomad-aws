datacenter = "$REGION"
bind_addr = "0.0.0.0"

data_dir = "/opt/nomad/"
log_level = "INFO"

advertise {
  http = "0.0.0.0"
}

server {
  enabled = true
  bootstrap_expect = 1
}

ports {
  http = 4646
}

client {
  enabled = true
}

telemetry {
  collection_interval        = "15s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

acl {
  enabled = true
}

tls {
  http = true
  rpc = true
  ca_file   = "/opt/certs/ca.pem"
  cert_file = "/opt/certs/server.pem"
  key_file  = "/opt/certs/server_key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}

plugin "raw_exec" {
    config {
      enabled = true
    }
}

plugin "docker" {

  config {

    allow_privileged = true
    extra_labels = [
      "job_id", "job_name",
      "node_id", "node_name",
      "namespace",
      "task_group_name", "task_name",
    ]

    volumes {
      enabled = true
    }

    logging {
      type = "json-file"

      config {
        max-size = "10m"
        max-file = 10
      }
    }
  }
}

consul {
  # The address to the Consul agent.
  address = "127.0.0.1:8501"
  token   = $token
  grpc_address = "127.0.0.1:8503"

  # TLS encryption
  ssl = true
  grpc_ca_file = "/opt/certs/ca.pem"
  ca_file   = "/opt/certs/ca.pem"
  cert_file = "/opt/certs/server.pem"
  key_file  = "/opt/certs/server_key.pem"
  verify_ssl = true

  # The service name to register the server and client with Consul.
  server_service_name = "nomad-server"
  client_service_name = "nomad-client"

  # Enables automatically registering the services.
  auto_advertise = true
}