

variable "userpass_default_lease_ttl" {
  default = "28800s"
  type = string
}

variable "userpass_max_lease_ttl" {
  default = "28800s"
  type = string
}

variable "aws_default_lease_ttl_seconds" {
  default = "120"
  type = string
}

variable "aws_max_lease_ttl_seconds" {
  default = "240"
  type = string
}

variable "aws_profile" {
  default = "default"
  type = string
}

variable "name" {
  default = "aws-developer"
  type = string
}