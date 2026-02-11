databricks_account_id  = "databricks-account-id"
location               = "eastus2"
hub_vnet_cidr          = "10.0.0.0/23"
hub_resource_suffix    = "test"

spokes = {
  prod = {
    resource_suffix = "test-prod"
    workspace_vnet = {
      cidr     = "10.0.4.0/22"
      new_bits = 2
    }
  }
  dev = {
    resource_suffix = "test-dev"
    workspace_vnet = {
      cidr     = "10.0.8.0/22"
      new_bits = 2
    }
  }
}

tags = {
  example = "value"
}
subscription_id = "00000"
