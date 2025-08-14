terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }
  required_version = ">= 1.0"
}
provider "azurerm" {
  features {}
}
provider "http" {}
provider "azuread" {}
data "azuread_client_config" "current" {}
locals {
  common_tags = {
    environment = var.environment
    owner       = var.owner
  }
}

resource "azurerm_resource_group" "tf-group" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "tf-vnet" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.tf-group.location
  resource_group_name = azurerm_resource_group.tf-group.name
}

module "subnet-1" {
  source               = "./modules/subnet"
  name                 = "tf-subnet-1"
  resource_group_name  = azurerm_resource_group.tf-group.name
  virtual_network_name = azurerm_virtual_network.tf-vnet.name
  address_prefixes     = ["10.0.0.0/26"]
}

module "subnet-2" {
  source               = "./modules/subnet"
  name                 = "sql-subnet"
  resource_group_name  = azurerm_resource_group.tf-group.name
  virtual_network_name = azurerm_virtual_network.tf-vnet.name
  address_prefixes     = ["10.0.0.64/26"]
  service_endpoints    = ["Microsoft.Storage"]
  delegations = [{
    name = "fs"
    service_delegation = {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.tf-group.location
  resource_group_name = azurerm_resource_group.tf-group.name
  dns_prefix          = "myaks"
  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }
  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_B2ms"
    vnet_subnet_id = module.subnet-1.subnet_id
  }
  identity {
    type = "SystemAssigned"
  }
  kubernetes_version = "1.33"
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = azurerm_resource_group.tf-group.location
  resource_group_name = azurerm_resource_group.tf-group.name
  sku                 = "Premium"
  admin_enabled       = true
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aks_acr" {
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
}

resource "azuread_application" "github_actions" {
  display_name = "gh-app"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

resource "azuread_service_principal_password" "github_actions" {
  service_principal_id = azuread_service_principal.github_actions.id
  display_name         = "github-actions-secret"
  end_date             = timeadd(timestamp(), "17520h")
}

resource "azurerm_role_assignment" "github_actions_acr" {
  principal_id         = azuread_service_principal.github_actions.id
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "kiszka-kis1.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.tf-group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "sql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.tf-vnet.id
  resource_group_name   = azurerm_resource_group.tf-group.name
  depends_on = [
    azurerm_private_dns_zone.sql,
    azurerm_virtual_network.tf-vnet,
    module.subnet-2
  ]
}

resource "azurerm_postgresql_flexible_server" "pgsql" {
  name                          = "kiszka-pgsqlserver-poland"
  resource_group_name           = azurerm_resource_group.tf-group.name
  location                      = "polandcentral"
  version                       = "16"
  zone                          = "1"
  delegated_subnet_id           = module.subnet-2.subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.sql.id
  public_network_access_enabled = false
  administrator_login           = "psqladmin"
  administrator_password        = "psqladmin"
  sku_name                      = "B_Standard_B1ms"
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.sql_dns_link]
}

resource "azurerm_network_security_group" "tf-nsg" {
  name                = "tf-nsg"
  location            = azurerm_resource_group.tf-group.location
  resource_group_name = azurerm_resource_group.tf-group.name
  security_rule {
    name                       = "AllowHTTPInbound-tf"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_ssh_ip[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowHTTPSInbound-tf"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.allowed_ssh_ip[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSpringInbound-tf"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.allowed_ssh_ip[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "tf-nic-nsg" {
  subnet_id                 = module.subnet-1.subnet_id
  network_security_group_id = azurerm_network_security_group.tf-nsg.id
}