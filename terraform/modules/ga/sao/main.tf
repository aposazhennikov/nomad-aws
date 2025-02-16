# Create GA endpoint group and add EC2 id's to it.
resource "aws_globalaccelerator_endpoint_group" "ga_endpoint_group" {
  listener_arn = var.ga_listener_id

  endpoint_configuration {
    endpoint_id                    = var.ec2_id
    weight                         = 128
    client_ip_preservation_enabled = true
  }

  health_check_port     = 9999
  health_check_protocol = "TCP"

  port_override {
    endpoint_port = 9999
    listener_port = 80
  }
}
