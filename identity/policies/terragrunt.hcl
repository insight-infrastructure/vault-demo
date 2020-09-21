terraform {
  source = "."
}

include {
  path = find_in_parent_folders()
  vault = find_in_parent_folders("vault")
}

dependencies {
  paths = [local.vault]
}

dependency "vault" {
  config_path = local.vault
}

inputs = {
  vault_address = dependency.vault.outputs.vault_address
//  vault_token = dependency.vault.outputs.vault_token
}
