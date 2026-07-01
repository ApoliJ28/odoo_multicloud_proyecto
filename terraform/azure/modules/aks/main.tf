resource "azurerm_kubernetes_cluster" "main" {
  name                = "odoo-azure-aks-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "odoo-aks"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }
}