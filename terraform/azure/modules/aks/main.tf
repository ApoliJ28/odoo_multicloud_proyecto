resource "azurerm_kubernetes_cluster" "main" {
  name                = "odoo-azure-aks-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "odoo-aks"

  oidc_issuer_enabled = true # Activar ODIC para que cuando creemos el ServiceAccount en Kubernetes, podamos usarlo para autenticar con Azure Key Vault y obtener secretos de manera segura.

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_B2s"
    vnet_subnet_id = var.subnet_private_ids[0]
  }

  identity {
    type = "SystemAssigned"
  }
}