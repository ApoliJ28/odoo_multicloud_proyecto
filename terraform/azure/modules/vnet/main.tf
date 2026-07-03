# VNet Principal (Equivalente a VPC)
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.nombre_proyecto}-main"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    Name = "vnet-${var.nombre_proyecto}-main"
  }
}

# Subredes Públicas (Dinámicas para alta disponibilidad)
resource "azurerm_subnet" "public" {
  count                = 2
  name                 = "subnet-${var.nombre_proyecto}-pub-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  # Se asume que var.vnet_address_space es una lista, ej: ["10.1.0.0/16"]
  address_prefixes     = [cidrsubnet(var.vnet_address_space[0], 8, count.index + 1)]
}

# Subredes Privadas (Dinámicas para alta disponibilidad)
# Aquí es donde vivira el clúster de AKS por seguridad
resource "azurerm_subnet" "private" {
  count                = 2
  name                 = "subnet-${var.nombre_proyecto}-priv-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space[0], 8, count.index + 10)]
}

# Configuración de Salida a Internet (NAT)

# IP Pública Estática para el NAT Gateway (Equivalente al Elastic IP de AWS)
resource "azurerm_public_ip" "nat_pip" {
  name                = "pip-${var.nombre_proyecto}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard" # Requisito estricto para NAT Gateways en Azure
  tags = {
    Name = "pip-${var.nombre_proyecto}-nat"
  }
}

# NAT Gateway
resource "azurerm_nat_gateway" "nat" {
  name                    = "nat-${var.nombre_proyecto}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags = {
    Name = "nat-${var.nombre_proyecto}"
  }
}

# Asociación de la IP Pública al NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Asociación del NAT Gateway a las Subredes Privadas
# (En Azure se asocia a la subred, no a la tabla de enrutamiento como en AWS)
resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = 2
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# Tablas de Enrutamiento (Route Tables)
# Route Table Pública
resource "azurerm_route_table" "public" {
  name                = "rt-${var.nombre_proyecto}-public"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Ruta explícita hacia Internet (Equivalente al Internet Gateway de AWS)
  route {
    name           = "InternetOutbound"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = {
    Name = "rt-${var.nombre_proyecto}-public"
  }
}

# Asociación Route Table Pública
resource "azurerm_subnet_route_table_association" "public" {
  count          = 2
  subnet_id      = azurerm_subnet.public[count.index].id
  route_table_id = azurerm_route_table.public.id
}

# Route Table Privada
resource "azurerm_route_table" "private" {
  name                = "rt-${var.nombre_proyecto}-private"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Nota: En Azure, no necesitamos declarar explícitamente el NAT Gateway aquí.
  # Al haber asociado el NAT Gateway directamente a la subred arriba, Azure
  # sobrescribe la ruta de salida automáticamente con máxima prioridad.

  tags = {
    Name = "rt-${var.nombre_proyecto}-private"
  }
}

# Asociación Route Table Privada
resource "azurerm_subnet_route_table_association" "private" {
  count          = 2
  subnet_id      = azurerm_subnet.private[count.index].id
  route_table_id = azurerm_route_table.private.id
}