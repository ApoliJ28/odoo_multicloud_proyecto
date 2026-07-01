resource "aws_ecr_repository" "odoo_app" {
    name                 = "odoo-app"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
        scan_on_push = true
    }
}

resource "aws_secretsmanager_secret" "odoo_db_credentials" {
    name        = "odoo/db-credentials"
    description = "Credenciales inyectadas dinámicamente a EKS"
}