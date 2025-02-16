packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "ami_filter" {
  type    = string
  default = "*debian*-*12*"
}

variable "ami_owner" {
  type    = string
  default = "136693071363"  # Debian owner ID
}

source "amazon-ebs" "debian" {
  region                 = var.aws_region
  source_ami_filter {
    filters = {
      name                = var.ami_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    most_recent = true
    owners      = [var.ami_owner]
  }
  instance_type          = "t2.micro"
  ssh_username           = "admin"
  ami_name               = "Nomad-v1"
}

build {
  sources = [
    "source.amazon-ebs.debian"
  ]

  provisioner "file" {
    source      = "C:\\keys\\my_company.pub"
    destination = "/home/admin/my_company.pub"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /home/admin/.ssh",
      "cat /home/admin/my_company.pub >> /home/admin/.ssh/authorized_keys",
      "chmod 600 /home/admin/.ssh/authorized_keys",
      "rm /home/admin/my_company.pub"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/shared",
      "sudo chown -R admin:admin /opt/shared"
    ]
  }

  provisioner "file" {
    source      = "./shared"
    destination = "/opt"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /opt/shared/scripts/setup_packer.sh",
      "sudo /opt/shared/scripts/setup_packer.sh"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /opt/shared/scripts/generate_certs.sh",
      "sudo /opt/shared/scripts/generate_certs.sh us-east-2"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /opt/shared/scripts/initialization.sh",
      "sudo /opt/shared/scripts/initialization.sh us-east-2"
    ]
  }
}
