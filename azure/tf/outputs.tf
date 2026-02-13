output "hub_network_subnets" {
  description = "Subnets created in the hub network"
  value       = var.create_hub ? module.hub[0].network_cidr_blocks : null
}

output "hub_resource_group_name" {
  description = "Name of created hub resource group"
  value       = var.create_hub ? azurerm_resource_group.hub[0].name : null
}

#output "hub_workspace_info" {
#  description = "URLs for the one (or more) deployed Databricks Workspaces"
#  value       = var.create_hub ? [azurerm_resource_group.hub[0].name, module.webauth_workspace[0].workspace_url] : null
#}

output "spoke_workspace_info" {
  description = "Information for each deployed spoke Databricks workspace (keyed by spoke name: prod, dev)"
  value = {
    for k, v in module.spoke_workspace : k => {
      resource_group_name = v.resource_group_name
      workspace_url       = v.workspace_url
      workspace_id        = v.workspace_id
    }
  }
}

output "spoke_workspace_catalog" {
  description = "Catalog name for each spoke workspace (keyed by spoke name: prod, dev)"
  value = merge(
    length(module.spoke_catalog_prod) > 0 ? { prod = module.spoke_catalog_prod[0].catalog_name } : {},
    length(module.spoke_catalog_dev) > 0 ? { dev = module.spoke_catalog_dev[0].catalog_name } : {}
  )
}

output "spoke_data_factory_info" {
  description = "Data Factory ID and name per spoke"
  value = {
    for k, v in azurerm_data_factory.spoke : k => {
      id   = v.id
      name = v.name
    }
  }
}
