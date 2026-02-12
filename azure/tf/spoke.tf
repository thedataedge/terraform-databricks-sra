resource "azurerm_resource_group" "spoke" {
  for_each = var.spokes

  location = var.location
  name     = "rg-${each.value.resource_suffix}"
  tags     = var.tags
}

module "spoke_network" {
  source   = "./modules/virtual_network"
  for_each = var.create_workspace_vnet ? var.spokes : {}

  # Azure Parameters
  resource_suffix     = each.value.resource_suffix
  tags                = var.tags
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  location            = var.location

  # Networking Parameters
  vnet_cidr                = each.value.workspace_vnet.cidr
  route_table_id           = var.create_hub ? module.hub[0].route_table_id : var.existing_hub_vnet.route_table_id
  ipgroup_id               = var.create_hub ? module.hub[0].ipgroup_id : null
  virtual_network_peerings = var.create_hub ? { hub = { remote_virtual_network_id = module.hub[0].vnet_id } } : { hub = { remote_virtual_network_id = var.existing_hub_vnet.vnet_id } }
  workspace_subnets = {
    create          = true
    new_bits        = each.value.workspace_vnet.new_bits
    add_to_ip_group = var.create_hub
  }
}

module "spoke_workspace" {
  source   = "./modules/workspace"
  for_each = var.spokes

  # Azure/Network parameters
  location                     = var.location
  resource_suffix              = each.value.resource_suffix
  resource_group_name          = azurerm_resource_group.spoke[each.key].name
  tags                         = var.tags
  enhanced_security_compliance = var.workspace_security_compliance
  name_overrides               = var.workspace_name_overrides
  network_configuration        = module.spoke_network[each.key].network_configuration
  dns_zone_ids                 = module.spoke_network[each.key].dns_zone_ids

  # KMS parameters
  is_kms_enabled          = var.cmk_enabled
  managed_disk_key_id     = local.cmk_managed_disk_key_id
  managed_services_key_id = local.cmk_managed_services_key_id
  key_vault_id            = local.cmk_keyvault_id

  # Account parameters
  ncc_id                   = var.create_hub ? module.hub[0].ncc_id : var.existing_ncc_id
  ncc_name                 = var.create_hub ? module.hub[0].ncc_name : var.existing_ncc_name
  network_policy_id        = var.create_hub ? module.hub[0].network_policy_id : var.existing_network_policy_id
  metastore_id             = var.create_hub ? module.hub[0].metastore_id : var.databricks_metastore_id
  provisioner_principal_id = data.azurerm_client_config.current.object_id
  databricks_account_id    = var.databricks_account_id
}

# Legacy settings per spoke (required until unified provider). Separate blocks required (provider cannot be conditional).
resource "databricks_disable_legacy_dbfs_setting" "spoke_prod" {
  count = contains(keys(var.spokes), "prod") ? 1 : 0

  disable_legacy_dbfs {
    value = true
  }

  depends_on = [module.spoke_workspace]
  provider   = databricks.spoke_prod
}

resource "databricks_disable_legacy_dbfs_setting" "spoke_dev" {
  count = contains(keys(var.spokes), "dev") ? 1 : 0

  disable_legacy_dbfs {
    value = true
  }

  depends_on = [module.spoke_workspace]
  provider   = databricks.spoke_dev
}

resource "databricks_disable_legacy_access_setting" "spoke_prod" {
  count = contains(keys(var.spokes), "prod") ? 1 : 0

  disable_legacy_access {
    value = true
  }

  depends_on = [module.spoke_workspace]
  provider   = databricks.spoke_prod
}

resource "databricks_disable_legacy_access_setting" "spoke_dev" {
  count = contains(keys(var.spokes), "dev") ? 1 : 0

  disable_legacy_access {
    value = true
  }

  depends_on = [module.spoke_workspace]
  provider   = databricks.spoke_dev
}

# Catalog per spoke (separate module blocks required for static provider references)
module "spoke_catalog_prod" {
  count  = contains(keys(var.spokes), "prod") ? 1 : 0
  source = "./modules/catalog"

  catalog_name         = module.spoke_workspace["prod"].resource_suffix
  is_default_namespace = true

  dns_zone_ids        = module.spoke_workspace["prod"].dns_zone_ids
  location            = var.location
  resource_group_name = module.spoke_workspace["prod"].resource_group_name
  resource_suffix     = module.spoke_workspace["prod"].resource_suffix
  subnet_id           = module.spoke_workspace["prod"].subnet_ids.privatelink
  tags                = module.spoke_workspace["prod"].tags

  databricks_account_id = var.databricks_account_id
  metastore_id          = var.create_hub ? module.hub[0].metastore_id : var.databricks_metastore_id
  ncc_id                = module.spoke_workspace["prod"].ncc_id
  ncc_name              = module.spoke_workspace["prod"].ncc_name

  force_destroy = var.catalog_force_destroy

  providers = {
    databricks.workspace = databricks.spoke_prod
  }
}

module "spoke_catalog_dev" {
  count  = contains(keys(var.spokes), "dev") ? 1 : 0
  source = "./modules/catalog"

  catalog_name         = module.spoke_workspace["dev"].resource_suffix
  is_default_namespace = true

  dns_zone_ids        = module.spoke_workspace["dev"].dns_zone_ids
  location            = var.location
  resource_group_name = module.spoke_workspace["dev"].resource_group_name
  resource_suffix     = module.spoke_workspace["dev"].resource_suffix
  subnet_id           = module.spoke_workspace["dev"].subnet_ids.privatelink
  tags                = module.spoke_workspace["dev"].tags

  databricks_account_id = var.databricks_account_id
  metastore_id          = var.create_hub ? module.hub[0].metastore_id : var.databricks_metastore_id
  ncc_id                = module.spoke_workspace["dev"].ncc_id
  ncc_name              = module.spoke_workspace["dev"].ncc_name

  force_destroy = var.catalog_force_destroy

  providers = {
    databricks.workspace = databricks.spoke_dev
  }
}
