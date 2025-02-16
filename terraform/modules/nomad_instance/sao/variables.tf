variable "region" {
  type = string
  default = "sa-east-1"
}
variable "nomad_ami_name"{
  type = string
}
variable "ga_ips"{
}
variable "ip_for_pass"{
  default = ["37.99.85.146/32", "65.108.12.218/32"]
}
