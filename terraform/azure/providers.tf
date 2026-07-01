terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # Configuración del estado remoto para Azure
  backend "azurerm" {
    resource_group_name  = "odoo-multicloud-terraform-state-rg"
    storage_account_name = "odoo-statestorage"
    container_name       = "odoo-state"
    key                  = "azure/terraform.tfstate"
  }
}

provider "azurerm" {
    
    subscription_id = var.subscription_id
    tenant_id       = var.tenant_id
    client_id       = var.client_id
    client_secret   = var.client_secret

    features {
        key_vault {
        purge_soft_delete_on_destroy    = true
        recover_soft_deleted_key_vaults = true
        }
    }
}