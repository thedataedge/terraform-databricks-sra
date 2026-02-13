# The below mocked providers have mock_data blocks anywhere a properly formatted GUID is used in the configuration
# (i.e. access policies, role assignments, etc.)
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
      object_id = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azurerm_subscription" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_application_published_app_ids" {
    defaults = {
      result = {
        AzureDataBricks = "00000000-0000-0000-0000-000000000000"
      }
    }
  }
  mock_data "azuread_service_principal" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "databricks" {
  mock_data "databricks_user" {
    defaults = {
      id = 0
    }
  }
}

mock_provider "databricks" {
  alias = "SAT"
}

run "plan_test_defaults" {
  command   = plan
}

run "plan_test_sat_broken_classic" {
  command         = plan
  expect_failures = [var.allowed_fqdns]
  variables {
    sat_configuration = {
      enabled = true
    }
    allowed_fqdns    = []
    hub_allowed_urls = []
  }
}

run "plan_test_sat_broken_serverless" {
  command         = plan
  expect_failures = [var.hub_allowed_urls]
  variables {
    sat_configuration = {
      enabled           = true
      run_on_serverless = true
    }
    allowed_fqdns    = []
    hub_allowed_urls = []
  }
}

run "plan_test_sat_with_byosp" {
  command   = plan
  variables {
    allowed_fqdns = ["management.azure.com", "login.microsoftonline.com", "python.org", "*.python.org", "pypi.org", "*.pypi.org", "pythonhosted.org", "*.pythonhosted.org"]
    sat_configuration = {
      enabled = true
    }
    sat_service_principal = {
      client_id     = ""
      client_secret = ""
    }
  }
}

run "plan_test_sat_nondefaults" {
  command   = plan
  variables {
    allowed_fqdns = ["management.azure.com", "login.microsoftonline.com", "python.org", "*.python.org", "pypi.org", "*.pypi.org", "pythonhosted.org", "*.pythonhosted.org"]
    sat_configuration = {
      enabled           = true
      proxies           = { "http_proxy" : "http://localhost:80" }
      run_on_serverless = false
      schema_name       = "notsat"
      catalog_name      = "notsat"
    }
  }
}

run "plan_test_byo_hub_with_spoke" {
  command   = plan
  variables {
    create_hub              = false
    databricks_metastore_id = "00000000-0000-0000-0000-000000000000"
    tags                    = { example = "value" }

    spokes = {
      prod = {
        resource_suffix = "spoke"
        workspace_vnet  = { cidr = "10.0.2.0/24", new_bits = null }
      }
      dev = {
        resource_suffix = "spoke-dev"
        workspace_vnet  = { cidr = "10.0.2.0/24", new_bits = null }
      }
    }

    existing_ncc_id            = "mock-ncc-id"
    existing_ncc_name          = "mock-ncc"
    existing_network_policy_id = "mock-policy-id"
    existing_cmk_ids = {
      key_vault_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock-kv"
      managed_disk_key_id     = "https://example-keyvault.vault.azure.net/keys/example/fdf067c93bbb4b22bff4d8b7a9a56217"
      managed_services_key_id = "https://example-keyvault.vault.azure.net/keys/example/fdf067c93bbb4b22bff4d8b7a9a56217"
    }

    existing_hub_vnet = {
      route_table_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-external-hub/providers/Microsoft.Network/routeTables/rt-external"
      vnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-external-hub/providers/Microsoft.Network/virtualNetworks/vnet-external-hub"
    }
  }
}

# plan_test_byo_hub_byo_network removed: create_workspace_vnet=false with existing_workspace_vnet
# is not supported in the current multi-spoke architecture (spoke.tf always references
# module.spoke_network which is empty when create_workspace_vnet=false).

run "plan_test_cmk_disabled" {
  command   = plan
  variables {
    cmk_enabled = false
    spokes = {
      prod = {
        resource_suffix = "nocmk"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
      dev = {
        resource_suffix = "nocmk-dev"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
    }
  }
}

run "plan_test_enhanced_security" {
  command   = plan
  variables {
    spokes = {
      prod = {
        resource_suffix = "secure"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
      dev = {
        resource_suffix = "secure-dev"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
    }
    workspace_security_compliance = {
      automatic_cluster_update_enabled      = true
      compliance_security_profile_enabled   = true
      compliance_security_profile_standards = ["HIPAA", "PCI_DSS"]
      enhanced_security_monitoring_enabled  = true
    }
  }
}

run "plan_test_byo_resource_group" {
  command   = plan
  variables {
    spokes = {
      prod = {
        resource_suffix                 = "byorg"
        create_workspace_resource_group = false
        workspace_vnet                 = { cidr = "10.1.0.0/20", new_bits = null }
      }
      dev = {
        resource_suffix                 = "byorg-dev"
        create_workspace_resource_group = false
        workspace_vnet                 = { cidr = "10.1.0.0/20", new_bits = null }
      }
    }
  }
}

run "plan_test_name_overrides" {
  command   = plan
  variables {
    spokes = {
      prod = {
        resource_suffix = "custom"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
      dev = {
        resource_suffix = "custom-dev"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = null }
      }
    }
    workspace_name_overrides = {
      databricks_workspace = "my-custom-workspace"
      private_endpoint     = "pe-custom-databricks"
    }
  }
}

run "plan_test_custom_subnet_sizing" {
  command   = plan
  variables {
    spokes = {
      prod = {
        resource_suffix = "customsubs"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = 3 }
      }
      dev = {
        resource_suffix = "customsubs-dev"
        workspace_vnet  = { cidr = "10.1.0.0/20", new_bits = 3 }
      }
    }
  }
}
