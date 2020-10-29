# Create a Virtual Network within the Resource Group
resource azurerm_virtual_network main {
  name                = "${random_id.randomId.hex}-network"
  address_space       = [var.cidr]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Create the Management Subnet within the Virtual Network
resource azurerm_subnet mgmt {
  name                 = "mgmt"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [var.subnets["management"]]
}

# Create the external IPS subnet within the Vnet
resource azurerm_subnet inspect_external {
  name                 = "inspect_external"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [var.subnets["inspect_ext"]]
}
# Create the internal IPS subnet within the Vnet
resource azurerm_subnet inspect_internal {
  name                 = "inspect_internal"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [var.subnets["inspect_int"]]
}