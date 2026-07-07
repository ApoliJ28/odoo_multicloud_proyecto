resource "aws_ecr_repository" "odoo_app" {
    name                 = "odoo-app"
    image_tag_mutability = "MUTABLE"
    force_delete         = true
    image_scanning_configuration {
        scan_on_push = true
    }
}

# Genera una contraseña aleatoria para la base de datos de Odoo
# resource "random_password" "db_password" {
#   length           = 16
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }

# Crea un secreto en AWS Secrets Manager para almacenar las credenciales de la base de datos
resource "aws_secretsmanager_secret" "odoo_db_credentials" {
  name        = "odoo-db-credentials"
  description = "Credenciales inyectadas dinámicamente a EKS"
  
  # Permite destruir el secreto sin esperar 30 días
  recovery_window_in_days = 0 
}

# El contenido del secreto se define en la versión del secreto, que puede ser actualizado dinámicamente
resource "aws_secretsmanager_secret_version" "odoo_db_credentials_version" {
    secret_id     = aws_secretsmanager_secret.odoo_db_credentials.id
    secret_string = jsonencode({
        db_host        = "odoo-db-service"
        db_user        = var.db_user
        db_password    = var.db_password
        admin_password = var.admin_password
    })
}