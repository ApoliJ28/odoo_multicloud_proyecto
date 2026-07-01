variable "location" {
  description = "Región de Azure donde se desplegará la infraestructura"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Nombre del Grupo de Recursos principal"
  type        = string
  default     = "odoo-multicloud-rg"
}

variable "vnet_address_space" {
  description = "Espacio de direcciones para la VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subscription_id" {
  description = "ID de la Suscripción de Azure"
  type        = string
}

variable "tenant_id" {
  description = "ID del Tenant de Azure (Directorio)"
  type        = string
}

variable "client_id" {
  description = "ID de la Aplicación (Service Principal)"
  type        = string
}

variable "client_secret" {
  description = "Contraseña del Service Principal"
  type        = string
  sensitive   = true # Evita que imprima el valor en los logs de Terraform
}

variable "db_user" {
  description = "Usuario de la base de datos de Odoo"
  type        = string
}

variable "db_password" {
  description = "Contraseña de la base de datos de Odoo"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Contraseña de administrador de Odoo"
  type        = string
  sensitive   = true
}