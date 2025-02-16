data "aws_ami" "nomad" {
  most_recent = true
  filter {
    name   = "name"
    values = [var.ami_name]
  }
  owners = ["self"]
}

data "aws_ami" "debian" {
  most_recent = true
  filter {
    name   = "name"
    values = ["*debian*-*12*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["136693071363"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

locals {
  default_subnet_id = element(tolist(data.aws_subnet_ids.default.ids), 0)
  global_accelerator_ips = [for ip in aws_globalaccelerator_accelerator.ga.ip_sets[0].ip_addresses : "${ip}/32"]
  nomad_sg_ingress_cidrs = concat(["37.99.2.223/32", "65.108.12.218/32"], local.global_accelerator_ips)
  ip_for_pass = ["37.99.2.223/32", "65.108.12.218/32"]
}

resource "aws_security_group" "nomad_sg" {
  name   = "nomad-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    from_port   = 9998
    to_port     = 9998
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = local.nomad_sg_ingress_cidrs
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = local.ip_for_pass
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nomad Security Group"
  }
}

resource "aws_security_group" "redis_sg" {
  name   = "redis-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Redis Security Group"
  }
}

resource "aws_instance" "nomad" {
  ami             = data.aws_ami.nomad.id
  instance_type   = "t2.medium"
  subnet_id       = local.default_subnet_id
  security_groups = [aws_security_group.nomad_sg.id]

  tags = {
    Name   = "nomad-${var.region}"
    Region = var.region
  }

  root_block_device {
    volume_size = 30
  }
  depends_on = [aws_security_group.nomad_sg]
}

resource "aws_instance" "redis" {
  ami             = data.aws_ami.debian.id
  instance_type   = "t2.micro"
  subnet_id       = local.default_subnet_id
  security_groups = [aws_security_group.redis_sg.id]
  user_data       = var.user_data

  tags = {
    Name   = "redis-${var.region}"
    Region = var.region
  }

  root_block_device {
    volume_size = 30
  }

  depends_on = [aws_security_group.redis_sg]
}

resource "aws_globalaccelerator_accelerator" "ga" {
  name             = "nomad-ga"
  ip_address_type  = "IPV4"
  enabled          = true
}

resource "aws_globalaccelerator_listener" "ga_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.ga.id
  protocol        = "TCP"
  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "ga_endpoint_group" {
  listener_arn = aws_globalaccelerator_listener.ga_listener.id

  endpoint_configuration {
    endpoint_id = aws_instance.nomad.id
    weight      = 128
    client_ip_preservation_enabled = true
  }

  health_check_port     = 9999
  health_check_protocol = "TCP"

  port_override {
    endpoint_port = 9999
    listener_port = 80
  }
}
