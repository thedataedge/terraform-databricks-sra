provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}

# Account-level Databricks provider.
# Uses databricks_azure_client_id + TF_VAR_databricks_azure_client_secret.
# Alternative: set DATABRICKS_CONFIG_PROFILE env var to use ~/.databrickscfg (see databrickscfg.example).
provider "databricks" {
  host                 = "https://accounts.azuredatabricks.net"
  account_id           = var.databricks_account_id
  auth_type            = "azure-client-secret"
  azure_client_id      = var.databricks_azure_client_id
  azure_client_secret  = var.databricks_azure_client_secret
  azure_tenant_id      = var.azure_tenant_id
}

# Hub provider (used if SAT/customizations are enabled; webauth workspace is optional)
provider "databricks" {
  alias = "hub"
  host  = "https://placeholder.azuredatabricks.net"
}

# Spoke providers (one per spoke; required for catalog and legacy settings in each workspace)
provider "databricks" {
  alias = "spoke_prod"
  host  = try(module.spoke_workspace["prod"].workspace_url, "https://placeholder.azuredatabricks.net")
}

provider "databricks" {
  alias = "spoke_dev"
  host  = try(module.spoke_workspace["dev"].workspace_url, "https://placeholder.azuredatabricks.net")
}

# These blocks are not required by terraform, but they are here to silence TFLint warnings
provider "null" {}

provider "time" {}
