locals {
  env = "dev"
  region = "us-east-1"

  secrets = yamldecode(file(find_in_parent_folders("secrets.yml")))

  environment = {
    dev = {
      domain_name = "insight-infra.de"
    }
    prod = {}
  }[local.env]

  # Remote State
  remote_state_path = "${local.env}/master"
}