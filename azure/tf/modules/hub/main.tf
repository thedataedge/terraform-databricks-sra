module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~>0.4"
  suffix  = [var.resource_suffix]
}

# Create hub network infrastructure
module "hub_network" {
  source = "../virtual_network"

  vnet_cidr           = var.vnet_cidr
  resource_suffix     = var.resource_suffix
  tags                = var.tags
  resource_group_name = var.resource_group_name
  location            = var.location
  has_backend         = var.has_backend

  # Reference resources created in firewall.tf
  route_table_id = azurerm_route_table.this.id
  ipgroup_id     = azurerm_ip_group.this.id

  virtual_network_peerings = var.virtual_network_peerings

  # Hub does not host Databricks workspaces; container and host subnets are only needed in spokes
  workspace_subnets = {
    create          = var.create_workspace_subnets
    add_to_ip_group = false
  }

  # Basic SKU requires AzureFirewallManagementSubnet for its management NIC
  extra_subnets = merge(
    {
      AzureFirewallSubnet = {
        name     = "AzureFirewallSubnet"
        new_bits = 26 - split("/", var.vnet_cidr)[1]
      }
    },
    var.is_firewall_enabled && var.firewall_sku == "Basic" ? {
      AzureFirewallManagementSubnet = {
        name     = "AzureFirewallManagementSubnet"
        new_bits = 26 - split("/", var.vnet_cidr)[1]
      }
    } : {}
  )
}
