output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = module.services.ecr_url
}

output "secrets_manager_arn" {
  value = module.services.secrets_arn
}

output "jenkins_server_ip" {
  value = module.jenkins.jenkins_public_ip
}

output "jenkins_ssh_private_key" {
  value     = module.jenkins.jenkins_private_key
  sensitive = true
}