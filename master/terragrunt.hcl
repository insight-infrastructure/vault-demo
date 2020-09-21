locals {
  vars = read_terragrunt_config(find_in_parent_folders("${get_parent_terragrunt_dir()}/variables.hcl")).locals
}

inputs = merge(
local.vars,
local.vars.environment,
local.vars.secrets,
)

generate "provider" {
  path = "tg-provider.tf"
  if_exists = "skip"
  contents =<<-EOF
variable "vault_address" {
  description = "Enter the vault cluster elastic load balancer address"
  type        = string
  default     = ""
}

variable "developer_token" {
  description = "Enter Temporary token. User can generate token by login in vault with userpass"
  type        = string
  default     = ""
}

data "terraform_remote_state" "admin" {
  backend = "local"

  config = {
    path = "${var.path}"
  }
}

provider "vault" {
    address         = var.vault_address
    token           = var.developer_token
    skip_tls_verify = "true"
}

data "vault_aws_access_credentials" "creds" {
  backend = var.aws_backend
  role    = var.aws_role
}

provider "aws" {
  region = "${local.vars.region}"
  skip_get_ec2_platforms     = true
  skip_metadata_api_check    = true
  skip_region_validation     = true
  skip_requesting_account_id = true

  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt = true
    region = "us-east-1"
    key = "${local.vars.remote_state_path}/${path_relative_to_include()}/terraform.tfstate"
    bucket = "terraform-states-${get_aws_account_id()}"
    dynamodb_table = "terraform-locks-${get_aws_account_id()}"
  }

  generate = {
    path = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
