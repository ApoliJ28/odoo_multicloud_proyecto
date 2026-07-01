output "jenkins_public_ip" {
  description = "IP Pública para que Ansible se conecte"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_private_key" {
  description = "Llave SSH privada generada dinámicamente"
  value       = tls_private_key.jenkins_key.private_key_pem
  sensitive   = true
}