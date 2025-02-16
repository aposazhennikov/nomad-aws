job "fabio-t" {
  datacenters = ["*"]
  type = "system"

  group "fabio" {
    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "lb" {
        static = 9999
      }
      port "ui" {
        static = 9998
      }
    }

    task "fabio" {
      driver = "docker"

      config {
        image = "fabiolb/fabio"
        network_mode = "host"
        ports = ["lb", "ui", "http", "https"]
      }
      
      env {
        CONSUL_HTTP_TOKEN = "$token"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
