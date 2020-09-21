terraform {
  source = "."
}

include {
  path = find_in_parent_folders()
}

locals {
  network = find_in_parent_folders("network")
}

dependencies {
  paths = [local.network]
}

dependency "network" {
  config_path = local.network
}

inputs = {
  vpc_id = dependency.network.outputs.vpc_id
  subnet_ids = [ for i in range(3) : dependency.network.outputs.subnet_ids[i] ]
}
