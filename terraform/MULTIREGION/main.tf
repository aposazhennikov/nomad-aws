# Create Global Accelerator in Frankfurt(eu-central-1).
resource "aws_globalaccelerator_accelerator" "ga" {
  name             = "nomad-ga"
  ip_address_type  = "IPV4"
  enabled          = true
}

# Create Global Accelerator listener on port 80 in Frankfurt(eu-central-1).
resource "aws_globalaccelerator_listener" "ga_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.ga.id
  protocol        = "TCP"
  port_range {
    from_port = 80
    to_port   = 80
  }
}

# Create local variable for Nomad Security Groups
locals {
  global_accelerator_ips = [for ip in aws_globalaccelerator_accelerator.ga.ip_sets[0].ip_addresses : "${ip}/32"]
}

# Create EC2 Instances in Frankfurt(eu-central-1). Nomad and Redis.
module "nomad_fra" {
  source           = "../modules/nomad_instance/fra"
  nomad_ami_name   = var.nomad_ami_name
  ga_ips           = local.global_accelerator_ips
  ip_for_pass      = ["37.99.85.146/32", "65.108.12.218/32"]

}
module "redis_fra" {
  source           = "../modules/redis_instance/fra"
}


# Create EC2 Instances in Mumbai(ap-south-1). Nomad and Redis.
module "nomad_mumbai" {
  source           = "../modules/nomad_instance/mumbai"
  nomad_ami_name   = var.nomad_ami_name
  ga_ips           = local.global_accelerator_ips
  ip_for_pass      = ["37.99.85.146/32", "65.108.12.218/32"]

}
module "redis_mumbai" {
  source           = "../modules/redis_instance/mumbai"
}


# Create EC2 Instances in Ohio(us-east-2). Nomad and Redis.
module "nomad_ohio" {
  source           = "../modules/nomad_instance/ohio"
  nomad_ami_name   = var.nomad_ami_name
  ga_ips           = local.global_accelerator_ips
  ip_for_pass      = ["37.99.85.146/32", "65.108.12.218/32"]
}
module "redis_ohio" {
  source           = "../modules/redis_instance/ohio"
}


# Create EC2 Instances in Sao Paulo(sa-east-1). Nomad and Redis.
module "nomad_sao" {
  source           = "../modules/nomad_instance/sao"
  nomad_ami_name   = var.nomad_ami_name
  ga_ips           = local.global_accelerator_ips
  ip_for_pass      = ["37.99.85.146/32", "65.108.12.218/32"]

}
module "redis_sao" {
  source           = "../modules/redis_instance/sao"
}

# Create Global Accelerator Endpoint Group for every region
module "ga_fra" {
  source           = "../modules/ga/fra"
  ec2_id           = module.nomad_fra.id
  ga_listener_id   = aws_globalaccelerator_listener.ga_listener.id
}
module "ga_mumbai" {
  source           = "../modules/ga/mumbai"
  ec2_id           = module.nomad_mumbai.id
  ga_listener_id   = aws_globalaccelerator_listener.ga_listener.id
}
module "ga_ohio" {
  source           = "../modules/ga/ohio"
  ec2_id           = module.nomad_ohio.id
  ga_listener_id   = aws_globalaccelerator_listener.ga_listener.id
}
module "ga_sao" {
  source           = "../modules/ga/sao"
  ec2_id           = module.nomad_sao.id
  ga_listener_id   = aws_globalaccelerator_listener.ga_listener.id
}