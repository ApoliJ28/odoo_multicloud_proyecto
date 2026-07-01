resource "azurerm_container_registry" "acr" {
  # El nombre de ACR debe ser globalmente único y sin caracteres especiales
  name                = "odooappacr" 
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true
}

resource "azurerm_key_vault" "kv" {
  # El nombre de Key Vault debe ser globalmente único
  name                        = "odoo-kv" 
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id
    secret_permissions = ["Get", "List", "Set", "Delete"]
  }
}

resource "azurerm_key_vault_secret" "odoo_db_credentials" {
  name         = "odoo-db-credentials"
  value        = "{\"placeholder\":\"se-inyectara-desde-jenkins\"}"
  key_vault_id = azurerm_key_vault.kv.id
}