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

resource "azurerm_kubernetes_cluster" "aks" {
    name = var.aks_name
    location = azurerm_resource_group.tf-group.location
    resource_group_name = azurerm_resource_group.tf-group.name
    dns_prefix = "myaks"
    network_profile {
      network_plugin = "azure"
      service_cidr = "10.1.0.0/16"
      dns_service_ip = "10.1.0.10"
    }
    default_node_pool {
        name       = "default"
        node_count = 2
        vm_size   = "Standard_B2ms"
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
    role_definition_name = "AcrPull"
}

resource "azuread_application" "github_actions" {
    display_name = "gh-app"
}

resource "azuread_service_principal" "github_actions" {
    client_id = azuread_application.github_actions.client_id
}

resource "azuread_service_principal_password" "github_actions" {
    service_principal_id = azuread_service_principal.github_actions.id
    display_name = "github-actions-secret"
    end_date = timeadd(timestamp(),"17520h")
}

resource "azurerm_role_assignment" "github_actions_acr" {
    principal_id         = azuread_service_principal.github_actions.id
    scope                = azurerm_container_registry.acr.id
    role_definition_name = "AcrPull"
}