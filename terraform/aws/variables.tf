variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "nombre_proyecto" {
  description = "Nombre del proyecto"
  type        = string
  default     = "odoo-multicloud-terraform"
}

variable "vpc_cidr" {
  description = "Rango CIDR para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "access_key" {
    description = "AWS access key"
    type        = string
}

variable "secret_key" {
    description = "AWS secret key"
    type        = string
}

variable "session_token" {
    description = "AWS session token"
    type        = string
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