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


  locals {
    default_subnet_id = element(tolist(data.aws_subnet_ids.default.ids), 0)
  }

  resource "aws_instance" "redis" {

    ami             = data.aws_ami.debian.id
    instance_type   = "t2.micro"
    subnet_id       = local.default_subnet_id
    security_groups = [aws_security_group.redis_sg.id]
    user_data       = file("${path.module}/user_data_redis.sh")


    tags = { Name = "redis-${var.region}",
            Region = "${var.region}" }

    root_block_device {
      volume_size = 30
    }

    depends_on = [aws_security_group.redis_sg]
  }