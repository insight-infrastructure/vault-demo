variable "vault_address" {
  default = ""
  type = string
}

variable "vault_token" {
  default = ""
  type = string
}

provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = "true"
}