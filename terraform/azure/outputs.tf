output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.services.acr_login_server
}

output "key_vault_uri" {
  value = module.services.key_vault_uri
}