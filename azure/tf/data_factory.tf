resource "azurerm_data_factory" "spoke" {
  for_each = var.spokes

  name                = "adf-${each.value.resource_suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  tags                = var.tags
}
