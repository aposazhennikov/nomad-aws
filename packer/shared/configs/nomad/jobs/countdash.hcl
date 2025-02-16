job "countdash" {
  datacenters = ["*"]
  type = "service"

  group "api" {
    network {
      port "api" {
        to = 9001
      }
    }

    service {
      name = "count-api"
      port = "api"
      tags = ["urlprefix-/api strip=/api"]
    }

    task "web" {
      driver = "docker"

      config {
        image = "hashicorpdev/counter-api:v3"
        ports = ["api"]
      }
    }
  }

  group "dashboard" {
    network {
      port "http" {
        to = 9002
      }
    }

    service {
      name = "count-dashboard"
      port = "http"
      tags = ["urlprefix-/"]
      check {
        name     = "alive"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "dashboard" {
      driver = "docker"

      template {
        destination=".env"
        env = true
        data = <<EOF
        COUNTING_SERVICE_URL=http://{{ range service "count-api" }}{{ .Address }}:{{ .Port }}{{ end }}
        EOF
      }

      config {
        image = "hashicorpdev/counter-dashboard:v3"
        ports = ["http"]
      }
    }
  }
}