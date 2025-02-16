datacenter = "$REGION"
data_dir = "/opt/consul/"
log_level = "INFO"
bootstrap_expect = 1
server = true

client_addr = "0.0.0.0"
bind_addr = "127.0.0.1"


# Need for service check enable
enable_local_script_checks = true

# Enable or disable UI, default - enabled=true
ui_config {
  enabled = true
}

# Ports part
ports {
  https  = 8501
  grpc_tls = 8503
}

# For grpc connect, sidecar connect turning on
connect {
  enabled = true
}

# DNS part
dns_config {
  enable_truncate = true
  only_passing = true
        service_ttl {
                "*.consul" = "10s"
        }
}

recursors = ["1.1.1.1","8.8.8.8"]

# TLS part
tls {
  defaults {
    ca_file   = "/etc/consul.d/certs/ca.pem"
    cert_file = "/etc/consul.d/certs/server.pem"
    key_file  = "/etc/consul.d/certs/server_key.pem"

    verify_incoming = false
    verify_outgoing = true
    verify_server_hostname = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
  grpc {
    verify_incoming = false
  }
}

auto_encrypt {
  allow_tls = false
}

# Enable ACL thats why we need to bootstrap our server first
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}
performance {
  raft_multiplier = 1
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}