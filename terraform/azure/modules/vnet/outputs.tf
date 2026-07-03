output "vnet_id" { 
  value = azurerm_virtual_network.main.id 
}

output "private_subnets_ids" {
  value = azurerm_subnet.private[*].id
}

output "public_subnets_ids" {
  value = azurerm_subnet.public[*].id
}