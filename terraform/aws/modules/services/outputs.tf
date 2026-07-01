output "ecr_url" {
  value = aws_ecr_repository.odoo_app.repository_url
}

output "secrets_arn" {
  value = aws_secretsmanager_secret.odoo_db_credentials.arn
}