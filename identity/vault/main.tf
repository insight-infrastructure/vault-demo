terraform {
  required_version = ">= 0.12"
}

variable "id" {
  default = ""
}

resource "random_pet" "this" {
  length = 2
}

locals {
  id   = var.id == "" ? random_pet.this.id : var.id
}

variable "ca_public_key_file_path" {}
variable "public_key_file_path" {}
variable "private_key_file_path" {}
variable "owner" {}
variable "organization_name" {}
variable "ca_common_name" {}
variable "common_name" {}
variable "dns_names" {}
variable "validity_period_hours" {}

module "tls_cert" {
  source = "github.com/hashicorp/terraform-aws-vault//modules/private-tls-cert?ref=v0.13.11"
  ca_public_key_file_path = var.ca_public_key_file_path
  public_key_file_path = var.public_key_file_path
  private_key_file_path = var.private_key_file_path
  owner = var.owner
  organization_name = var.organization_name
  ca_common_name = var.ca_common_name
  common_name = var.common_name
  dns_names = var.dns_names
}

module "packer" {
  source = "github.com/insight-infrastructure/terraform-aws-packer-ami.git?ref=master"

  packer_config_path = "${path.module}/vault-consul-ami/vault-consul-ubuntu.json"
  timestamp_ui       = true
  vars = {
    id = local.id
    tls_public_key_path = ""
  }
}

// Was having issues in some regions so put in a sleep to fix
resource "null_resource" "wait" {
  triggers = {
    time = timestamp()
  }

  provisioner "local-exec" {
    command = "sleep 10"
  }

  depends_on = [module.packer]
}

data "aws_ami" "vault_consul" {
  most_recent = true

  filter {
    name   = "tag:Id"
    values = [local.id]
  }

  owners = ["self"]
  depends_on = [module.packer.packer_command, null_resource.wait]
}

// Building manually
//data "aws_ami" "vault_consul" {
//  most_recent = true
//  owners = ["self"]
//  tags = {
//    Name = "vault-consul-ubuntu-18"
//  }
//}

module "vault_cluster" {
 
  source = "github.com/hashicorp/terraform-aws-vault//modules/vault-cluster?ref=v0.13.11"

  cluster_name  = var.vault_cluster_name
  cluster_size  = var.vault_cluster_size
  instance_type = var.vault_instance_type

  ami_id    = var.ami_id == null ? data.aws_ami.vault_consul.image_id : var.ami_id
  user_data = data.template_file.user_data_vault_cluster.rendered

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  health_check_type = "EC2"

  allowed_ssh_cidr_blocks              = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks          = ["0.0.0.0/0"]
  allowed_inbound_security_group_ids   = []
  allowed_inbound_security_group_count = 0
  ssh_key_name                         = var.ssh_key_name
}

resource "aws_iam_role_policy" "vault_iam_policy" {
  name = "vault_iam"
  role = module.vault_cluster.iam_role_id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "iam:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

module "consul_iam_policies_servers" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.7.7"

  iam_role_id = module.vault_cluster.iam_role_id
}

data "template_file" "user_data_vault_cluster" {
  template = file("${path.module}/user-data/user-data-vault.sh")

  vars = {
    aws_region               = data.aws_region.current.name
    consul_cluster_tag_key   = var.consul_cluster_tag_key
    consul_cluster_tag_value = var.consul_cluster_name
  }
}

module "security_group_rules" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-client-security-group-rules?ref=v0.7.7"

  security_group_id = module.vault_cluster.security_group_id

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
}

module "vault_elb" {

  source = "github.com/hashicorp/terraform-aws-vault//modules/vault-elb?ref=v0.13.11"

  name = var.vault_cluster_name

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  vault_asg_name = module.vault_cluster.asg_name

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]

  create_dns_entry = var.create_dns_entry

  hosted_zone_id = var.create_dns_entry ? join("", data.aws_route53_zone.selected.*.zone_id) : ""

  domain_name = var.vault_domain_name
}

data "aws_route53_zone" "selected" {
  count = var.create_dns_entry ? 1 : 0
  name  = "${var.hosted_zone_domain_name}."
}

module "consul_cluster" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.7.7"

  cluster_name  = var.consul_cluster_name
  cluster_size  = var.consul_cluster_size
  instance_type = var.consul_instance_type

  cluster_tag_key   = var.consul_cluster_tag_key
  cluster_tag_value = var.consul_cluster_name

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  ami_id    = var.ami_id == null ? data.aws_ami.vault_consul.image_id : var.ami_id
  user_data = data.template_file.user_data_consul.rendered

  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = var.ssh_key_name
}

data "template_file" "user_data_consul" {
  template = file("${path.module}/user-data/user-data-consul.sh")

  vars = {
    consul_cluster_tag_key   = var.consul_cluster_tag_key
    consul_cluster_tag_value = var.consul_cluster_name
  }
}

data "aws_region" "current" {}