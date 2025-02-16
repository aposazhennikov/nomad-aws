data "aws_ami" "nomad" {
  most_recent = true
  filter {
    name   = "name"
    values = [var.nomad_ami_name]
  }
  owners = ["self"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }
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
    cidr_blocks = var.ip_for_pass
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
    cidr_blocks = var.ip_for_pass
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ip_for_pass
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.ip_for_pass
  }

  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = var.ip_for_pass
  }

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = var.ip_for_pass
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

locals {
  default_subnet_id = element(tolist(data.aws_subnet_ids.default.ids), 0)
  nomad_sg_ingress_cidrs = concat(var.ip_for_pass, var.ga_ips)
}

resource "aws_instance" "nomad" {

  ami             = data.aws_ami.nomad.id
  instance_type   = "t2.medium"
  availability_zone  = var.availability_zone
  subnet_id       = local.default_subnet_id
  security_groups = [aws_security_group.nomad_sg.id]
  user_data       = file("${path.module}/user_data.sh")

  tags = { Name = "nomad-${var.region}",
           Region = "${var.region}" }

  root_block_device {
    volume_size = 30
  }

  depends_on = [aws_security_group.nomad_sg]
}

